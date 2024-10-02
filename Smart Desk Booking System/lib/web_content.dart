import 'package:firebase/core/app_export.dart';
import 'package:firebase/webPage/map_management.dart';
import 'package:firebase/webPage/booking.dart';
import 'package:flutter/material.dart';

import 'webPage/login.dart';

class WebContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Desk Booking System',
      home: LoginPage(),
      //home: BookingSystem(),
      initialRoute: '/', // Set initialRoute to your login screen
      routes: AppRoutes.routes, // Use the routes defined in app_routes.dart
    );
  }
}
