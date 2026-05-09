import 'package:flutter/material.dart';

class AppProvider {
  static List<ChangeNotifierProvider> providers = [
    ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
    ChangeNotifierProvider<AppointmentProvider>(create: (_) => AppointmentProvider()),
    ChangeNotifierProvider<PointsProvider>(create: (_) => PointsProvider()),
  ];
}

class AuthProvider extends ChangeNotifier {}
class AppointmentProvider extends ChangeNotifier {}
class PointsProvider extends ChangeNotifier {}
