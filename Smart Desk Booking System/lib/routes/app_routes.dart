import 'package:firebase/webPage/employee.dart';
import 'package:flutter/material.dart';
import 'package:firebase/phoneScreen/homepage.dart';
import 'package:firebase/phoneScreen/welcomepage.dart';
import 'package:firebase/phoneScreen/mapscreen.dart';
import 'package:firebase/phoneScreen/app_navigation_screen/app_navigation_screen.dart';

//import 'package:firebase/screen/four_screen.dart';
//import 'package:firebase/screen/one_screen.dart';
//import 'package:firebase/screen/five_screen.dart';
//import 'package:firebase/screen/six_screen.dart';
//import 'package:firebase/screen/seven_screen.dart';
//import 'package:firebase/screen/eight_screen.dart';

class AppRoutes {
  static const String iphone13ProMaxFourScreen =
      '/iphone_13_pro_max_four_screen';

  static const String iphone13ProMaxOneScreen = '/iphone_13_pro_max_one_screen';

  static const String iphone13ProMaxFiveScreen =
      '/iphone_13_pro_max_five_screen';

  static const String iphone13ProMaxSevenScreen =
      '/iphone_13_pro_max_seven_screen';

  static const String iphone13ProMaxEightScreen =
      '/iphone_13_pro_max_eight_screen';

  static const String Iphone13ProMaxTwoBottomsheet =
      '/iphone_13_pro_max_two_bottomsheet';

  static const String employeeScreen = '/employee';
  // static const String FourScreen = '/four_screen';

  //static const String FiveScreen = '/five_screen';

//  static const String SixScreen = '/six_screen';

  //static const String SevenScreen = '/seven_screen';

  //static const String EightScreen = '/eight_screen';

  static const String appNavigationScreen = '/app_navigation_screen';

  static Map<String, WidgetBuilder> routes = {
    iphone13ProMaxFourScreen: (context) => MainScreen(empId: empId),
    iphone13ProMaxOneScreen: (context) => welcomeScreen(),

    iphone13ProMaxSevenScreen: (context) =>
        Iphone13ProMaxSevenScreen(empId: empId),
    appNavigationScreen: (context) => AppNavigationScreen(),
    employeeScreen: (context) => EmployeePage(),
    //fourScreen: (context) => FourScreen(),
    //fiveScreen: (context) => FiveScreen(),
    //sixScreen: (context) => SixScreen(),
    //sevenScreen: (context) => SevenScreen(),
    //eightScreen: (context) => EightScreen(),
  };

  static get empId => null;
}
