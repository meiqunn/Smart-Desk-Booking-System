import 'package:firebase/phoneScreen/homepage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_sound/flutter_sound.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MaterialApp(home: LoginScreen()));
}

class LoginScreen extends StatefulWidget {
  final bool scanFromGallery;

  LoginScreen({this.scanFromGallery = false});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  MobileScannerController controller = MobileScannerController();
  final ImagePicker _picker = ImagePicker();
  static const platform =
      MethodChannel('com.teyyuanpingsapplication.app/qr_code');

  bool _isScanning = true;
  bool _isLoading = false;
  FlutterSoundPlayer _soundPlayer = FlutterSoundPlayer();

  @override
  void initState() {
    super.initState();
    _initializeSoundPlayer();
    if (widget.scanFromGallery) {
      _scanFromGallery();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    _soundPlayer.closePlayer();
    super.dispose();
  }

  void _initializeSoundPlayer() async {
    await _soundPlayer.openPlayer();
  }

  void _playSuccessSound() async {
    await _soundPlayer.startPlayer(fromURI: 'path_to_success_sound.mp3');
  }

  void _playErrorSound() async {
    await _soundPlayer.startPlayer(fromURI: 'path_to_error_sound.mp3');
  }

  void _onDetect(BarcodeCapture barcodeCapture) async {
    if (!_isScanning) return;
    setState(() {
      _isScanning = false;
      _isLoading = true;
    });

    final barcode = barcodeCapture.barcodes.first;
    final rawValue = barcode.rawValue;
    print('QR Code detected: $rawValue'); // Debug statement
    if (rawValue != null) {
      final uri = Uri.parse(rawValue);
      final employeeId = uri.queryParameters['employeeId'];
      final token = uri.queryParameters['token'];

      if (employeeId != null && token != null) {
        await _fetchEmployeeDataAndAuthenticate(employeeId, token);
      } else {
        _handleError('Invalid QR Code detected: $rawValue');
      }
    } else {
      _handleError('Invalid QR Code detected: ${barcode.rawValue}');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _fetchEmployeeDataAndAuthenticate(
      String employeeId, String token) async {
    print('Fetching employee data for ID: $employeeId'); // Debug statement
    try {
      final doc = await FirebaseFirestore.instance
          .collection('employee')
          .doc(employeeId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        print('Employee data fetched: $data'); // Debug statement
        if (data != null && data['token'] == token) {
          await _authenticateWithFirebase(employeeId, token, data['name']);
        } else {
          _handleError('Invalid token');
        }
      } else {
        _handleError('Employee data not found');
      }
    } catch (e) {
      _handleError('Error fetching employee data: $e');
    }
  }

  Future<void> _authenticateWithFirebase(
      String employeeId, String token, String empName) async {
    print(
        'Authenticating with Firebase for employee: $employeeId'); // Debug statement
    try {
      final response = await http.post(
        Uri.parse(
            'https://us-central1-fire-setup-b5eb2.cloudfunctions.net/api/authenticate'), // Use 10.0.2.2 for Android emulator
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(
            <String, String>{'employeeId': employeeId, 'token': token}),
      );

      print('Authentication response: ${response.body}'); // Debug statement
      if (response.statusCode == 200) {
        final customToken = jsonDecode(response.body)['customToken'];
        print('Custom token received: $customToken'); // Debug statement
        await FirebaseAuth.instance.signInWithCustomToken(customToken);
        Vibration.vibrate();
        _playSuccessSound();
        await _setTokenToNull(employeeId);
        _navigateToEmployeeDetail(employeeId);
      } else {
        _handleError('Failed to authenticate: ${response.body}');
      }
    } catch (e) {
      _handleError('Error authenticating with Firebase: $e');
    }
  }

  Future<void> _setTokenToNull(String employeeId) async {
    try {
      await FirebaseFirestore.instance
          .collection('employee')
          .doc(employeeId)
          .update({'token': null});
      print('Token set to null for employee: $employeeId'); // Debug statement
    } catch (e) {
      print('Error setting token to null: $e'); // Debug statement
    }
  }

  void _navigateToEmployeeDetail(String employeeId) {
    print(
        'Navigating to MainScreen with employee ID: $employeeId'); // Debug statement
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => MainScreen(empId: employeeId)),
    );
  }

  Future<void> _scanFromGallery() async {
    try {
      setState(() {
        _isLoading = true;
      });
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final File file = File(image.path);
        print('Image picked: ${file.path}'); // Debug statement
        final qrCode = await _scanQRCodeFromFile(file);
        print('QR Code from file: $qrCode'); // Debug statement
        if (qrCode != null) {
          final uri = Uri.parse(qrCode);
          final employeeId = uri.queryParameters['employeeId'];
          final token = uri.queryParameters['token'];

          if (employeeId != null && token != null) {
            await _fetchEmployeeDataAndAuthenticate(employeeId, token);
          } else {
            _handleError('Invalid QR Code from gallery: $qrCode');
          }
        } else {
          _handleError('No QR code found in the image');
        }
      } else {
        print('No image picked.');
      }
    } catch (e) {
      _handleError('Error scanning QR code from gallery: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String?> _scanQRCodeFromFile(File file) async {
    final byteArray = await file.readAsBytes();
    print('File bytes length: ${byteArray.length}'); // Debug statement
    try {
      final qrCode = await platform
          .invokeMethod<String>('decodeQRCode', {'image': byteArray});
      print('Decoded QR code: $qrCode'); // Debug statement
      return qrCode;
    } catch (e) {
      print('Error decoding QR code from file: $e'); // Debug statement
      return null;
    }
  }

  void _handleError(String message) {
    Vibration.vibrate();
    _playErrorSound();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    Navigator.pop(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login with QR Code')),
      body: Stack(
        children: [
          Column(
            children: <Widget>[
              Expanded(
                flex: 4,
                child: MobileScanner(
                  key: qrKey,
                  controller: controller,
                  onDetect: _onDetect,
                ),
              ),
              Expanded(
                flex: 1,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Scan a QR code to log in'),
                      ElevatedButton(
                        onPressed: _scanFromGallery,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                              horizontal: 40.0, vertical: 20.0),
                          backgroundColor: Colors.orange,
                          textStyle: TextStyle(
                            fontSize: 20.0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                        child: Text('Scan from Gallery',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
