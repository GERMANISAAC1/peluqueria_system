import 'package:flutter/material.dart';
import '../presentation/screens/auth/login.dart';
import '../presentation/screens/cliente/home_cliente.dart';
import '../presentation/screens/admin/home_admin.dart';

class RouteGenerator {
  static Route generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case '/cliente':
        return MaterialPageRoute(builder: (_) => const HomeCliente());
      case '/admin':
        return MaterialPageRoute(builder: (_) => const HomeAdmin());
      default:
        return MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text('404'))));
    }
  }
}
