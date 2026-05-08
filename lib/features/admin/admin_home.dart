import 'package:flutter/material.dart';

class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Administrador"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(
            child: ListTile(
              leading: Icon(Icons.people),
              title: Text("Clientes"),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.qr_code),
              title: Text("Generar QR"),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.attach_money),
              title: Text("Ingresos"),
            ),
          ),
        ],
      ),
    );
  }
}
