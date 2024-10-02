import 'dart:ui' as ui;
import 'package:firebase/webPage/function_schedule.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ViewBookingsScreen extends StatefulWidget {
  @override
  _ViewBookingsScreenState createState() => _ViewBookingsScreenState();
}

class _ViewBookingsScreenState extends State<ViewBookingsScreen> {
  DateTime? selectedDate;
  TextEditingController searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('View Bookings'),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: _selectDate,
                  child: Text(
                    selectedDate == null
                        ? 'Select Date'
                        : DateFormat('yyyy-MM-dd').format(selectedDate!),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by Employee ID or Desk ID',
                      border: OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          searchController.clear();
                          setState(() {});
                        },
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () {
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getBookingsStream(),
              builder: (context, snapshot) {
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
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text('No bookings available.'),
                  );
                }

                var bookings = snapshot.data!.docs
                    .map((doc) => doc.data() as Map<String, dynamic>)
                    .toList();

                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: DataTable(
                    columns: [
                      DataColumn(label: Text('No.')),
                      DataColumn(label: Text('Employee ID')),
                      DataColumn(label: Text('Booking Date')),
                      DataColumn(label: Text('Desk ID')),
                      DataColumn(label: Text('Booking Status')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: List.generate(bookings.length, (index) {
                      var booking = bookings[index];
                      return DataRow(cells: [
                        DataCell(Text((index + 1).toString())),
                        DataCell(Text(booking['emp_id'] ?? '')),
                        DataCell(Text(booking['booking_date'] ?? '')),
                        DataCell(Text(booking['desk_id'] ?? '')),
                        DataCell(Text(booking['booking_status'] ?? '')),
                        DataCell(Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit),
                              onPressed: () {
                                _editBooking(
                                    context, snapshot.data!.docs[index].id);
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete),
                              onPressed: () {
                                _confirmDeleteBooking(
                                    context, snapshot.data!.docs[index].id);
                              },
                            ),
                          ],
                        )),
                      ]);
                    }),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _addBooking(context);
        },
        child: Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Stream<QuerySnapshot> _getBookingsStream() {
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('booking');

    if (selectedDate != null) {
      query = query.where('booking_date',
          isEqualTo: DateFormat('yyyy-MM-dd').format(selectedDate!));
    }

    if (searchController.text.isNotEmpty) {
      query = query.where('search_terms',
          arrayContains: searchController.text.toLowerCase());
    }

    return query.orderBy('booking_date', descending: true).snapshots();
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  void _addBooking(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddBookingScreen()),
    );
  }

  void _editBooking(BuildContext context, String bookingId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditBookingScreen(bookingId: bookingId),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Booking updated successfully'),
    ));
  }

  void _confirmDeleteBooking(BuildContext context, String bookingId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete this booking?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _deleteBooking(context, bookingId);
                Navigator.of(context).pop();
              },
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _deleteBooking(BuildContext context, String bookingId) async {
    try {
      await FirebaseFirestore.instance
          .collection('booking')
          .doc(bookingId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Booking deleted successfully'),
      ));
    } catch (error) {
      print("Error deleting booking: $error");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to delete booking'),
      ));
    }
  }
}

class EditBookingScreen extends StatefulWidget {
  final String bookingId;

  const EditBookingScreen({Key? key, required this.bookingId})
      : super(key: key);

  @override
  _EditBookingScreenState createState() => _EditBookingScreenState();
}

