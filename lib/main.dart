import 'package:flutter/material.dart';
import 'routes/app_routes.dart';
import 'features/auth/login_screen.dart';
import 'features/cliente/cliente_home.dart';
import 'features/admin/admin_home.dart';

void main() {
  runApp(const BarberApp());
}

class BarberApp extends StatelessWidget {
  const BarberApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BarberPro',
      routes: {
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.cliente: (_) => const ClienteHome(),
        AppRoutes.admin: (_) => const AdminHome(),
      },
      initialRoute: AppRoutes.login,
    );
  }
}
