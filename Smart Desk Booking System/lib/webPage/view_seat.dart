import 'package:firebase/phoneScreen/homepage.dart';
import 'package:firebase/webPage/employee.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum SeatType {
  single,
  double,
}

class Seat {
  String name;
  final String? deskIdA;
  final String? deskIdB;
  final SeatType type;

  Seat(this.name, {this.deskIdA, this.deskIdB, required this.type});
}

class ViewSeatMap extends StatefulWidget {
  final String? bookingId;
  final String empId;

  ViewSeatMap({Key? key, this.bookingId, required this.empId})
      : super(key: key);

  @override
  _ViewSeatMapState createState() => _ViewSeatMapState();
}

class _ViewSeatMapState extends State<ViewSeatMap> {
  List<List<Seat?>> seatMap = [];
  String? selectedDeskId;
  List<String> otherBookedDeskIds = [];
  List<String> desksUnderRepair = [];
  List<String> authUserBookedDeskIds = [];
  DateTime? selectedDate;
  Map<String, dynamic>? selectedDeskInfo;
  String? currentBookingDeskId;
  bool isAdmin = false; // Added to track if the user is an admin

  @override
  void initState() {
    super.initState();
    _initializeSelectedDate();
    _checkIfUserIsAdmin(); // Check if the user is an admin
  }

  Future<void> _checkIfUserIsAdmin() async {
    try {
      String? userEmail = FirebaseAuth.instance.currentUser?.email;
      if (userEmail != null) {
        QuerySnapshot employeeSnapshot = await FirebaseFirestore.instance
            .collection('employee')
            .where('email', isEqualTo: userEmail)
            .limit(1)
            .get();

        if (employeeSnapshot.docs.isNotEmpty) {
          bool admin = employeeSnapshot.docs.first['admin'] ?? false;
          setState(() {
            isAdmin = admin;
          });
        }
      }
    } catch (e) {
      print('Error checking admin status: $e');
    }
  }

  Future<void> _initializeSelectedDate() async {
    try {
      if (widget.bookingId != null) {
        DocumentSnapshot bookingSnapshot = await FirebaseFirestore.instance
            .collection('booking')
            .doc(widget.bookingId)
            .get();

        if (bookingSnapshot.exists) {
          setState(() {
            selectedDate = DateTime.parse(bookingSnapshot['booking_date']);
            currentBookingDeskId = bookingSnapshot['desk_id'];
          });
        }
      }

      if (selectedDate == null) {
        setState(() {
          selectedDate = DateTime.now();
        });
      }

      _fetchSeatsFromFirestore();
    } catch (e) {
      print('Error initializing selected date: $e');
    }
  }

