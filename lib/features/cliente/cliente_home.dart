import 'package:flutter/material.dart';

class ClienteHome extends StatelessWidget {
  const ClienteHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cliente"),
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        children: const [
          Card(child: Center(child: Text("Reservar"))),
          Card(child: Center(child: Text("Escanear QR"))),
          Card(child: Center(child: Text("Mis puntos"))),
          Card(child: Center(child: Text("Membresía"))),
        ],
      ),
    );
  }
}
