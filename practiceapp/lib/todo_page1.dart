import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class Todo_Page1 extends StatelessWidget {
  const Todo_Page1({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
    backgroundColor: Colors.black,
    body: Center(
    
    child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        height: 100,
        width: 100,
        decoration: BoxDecoration(
          color: Colors.deepPurpleAccent,
          borderRadius: BorderRadius.circular(24)
        ),
        child: Icon(
          Icons.check,
          size: 80,
          color:Colors.white ,
        ),
      ),
      SizedBox(height: 20),
      Text(
        "UPTODO",
        style: TextStyle(
          
          fontSize: 40,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurpleAccent,
          letterSpacing: -1,
        ),
      ),
    ],
    ),

    ),

    );
  }
}