class _EditBookingScreenState extends State<EditBookingScreen> {
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _statusController = TextEditingController();
  final TextEditingController _deskIdController = TextEditingController();
  final TextEditingController _empIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBookingDetails();
  }

  Future<void> _loadBookingDetails() async {
    try {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('booking')
          .doc(widget.bookingId)
          .get();

      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;

      _dateController.text = data['booking_date'] ?? '';
      _statusController.text = data['booking_status'] ?? '';
      _deskIdController.text = data['desk_id'] ?? '';
      _empIdController.text = data['emp_id'] ?? '';
    } catch (error) {
      print("Error loading booking details: $error");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Booking'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _dateController,
              decoration: InputDecoration(labelText: 'Booking Date'),
            ),
            TextFormField(
              controller: _statusController,
              decoration: InputDecoration(labelText: 'Booking Status'),
            ),
            TextFormField(
              controller: _deskIdController,
              decoration: InputDecoration(labelText: 'Desk ID'),
            ),
            TextFormField(
              controller: _empIdController,
              decoration: InputDecoration(labelText: 'Employee ID'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveChanges,
              child: Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _saveChanges() async {
    if (_dateController.text.isEmpty ||
        _statusController.text.isEmpty ||
        _deskIdController.text.isEmpty ||
        _empIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please fill all fields'),
      ));
      return;
    }

    DocumentSnapshot snapshot = await FirebaseFirestore.instance
        .collection('booking')
        .doc(widget.bookingId)
        .get();

    Map<String, dynamic> oldData = snapshot.data() as Map<String, dynamic>;

    if (_dateController.text == oldData['booking_date'] &&
        _statusController.text == oldData['booking_status'] &&
        _deskIdController.text == oldData['desk_id'] &&
        _empIdController.text == oldData['emp_id']) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No changes made'),
      ));
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('booking')
          .doc(widget.bookingId)
          .update({
        'booking_date': _dateController.text,
        'booking_status': _statusController.text,
        'desk_id': _deskIdController.text,
        'emp_id': _empIdController.text,
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Booking updated successfully'),
      ));
    } catch (error) {
      print("Error updating booking: $error");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to update booking'),
      ));
    }
  }
}

class AddBookingScreen extends StatefulWidget {
  @override
  _AddBookingScreenState createState() => _AddBookingScreenState();
}

class _AddBookingScreenState extends State<AddBookingScreen> {
  final TextEditingController _dateController = TextEditingController();
  String? _selectedEmployeeId;
  bool _isLoadingEmployees = false;
  List<String> _availableEmployeeIds = [];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _selectDate() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 30)),
    );
    if (pickedDate != null) {
      _dateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
      await _loadAvailableEmployees(pickedDate);
    }
  }

  Future<void> _loadAvailableEmployees(DateTime selectedDate) async {
    setState(() {
      _isLoadingEmployees = true;
    });

    var bookingsSnapshot = await FirebaseFirestore.instance
        .collection('booking')
        .where('booking_date',
            isEqualTo: DateFormat('yyyy-MM-dd').format(selectedDate))
        .get();

    var bookedEmployeeIds =
        bookingsSnapshot.docs.map((doc) => doc['emp_id'] as String).toList();

    var employeeSnapshot = await FirebaseFirestore.instance
        .collection('employee')
        .where(FieldPath.documentId,
            whereNotIn:
                bookedEmployeeIds.isEmpty ? ['dummy'] : bookedEmployeeIds)
        .get();

    setState(() {
      _availableEmployeeIds =
          employeeSnapshot.docs.map((doc) => doc.id).toList();
      _isLoadingEmployees = false;
    });
  }

  Future<void> _saveBooking() async {
    if (_dateController.text.isEmpty || _selectedEmployeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please fill all fields'),
      ));
      return;
    }

    DateTime selectedDate = DateTime.parse(_dateController.text);
    String deskId = await getAvailableDeskId(selectedDate);

    if (deskId == 'No available desk') {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No available desks for the selected date.'),
      ));
      return;
    }

    await FirebaseFirestore.instance.collection('booking').add({
      'booking_date': _dateController.text,
      'booking_status': 'scheduled',
      'desk_id': deskId,
      'emp_id': _selectedEmployeeId,
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Booking added successfully'),
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Booking'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _dateController,
              decoration: InputDecoration(labelText: 'Booking Date'),
              onTap: _selectDate,
            ),
            SizedBox(height: 16.0),
            _isLoadingEmployees
                ? CircularProgressIndicator()
                : DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: 'Employee ID'),
                    value: _selectedEmployeeId,
                    items: _availableEmployeeIds.map((id) {
                      return DropdownMenuItem<String>(
                        value: id,
                        child: Text(id),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedEmployeeId = value;
                      });
                    },
                  ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveBooking,
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
