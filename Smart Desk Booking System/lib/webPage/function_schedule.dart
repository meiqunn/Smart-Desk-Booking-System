// scheduling_utils.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

Future<String> getAvailableDeskId(DateTime date) async {
  List<String> scheduledDeskIds = [];

  QuerySnapshot bookingSnapshot = await FirebaseFirestore.instance
      .collection('booking')
      .where('booking_date', isEqualTo: DateFormat('yyyy-MM-dd').format(date))
      .get();

  for (QueryDocumentSnapshot doc in bookingSnapshot.docs) {
    scheduledDeskIds.add(doc['desk_id']);
  }

  QuerySnapshot deskSnapshot =
      await FirebaseFirestore.instance.collection('desks').get();
  List allDeskIds = deskSnapshot.docs.map((doc) => doc['desk_id']).toList();

  List availableDeskIds =
      allDeskIds.where((deskId) => !scheduledDeskIds.contains(deskId)).toList();

  if (availableDeskIds.isNotEmpty) {
    return availableDeskIds[Random().nextInt(availableDeskIds.length)];
  } else {
    return 'No available desk';
  }
}
