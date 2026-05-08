
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Peluqueria Kety"),
        backgroundColor: const Color(0xFFE91E63),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Bienvenida",
                      style: TextStyle(color: Colors.white, fontSize: 22)),
                  SizedBox(height: 5),
                  Text("Reserva tu cita fácil y rápido",
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [

                _card(Icons.calendar_month, "Reservar"),
                _card(Icons.qr_code_scanner, "QR"),
                _card(Icons.star, "Puntos"),
                _card(Icons.workspace_premium, "VIP"),

              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _card(IconData icon, String title) {
    return Card(
      elevation: 3,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: const Color(0xFF9C27B0)),
            const SizedBox(height: 10),
            Text(title),
          ],
        ),
      ),
    );
  }
}
