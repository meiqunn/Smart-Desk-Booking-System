import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/app_export.dart';
import 'web_content.dart';
import 'mobile_content.dart';

var globalMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyCg6rme4z1U20jRKVuW0mnmSXhv-Qs3jrM",
      authDomain: "fire-setup-b5eb2.firebaseapp.com",
      projectId: "fire-setup-b5eb2",
      storageBucket: "fire-setup-b5eb2.appspot.com",
      messagingSenderId: "828620305422",
      appId: "1:828620305422:web:3699a295c544a14d96b85f",
      measurementId: "G-38FEML7MGX",
    ),
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Please update theme as per your need if required.
  ThemeHelper().changeTheme('primary');
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'meiqunFYP',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ResponsiveContent(),
      debugShowCheckedModeBanner:
          false, // Add this line to remove the debug banner
      routes: AppRoutes.routes,
    );
  }
}

class ResponsiveContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return kIsWeb
        ? WebContent()
        : MobileContent(); // Use kIsWeb to determine the content
  }
}
