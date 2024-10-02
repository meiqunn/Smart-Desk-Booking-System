import 'package:firebase/phoneScreen/homepage.dart';
import 'package:firebase/phoneScreen/welcomepage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:uni_links/uni_links.dart';
import 'dart:async';
import 'core/app_export.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MobileContent());
}

class MobileContent extends StatefulWidget {
  @override
  _MobileContentState createState() => _MobileContentState();
}

class _MobileContentState extends State<MobileContent> {
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _initUniLinks();
  }

  Future<void> _initUniLinks() async {
    _sub = linkStream.listen((String? link) {
      if (link != null) {
        _handleIncomingLink(link);
      }
    }, onError: (err) {
      // handle error
    });

    // check initial link
    try {
      final initialLink = await getInitialLink();
      if (initialLink != null) {
        _handleIncomingLink(initialLink);
      }
    } on PlatformException {
      // handle error
    } on FormatException {
      // handle format error
    }
  }

  void _handleIncomingLink(String link) {
    Uri uri = Uri.parse(link);
    if (uri.path == '/api/authenticate') {
      String? employeeId = uri.queryParameters['employeeId'];
      String? token = uri.queryParameters['token'];
      // navigate to the specify
      if (employeeId != null && token != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                AuthenticationPage(employeeId: employeeId, token: token),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp(
          theme: theme,
          title: 'meiqunFYP',
          debugShowCheckedModeBanner: false,
          home: AuthHandler(),
          routes: AppRoutes.routes,
        );
      },
    );
  }
}

class AuthHandler extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasData) {
          return MainScreen(empId: snapshot.data!.uid);
        } else {
          return welcomeScreen();
        }
      },
    );
  }
}

class AuthenticationPage extends StatelessWidget {
  final String employeeId;
  final String token;

  AuthenticationPage({required this.employeeId, required this.token});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Authentication Page'),
      ),
      body: Center(
        child: Text('Employee ID: $employeeId\nToken: $token'),
      ),
    );
  }
}
