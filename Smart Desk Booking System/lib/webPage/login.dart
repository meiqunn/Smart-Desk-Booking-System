import 'package:firebase/webPage/Dashboard.dart';
import 'package:firebase/webPage/employee_home.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase/webPage/home_screen.dart';
import 'package:firebase/core/utils/image_constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _errorText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  ImageConstant.imgImage184x428,
                  height: 100,
                ),
                const SizedBox(height: 16),
                Container(
                  width:
                      500, // Set the width of the container to make it smaller
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Desk Booking System',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: TextField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email address',
                            border: const OutlineInputBorder(),
                            errorText: _errorText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: TextField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            border: const OutlineInputBorder(),
                            errorText: _errorText,
                          ),
                          obscureText: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 16),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                        child: const Text(
                          'Login',
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _showForgotPasswordDialog,
                        child: const Text(
                          'Forgot your password?',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Fetch employee data from Firestore based on email
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('employee')
          .where('email', isEqualTo: email)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        DocumentSnapshot userDoc = querySnapshot.docs.first;
        bool isAdmin = userDoc['admin'] ?? false;
        var empId = userDoc['ID'];

        if (isAdmin) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => Dashboard(
                      empId: empId,
                    )),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => EmployeeHomeScreen(
                      empId: empId,
                    )),
          );
        }
      } else {
        setState(() {
          _errorText = 'No employee found with this email.';
        });
      }
    } catch (e) {
      print('Error during login: $e');
      setState(() {
        _errorText = 'Invalid email or password. Please try again.';
      });
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final TextEditingController emailController = TextEditingController();
    String? dialogErrorText;

    return showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Forgot Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: Text(
                        'Enter your email address to receive a password reset link.'),
                  ),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'Email address',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      errorText: dialogErrorText,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    String email = emailController.text.trim();
                    if (email.isEmpty) {
                      setState(() {
                        dialogErrorText = 'Email cannot be empty';
                      });
                    } else if (!_isValidEmail(email)) {
                      setState(() {
                        dialogErrorText = 'Invalid email format';
                      });
                    } else {
                      setState(() {
                        dialogErrorText = null;
                      });
                      await _sendPasswordResetEmail(email);
                      Navigator.of(context).pop();
                      _showPasswordResetSentDialog(email);
                    }
                  },
                  child: const Text('Send'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool _isValidEmail(String email) {
    String pattern =
        r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@(([^<>()[\]\\.,;:\s@\"]+\.)+[^<>()[\]\\.,;:\s@\"]{2,}))$';
    RegExp regex = RegExp(pattern);
    return regex.hasMatch(email);
  }

  Future<void> _sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('Error sending password reset email: $e');
      setState(() {
        _errorText = 'Error sending password reset email. Please try again.';
      });
    }
  }

  Future<void> _showPasswordResetSentDialog(String email) async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Password Reset Email Sent'),
          content: Text(
              'A password reset link has been sent to $email. Please check your email.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                _showForgotPasswordDialog(); // Show the forgot password dialog again
              },
              child: const Text('Resend'),
            ),
          ],
        );
      },
    );
  }
}