  Future<void> _fetchSeatsFromFirestore() async {
    try {
      QuerySnapshot seatSnapshot =
          await FirebaseFirestore.instance.collection('desks').get();

      // Initialize the seat map
      seatMap.clear();

      // Identify all available desk locations and corresponding desk IDs
      Map<String, String> deskIdMap = {};
      seatSnapshot.docs.forEach((DocumentSnapshot doc) {
        if (doc['desk_location'] != null && doc['desk_id'] != null) {
          String deskLocation = doc['desk_location'];
          String deskId = doc['desk_id'];
          deskIdMap[deskLocation] = deskId;
          if (doc['status'] == 'under repair') {
            desksUnderRepair.add(deskId);
          }
        }
      });

      // Retrieve bookings for the selected date
      String selectedDateString =
          DateFormat('yyyy-MM-dd').format(selectedDate!);
      QuerySnapshot bookingsSnapshot = await FirebaseFirestore.instance
          .collection('booking')
          .where('booking_date', isEqualTo: selectedDateString)
          .get();

      otherBookedDeskIds.clear();
      authUserBookedDeskIds.clear();
      String? userId = FirebaseAuth.instance.currentUser?.uid;
      bookingsSnapshot.docs.forEach((bookingDoc) {
        String? deskId = bookingDoc['desk_id'];
        String? empId = bookingDoc['emp_id'];
        if (deskId != null) {
          if (empId == userId) {
            authUserBookedDeskIds.add(deskId);
          } else {
            otherBookedDeskIds.add(deskId);
          }
        }
      });

      // Retrieve the current booking desk ID for the user
      if (widget.empId != null) {
        QuerySnapshot userBookingsSnapshot = await FirebaseFirestore.instance
            .collection('booking')
            .where('booking_date', isEqualTo: selectedDateString)
            .where('emp_id', isEqualTo: widget.empId)
            .get();

        if (userBookingsSnapshot.docs.isNotEmpty) {
          setState(() {
            currentBookingDeskId = userBookingsSnapshot.docs.first['desk_id'];
          });
        } else {
          setState(() {
            currentBookingDeskId = null;
          });
        }
      }

      int maxRow = 0;
      int maxColumn = 0;
      deskIdMap.keys.forEach((deskLocation) {
        List<int> indices = _extractIndicesFromDeskLocation(deskLocation);
        if (indices[0] > maxRow) maxRow = indices[0];
        if (indices[1] > maxColumn) maxColumn = indices[1];
      });

      for (int i = 0; i <= maxRow; i++) {
        List<Seat?> rowSeats = [];
        for (int j = 0; j <= maxColumn; j++) {
          String currentLocationA = _getLocationFromIndices(i, j, 'A');
          String currentLocationB = _getLocationFromIndices(i, j, 'B');
          String? deskIdA = deskIdMap[currentLocationA];
          String? deskIdB = deskIdMap[currentLocationB];

          if (deskIdA != null && deskIdB != null) {
            rowSeats.add(Seat(
              '2 seats',
              deskIdA: deskIdA,
              deskIdB: deskIdB,
              type: SeatType.double,
            ));
          } else {
            String currentLocation = _getLocationFromIndices(i, j, '');
            String? deskId = deskIdMap[currentLocation];
            if (deskId != null) {
              rowSeats.add(Seat(
                '1 seat',
                deskIdA: deskId,
                type: SeatType.single,
              ));
            } else {
              rowSeats.add(null);
            }
          }
        }
        seatMap.add(rowSeats);
      }

      setState(() {});
    } catch (e) {
      print('Error fetching seats: $e');
    }
  }

  String _getLocationFromIndices(int row, int column, String suffix) {
    String rowChar = String.fromCharCode('A'.codeUnitAt(0) + row);
    int colIndex = column + 1;
    return '$rowChar$colIndex$suffix';
  }

  List<int> _extractIndicesFromDeskLocation(String deskLocation) {
    String rowString = deskLocation.replaceAll(RegExp(r'[A-Z]'), '');
    String columnString = deskLocation.replaceAll(RegExp(r'[0-9]'), '');
    int column = int.parse(rowString) - 1;
    int row = columnString.codeUnitAt(0) - 'A'.codeUnitAt(0);
    return [row, column];
  }

  void _onDeskSelected(Seat seat, bool isDeskA) async {
    try {
      String? selectedDeskId = isDeskA ? seat.deskIdA : seat.deskIdB;
      if (selectedDeskId != null) {
        DocumentSnapshot deskSnapshot = await FirebaseFirestore.instance
            .collection('desks')
            .doc(selectedDeskId)
            .get();
        QuerySnapshot bookingSnapshot = await FirebaseFirestore.instance
            .collection('booking')
            .where('desk_id', isEqualTo: selectedDeskId)
            .where('booking_date',
                isEqualTo: DateFormat('yyyy-MM-dd').format(selectedDate!))
            .get();

        setState(() {
          this.selectedDeskId = selectedDeskId;
          selectedDeskInfo = {
            'deskId': selectedDeskId,
            'description': deskSnapshot['desk_description'] ?? '',
            'device': deskSnapshot['desk_device'] ?? '',
            'status': deskSnapshot['status'] ?? 'available',
            'isAvailable': bookingSnapshot.docs.isEmpty,
            'bookingInfo': bookingSnapshot.docs.isEmpty
                ? null
                : bookingSnapshot.docs.first.data(),
          };
        });
      } else {
        setState(() {
          selectedDeskInfo = null;
        });
      }
    } catch (e) {
      print('Error selecting desk: $e');
    }
  }

  void _onDateChanged(DateTime date) {
    try {
      setState(() {
        selectedDate = date;
        selectedDeskInfo = null;
      });
      _fetchSeatsFromFirestore();
    } catch (e) {
      print('Error changing date: $e');
    }
  }

