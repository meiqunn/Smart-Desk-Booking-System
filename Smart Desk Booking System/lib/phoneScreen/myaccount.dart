import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase/phoneScreen/welcomepage.dart';

class MyAccountScreen extends StatefulWidget {
  final String empId;

  const MyAccountScreen({Key? key, required this.empId}) : super(key: key);

  @override
  _MyAccountScreenState createState() => _MyAccountScreenState();
}

class _MyAccountScreenState extends State<MyAccountScreen> {
  late String empName;
  late String empEmail;
  late String empPhone;
  late String initialName;
  late String initialPhone;

  @override
  void initState() {
    super.initState();
    empName = 'Loading...';
    empEmail = 'Loading...';
    empPhone = 'Loading...';
    _fetchEmpDetails();
  }

  Future<void> _fetchEmpDetails() async {
    print(
        'Fetching details for Employee UID: ${widget.empId}'); // Debug statement

    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('employee')
          .where('uid', isEqualTo: widget.empId)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        DocumentSnapshot doc = querySnapshot.docs.first;
        final data = doc.data() as Map<String, dynamic>?;
        print('Employee Data: $data'); // Debug statement

        setState(() {
          empName = data?['name'] ?? 'Employee';
          empEmail = data?['email'] ?? 'No email';
          empPhone = data?.containsKey('phone') == true ? data!['phone'] : '--';
          initialName = empName;
          initialPhone = empPhone;
        });
      } else {
        print(
            'No document found for Employee UID: ${widget.empId}'); // Debug statement
        setState(() {
          empName = 'Employee';
          empEmail = 'No email';
          empPhone = '';
          initialName = empName;
          initialPhone = empPhone;
        });
      }
    } catch (e) {
      print('Error fetching employee details: $e'); // Debug statement
      setState(() {
        empName = 'Employee';
        empEmail = 'Error fetching email';
        empPhone = 'Error fetching phone';
        initialName = empName;
        initialPhone = empPhone;
      });
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => Iphone13ProMaxOneScreen(),
      ),
    );
  }

  void _showEditDialog() {
    TextEditingController nameController = TextEditingController(text: empName);
    TextEditingController phoneController =
        TextEditingController(text: empPhone);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Profile'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Full Name'),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: 'Enter your full name',
                  ),
                ),
                SizedBox(height: 16),
                Text('Phone Number'),
                TextField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    hintText: 'Enter your phone number',
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Your save button logic
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Account information'),
        actions: [
          TextButton(
            onPressed: _showEditDialog,
            child: Text('Edit', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ListTile(
            title: Text(
              empName,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              empEmail,
              style: TextStyle(fontSize: 16, color: Colors.blue),
            ),
          ),
          ListTile(
            title: Text('Phone'),
            subtitle: Text(empPhone.isNotEmpty ? empPhone : '--'),
          ),
          ListTile(
            title: Text('Primary location'),
            subtitle: Text('IT ASIA'),
          ),
          SizedBox(height: 20),
          Container(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _logout,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.orange, // text color
                padding: EdgeInsets.symmetric(vertical: 16), // button height
              ),
              child: Text('Logout', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

class Iphone13ProMaxOneScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return welcomeScreen();
  }
}
