import 'package:firebase/core/utils/image_constant.dart';
import 'package:firebase/webPage/employee.dart';
import 'package:firebase/webPage/map_management.dart';
import 'package:firebase/webPage/setting_screen.dart';
import 'package:firebase/webPage/home_screen.dart';
import 'package:firebase/webPage/Dashboard.dart';
import 'package:firebase/webPage/view_booking.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // To format the date

class BookingSystem extends StatefulWidget {
  @override
  _BookingSystemState createState() => _BookingSystemState();
}

class _BookingSystemState extends State<BookingSystem> {
  bool isMapView = true;
  String? selectedDeskId;
  DateTime selectedDate = DateTime.now();
  double _scale = 1.0;

  void _zoomIn() {
    setState(() {
      _scale = (_scale + 0.2).clamp(0.2, 2.0);
    });
  }

  void _zoomOut() {
    setState(() {
      _scale = (_scale - 0.2).clamp(0.2, 2.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Booking'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: GestureDetector(
        onTap: () {
          setState(() {
            selectedDeskId = null;
          });
        },
        child: Column(
          children: [
            Container(
              color: Colors.grey[200],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ViewBookingsScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'View by List',
                          style: TextStyle(
                            color: isMapView ? Colors.black : Colors.blue,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            isMapView = true;
                          });
                        },
                        child: Text(
                          'View by Map',
                          style: TextStyle(
                            color: isMapView ? Colors.blue : Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _selectDate,
                    child: Text(
                      'Select Date: ${DateFormat('yyyy-MM-dd').format(selectedDate)}',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: Colors.grey,
                            width: 1,
                          ),
                        ),
                      ),
                      child: ClipRect(
                        child: isMapView
                            ? Stack(
                                children: [
                                  showMap(
                                    selectedDate: selectedDate,
                                    onSelectDesk: (deskId) {
                                      setState(() {
                                        selectedDeskId = deskId;
                                      });
                                    },
                                    selectedDeskId: selectedDeskId,
                                    scale: _scale,
                                    key: ValueKey(selectedDate),
                                  ),
                                  Positioned(
                                    bottom: 20,
                                    left:
                                        MediaQuery.of(context).size.width / 2 -
                                            70,
                                    child: Row(
                                      children: [
                                        FloatingActionButton(
                                          onPressed: _zoomIn,
                                          child: Icon(Icons.zoom_in),
                                        ),
                                        SizedBox(width: 10),
                                        FloatingActionButton(
                                          onPressed: _zoomOut,
                                          child: Icon(Icons.zoom_out),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : _buildListView(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 1,
                    child: Container(
                      color: Colors.grey,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: Colors.grey,
                            width: 1,
                          ),
                        ),
                      ),
                      child: selectedDeskId == null
                          ? _buildAllBookingsDetails()
                          : _buildBookingDetails(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('booking')
          .where('booking_date',
              isEqualTo: DateFormat('yyyy-MM-dd').format(selectedDate))
          .orderBy('booking_date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No bookings available.'));
        }

        return ListView(
          children: snapshot.data!.docs.map((doc) {
            var booking = doc.data() as Map<String, dynamic>;
            return ListTile(
              title: Text('Desk ID: ${booking['desk_id']}'),
              subtitle: Text('Employee ID: ${booking['emp_id']}'),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildAllBookingsDetails() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('booking')
          .where('booking_date',
              isEqualTo: DateFormat('yyyy-MM-dd').format(selectedDate))
          .orderBy('booking_date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No details available.'));
        }

        return ListView(
          children: snapshot.data!.docs.map((doc) {
            var booking = doc.data() as Map<String, dynamic>;
            return ListTile(
              title: Text('Desk ID: ${booking['desk_id']}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Booking Date: ${booking['booking_date']}'),
                  Text('Status: ${booking['booking_status']}'),
                  Text('Employee ID: ${booking['emp_id']}'),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildBookingDetails() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('booking')
          .where('desk_id', isEqualTo: selectedDeskId)
          .where('booking_date',
              isEqualTo: DateFormat('yyyy-MM-dd').format(selectedDate))
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No details available.'));
        }

        var booking = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Booking Date: ${booking['booking_date']}'),
              Text('Status: ${booking['booking_status']}'),
              Text('Desk ID: ${booking['desk_id']}'),
              Text('Employee ID: ${booking['emp_id']}'),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        selectedDeskId = null; // Reset selected desk
      });
    }
  }
}

class showMap extends StatefulWidget {
  final DateTime selectedDate;
  final void Function(String?) onSelectDesk;
  final String? selectedDeskId;
  final double scale;

  showMap({
    Key? key,
    required this.selectedDate,
    required this.onSelectDesk,
    this.selectedDeskId,
    this.scale = 1.0,
  }) : super(key: key);

  @override
  _showMapState createState() => _showMapState();
}

class _showMapState extends State<showMap> {
  List<List<Seat?>> seatMap = [];
  List<String> otherBookedDeskIds = [];
  List<String> desksUnderRepair = [];

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      scaleEnabled: true,
      panEnabled: true,
      minScale: 0.2,
      maxScale: 2.0,
      constrained: false,
      transformationController: TransformationController()
        ..value = Matrix4.identity().scaled(widget.scale),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (seatMap.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (int i = 0; i < seatMap.length; i++)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (int j = 0; j < seatMap[i].length; j++)
                            GestureDetector(
                              onTap: () {
                                String? selectedDeskId =
                                    seatMap[i][j]?.deskIdA ??
                                        seatMap[i][j]?.deskIdB;
                                widget.onSelectDesk(selectedDeskId);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Container(
                                  width:
                                      seatMap[i][j]?.deskIdB != null ? 100 : 50,
                                  height: 60,
                                  child: Center(
                                    child: seatMap[i][j] != null
                                        ? _buildSeatWidget(seatMap[i][j]!)
                                        : SizedBox(
                                            width:
                                                seatMap[i][j]?.deskIdB != null
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
            ],
          ),
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
          Image.asset(
            'assets/images/img_image_24.png',
            width: 24,
            height: 24,
            color: seatColorA,
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
                  widget.onSelectDesk(seat.deskIdA);
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
                  widget.onSelectDesk(seat.deskIdB);
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
    if (desksUnderRepair.contains(deskId)) return Colors.grey;
    if (deskId == widget.selectedDeskId) return Colors.red;
    if (otherBookedDeskIds.contains(deskId)) return Colors.blue;
    return Colors.black;
  }

  Widget _buildLegend() {
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        _buildLegendItem(Colors.red, 'Selected Seat'),
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

  @override
  void initState() {
    super.initState();
    _fetchSeatsFromFirestore();
  }

  void _fetchSeatsFromFirestore() async {
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

      // Get the selected date
      String selectedDateStr =
          DateFormat('yyyy-MM-dd').format(widget.selectedDate);

      // Retrieve bookings for the selected date
      QuerySnapshot bookingsSnapshot = await FirebaseFirestore.instance
          .collection('booking')
          .where('booking_date', isEqualTo: selectedDateStr)
          .get();

      bookingsSnapshot.docs.forEach((bookingDoc) {
        String? deskId = bookingDoc['desk_id'];
        if (deskId != null) {
          otherBookedDeskIds.add(deskId);
        }
      });

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
            rowSeats.add(Seat('2 seats',
                deskIdA: deskIdA, deskIdB: deskIdB, type: SeatType.faceToFace));
          } else {
            String currentLocation = _getLocationFromIndices(i, j, '');
            String? deskId = deskIdMap[currentLocation];
            if (deskId != null) {
              rowSeats.add(
                  Seat('1 seat', deskIdA: deskId, type: SeatType.individual));
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
}

enum SeatType { individual, faceToFace }

class Seat {
  final String name;
  final String? deskIdA;
  final String? deskIdB;
  final SeatType type;

  Seat(this.name, {this.deskIdA, this.deskIdB, required this.type});
}
