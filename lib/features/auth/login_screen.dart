import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.content_cut, size: 90),
            const SizedBox(height: 20),
            const Text(
              'BarberPro',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),

            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.cliente,
                );
              },
              icon: const Icon(Icons.person),
              label: const Text("Entrar como Cliente"),
            ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.admin,
                );
              },
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text("Entrar como Admin"),
            ),
          ],
        ),
      ),
    );
  }
}
