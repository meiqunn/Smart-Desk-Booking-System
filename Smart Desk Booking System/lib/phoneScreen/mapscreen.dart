import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase/webPage/view_seat.dart';

class Iphone13ProMaxSevenScreen extends StatelessWidget {
  final String empId;

  const Iphone13ProMaxSevenScreen({Key? key, required this.empId})
      : super(key: key);

  Future<String?> fetchEmployeeId() async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('employee')
          .where('uid', isEqualTo: empId)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        var data = querySnapshot.docs.first.data() as Map<String, dynamic>;
        var id = data['ID'];
        print('empid=$id');
        return data['ID'];
      }
    } catch (e) {
      print('Error fetching employee ID: $e');
    }
    return null;
  }

  /// Navigates back to the previous screen.
  onTapImgArrowLeft(BuildContext context) {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<String?>(
        future: fetchEmployeeId(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error fetching employee ID: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Text('Employee ID not found'),
            );
          }

          String employeeId = snapshot.data!;
          return Center(
            child: ViewSeatMap(
              bookingId: null,
              empId: employeeId,
            ),
          );
        },
      ),
    );
  }
}
