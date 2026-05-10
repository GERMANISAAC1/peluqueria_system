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
    String hoy = DateTime.now().toIso8601String().split('T')[0];
    return {
      "usuarios": [
        {"id": "CLI001", "nombre": "Carlos Mendoza", "telefono": "987654321", "password": "123456", "rol": "cliente", "puntos": 320, "membresia": "Premium"},
        {"id": "ADM001", "nombre": "Admin BarberPro", "telefono": "999888777", "password": "admin123", "rol": "admin", "puntos": 0, "membresia": "Admin"}
      ],
      "citas": [],
      "servicios": [
        {"id": "1", "nombre": "Corte Clásico", "precio": 25.0, "puntos": 10},
        {"id": "2", "nombre": "Corte + Barba", "precio": 40.0, "puntos": 15},
        {"id": "3", "nombre": "Degradado", "precio": 35.0, "puntos": 12},
      ]
    };
  }
}

// ==================== MODELOS ====================
class Usuario {
  String id, nombre, telefono, rol, membresia;
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

    final db = await BarberDB.load();
    final usuarios = db['usuarios'] as List;

    final userMap = usuarios.firstWhere(
      (u) => u['telefono'] == telCtrl.text.trim() && u['password'] == passCtrl.text.trim(),
      orElse: () => null,
    );

    if (userMap != null) {
      final user = Usuario(
        id: userMap['id'],
        nombre: userMap['nombre'],
        telefono: userMap['telefono'],
        rol: userMap['rol'],
        membresia: userMap['membresia'],
        puntos: userMap['puntos'],
      );

      if (user.rol == "cliente") {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ClienteMain(usuario: user)));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminMain()));
      }
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
  final Usuario usuario;
  const ClienteMain({super.key, required this.usuario});
  @override
  State<ClienteMain> createState() => _ClienteMainState();
}

class _ClienteMainState extends State<ClienteMain> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      ClienteInicio(usuario: widget.usuario),
      ClienteCitas(usuario: widget.usuario),
      ClienteQR(usuario: widget.usuario),
      ClientePuntos(usuario: widget.usuario),
      ClientePerfil(usuario: widget.usuario),
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

// ==================== PANTALLAS ====================
class ClienteInicio extends StatelessWidget {
  final Usuario usuario;
  const ClienteInicio({super.key, required this.usuario});
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Hola, ${usuario.nombre.split(" ")[0]} 👋", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text("Puntos: ${usuario.puntos} ⭐ • ${usuario.membresia}", style: const TextStyle(color: Color(0xFFC9A84C), fontSize: 16)),
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
            QuickCard("Puntos", "⭐", () {}),
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

// ==================== RESERVA DE CITA ====================
class ReservaCitaPage extends StatefulWidget {
  final Usuario usuario;
  const ReservaCitaPage({super.key, required this.usuario});
  @override
  State<ReservaCitaPage> createState() => _ReservaCitaPageState();
}

class _ReservaCitaPageState extends State<ReservaCitaPage> {
  String? selectedService;
  DateTime? selectedDate;
  String? selectedHora;

  final List<Map<String, dynamic>> servicios = [
    {"nombre": "Corte Clásico", "precio": 25.0},
    {"nombre": "Corte + Barba", "precio": 40.0},
    {"nombre": "Degradado", "precio": 35.0},
  ];

  Future<void> reservar() async {
    if (selectedService == null || selectedDate == null || selectedHora == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Completa todos los campos")));
      return;
    }

    final db = await BarberDB.load();
    final nuevaCita = {
      "id": "CIT${DateTime.now().millisecondsSinceEpoch}",
      "clienteId": widget.usuario.id,
      "clienteNombre": widget.usuario.nombre,
      "servicio": selectedService,
      "fecha": selectedDate!.toIso8601String().split('T')[0],
      "hora": selectedHora,
      "estado": "pendiente",
      "precio": servicios.firstWhere((s) => s['nombre'] == selectedService)['precio']
    };

    (db['citas'] as List).add(nuevaCita);
    await BarberDB.save(db);

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Cita reservada con éxito!"), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nueva Cita")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: "Servicio"),
              value: selectedService,
              items: servicios.map((s) => DropdownMenuItem<String>(
                    value: s['nombre'] as String,
                    child: Text("\( {s['nombre']} - S/ \){s['precio']}"),
                  )).toList(),
              onChanged: (v) => setState(() => selectedService = v),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: Text(selectedDate == null ? "Seleccionar fecha" : selectedDate!.toLocal().toString().split(' ')[0]),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (date != null) setState(() => selectedDate = date);
              },
            ),
            Wrap(
              children: ["09:00","10:00","11:00","14:00","15:00","16:00","17:00"].map((hora) => Padding(
                padding: const EdgeInsets.all(4),
                child: ChoiceChip(
                  label: Text(hora),
                  selected: selectedHora == hora,
                  onSelected: (sel) => setState(() => selectedHora = sel ? hora : null),
                ),
              )).toList(),
            ),
            const Spacer(),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: reservar, child: const Text("Confirmar Reserva"))),
          ],
        ),
      ),
    );
  }
}

// ==================== OTRAS PANTALLAS ====================
class ClienteCitas extends StatefulWidget {
  final Usuario usuario;
  const ClienteCitas({super.key, required this.usuario});
  @override
  State<ClienteCitas> createState() => _ClienteCitasState();
}

class _ClienteCitasState extends State<ClienteCitas> {
  List<dynamic> citas = [];

  @override
  void initState() {
    super.initState();
    _loadCitas();
  }

  Future<void> _loadCitas() async {
    final db = await BarberDB.load();
    setState(() => citas = db['citas'] ?? []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mis Citas")),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReservaCitaPage(usuario: widget.usuario))),
        child: const Icon(Icons.add),
      ),
      body: citas.isEmpty
          ? const Center(child: Text("No tienes citas todavía"))
          : ListView.builder(
              itemCount: citas.length,
              itemBuilder: (context, i) {
                final c = citas[i];
                return Card(
                  margin: const EdgeInsets.all(10),
                  child: ListTile(
                    title: Text(c['servicio']),
                    subtitle: Text("${c['fecha']} • ${c['hora']}"),
                    trailing: Chip(label: Text(c['estado'])),
                  ),
                );
              },
            ),
    );
  }
}

class ClienteQR extends StatelessWidget {
  final Usuario usuario;
  const ClienteQR({super.key, required this.usuario});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("Mi QR")), body: Center(child: Text("QR Cliente\n${usuario.id}", textAlign: TextAlign.center, style: const TextStyle(fontSize: 20))));
}

class ClientePuntos extends StatelessWidget {
  final Usuario usuario;
  const ClientePuntos({super.key, required this.usuario});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("Mis Puntos")), body: Center(child: Text("${usuario.puntos} PUNTOS", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFFC9A84C)))));
}

class ClientePerfil extends StatelessWidget {
  final Usuario usuario;
  const ClientePerfil({super.key, required this.usuario});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("Perfil")), body: Center(child: Text(usuario.nombre)));
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
