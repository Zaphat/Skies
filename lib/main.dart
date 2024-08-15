import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});
  static const Map<String, LinearGradient> theme_day = {
    'no_rain': LinearGradient(
        colors: [
          Color(0xff3F28CF),
          Color(0xff5A6AC0),
          Color(0xff4CBAE9),
          Color(0xffE89153)
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.0, 1 / 3, 2 / 3, 1.0],
        tileMode: TileMode.clamp,
        transform: GradientRotation(-pi)
        )
  };
  static Map<String, dynamic> theme_night = {};
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        body: Container(
          decoration: BoxDecoration(
            gradient: theme_day['no_rain'],
          ),
        ),
      )
    );
}


}