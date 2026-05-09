import 'package:flutter/material.dart';

class HomeCliente extends StatelessWidget {
  const HomeCliente({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cliente Unicorn')),
      body: const Center(child: Text('Dashboard Cliente SaaS')),
    );
  }
}
