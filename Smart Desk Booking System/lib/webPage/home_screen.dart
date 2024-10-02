import 'dart:math';

import 'package:firebase/core/utils/image_constant.dart';
import 'package:firebase/webPage/Dashboard.dart';
import 'package:firebase/webPage/employee.dart';
import 'package:firebase/webPage/map_management.dart';
import 'package:firebase/webPage/setting_screen.dart';
import 'package:firebase/webPage/booking.dart';
import 'package:firebase/webPage/view_seat.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  final String empId;

  const HomeScreen({Key? key, required this.empId}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late List<bool> isScheduledList;
  bool _isLoading = true;
  String? _empId;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    isScheduledList = List<bool>.filled(7, false);
    _checkLogin();
    _loadData();
  }

  Future<void> _checkLogin() async {
    FirebaseAuth auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Please login first!'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pushReplacementNamed(context, '/login');
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    } else {
      _empId = await _getCurrentEmployeeId();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    await Future.delayed(Duration(seconds: 2));
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildNavigationDrawer(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isWideScreen = constraints.maxWidth >= 600;
          return Row(
            children: [
              Visibility(
                visible: isWideScreen,
                child: Container(
                  width: 250,
                  color: Colors.white,
                  child: _buildNavigationDrawerContent(),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isWideScreen)
                          IconButton(
                            icon: Icon(Icons.menu),
                            onPressed: () {
                              _scaffoldKey.currentState!.openDrawer();
                            },
                          ),
                        _buildHeader(),
                        SizedBox(height: 16),
                        if (_isLoading)
                          Center(
                            child: CircularProgressIndicator(),
                          )
                        else
                          _buildDateRows(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNavigationDrawer() {
    return Drawer(
      child: _buildNavigationDrawerContent(),
    );
  }

  Widget _buildNavigationDrawerContent() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          height: 84,
          width: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(ImageConstant.imgImage184x428),
              fit: BoxFit.cover,
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

  Widget _buildHeader() {
    return Text(
      'Home',
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 24,
      ),
    );
  }

  String _getDateRange() {
    DateTime now = DateTime.now();
    DateTime startDate = now;
    DateTime endDate = startDate.add(Duration(days: 6));
    return DateFormat('MMM d').format(startDate) +
        ' - ' +
        DateFormat('MMM d').format(endDate);
  }

  Widget _buildDateRows() {
    DateTime now = DateTime.now();
    DateTime startDate = now;

    List<Widget> rows = [];
    for (int i = 0; i < 7; i++) {
      DateTime date = startDate.add(Duration(days: i));
      rows.add(_buildDateRow(date, i));
    }

    return Column(
      children: rows,
    );
  }

  Future<String> _getCurrentEmployeeId() async {
    String? userEmail = FirebaseAuth.instance.currentUser?.email;

    if (userEmail == null) {
      print('User not logged in.');
      return '';
    }

    try {
      QuerySnapshot employeeSnapshot = await FirebaseFirestore.instance
          .collection('employee')
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();

      if (employeeSnapshot.docs.isEmpty) {
        print('Employee not found with email: $userEmail');
        return '';
      }

      String empId = employeeSnapshot.docs.first['ID'];
      return empId;
    } catch (e) {
      print('Error retrieving employee ID: $e');
      return '';
    }
  }

  Widget _buildDateRow(DateTime date, int index) {
    return FutureBuilder<String>(
      future: _getCurrentEmployeeId(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          String empId = snapshot.data ?? '';
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('booking')
                .where('booking_date',
                    isEqualTo: DateFormat('yyyy-MM-dd').format(date))
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SizedBox.shrink();
              } else if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              } else {
                int totalBookings = snapshot.data?.docs.length ?? 0;
                bool isScheduledByCurrentEmp =
                    snapshot.data?.docs.any((doc) => doc['emp_id'] == empId) ??
                        false;

                return InkWell(
                  onTap: () {
                    if (isScheduledByCurrentEmp) {
                      String? bookingId = snapshot.data?.docs[0].id;
                      if (bookingId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ViewSeatMap(
                              bookingId: bookingId,
                              empId: empId,
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Booking ID not available.'),
                          ),
                        );
                      }
                    }
                  },
                  child: Tooltip(
                    message: totalBookings > 0 && isScheduledByCurrentEmp
                        ? 'Desk ID: ${snapshot.data!.docs[0]['desk_id']}'
                        : 'No bookings',
                    child: Container(
                      margin: EdgeInsets.symmetric(vertical: 8.0),
                      padding: EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8.0),
                        color: Colors.grey[200],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('EEE, MMM d').format(date),
                            style: TextStyle(fontSize: 16),
                          ),
                          Text(
                            '$totalBookings people scheduled',
                            style: TextStyle(
                              fontSize: 16,
                              color: isScheduledByCurrentEmp
                                  ? Colors.orange
                                  : Colors.green,
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              if (isScheduledByCurrentEmp) {
                                _unscheduleDesk(date);
                              } else {
                                _scheduleDesk(date);
                              }
                            },
                            child: Text(isScheduledByCurrentEmp
                                ? 'Unschedule'
                                : 'Schedule'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
            },
          );
        }
      },
    );
  }

  Future<void> _scheduleDesk(DateTime date) async {
    try {
      String? userEmail = FirebaseAuth.instance.currentUser?.email;
      if (userEmail == null) {
        print('User not logged in.');
        return;
      }

      QuerySnapshot employeeSnapshot = await FirebaseFirestore.instance
          .collection('employee')
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();

      if (employeeSnapshot.docs.isEmpty) {
        print('Employee not found with email: $userEmail');
        return;
      }

      String empId = employeeSnapshot.docs.first['ID'];
      String deskId = await _getAvailableDeskId(date);

      await FirebaseFirestore.instance.collection('booking').add({
        'booking_date': DateFormat('yyyy-MM-dd').format(date),
        'booking_status': 'scheduled',
        'desk_id': deskId,
        'emp_id': empId,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Desk scheduled successfully.'),
        ),
      );
    } catch (e) {
      print('Error scheduling desk: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred while scheduling the desk.'),
        ),
      );
    }
  }

  Future<void> _unscheduleDesk(DateTime date) async {
    try {
      QuerySnapshot bookingSnapshot = await FirebaseFirestore.instance
          .collection('booking')
          .where('booking_date',
              isEqualTo: DateFormat('yyyy-MM-dd').format(date))
          .where('emp_id', isEqualTo: _empId)
          .get();

      for (QueryDocumentSnapshot bookingDoc in bookingSnapshot.docs) {
        await bookingDoc.reference.delete();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Desk unscheduled successfully.'),
        ),
      );
    } catch (e) {
      print('Error unscheduling desk: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred while unscheduling the desk.'),
        ),
      );
    }
  }

  Future<String> _getAvailableDeskId(DateTime date) async {
    List<String> scheduledDeskIds = [];

    // Get all booked desk IDs for the given date
    QuerySnapshot bookingSnapshot = await FirebaseFirestore.instance
        .collection('booking')
        .where('booking_date', isEqualTo: DateFormat('yyyy-MM-dd').format(date))
        .get();

    for (QueryDocumentSnapshot doc in bookingSnapshot.docs) {
      scheduledDeskIds.add(doc['desk_id']);
    }

    // Get all desk IDs and find the maintenance desk ID
    QuerySnapshot deskSnapshot =
        await FirebaseFirestore.instance.collection('desks').get();
    List allDeskIds = deskSnapshot.docs.map((doc) => doc['desk_id']).toList();

    String? maintenanceDeskId;
    for (var doc in deskSnapshot.docs) {
      if (doc['status'] != 'available') {
        maintenanceDeskId = doc['desk_id'];
        break;
      }
    }

    // Exclude scheduled and maintenance desk IDs from available desk IDs
    List availableDeskIds = allDeskIds
        .where((deskId) =>
            !scheduledDeskIds.contains(deskId) && deskId != maintenanceDeskId)
        .toList();

    if (availableDeskIds.isNotEmpty) {
      return availableDeskIds[Random().nextInt(availableDeskIds.length)];
    } else {
      return 'No available desk';
    }
  }
}

class BookingListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('booking').snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }
        if (snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text('No bookings available.'),
          );
        }
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            DocumentSnapshot document = snapshot.data!.docs[index];
            Map<String, dynamic> data = document.data() as Map<String, dynamic>;
            String bookingDate = data['booking_date'] ?? '';
            String bookingStatus = data['booking_status'] ?? '';
            String deskId = data['desk_id'] ?? '';
            String empId = data['emp_id'] ?? '';
            return ListTile(
              title: Text('Booking Date: $bookingDate'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status: $bookingStatus'),
                  Text('Desk ID: $deskId'),
                  Text('Employee ID: $empId'),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
