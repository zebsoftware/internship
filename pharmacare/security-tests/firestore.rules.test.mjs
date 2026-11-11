import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { after, before, beforeEach, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  setDoc,
  Timestamp,
  updateDoc,
} from 'firebase/firestore';

let environment;
let alice;
let bob;
let anonymous;

before(async () => {
  environment = await initializeTestEnvironment({
    projectId: 'demo-pharmacare-security',
    firestore: {
      rules: readFileSync(resolve('firestore.rules'), 'utf8'),
    },
  });
  alice = environment.authenticatedContext('alice', {
    email: 'alice@example.com',
  });
  bob = environment.authenticatedContext('bob', {
    email: 'bob@example.com',
  });
  anonymous = environment.unauthenticatedContext();
});

beforeEach(async () => {
  await environment.clearFirestore();
});

after(async () => {
  await environment?.cleanup();
});

const medicine = {
  name: 'Example medicine',
  batchNo: 'B-100',
  type: 'Tablet',
  quantity: 10,
  costPrice: 1,
  sellingPrice: 3,
  expiryDate: Timestamp.fromDate(new Date('2028-06-01T00:00:00Z')),
  createdAt: Timestamp.now(),
};

const order = {
  customerName: 'Test customer',
  customerPhone: '',
  customerEmail: '',
  items: [{
    medicineId: 'm1',
    medicineName: 'Example medicine',
    quantity: 1,
    price: 3,
    total: 3,
  }],
  subtotal: 3,
  tax: 0,
  totalAmount: 3,
  status: 'pending',
  paymentMethod: 'cash',
  notes: '',
  createdAt: Timestamp.now(),
  updatedAt: null,
};

test('only a signed-in owner can create and read their profile', async () => {
  const owner = doc(alice.firestore(), 'users/alice');
  const outsider = doc(bob.firestore(), 'users/alice');
  const publicRef = doc(anonymous.firestore(), 'users/alice');

  await assertSucceeds(setDoc(owner, {
    uid: 'alice',
    email: 'alice@example.com',
    accountType: 'pharmacy',
    isActive: true,
    createdAt: Timestamp.now(),
    fullName: 'Alice',
  }));

  await assertSucceeds(getDoc(owner));
  await assertFails(getDoc(outsider));
  await assertFails(getDoc(publicRef));
  await assertFails(updateDoc(owner, { accountType: 'admin' }));
  await assertFails(updateDoc(owner, { isActive: false }));
  await assertSucceeds(updateDoc(owner, { fullName: 'Alice Updated' }));
});

test('medicine records are private, validated, and never hard-deleted', async () => {
  const mine = doc(alice.firestore(), 'users/alice/medicines/m1');
  const theirs = doc(bob.firestore(), 'users/alice/medicines/m1');

  await assertSucceeds(setDoc(mine, medicine));
  await assertFails(getDoc(theirs));
  await assertFails(setDoc(theirs, medicine));
  await assertFails(updateDoc(mine, { quantity: -3 }));
  await assertFails(deleteDoc(mine));
  await assertSucceeds(updateDoc(mine, {
    archived: true,
    updatedAt: Timestamp.now(),
  }));
});

test('order totals are immutable and order statuses follow legal transitions', async () => {
  const mine = doc(alice.firestore(), 'users/alice/orders/o1');
  const theirs = doc(bob.firestore(), 'users/alice/orders/o1');

  await assertSucceeds(setDoc(mine, order));
  await assertFails(getDoc(theirs));
  await assertFails(updateDoc(mine, { totalAmount: 999 }));
  await assertFails(deleteDoc(mine));
  await assertSucceeds(updateDoc(mine, {
    status: 'processing',
    updatedAt: Timestamp.now(),
  }));
  await assertFails(updateDoc(mine, { status: 'pending' }));
  await assertFails(updateDoc(mine, { archived: true }));
  await assertSucceeds(updateDoc(mine, {
    status: 'cancelled',
    stockRestored: true,
    archived: true,
    updatedAt: Timestamp.now(),
  }));
});

test('settings preserve currency and stock adjustment records are append-only', async () => {
  const settings = doc(alice.firestore(), 'users/alice/settings/pharmacy');
  await assertSucceeds(setDoc(settings, {
    name: 'Example Pharmacy',
    currency: 'PKR',
    taxPercent: 0,
    lowStockThreshold: 20,
    expiryWarningDays: 60,
    alertsEnabled: true,
  }));
  await assertFails(updateDoc(settings, { currency: 'USD' }));

  const adjustment = doc(alice.firestore(), 'users/alice/stockAdjustments/a1');
  await assertSucceeds(setDoc(adjustment, {
    medicineId: 'm1',
    medicineName: 'Example medicine',
    quantityDelta: 3,
    reason: 'restock',
    note: '',
    createdAt: Timestamp.now(),
  }));
  await assertFails(updateDoc(adjustment, { quantityDelta: 1000 }));
  await assertFails(deleteDoc(adjustment));
});

test('legacy global collections are not accessible to clients', async () => {
  await assertFails(getDoc(doc(alice.firestore(), 'medicines/old-medicine')));
  await assertFails(getDoc(doc(alice.firestore(), 'orders/old-order')));
});
