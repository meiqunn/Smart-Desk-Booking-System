import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase/phoneScreen/homepage.dart';
import 'package:firebase/phoneScreen/scanpage.dart';
import 'package:flutter_svg_provider/flutter_svg_provider.dart' as fs;
import 'package:firebase/core/utils/image_constant.dart';

class welcomeScreen extends StatefulWidget {
  const welcomeScreen({Key? key}) : super(key: key);

  @override
  _welcomeScreenState createState() => _welcomeScreenState();
}

class _welcomeScreenState extends State<welcomeScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _errorText;
  String _currentScreen = 'welcome';
  String? _email;
  bool _isLoading = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        automaticallyImplyLeading: _currentScreen != 'welcome',
        leading: _currentScreen != 'welcome'
            ? IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _currentScreen = 'welcome';
                    _errorText = null;
                  });
                },
              )
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: _buildCurrentScreen(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _getTitle() {
    switch (_currentScreen) {
      case 'welcome':
        return '';
      case 'chooseLogin':
        return 'Choose Login Method';
      case 'login':
        return 'Email Login';
      default:
        return '';
    }
  }

  Widget _buildCurrentScreen() {
    switch (_currentScreen) {
      case 'welcome':
        return _buildWelcomeScreen();
      case 'login':
        return _buildSimpleLoginScreen();
      default:
        return _buildWelcomeScreen();
    }
  }

  Widget _buildWelcomeScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Spacer(),
        Text(
          "Welcome to Continental\nSmart Desk Booking app",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        Container(
          height: 150,
          width: 150,
          margin: EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            image: DecorationImage(
              image: fs.Svg(ImageConstant.imgGroup2),
              fit: BoxFit.cover,
            ),
          ),
          child: Image.asset(
            ImageConstant.imgScan,
            height: 50,
            width: 50,
            alignment: Alignment.center,
          ),
        ),
        SizedBox(height: 20),
        Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: 227,
            child: Text(
              "Book a desk in easy way.",
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
        SizedBox(height: 10),
        TextField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: 'Email Address',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        if (_errorText != null) ...[
          SizedBox(height: 20),
          Text(
            _errorText!,
            style: TextStyle(color: Colors.red),
          ),
        ],
        SizedBox(height: 20),
        SizedBox(
          height: 40,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _validateEmail,
            child: _isLoading
                ? CircularProgressIndicator(color: Colors.black)
                : const Text('Next',
                    style: TextStyle(color: Colors.black, fontSize: 20)),
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all<Color>(Colors.orange),
            ),
          ),
        ),
        Spacer(),
      ],
    );
  }

  onTapLetsGetStarted(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _buildChooseLoginMethodScreen(context),
      isScrollControlled: true,
    );
  }

  Widget _buildChooseLoginMethodScreen(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.3,
      child: Container(
        padding: EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.email),
              title: Text('Login with Email'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _currentScreen = 'login';
                });
              },
            ),
            ListTile(
              leading: Icon(Icons.qr_code),
              title: Text('Login with QR Code'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        Iphone13ProMaxTwoBottomsheet(email: _email!),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleLoginScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Spacer(),
        Text(
          "Login to Your Account",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        Container(
          height: 150,
          width: 150,
          margin: EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            image: DecorationImage(
              image: fs.Svg(ImageConstant.imgGroup2),
              fit: BoxFit.cover,
            ),
          ),
          child: Image.asset(
            ImageConstant.imgScan,
            height: 50,
            width: 50,
            alignment: Alignment.center,
          ),
        ),
        SizedBox(height: 20),
        Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: 227,
            child: Text(
              "Enter your password to log in.",
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
        SizedBox(height: 10),
        TextField(
          controller: _passwordController,
          decoration: InputDecoration(
            labelText: 'Password',
            border: OutlineInputBorder(),
            errorText: _errorText,
          ),
          obscureText: true,
        ),
        SizedBox(height: 20),
        SizedBox(
          height: 40,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _login,
            child: _isLoading
                ? CircularProgressIndicator(color: Colors.black)
                : const Text('Login',
                    style: TextStyle(color: Colors.black, fontSize: 20)),
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all<Color>(Colors.orange),
            ),
          ),
        ),
        Spacer(),
      ],
    );
  }

  void _validateEmail() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    String email = _emailController.text.trim();
    print('Validating email: $email');

    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('employee')
          .where('email', isEqualTo: email)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          _email = email;
          _currentScreen = 'chooseLogin';
        });
        onTapLetsGetStarted(context);
      } else {
        print('Email not found in Firestore employee collection');
        _showEmailNotFoundAlert();
      }
    } catch (e) {
      print('Error during email validation: $e');
      setState(() {
        _errorText = 'Error checking email. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showEmailNotFoundAlert() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('We couldn\'t find your email'),
          content: Text('Please enter the correct email.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _login() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('employee')
          .where('email', isEqualTo: email)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        DocumentSnapshot userDoc = querySnapshot.docs.first;
        String empId = userDoc['ID'];

        // Set token to null after successful login
        await FirebaseFirestore.instance
            .collection('employee')
            .doc(empId)
            .update({'token': null});

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => MainScreen(
                    empId: empId,
                  )),
        );
      } else {
        setState(() {
          _errorText = 'No employee found with this email.';
        });
      }
    } catch (e) {
      print('Error during login: $e');
      setState(() {
        _errorText = 'Invalid password. Please try again.';
      });
    }
  }
}
