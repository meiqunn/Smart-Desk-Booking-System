import 'dart:io';
import 'dart:math';
import 'package:firebase/core/utils/image_constant.dart';
import 'package:firebase/core/utils/size_utils.dart';
import 'package:firebase/phoneScreen/QRlogin.dart';
import 'package:firebase/phoneScreen/welcomepage.dart';
import 'package:firebase/theme/custom_text_style.dart';
import 'package:firebase/theme/theme_helper.dart';
import 'package:firebase/widgets/custom_elevated_button.dart';
import 'package:firebase/widgets/custom_icon_button.dart';
import 'package:firebase/widgets/custom_image_view.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart' as mailer_pkg;
import 'package:mailer/smtp_server.dart';
import 'package:qr_flutter/qr_flutter.dart';

class Iphone13ProMaxTwoBottomsheet extends StatefulWidget {
  final String email;

  const Iphone13ProMaxTwoBottomsheet({Key? key, required this.email})
      : super(key: key);

  @override
  _Iphone13ProMaxTwoBottomsheetState createState() =>
      _Iphone13ProMaxTwoBottomsheetState();
}

class _Iphone13ProMaxTwoBottomsheetState
    extends State<Iphone13ProMaxTwoBottomsheet> {
  String? qrCodeImagePath;

  @override
  void initState() {
    super.initState();
    _sendEmailWithToken(widget.email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('QR Code Scanner'),
      ),
      body: Container(
        width: double.maxFinite,
        padding: EdgeInsets.symmetric(horizontal: 21, vertical: 26),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.only(left: 84.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 440.v,
                      width: 213.h,
                      child: Stack(
                        alignment: Alignment.topCenter,
                        children: [
                          CustomImageView(
                            imagePath: ImageConstant.imgQr,
                            height: 180.adaptSize,
                            width: 180.adaptSize,
                            alignment: Alignment.bottomCenter,
                          ),
                          _buildQrCodeSection(context),
                        ],
                      ),
                    ),
                    Padding(
                      padding:
                          EdgeInsets.only(left: 43.h, top: 5.v, bottom: 395.v),
                      child: CustomIconButton(
                        height: 43.v,
                        width: 41.h,
                        child: CustomImageView(
                            //imagePath: ImageConstant.imgGrid,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 18),
            Text(
              "QR Code has been sent to your email.",
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),
            CustomElevatedButton(
              text: "Scan the code",
              margin: EdgeInsets.only(left: 31, right: 36),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LoginScreen(scanFromGallery: false),
                  ),
                );
              },
            ),
            SizedBox(height: 20),
            CustomElevatedButton(
              width: 197,
              text: "Scan by gallery",
              rightIcon: Container(
                margin: EdgeInsets.only(left: 11),
                child: CustomImageView(
                  //imagePath: ImageConstant.imgBookmark,
                  height: 27,
                  width: 27,
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LoginScreen(scanFromGallery: true),
                  ),
                );
              },
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildQrCodeSection(BuildContext context) {
    Color orangeColor = Colors.orange;

    return SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 101.v),
          Text("Scan QR code", style: theme.textTheme.titleMedium),
          SizedBox(height: 16.v),
          SizedBox(
            width: 218.h,
            child: Text(
              "Place QR code inside the frame to scan. Please avoid shaking to get results quickly.",
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: CustomTextStyles.labelMediumInterGray400,
            ),
          ),
          SizedBox(height: 127.v),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              height: 13.adaptSize,
              width: 13.adaptSize,
              margin: EdgeInsets.only(left: 63.h),
              decoration: BoxDecoration(
                color: orangeColor,
                borderRadius: BorderRadius.circular(6.h),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendEmailWithToken(String email) async {
    final newToken = _generateToken();

    final employeeId = await _getEmployeeIdByEmail(email);

    if (employeeId == null) {
      print('No employee found with email: $email');
      return;
    }
    await _updateTokenInFirestore(employeeId, newToken);

    final qrCodeImageFile = await _generateQRCodeImage(employeeId, newToken);

    setState(() {
      qrCodeImagePath = qrCodeImageFile.path;
    });

    // send mail
    final smtpServer = gmail('qunqunqun142@gmail.com', 'zjcpokmdxfdovnlq');
    final message = mailer_pkg.Message()
      ..from = mailer_pkg.Address(
          'qunqunqun142@gmail.com', 'Smart Desk Booking System')
      ..recipients.add(email)
      ..subject = 'Confirm to get your Login'
      ..text = 'Your custom token is: $newToken'
      ..attachments = [
        mailer_pkg.FileAttachment(qrCodeImageFile)
          ..location = mailer_pkg.Location.inline
          ..cid = 'qrcode@myapp.com'
      ]
      ..html = '<h1>Your QR Code</h1><img src="cid:qrcode@myapp.com">';

    try {
      await mailer_pkg.send(message, smtpServer);
      print('Email sent successfully');
    } catch (e) {
      print('Error sending email: $e');
    }
  }

  Future<String?> _getEmployeeIdByEmail(String email) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('employee')
        .where('email', isEqualTo: email)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.id;
    }
    return null;
  }

  String _generateToken() {
    const String _chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    Random _rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        10, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));
  }

  Future<void> _updateTokenInFirestore(
      String employeeId, String newToken) async {
    await FirebaseFirestore.instance
        .collection('employee')
        .doc(employeeId)
        .update({'token': newToken});
  }

  Future<File> _generateQRCodeImage(String employeeId, String token) async {
    final qrData =
        'https://us-central1-fire-setup-b5eb2.cloudfunctions.net/api/authenticate?employeeId=$employeeId&token=$token';
    final qrValidationResult = QrValidator.validate(
      data: qrData,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.L,
    );

    if (qrValidationResult.status == QrValidationStatus.valid) {
      final qrCode = qrValidationResult.qrCode!;
      final painter = QrPainter.withQr(
        qr: qrCode,
        color: Color(0xff000000),
        emptyColor: Color(0xffffffff),
        gapless: true,
      );

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/qr_code.png').create();
      await painter.toImageData(200).then((byteData) {
        file.writeAsBytesSync(byteData!.buffer.asUint8List());
      });
      return file;
    } else {
      throw Exception('Failed to generate QR code');
    }
  }
}
