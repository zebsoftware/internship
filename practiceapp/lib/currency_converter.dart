import 'package:flutter/material.dart';

class CurrencyConverter extends StatelessWidget {
  const CurrencyConverter({super.key});
  @override
  Widget build(BuildContext context) {
    return  Scaffold(
    backgroundColor: Colors.black,
    body: Center(
      
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
       const Text("0",style: TextStyle(color: Color.fromARGB(255, 220, 222, 224),fontSize: 80),
        ),
        // SizedBox(),
           
        Container(
            padding:const EdgeInsets.all(8.0),
            child: TextField(
              style:  const TextStyle(
                color: Colors.cyanAccent
                
              ),
            
              decoration: InputDecoration(
                hintText: "ENTER THE AMOUNT IN USD",
                hintStyle: TextStyle(
                  color: Colors.black,
                ),
                filled: true,
                fillColor: Colors.white,
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    width: 2.0 ,
                    style: BorderStyle.solid
                  ),
                  borderRadius: BorderRadius.all(
                    Radius.circular(10)
                  ),
                )
              ),

            ),
          ),
           ElevatedButton(onPressed:null , 
           child: const Text("Calculate"),
           style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
           )
           ),
          
        ],
      ),
    ),

    );
  }

}