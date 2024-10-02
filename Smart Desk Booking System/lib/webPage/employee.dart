import 'dart:math';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mailer/mailer.dart' as mailer_pkg;
import 'package:mailer/smtp_server.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MaterialApp(
    home: EmployeePage(),
  ));
}

class EmployeePage extends StatefulWidget {
  @override
  _EmployeePageState createState() => _EmployeePageState();
}

class _EmployeePageState extends State<EmployeePage> {
  String? selectedEmployeeId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Employee List'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('employee').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error fetching data: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text('No employee data available'),
            );
          }
          return Row(
            children: [
              Expanded(
                flex: 1,
                child: ListView(
                  children: snapshot.data!.docs.map((doc) {
                    Map<String, dynamic>? data =
                        doc.data() as Map<String, dynamic>?;

                    if (data == null) {
                      return SizedBox();
                    }

                    return ListTile(
                      title: Text(data['name'] ?? 'Name not available'),
                      subtitle: Text(data['email'] ?? 'Email not available'),
                      onTap: () {
                        setState(() {
                          selectedEmployeeId = doc.id;
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              VerticalDivider(width: 1),
              Expanded(
                flex: 2,
                child: selectedEmployeeId == null
                    ? Center(child: Text('Select an employee to view details'))
                    : _buildEmployeeDetailsForm(selectedEmployeeId!),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _addEmployee(context);
        },
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmployeeDetailsForm(String docId) {
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('employee').doc(docId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error fetching data: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Center(
            child: Text('Employee not found'),
          );
        }

        Map<String, dynamic> data =
            snapshot.data!.data() as Map<String, dynamic>;
        TextEditingController nameController =
            TextEditingController(text: data['name']);
        TextEditingController emailController =
            TextEditingController(text: data['email']);
        TextEditingController passwordController =
            TextEditingController(text: data['password']);
        TextEditingController idController =
            TextEditingController(text: data['ID']);

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Name'),
              ),
              SizedBox(height: 16.0),
              TextFormField(
                controller: emailController,
                decoration: InputDecoration(labelText: 'Email'),
              ),
              SizedBox(height: 16.0),
              TextFormField(
                controller: idController,
                decoration: InputDecoration(labelText: 'Employee ID'),
              ),
              SizedBox(height: 16.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      _sendEmailWithToken(data['email']);
                    },
                    child: Text('Send Email'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _updateEmployee(
                          docId, nameController.text, emailController.text);
                    },
                    child: Text('Save Changes'),
                  ),
                ],
              ),
              SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: () {
                  _confirmDeleteEmployee(context, docId, data['uid']);
                },
                child: Text('Delete Employee'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendEmailWithToken(String email) async {
    final newToken = _generateToken();
    final employeeId = await _getEmployeeIdByEmail(email);

    if (employeeId == null) {
      print('No employee found with email: $email');
      return;
    }
    await _updateTokenInFirestore(employeeId, newToken);

    try {
      final qrCodeImageFile = await _generateQRCodeImage(employeeId, newToken);

      // send mail
      final smtpServer = gmail('qunqunqun142@gmail.com', 'zjcpokmdxfdovnlq');
      final message = mailer_pkg.Message()
        ..from = mailer_pkg.Address(
            'qunqunqun142@gmail.com', 'Smart Desk Booking System')
        ..recipients.add(email)
        ..subject = 'Confirm to get your Login'
        ..text = 'Your custom token is: $newToken'
        ..attachments = [
          mailer_pkg.FileAttachment(qrCodeImageFile)
            ..location = mailer_pkg.Location.inline
            ..cid = 'qrcode@myapp.com'
        ]
        ..html = '<h1>Your QR Code</h1><img src="cid:qrcode@myapp.com">';

      await mailer_pkg.send(message, smtpServer);
      print('Email sent successfully');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Email sent successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error sending email: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending email: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _getEmployeeIdByEmail(String email) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('employee')
        .where('email', isEqualTo: email)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.id;
    }
    return null;
  }

  Future<File> _generateQRCodeImage(String employeeId, String token) async {
    try {
      final qrValidationResult = QrValidator.validate(
        data:
            "https://fire-setup-b5eb2.cloudfunctions.net/api/authenticate?employeeId=$employeeId&token=$token",
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.L,
      );

      if (qrValidationResult.status != QrValidationStatus.valid) {
        throw Exception('QR Code generation failed');
      }

      final qrCode = qrValidationResult.qrCode;
      final painter = QrPainter.withQr(
        qr: qrCode!,
        color: const Color(0xFF000000),
        emptyColor: const Color(0xFFFFFFFF),
        gapless: true,
        embeddedImageStyle: null,
        embeddedImage: null,
      );

      final tempDir = await getTemporaryDirectory();
      final qrCodeImageFile = File('${tempDir.path}/qr_code.png');

      final picData =
          await painter.toImageData(200, format: ImageByteFormat.png);
      await qrCodeImageFile.writeAsBytes(picData!.buffer.asUint8List());

      print("QR Code Image File generated at: ${qrCodeImageFile.path}");

      return qrCodeImageFile;
    } catch (e) {
      print('Error generating QR code image: $e');
      rethrow;
    }
  }

  String _generateToken() {
    const String _chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    Random _rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        10, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));
  }

  Future<void> _updateTokenInFirestore(
      String employeeId, String newToken) async {
    try {
      await FirebaseFirestore.instance
          .collection('employee')
          .doc(employeeId)
          .update({'token': newToken});
      print('Token updated successfully');
    } catch (error) {
      print('Error updating token: $error');
    }
  }

  void _updateEmployee(String docId, String name, String email) {
    FirebaseFirestore.instance.collection('employee').doc(docId).update({
      'name': name,
      'email': email,
    }).then((value) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Employee updated successfully'),
      ));
    }).catchError((error) {
      print('Error updating employee: $error');
    });
  }

  void _confirmDeleteEmployee(BuildContext context, String docId, String uid) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Confirm Delete'),
          content: Text('Are you sure you want to delete this employee?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteEmployee(docId, uid);
              },
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _deleteEmployee(String docId, String uid) {
    FirebaseFirestore.instance
        .collection('employee')
        .doc(docId)
        .delete()
        .then((value) async {
      try {
        await FirebaseAuth.instance.currentUser?.delete();
        print('Employee deleted successfully');
      } catch (error) {
        print('Error deleting employee from authentication: $error');
      }
    }).catchError((error) {
      print('Error deleting employee: $error');
    });
  }

  void _addEmployee(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEmployeeScreen(),
      ),
    );
  }
}

class AddEmployeeScreen extends StatefulWidget {
  @override
  _AddEmployeeScreenState createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Employee'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'Name'),
            ),
            SizedBox(height: 16.0),
            TextFormField(
              controller: emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            SizedBox(height: 16.0),
            TextFormField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              obscureText: _obscurePassword,
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: () {
                _addEmployee(context);
              },
              child: Text('Add Employee'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addEmployee(BuildContext context) async {
    String name = nameController.text.trim();
    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('employee')
          .orderBy('ID', descending: true)
          .limit(1)
          .get();

      String newId = 'EMP01';
      if (querySnapshot.docs.isNotEmpty) {
        String lastId = querySnapshot.docs.first.get('ID');
        int newIdNumber = int.parse(lastId.substring(3)) + 1;
        newId = 'EMP${newIdNumber.toString().padLeft(2, '0')}';
      }

      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await FirebaseFirestore.instance.collection('employee').doc(newId).set({
        'name': name,
        'email': email,
        'password': password,
        'admin': false,
        'ID': newId,
        'uid': userCredential.user!.uid,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Employee added successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add employee: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
