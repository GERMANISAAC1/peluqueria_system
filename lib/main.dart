import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const BarberProApp());

class BarberProApp extends StatelessWidget {
  const BarberProApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BarberPro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFFC9A84C),
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

// ==================== BASE DE DATOS ====================
class BarberDB {
  static const String _key = 'barberpro_db';

  static Future<Map<String, dynamic>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_key);
    if (data == null) return _defaultData();
    return jsonDecode(data);
  }

  static Future<void> save(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_key, jsonEncode(data));
  }

  static Map<String, dynamic> _defaultData() {
    return {
      "usuarios": [
        {"id": "CLI001", "nombre": "Carlos Mendoza", "telefono": "987654321", "password": "123456", "rol": "cliente", "puntos": 320, "membresia": "Premium"},
        {"id": "ADM001", "nombre": "Admin BarberPro", "telefono": "999888777", "password": "admin123", "rol": "admin", "puntos": 0, "membresia": "Admin"}
      ],
      "citas": [],
    };
  }
}

// ==================== MODELOS ====================
class Usuario {
  final String id, nombre, telefono, rol, membresia;
  int puntos;
  Usuario({required this.id, required this.nombre, required this.telefono, required this.rol, this.membresia = "Ninguna", this.puntos = 0});
}

// ==================== LOGIN ====================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final telCtrl = TextEditingController(text: "987654321");
  final passCtrl = TextEditingController(text: "123456");
  bool loading = false;

  Future<void> login() async {
    setState(() => loading = true);
    await Future.delayed(const Duration(seconds: 1));

    if (telCtrl.text.trim() == "987654321" && passCtrl.text.trim() == "123456") {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ClienteMain()));
    } else if (telCtrl.text.trim() == "999888777" && passCtrl.text.trim() == "admin123") {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminMain()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Credenciales incorrectas"), backgroundColor: Colors.red));
    }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(-0.3, -0.5), radius: 1.3, colors: [Color(0xFF1A1200), Color(0xFF0A0A0A)])),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('✂️', style: TextStyle(fontSize: 90)),
                const Text('BarberPro', style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: Color(0xFFC9A84C))),
                const SizedBox(height: 50),
                TextField(controller: telCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Número de celular", border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone))),
                const SizedBox(height: 16),
                TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Contraseña", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock))),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: loading ? null : login,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC9A84C), foregroundColor: Colors.black),
                    child: loading ? const CircularProgressIndicator(color: Colors.black) : const Text("INICIAR SESIÓN", style: TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(height: 30),
                const Text("Demo Cliente:\n987654321 / 123456\nDemo Admin:\n999888777 / admin123", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== CLIENTE MAIN ====================
class ClienteMain extends StatefulWidget {
  const ClienteMain({super.key});
  @override
  State<ClienteMain> createState() => _ClienteMainState();
}

class _ClienteMainState extends State<ClienteMain> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const ClienteInicio(),
      const ClienteCitas(),
      const ClienteQR(),
      const ClientePuntos(),
      const ClientePerfil(),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        selectedItemColor: const Color(0xFFC9A84C),
        unselectedItemColor: Colors.grey,
        backgroundColor: const Color(0xFF111111),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Inicio"),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: "Citas"),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code), label: "QR"),
          BottomNavigationBarItem(icon: Icon(Icons.star), label: "Puntos"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Perfil"),
        ],
      ),
    );
  }
}

// ==================== PANTALLAS CLIENTE ====================
class ClienteInicio extends StatelessWidget {
  const ClienteInicio({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Hola, Carlos 👋", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text("Puntos: 320 ⭐ • Premium", style: TextStyle(color: Color(0xFFC9A84C), fontSize: 16)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text("Acceso Rápido", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            QuickCard("Reservar Cita", "📅", () {}),
            QuickCard("Mi QR", "📱", () {}),
            QuickCard("Mis Puntos", "⭐", () {}),
            QuickCard("Membresía", "👑", () {}),
          ],
        ),
      ],
    );
  }
}

class QuickCard extends StatelessWidget {
  final String title, emoji;
  final VoidCallback onTap;
  const QuickCard(this.title, this.emoji, this.onTap, {super.key});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(emoji, style: const TextStyle(fontSize: 42)), Text(title)]),
      ),
    );
  }
}

class ClienteCitas extends StatelessWidget {
  const ClienteCitas({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text("Mis Citas")));
}

class ClienteQR extends StatelessWidget {
  const ClienteQR({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("Mi QR")), body: const Center(child: Text("QR del Cliente\nCLI001", textAlign: TextAlign.center, style: TextStyle(fontSize: 20))));
}

class ClientePuntos extends StatelessWidget {
  const ClientePuntos({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("Mis Puntos")), body: const Center(child: Text("320 PUNTOS", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFFC9A84C)))));
}

class ClientePerfil extends StatelessWidget {
  const ClientePerfil({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("Perfil")), body: const Center(child: Text("Carlos Mendoza")));
}

class AdminMain extends StatelessWidget {
  const AdminMain({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("BarberPro - Admin")),
      body: const Center(child: Text("Panel de Administración", style: TextStyle(fontSize: 24))),
    );
  }
}
