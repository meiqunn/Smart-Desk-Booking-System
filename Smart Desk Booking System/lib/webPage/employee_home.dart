import 'dart:math';
import 'package:firebase/webPage/function_schedule.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase/webPage/view_seat.dart';
import 'package:firebase/webPage/setting_screen.dart';
import 'package:firebase/core/utils/image_constant.dart';

class EmployeeHomeScreen extends StatefulWidget {
  final String empId;

  const EmployeeHomeScreen({Key? key, required this.empId}) : super(key: key);

  @override
  _EmployeeHomeScreenState createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
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
    return Column(
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
          title: Text('Your schedule', style: TextStyle(color: Colors.black)),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EmployeeHomeScreen(
                  empId: widget.empId,
                ),
              ),
            );
          },
        ),
        ListTile(
          title: Text('Map', style: TextStyle(color: Colors.black)),
          onTap: () {
            if (_empId != null) {
              print('$_empId');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ViewSeatMap(
                    empId: _empId!,
                  ),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Employee ID not available.'),
                ),
              );
            }
          },
        ),
        ListTile(
          title: Text('Settings', style: TextStyle(color: Colors.black)),
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
                bool isScheduledByCurrentEmp = snapshot.data?.docs.any((doc) =>
                        (doc.data() as Map<String, dynamic>)['emp_id'] ==
                        empId) ??
                    false;

                bool isCheckedIn = snapshot.data?.docs.any((doc) =>
                        (doc.data() as Map<String, dynamic>)['emp_id'] ==
                            empId &&
                        (doc.data()
                                as Map<String, dynamic>)['booking_status'] ==
                            'checked in') ??
                    false;

                bool isToday = date.day == DateTime.now().day &&
                    date.month == DateTime.now().month &&
                    date.year == DateTime.now().year;

                return InkWell(
                  onTap: () {
                    if (isScheduledByCurrentEmp) {
                      String? bookingId = snapshot.data?.docs
                          .firstWhere((doc) =>
                              (doc.data() as Map<String, dynamic>)['emp_id'] ==
                              empId)
                          .id;
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
                        ? 'Desk ID: ${(snapshot.data!.docs.firstWhere((doc) => (doc.data() as Map<String, dynamic>)['emp_id'] == empId))['desk_id']}'
                        : 'No bookings',
                    child: Container(
                      margin: EdgeInsets.symmetric(vertical: 8.0),
                      padding: EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8.0),
                        color: isScheduledByCurrentEmp
                            ? Colors.purple[200]
                            : Colors.grey[200],
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
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              if (isScheduledByCurrentEmp) {
                                if (isCheckedIn) {
                                  _viewDesk(empId, date);
                                } else if (isToday) {
                                  _checkInDesk(date);
                                } else {
                                  _unscheduleDesk(date);
                                }
                              } else {
                                _scheduleDesk(date);
                              }
                            },
                            child: Text(isScheduledByCurrentEmp
                                ? (isCheckedIn
                                    ? 'View Desk'
                                    : isToday
                                        ? 'Check In'
                                        : 'Unschedule')
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
      String deskId = await getAvailableDeskId(date);

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
      String empId = await _getCurrentEmployeeId();
      QuerySnapshot bookingSnapshot = await FirebaseFirestore.instance
          .collection('booking')
          .where('booking_date',
              isEqualTo: DateFormat('yyyy-MM-dd').format(date))
          .where('emp_id', isEqualTo: empId)
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

  Future<void> _checkInDesk(DateTime date) async {
    try {
      String empId = await _getCurrentEmployeeId();
      QuerySnapshot bookingSnapshot = await FirebaseFirestore.instance
          .collection('booking')
          .where('booking_date',
              isEqualTo: DateFormat('yyyy-MM-dd').format(date))
          .where('emp_id', isEqualTo: empId)
          .get();

      for (QueryDocumentSnapshot bookingDoc in bookingSnapshot.docs) {
        await bookingDoc.reference.update({'booking_status': 'checked in'});
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Checked in successfully.'),
        ),
      );
    } catch (e) {
      print('Error checking in: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred while checking in.'),
        ),
      );
    }
  }

  Future<void> _viewDesk(String empId, DateTime date) async {
    try {
      QuerySnapshot bookingSnapshot = await FirebaseFirestore.instance
          .collection('booking')
          .where('booking_date',
              isEqualTo: DateFormat('yyyy-MM-dd').format(date))
          .where('emp_id', isEqualTo: empId)
          .get();

      if (bookingSnapshot.docs.isNotEmpty) {
        String bookingId = bookingSnapshot.docs.first.id;
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
            content: Text('No booking found.'),
          ),
        );
      }
    } catch (e) {
      print('Error viewing desk: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred while viewing the desk.'),
        ),
      );
    }
  }

  void _showBookingDetails(BuildContext context, DateTime date,
      List<QueryDocumentSnapshot> bookings) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
              'Booking Details - ${DateFormat('EEE, MMM d').format(date)}'),
          content: Container(
            height: 200,
            width: 300,
            child: ListView.builder(
              itemCount: bookings.length,
              itemBuilder: (context, index) {
                var booking = bookings[index];
                return ListTile(
                  title: Text('Desk ID: ${booking['desk_id']}'),
                  subtitle: Text('Booking ID: ${booking.id}'),
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
