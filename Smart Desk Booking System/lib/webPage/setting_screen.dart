import 'package:firebase/core/utils/image_constant.dart';
import 'package:firebase/webPage/Dashboard.dart';
import 'package:firebase/webPage/booking.dart';
import 'package:firebase/webPage/employee.dart';
import 'package:firebase/webPage/login.dart';
import 'package:firebase/webPage/map_management.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingScreen extends StatefulWidget {
  final String empId;

  const SettingScreen({Key? key, required this.empId}) : super(key: key);

  @override
  _SettingScreenState createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
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
        'Fetching details for Employee ID: ${widget.empId}'); // Debug statement

    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('employee')
          .where('ID', isEqualTo: widget.empId)
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
        builder: (context) => LoginPage(),
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

  Widget _buildNavigationDrawerContent() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => Dashboard(
                        empId: widget.empId,
                      )),
            );
          },
          child: Container(
            height: 84,
            width: double.infinity,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(ImageConstant.imgImage184x428),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        ListTile(
          title: Text('Booking'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BookingSystem(),
              ),
            );
          },
        ),
        ListTile(
          title: Text('Employee'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EmployeePage(),
              ),
            );
          },
        ),
        ListTile(
          title: Text('Map management'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CustomSeatMap(),
              ),
            );
          },
        ),
        ListTile(
          title: Text('Map usage'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Dashboard(
                  empId: widget.empId,
                ),
              ),
            );
          },
        ),
        ListTile(
          title: Text('Settings'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SettingScreen(empId: widget.empId),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      drawer: Drawer(
        child: _buildNavigationDrawerContent(),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    child: Text(
                      empName.isNotEmpty ? empName.substring(0, 2) : '',
                      style: TextStyle(fontSize: 24, color: Colors.white),
                    ),
                    backgroundColor: Colors.orange,
                  ),
                  SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        empName,
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 20),
              TextField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
                controller: TextEditingController(text: empName),
              ),
              SizedBox(height: 16),
              TextField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                controller: TextEditingController(text: empEmail),
              ),
              SizedBox(height: 16),
              TextField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                controller: TextEditingController(text: empPhone),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _showEditDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
                child: Text('Edit Profile'),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