  Future<void> updateDeskId(String bookingId, String newDeskId) async {
    final FirebaseAuth auth = FirebaseAuth.instance;
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    try {
      // Get the current user's email
      String? userEmail = auth.currentUser?.email;
      if (userEmail == null) {
        throw Exception('User not logged in.');
      }

      // Get the current booking document
      DocumentSnapshot bookingSnapshot =
          await firestore.collection('booking').doc(bookingId).get();

      if (!bookingSnapshot.exists) {
        throw Exception('Booking not found.');
      }

      // Get the current desk_id
      String currentDeskId = bookingSnapshot['desk_id'];

      // Update the desk_id in the booking document
      await firestore.collection('booking').doc(bookingId).update({
        'desk_id': newDeskId,
      });

      // Write to the desk_log collection
      await firestore.collection('desk_log').add({
        'booking_id': bookingId,
        'changed_by': bookingSnapshot['emp_id'],
        'previous_desk_id': currentDeskId,
        'new_desk_id': newDeskId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('Desk ID updated and audit log created.');
    } catch (e) {
      print('Error updating desk ID: $e');
    }
  }

  Future<void> createNewBooking(String newDeskId) async {
    final FirebaseAuth auth = FirebaseAuth.instance;
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    try {
      String? userId = auth.currentUser?.uid;

      if (userId == null) {
        throw Exception('User not logged in.');
      }

      // Create a new booking
      await firestore.collection('booking').add({
        'booking_date': DateFormat('yyyy-MM-dd').format(selectedDate!),
        'booking_status': 'scheduled',
        'desk_id': newDeskId,
        'emp_id': userId,
      });

      print('New booking created.');
    } catch (e) {
      print('Error creating new booking: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            SizedBox(height: 10),
            Text('Seat Map'),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Selected Date: '),
                  SizedBox(
                    height: 45,
                    width: 120,
                    child: TextField(
                      readOnly: true,
                      decoration: InputDecoration(
                        hintText: selectedDate != null
                            ? DateFormat('yyyy-MM-dd').format(selectedDate!)
                            : 'Select Date',
                      ),
                      onTap: () async {
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? DateTime.now(),
                          firstDate:
                              DateTime.now(), // Start from the current date
                          lastDate: isAdmin
                              ? DateTime.now().add(Duration(days: 30))
                              : DateTime.now().add(Duration(days: 7)),
                        );
                        if (pickedDate != null && pickedDate != selectedDate) {
                          _onDateChanged(pickedDate);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => onTapImgArrowLeft(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (seatMap.isNotEmpty)
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Center(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        for (int i = 0; i < seatMap.length; i++)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (int j = 0; j < seatMap[i].length; j++)
                                GestureDetector(
                                  onTap: () {
                                    if (seatMap[i][j] != null) {
                                      _onDeskSelected(seatMap[i][j]!, true);
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Container(
                                      width: seatMap[i][j]?.deskIdB != null
                                          ? 100
                                          : 50,
                                      height: 60,
                                      child: Center(
                                        child: seatMap[i][j] != null
                                            ? _buildSeatWidget(seatMap[i][j]!)
                                            : SizedBox(
                                                width: seatMap[i][j]?.deskIdB !=
                                                        null
                                                    ? 100
                                                    : 50,
                                                height: 60,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        SizedBox(height: 16),
                        _buildLegend(),
                      ],
                    ),
                  ),
                ),
              ),
            if (selectedDeskInfo != null) _buildDeskInfoCard(selectedDeskInfo!),
          ],
        ),
      ),
    );
  }

  Widget _buildSeatWidget(Seat seat) {
    Color seatColorA = _getDeskColor(seat.deskIdA);
    Color seatColorB = _getDeskColor(seat.deskIdB);

    if (seat.deskIdB == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              _onDeskSelected(seat, true);
            },
            child: Image.asset(
              'assets/images/img_image_24.png',
              width: 24,
              height: 24,
              color: seatColorA,
            ),
          ),
          SizedBox(height: 5),
          if (seat.deskIdA != null) Text(seat.deskIdA!),
        ],
      );
    } else {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  _onDeskSelected(seat, true);
                },
                child: Transform.rotate(
                  angle: 3.14159 / 2, // 90 degrees
                  child: Image.asset(
                    'assets/images/img_image_24.png',
                    width: 24,
                    height: 24,
                    color: seatColorA,
                  ),
                ),
              ),
              SizedBox(
                width: 5,
                child: Container(
                  color: Colors.black,
                  height: 24,
                ),
              ),
              GestureDetector(
                onTap: () {
                  _onDeskSelected(seat, false);
                },
                child: Transform.rotate(
                  angle: 3 * 3.14159 / 2, // 270 degrees
                  child: Image.asset(
                    'assets/images/img_image_24.png',
                    width: 24,
                    height: 24,
                    color: seatColorB,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 5),
          if (seat.deskIdA != null && seat.deskIdB != null)
            FittedBox(
              child: Text('${seat.deskIdA!} ${seat.deskIdB!}'),
              fit: BoxFit.scaleDown,
            ),
        ],
      );
    }
  }

