import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DeskBookingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Flutter Flask Integration'),
        ),
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              try {
                final response = await http.post(
                  Uri.parse('http://10.0.2.2:5000/predict'), // 修改为正确的本地服务器地址
                  headers: <String, String>{
                    'Content-Type': 'application/json; charset=UTF-8',
                  },
                  body: jsonEncode(<String, String>{
                    'emp_id': 'EMP04', // Replace with the actual emp_id
                  }),
                );

                if (response.statusCode == 200) {
                  var result = jsonDecode(response.body);
                  print('Preferred desks: ${result}');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Preferred desks: ${result}')),
                  );
                } else {
                  print(
                      'Failed to predict desk, status code: ${response.statusCode}');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to predict desk')),
                  );
                }
              } catch (e) {
                print('Error during request: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error during request')),
                );
              }
            },
            child: Text('Predict Preferred Desk'),
          ),
        ),
      ),
    );
  }
}

void main() => runApp(DeskBookingScreen());
