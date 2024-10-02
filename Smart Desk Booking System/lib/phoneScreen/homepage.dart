import 'package:firebase/phoneScreen/myaccount.dart';
import 'package:firebase/webPage/function_schedule.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'mapscreen.dart';

class MainScreen extends StatefulWidget {
  final String empId;

  const MainScreen({Key? key, required this.empId}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      BookingStatusScreen(empId: widget.empId),
      Iphone13ProMaxSevenScreen(empId: widget.empId),
      MyAccountScreen(empId: widget.empId),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        iconSize: 32.0,
        selectedFontSize: 16.0,
        unselectedFontSize: 14.0,
        selectedItemColor: Color.fromARGB(255, 255, 153, 0),
        unselectedItemColor: Colors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: 'My Account',
          ),
        ],
      ),
    );
  }
}

class BookingStatusScreen extends StatefulWidget {
  final String empId;

  const BookingStatusScreen({Key? key, required this.empId}) : super(key: key);

  @override
  _BookingStatusScreenState createState() => _BookingStatusScreenState();
}

class _BookingStatusScreenState extends State<BookingStatusScreen> {
  int _selectedDayIndex = 0;

  final List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  late final List<DateTime> dates;

  @override
  void initState() {
    super.initState();
    dates = List.generate(
      7,
      (index) => DateTime.now()
          .subtract(Duration(days: DateTime.now().weekday - 1 - index)),
    );

    // Set the default pointer to the current date
    _selectedDayIndex = DateTime.now().weekday - 1;
  }

  Future<bool> hasBookingForSelectedDate(String empId, DateTime date) async {
    var querySnapshot = await FirebaseFirestore.instance
        .collection('booking')
        .where('booking_date', isEqualTo: DateFormat('yyyy-MM-dd').format(date))
        .where('emp_id', isEqualTo: empId)
        .get();
    return querySnapshot.docs.isNotEmpty;
  }

  Future<String> getEmployeeId(String empUid) async {
    var empSnapshot = await FirebaseFirestore.instance
        .collection('employee')
        .where('uid', isEqualTo: empUid)
        .get();

    if (empSnapshot.docs.isNotEmpty) {
      var empid = empSnapshot.docs.first.data()['ID'];
      return empid;
    } else {
      throw Exception('No employee found with the given empUid.');
    }
  }

