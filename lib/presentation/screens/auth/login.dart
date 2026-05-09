import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('BarberPro Unicorn'),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/cliente'),
              child: const Text('Cliente'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/admin'),
              child: const Text('Admin'),
            ),
          ],
        ),
      ),
    );
  }
}
