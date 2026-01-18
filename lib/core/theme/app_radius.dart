import 'package:flutter/material.dart';

class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double circle = 999.0;
  
  // Border Radius
  static const BorderRadius smallRadius = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mediumRadius = BorderRadius.all(Radius.circular(md));
  static const BorderRadius largeRadius = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlRadius = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius circularRadius = BorderRadius.all(Radius.circular(circle));
}
