import 'package:flutter/material.dart';

class HomeAdmin extends StatelessWidget {
  const HomeAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Unicorn')),
      body: const Center(child: Text('Dashboard Admin SaaS')),
    );
  }
}