  Future<void> scheduleDesk(DateTime date) async {
    try {
      String deskId = await getAvailableDeskId(date);
      await FirebaseFirestore.instance.collection('booking').add({
        'booking_date': DateFormat('yyyy-MM-dd').format(date),
        'booking_status': 'scheduled',
        'desk_id': deskId,
        'emp_id': widget.empId,
      });

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Booking Successful'),
            content: Text('Desk has been booked successfully.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {});
                },
                child: Text('OK'),
              ),
            ],
          );
        },
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

  Future<void> checkIn(String bookingId) async {
    try {
      await FirebaseFirestore.instance
          .collection('booking')
          .doc(bookingId)
          .update({
        'booking_status': 'checked_in',
      });

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Check-In Successful'),
            content: Text("You're checked into your workplace reservation."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {});
                },
                child: Text('OK'),
              ),
            ],
          );
        },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Booking Status'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(days.length, (index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDayIndex = index;
                      });
                    },
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _selectedDayIndex == index
                                ? Colors.orange
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            days[index],
                            style: TextStyle(
                              color: _selectedDayIndex == index
                                  ? Colors.orange
                                  : Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 12, // Adjusted font size
                            ),
                          ),
                          Text(
                            DateFormat('d MMM').format(dates[index]),
                            style: TextStyle(
                              color: _selectedDayIndex == index
                                  ? Colors.orange
                                  : Colors.black,
                              fontSize: 12, // Adjusted font size
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            FutureBuilder<bool>(
              future: hasBookingForSelectedDate(
                  widget.empId, dates[_selectedDayIndex]),
              builder: (context, bookingSnapshot) {
                if (bookingSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(),
                  );
                }
                if (bookingSnapshot.hasError) {
                  return Center(
                    child:
                        Text('Error fetching data: ${bookingSnapshot.error}'),
                  );
                }

                bool hasBooking = bookingSnapshot.data ?? false;
                bool isToday =
                    DateFormat('yyyy-MM-dd').format(dates[_selectedDayIndex]) ==
                        DateFormat('yyyy-MM-dd').format(DateTime.now());

                return FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('booking')
                      .where('booking_date',
                          isEqualTo: DateFormat('yyyy-MM-dd')
                              .format(dates[_selectedDayIndex]))
                      .where('emp_id', isEqualTo: widget.empId)
                      .get(),
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

                    var booking = snapshot.data!.docs.isNotEmpty
                        ? snapshot.data!.docs.first
                        : null;

                    String bookingStatus =
                        booking != null ? booking['booking_status'] ?? '' : '';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          title: Text('Status for ${days[_selectedDayIndex]}'),
                          subtitle: Text(
                            hasBooking ? bookingStatus : 'No onsite',
                          ),
                          trailing: isToday && bookingStatus == 'scheduled'
                              ? ElevatedButton(
                                  onPressed: () {
                                    if (hasBooking) {
                                      checkIn(booking!.id);
                                    }
                                  },
                                  child: Text(
                                    'Check In',
                                    style: TextStyle(
                                        fontSize: 14.0, color: Colors.black),
                                  ),
                                )
                              : ElevatedButton(
                                  onPressed: () {
                                    if (hasBooking) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              Iphone13ProMaxSevenScreen(
                                                  empId: widget.empId),
                                        ),
                                      );
                                    } else {
                                      scheduleDesk(dates[_selectedDayIndex]);
                                    }
                                  },
                                  child: Text(
                                    hasBooking
                                        ? 'View schedule'
                                        : 'Schedule now',
                                    style: TextStyle(
                                        fontSize: 14.0, color: Colors.black),
                                  ),
                                ),
                        ),
                        FutureBuilder<QuerySnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('booking')
                              .where('booking_date',
                                  isEqualTo: DateFormat('yyyy-MM-dd')
                                      .format(dates[_selectedDayIndex]))
                              .get(),
                          builder: (context, coworkerSnapshot) {
                            if (coworkerSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (coworkerSnapshot.hasError) {
                              return Center(
                                child: Text(
                                    'Error fetching data: ${coworkerSnapshot.error}'),
                              );
                            }

                            List<DocumentSnapshot> bookings =
                                coworkerSnapshot.data!.docs;
                            List<String> employeeIds = bookings
                                .map((booking) => booking['emp_id'] as String)
                                .toList();

                            return FutureBuilder<String>(
                              future: getEmployeeId(widget.empId),
                              builder: (context, empIdSnapshot) {
                                if (empIdSnapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                if (empIdSnapshot.hasError) {
                                  return Center(
                                    child: Text(
                                        'Error fetching data: ${empIdSnapshot.error}'),
                                  );
                                }

                                String currentEmpId = empIdSnapshot.data ?? '';
                                employeeIds.remove(currentEmpId);

                                if (employeeIds.isEmpty) {
                                  return ListTile(
                                    title: Text('Coworkers in the workplace'),
                                    subtitle: Text('No reservations yet.'),
                                  );
                                }

                                return FutureBuilder<QuerySnapshot>(
                                  future: FirebaseFirestore.instance
                                      .collection('employee')
                                      .where(FieldPath.documentId,
                                          whereIn: employeeIds)
                                      .get(),
                                  builder: (context, employeeSnapshot) {
                                    if (employeeSnapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }
                                    if (employeeSnapshot.hasError) {
                                      return Center(
                                        child: Text(
                                            'Error fetching data: ${employeeSnapshot.error}'),
                                      );
                                    }

                                    List<DocumentSnapshot> employees =
                                        employeeSnapshot.data!.docs;

                                    return ListTile(
                                      title: Text('Coworkers in the workplace'),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: employees.map((employee) {
                                          String name = employee['name'] ?? '';
                                          String initials = '';
                                          if (name.isNotEmpty) {
                                            var splitName = name.split(' ');
                                            if (splitName.length > 1) {
                                              initials = splitName[0][0] +
                                                  splitName[1][0];
                                            } else {
                                              initials = splitName[0][0];
                                            }
                                          }
                                          Color circleColor = Colors.primaries[
                                              (employeeIds
                                                      .indexOf(employee.id) %
                                                  Colors.primaries.length)];
                                          return ListTile(
                                            leading: CircleAvatar(
                                              backgroundColor: circleColor,
                                              child: Text(
                                                initials,
                                                style: TextStyle(
                                                    color: Colors.white),
                                              ),
                                            ),
                                            title: Text(name),
                                            onTap: () {
                                              // Show booking details
                                            },
                                          );
                                        }).toList(),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
