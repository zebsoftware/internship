import 'package:flutter/material.dart';
// import 'package:practiceapp/currency_converter.dart';
import 'package:practiceapp/todo_page1.dart';


void main(){
  runApp( const Myapp());
}

class Myapp extends StatelessWidget{
   const Myapp({super.key});

   @override
   Widget build(BuildContext context){
    return const MaterialApp(
      home:Todo_Page1(),
      debugShowCheckedModeBanner: false,
    );
}
}