  Color _getDeskColor(String? deskId) {
    if (deskId == null) return Colors.black;
    if (deskId == selectedDeskId) return Colors.green;
    if (deskId == currentBookingDeskId) return Colors.red;
    if (desksUnderRepair.contains(deskId)) return Colors.grey;
    if (authUserBookedDeskIds.contains(deskId)) return Colors.red;
    if (otherBookedDeskIds.contains(deskId)) return Colors.blue;
    return Colors.black;
  }

  Widget _buildLegend() {
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        _buildLegendItem(Colors.green, 'Selected Desk'),
        SizedBox(width: 8),
        _buildLegendItem(Colors.red, 'Your Booking'),
        SizedBox(width: 8),
        _buildLegendItem(Colors.blue, 'Booked by Others'),
        SizedBox(width: 8),
        _buildLegendItem(Colors.black, 'Available'),
        SizedBox(width: 8),
        _buildLegendItem(Colors.grey, 'Under Repair'),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 24,
          height: 24,
          color: color,
        ),
        SizedBox(height: 4),
        Text(text),
      ],
    );
  }

  Widget _buildDeskInfoCard(Map<String, dynamic> deskInfo) {
    bool isAvailable = deskInfo['isAvailable'];
    String status = deskInfo['status'];
    Map<String, dynamic>? bookingInfo = deskInfo['bookingInfo'];

    if (status != 'available') {
      return Card(
        margin: EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Desk ${deskInfo['deskId']} is not available for booking.',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              deskInfo['deskId'],
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text('Description: ${deskInfo['description']}'),
            Text('Device: ${deskInfo['device']}'),
            SizedBox(height: 8),
            if (isAvailable)
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      // Get the current booking ID
                      String? bookingId = widget.bookingId;
                      if (bookingId != null) {
                        // Prompt the user to confirm the desk change
                        bool confirmChange = await showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: Text('Confirm Desk Change'),
                              content: Text(
                                  'Do you want to change your booking to this desk?'),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop(false);
                                  },
                                  child: Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop(true);
                                  },
                                  child: Text('Confirm'),
                                ),
                              ],
                            );
                          },
                        );

                        if (confirmChange) {
                          // Update the desk ID and log the change
                          await updateDeskId(bookingId, deskInfo['deskId']);
                          // Refresh the seat map
                          _fetchSeatsFromFirestore();
                        }
                      } else {
                        // Create a new booking for the selected desk
                        await createNewBooking(deskInfo['deskId']);
                        // Refresh the seat map
                        _fetchSeatsFromFirestore();
                      }
                    },
                    child: Text(
                      'Book Desk',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                  SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        selectedDeskInfo = null;
                      });
                    },
                    child: Text('Cancel'),
                  ),
                ],
              )
            else if (bookingInfo != null)
              Text(
                'Scheduled by EMP ID: ${bookingInfo['emp_id']}',
                style: TextStyle(color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }

  void onTapImgArrowLeft(BuildContext context) {
    if (kIsWeb) {
      Navigator.pop(context); // For web, pop the current page to go back
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MainScreen(
            empId: widget.empId,
          ),
        ),
      ); // For mobile, navigate to HomeScreen
    }
  }
}
