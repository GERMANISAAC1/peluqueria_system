import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(const BarberProApp());
}

class BarberProApp extends StatelessWidget {
  const BarberProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BarberPro',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFC9A84C),
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        fontFamily: 'Poppins',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF111111),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFFC9A84C),
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: 'PlayfairDisplay',
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF111111),
          selectedItemColor: Color(0xFFC9A84C),
          unselectedItemColor: Color(0xFF888888),
          type: BottomNavigationBarType.fixed,
        ),
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Splash Screen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFC9A84C), width: 2),
              ),
              child: const Center(
                child: Text('✂️', style: TextStyle(fontSize: 48)),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'BARBERPRO',
              style: TextStyle(
                color: Color(0xFFC9A84C),
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                fontFamily: 'PlayfairDisplay',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Login Screen
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.3),
            radius: 1.2,
            colors: const [
              Color(0xFF1A1200),
              Color(0xFF0A0A0A),
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFC9A84C), width: 2),
                  ),
                  child: const Center(
                    child: Text('✂️', style: TextStyle(fontSize: 42)),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'BarberPro',
                  style: TextStyle(
                    color: Color(0xFFC9A84C),
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'PlayfairDisplay',
                  ),
                ),
                const Text(
                  'Sistema de gestión profesional',
                  style: TextStyle(color: Color(0xFF888888), fontSize: 14),
                ),
                const SizedBox(height: 48),
                _buildLoginButton(
                  icon: '👤',
                  text: 'Entrar como Cliente',
                  onTap: () => _loginAs('cliente'),
                  isGold: true,
                ),
                const SizedBox(height: 16),
                _buildLoginButton(
                  icon: '⚙️',
                  text: 'Entrar como Administrador',
                  onTap: () => _loginAs('admin'),
                  isGold: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton({
    required String icon,
    required String text,
    required VoidCallback onTap,
    required bool isGold,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isGold ? const Color(0xFFC9A84C) : Colors.transparent,
          border: isGold ? null : Border.all(color: const Color(0xFFC9A84C), width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                color: isGold ? Colors.black : const Color(0xFFC9A84C),
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _loginAs(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_role', role);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => role == 'cliente'
            ? const ClienteMainScreen()
            : const AdminMainScreen(),
      ),
    );
  }
}

// Models
class Cliente {
  final String id;
  String nombre;
  String telefono;
  String email;
  String membresia;
  int puntos;
  List<HistorialPunto> historialPuntos;

  Cliente({
    required this.id,
    required this.nombre,
    required this.telefono,
    required this.email,
    required this.membresia,
    required this.puntos,
    required this.historialPuntos,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'telefono': telefono,
    'email': email,
    'membresia': membresia,
    'puntos': puntos,
    'historialPuntos': historialPuntos.map((e) => e.toJson()).toList(),
  };

  factory Cliente.fromJson(Map<String, dynamic> json) => Cliente(
    id: json['id'],
    nombre: json['nombre'],
    telefono: json['telefono'],
    email: json['email'],
    membresia: json['membresia'],
    puntos: json['puntos'],
    historialPuntos: (json['historialPuntos'] as List)
        .map((e) => HistorialPunto.fromJson(e))
        .toList(),
  );
}

class HistorialPunto {
  final String fecha;
  final String concepto;
  final int puntos;

  HistorialPunto({required this.fecha, required this.concepto, required this.puntos});

  Map<String, dynamic> toJson() => {
    'fecha': fecha,
    'concepto': concepto,
    'puntos': puntos,
  };

  factory HistorialPunto.fromJson(Map<String, dynamic> json) => HistorialPunto(
    fecha: json['fecha'],
    concepto: json['concepto'],
    puntos: json['puntos'],
  );
}

class Servicio {
  final String id;
  final String nombre;
  final String descripcion;
  final double precio;
  final int duracion;
  final int puntos;
  final String icono;
  bool activo;

  Servicio({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.precio,
    required this.duracion,
    required this.puntos,
    required this.icono,
    this.activo = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'descripcion': descripcion,
    'precio': precio,
    'duracion': duracion,
    'puntos': puntos,
    'icono': icono,
    'activo': activo,
  };

  factory Servicio.fromJson(Map<String, dynamic> json) => Servicio(
    id: json['id'],
    nombre: json['nombre'],
    descripcion: json['descripcion'],
    precio: json['precio'],
    duracion: json['duracion'],
    puntos: json['puntos'],
    icono: json['icono'],
    activo: json['activo'],
  );
}

class Cita {
  final String id;
  final String clienteId;
  final String clienteNombre;
  final String servicioId;
  final String servicioNombre;
  final String fecha;
  final String hora;
  String estado;
  final double precio;
  final String notas;

  Cita({
    required this.id,
    required this.clienteId,
    required this.clienteNombre,
    required this.servicioId,
    required this.servicioNombre,
    required this.fecha,
    required this.hora,
    required this.estado,
    required this.precio,
    required this.notas,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'clienteId': clienteId,
    'clienteNombre': clienteNombre,
    'servicioId': servicioId,
    'servicioNombre': servicioNombre,
    'fecha': fecha,
    'hora': hora,
    'estado': estado,
    'precio': precio,
    'notas': notas,
  };

  factory Cita.fromJson(Map<String, dynamic> json) => Cita(
    id: json['id'],
    clienteId: json['clienteId'],
    clienteNombre: json['clienteNombre'],
    servicioId: json['servicioId'],
    servicioNombre: json['servicioNombre'],
    fecha: json['fecha'],
    hora: json['hora'],
    estado: json['estado'],
    precio: json['precio'],
    notas: json['notas'],
  );
}

class Promocion {
  final String id;
  final String titulo;
  final String descripcion;
  final int descuento;
  final String hasta;
  bool activa;

  Promocion({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.descuento,
    required this.hasta,
    this.activa = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'titulo': titulo,
    'descripcion': descripcion,
    'descuento': descuento,
    'hasta': hasta,
    'activa': activa,
  };

  factory Promocion.fromJson(Map<String, dynamic> json) => Promocion(
    id: json['id'],
    titulo: json['titulo'],
    descripcion: json['descripcion'],
    descuento: json['descuento'],
    hasta: json['hasta'],
    activa: json['activa'],
  );
}

// Database Service
class DatabaseService {
  static const String _dbKey = 'barberpro_db';
  final SharedPreferences _prefs;

  DatabaseService(this._prefs);

  Future<void> initData() async {
    if (_prefs.getString(_dbKey) == null) {
      await _saveDefaultData();
    }
  }

  Future<void> _saveDefaultData() async {
    final hoy = DateTime.now().toIso8601String().split('T')[0];
    final data = {
      'clientes': [
        {
          'id': 'CLI001',
          'nombre': 'Carlos Mendoza',
          'telefono': '+51 987 654 321',
          'email': 'carlos@email.com',
          'membresia': 'Premium',
          'puntos': 320,
          'historialPuntos': [
            {'fecha': hoy, 'concepto': 'Corte clásico', 'puntos': 10}
          ],
        },
        {
          'id': 'CLI002',
          'nombre': 'Pedro Sánchez',
          'telefono': '+51 976 543 210',
          'email': 'pedro@email.com',
          'membresia': 'Básico',
          'puntos': 85,
          'historialPuntos': [],
        },
      ],
      'servicios': [
        {
          'id': 'SVC001',
          'nombre': 'Corte clásico',
          'descripcion': 'Corte tradicional con tijera',
          'precio': 25,
          'duracion': 30,
          'puntos': 10,
          'icono': '✂️',
          'activo': true,
        },
        {
          'id': 'SVC002',
          'nombre': 'Corte + barba',
          'descripcion': 'Corte y arreglo de barba completo',
          'precio': 40,
          'duracion': 50,
          'puntos': 15,
          'icono': '🪒',
          'activo': true,
        },
        {
          'id': 'SVC003',
          'nombre': 'Afeitado clásico',
          'descripcion': 'Afeitado con navaja caliente',
          'precio': 30,
          'duracion': 40,
          'puntos': 12,
          'icono': '🔥',
          'activo': true,
        },
        {
          'id': 'SVC004',
          'nombre': 'Degradado',
          'descripcion': 'Fade profesional a máquina',
          'precio': 35,
          'duracion': 45,
          'puntos': 13,
          'icono': '💈',
          'activo': true,
        },
      ],
      'citas': [
        {
          'id': 'CIT001',
          'clienteId': 'CLI001',
          'clienteNombre': 'Carlos Mendoza',
          'servicioId': 'SVC001',
          'servicioNombre': 'Corte clásico',
          'fecha': hoy,
          'hora': '10:00',
          'estado': 'confirmada',
          'precio': 25,
          'notas': '',
        },
        {
          'id': 'CIT002',
          'clienteId': 'CLI002',
          'clienteNombre': 'Pedro Sánchez',
          'servicioId': 'SVC002',
          'servicioNombre': 'Corte + barba',
          'fecha': hoy,
          'hora': '11:00',
          'estado': 'pendiente',
          'precio': 40,
          'notas': '',
        },
      ],
      'promociones': [
        {
          'id': 'PRO001',
          'titulo': 'Martes de descuento',
          'descripcion': '20% off en todos los cortes los martes',
          'descuento': 20,
          'hasta': '2025-12-31',
          'activa': true,
        },
      ],
    };
    await _prefs.setString(_dbKey, jsonEncode(data));
  }

  Future<Map<String, dynamic>> getData() async {
    final dataStr = _prefs.getString(_dbKey);
    return jsonDecode(dataStr!);
  }

  Future<void> saveData(Map<String, dynamic> data) async {
    await _prefs.setString(_dbKey, jsonEncode(data));
  }

  String generateId(String prefix) {
    return '$prefix${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
  }
}

// Cliente Main Screen
class ClienteMainScreen extends StatefulWidget {
  const ClienteMainScreen({super.key});

  @override
  State<ClienteMainScreen> createState() => _ClienteMainScreenState();
}

class _ClienteMainScreenState extends State<ClienteMainScreen> {
  int _selectedIndex = 0;
  late DatabaseService _db;
  Cliente? _clienteActual;

  @override
  void initState() {
    super.initState();
    _initDb();
  }

  Future<void> _initDb() async {
    final prefs = await SharedPreferences.getInstance();
    _db = DatabaseService(prefs);
    await _db.initData();
    await _loadClienteActual();
    setState(() {});
  }

  Future<void> _loadClienteActual() async {
    final data = await _db.getData();
    final clientes = (data['clientes'] as List).map((c) => Cliente.fromJson(c)).toList();
    _clienteActual = clientes.firstWhere((c) => c.id == 'CLI001');
  }

  Future<void> _refreshData() async {
    await _loadClienteActual();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_clienteActual == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0A),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final screens = [
      ClienteHomeScreen(cliente: _clienteActual!, db: _db, onRefresh: _refreshData),
      ClienteCitasScreen(cliente: _clienteActual!, db: _db, onRefresh: _refreshData),
      ClienteQRScreen(cliente: _clienteActual!),
      ClientePuntosScreen(cliente: _clienteActual!, db: _db, onRefresh: _refreshData),
      ClientePerfilScreen(cliente: _clienteActual!, db: _db, onRefresh: _refreshData),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('✂️ BarberPro'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFC9A84C).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.star, size: 14, color: Color(0xFFC9A84C)),
                const SizedBox(width: 4),
                Text(
                  '${_clienteActual!.puntos} pts',
                  style: const TextStyle(color: Color(0xFFC9A84C), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Citas'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code), label: 'QR'),
          BottomNavigationBarItem(icon: Icon(Icons.star), label: 'Puntos'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}

// Cliente Home Screen
class ClienteHomeScreen extends StatefulWidget {
  final Cliente cliente;
  final DatabaseService db;
  final VoidCallback onRefresh;

  const ClienteHomeScreen({
    super.key,
    required this.cliente,
    required this.db,
    required this.onRefresh,
  });

  @override
  State<ClienteHomeScreen> createState() => _ClienteHomeScreenState();
}

class _ClienteHomeScreenState extends State<ClienteHomeScreen> {
  List<Cita> _citas = [];
  List<Servicio> _servicios = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await widget.db.getData();
    setState(() {
      _citas = (data['citas'] as List).map((c) => Cita.fromJson(c)).toList();
      _servicios = (data['servicios'] as List)
          .map((s) => Servicio.fromJson(s))
          .where((s) => s.activo)
          .toList();
    });
  }

  Cita? _getProximaCita() {
    final hoy = DateTime.now().toIso8601String().split('T')[0];
    final citasCliente = _citas
        .where((c) => c.clienteId == widget.cliente.id && c.estado != 'cancelada')
        .toList();
    citasCliente.sort((a, b) => '$a.fecha $a.hora'.compareTo('$b.fecha $b.hora'));
    return citasCliente.firstWhere(
      (c) => c.fecha.compareTo(hoy) >= 0,
      orElse: () => citasCliente.isNotEmpty ? citasCliente.first : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final proximaCita = _getProximaCita();

    return RefreshIndicator(
      onRefresh: () async {
        await _loadData();
        widget.onRefresh();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A1200), Color(0xFF2A1F00)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFC9A84C)),
              ),
              child: Row(
                children: [
                  const Text('📅', style: TextStyle(fontSize: 36)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PRÓXIMA CITA',
                          style: TextStyle(
                            color: Color(0xFF888888),
                            fontSize: 11,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          proximaCita != null
                              ? '${_formatFecha(proximaCita.fecha)} · ${proximaCita.hora}'
                              : 'Sin citas programadas',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (proximaCita != null)
                          Text(
                            proximaCita.servicioNombre,
                            style: const TextStyle(
                              color: Color(0xFFC9A84C),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFC9A84C)),
                    ),
                    child: const Text('Ver', style: TextStyle(color: Color(0xFFC9A84C))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildStatCard(
                  icon: '📅',
                  value: _citas.where((c) => c.clienteId == widget.cliente.id).length.toString(),
                  label: 'Citas totales',
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  icon: '⭐',
                  value: widget.cliente.puntos.toString(),
                  label: 'Mis puntos',
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'ACCESO RÁPIDO',
                style: TextStyle(
                  color: Color(0xFFC9A84C),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: [
                _buildQuickAccessCard(
                  icon: '✂️',
                  title: 'Reservar cita',
                  subtitle: 'Elige tu servicio',
                  onTap: () => _showReservarDialog(),
                ),
                _buildQuickAccessCard(
                  icon: '📱',
                  title: 'Mi QR',
                  subtitle: 'Código de cliente',
                  onTap: () {},
                ),
                _buildQuickAccessCard(
                  icon: '⭐',
                  title: 'Mis puntos',
                  subtitle: 'Programa de lealtad',
                  onTap: () {},
                ),
                _buildQuickAccessCard(
                  icon: '👑',
                  title: 'Membresía',
                  subtitle: 'Planes y beneficios',
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({required String icon, required String value, required String label}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFFC9A84C),
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Color(0xFF888888), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessCard({
    required String icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF222222),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(subtitle, style: const TextStyle(color: Color(0xFF888888), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  void _showReservarDialog() {
    showDialog(
      context: context,
      builder: (context) => ReservarCitaDialog(
        db: widget.db,
        cliente: widget.cliente,
        onSuccess: () {
          _loadData();
          widget.onRefresh();
        },
      ),
    );
  }

  String _formatFecha(String fecha) {
    final parts = fecha.split('-');
    if (parts.length != 3) return fecha;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }
}

// Reservar Cita Dialog
class ReservarCitaDialog extends StatefulWidget {
  final DatabaseService db;
  final Cliente cliente;
  final VoidCallback onSuccess;

  const ReservarCitaDialog({
    super.key,
    required this.db,
    required this.cliente,
    required this.onSuccess,
  });

  @override
  State<ReservarCitaDialog> createState() => _ReservarCitaDialogState();
}

class _ReservarCitaDialogState extends State<ReservarCitaDialog> {
  List<Servicio> _servicios = [];
  Servicio? _servicioSeleccionado;
  DateTime _fechaSeleccionada = DateTime.now();
  String? _horaSeleccionada;
  String _notas = '';

  final List<String> _horas = [
    '09:00', '09:30', '10:00', '10:30', '11:00', '11:30',
    '12:00', '14:00', '14:30', '15:00', '15:30', '16:00', '16:30', '17:00', '17:30', '18:00'
  ];

  @override
  void initState() {
    super.initState();
    _loadServicios();
  }

  Future<void> _loadServicios() async {
    final data = await widget.db.getData();
    setState(() {
      _servicios = (data['servicios'] as List)
          .map((s) => Servicio.fromJson(s))
          .where((s) => s.activo)
          .toList();
    });
  }

  Future<List<Cita>> _getCitasOcupadas() async {
    final data = await widget.db.getData();
    final citas = (data['citas'] as List)
        .map((c) => Cita.fromJson(c))
        .where((c) => c.fecha == _fechaSeleccionada.toIso8601String().split('T')[0])
        .toList();
    return citas;
  }

  bool _isHoraOcupada(String hora, List<Cita> citas) {
    return citas.any((c) => c.hora == hora && c.estado != 'cancelada');
  }

  Future<void> _crearCita() async {
    if (_servicioSeleccionado == null) {
      _showSnackbar('Selecciona un servicio');
      return;
    }
    if (_horaSeleccionada == null) {
      _showSnackbar('Selecciona un horario');
      return;
    }

    final citasOcupadas = await _getCitasOcupadas();
    if (_isHoraOcupada(_horaSeleccionada!, citasOcupadas)) {
      _showSnackbar('Horario no disponible');
      return;
    }

    final data = await widget.db.getData();
    final nuevaCita = {
      'id': widget.db.generateId('CIT'),
      'clienteId': widget.cliente.id,
      'clienteNombre': widget.cliente.nombre,
      'servicioId': _servicioSeleccionado!.id,
      'servicioNombre': _servicioSeleccionado!.nombre,
      'fecha': _fechaSeleccionada.toIso8601String().split('T')[0],
      'hora': _horaSeleccionada,
      'estado': 'pendiente',
      'precio': _servicioSeleccionado!.precio,
      'notas': _notas,
    };
    data['citas'].add(nuevaCita);
    await widget.db.saveData(data);

    if (mounted) {
      Navigator.pop(context);
      widget.onSuccess();
      _showSnackbar('Cita reservada con éxito', isError: false);
    }
  }

  void _showSnackbar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reservar Cita',
                  style: TextStyle(
                    color: Color(0xFFC9A84C),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Elige el servicio', style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _servicios.length,
                itemBuilder: (context, index) {
                  final servicio = _servicios[index];
                  final isSelected = _servicioSeleccionado?.id == servicio.id;
                  return GestureDetector(
                    onTap: () => setState(() => _servicioSeleccionado = servicio),
                    child: Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF222222),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFC9A84C)
                              : const Color(0xFFC9A84C).withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(servicio.icono, style: const TextStyle(fontSize: 24)),
                          Text(servicio.nombre, style: const TextStyle(fontSize: 12)),
                          Text(
                            'S/${servicio.precio}',
                            style: const TextStyle(color: Color(0xFFC9A84C), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text('Fecha', style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF222222),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Color(0xFF888888)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _fechaSeleccionada,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 60)),
                            builder: (context, child) {
                              return Theme(
                                data: ThemeData.dark().copyWith(
                                  colorScheme: const ColorScheme.dark(
                                    primary: Color(0xFFC9A84C),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (date != null) {
                            setState(() => _fechaSeleccionada = date);
                          }
                        },
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${_fechaSeleccionada.day}/${_fechaSeleccionada.month}/${_fechaSeleccionada.year}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Horario disponible', style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: FutureBuilder<List<Cita>>(
                future: _getCitasOcupadas(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final ocupadas = snapshot.data!;
                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: _horas.length,
                    itemBuilder: (context, index) {
                      final hora = _horas[index];
                      final isOcupada = _isHoraOcupada(hora, ocupadas);
                      final isSelected = _horaSeleccionada == hora;
                      return GestureDetector(
                        onTap: isOcupada ? null : () => setState(() => _horaSeleccionada = hora),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFC9A84C)
                                : const Color(0xFF222222),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isOcupada
                                  ? Colors.red.withOpacity(0.3)
                                  : const Color(0xFFC9A84C).withOpacity(0.2),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              hora,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.black
                                    : isOcupada
                                        ? Colors.red
                                        : Colors.white,
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : null,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text('Notas (opcional)', style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
            const SizedBox(height: 8),
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF222222),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                hintText: 'Indicaciones especiales...',
                hintStyle: const TextStyle(color: Color(0xFF555555)),
              ),
              onChanged: (value) => _notas = value,
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _crearCita,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC9A84C),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('✅ Confirmar reserva', fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Cliente Citas Screen
class ClienteCitasScreen extends StatefulWidget {
  final Cliente cliente;
  final DatabaseService db;
  final VoidCallback onRefresh;

  const ClienteCitasScreen({
    super.key,
    required this.cliente,
    required this.db,
    required this.onRefresh,
  });

  @override
  State<ClienteCitasScreen> createState() => _ClienteCitasScreenState();
}

class _ClienteCitasScreenState extends State<ClienteCitasScreen> {
  List<Cita> _citas = [];

  @override
  void initState() {
    super.initState();
    _loadCitas();
  }

  Future<void> _loadCitas() async {
    final data = await widget.db.getData();
    setState(() {
      _citas = (data['citas'] as List)
          .map((c) => Cita.fromJson(c))
          .where((c) => c.clienteId == widget.cliente.id)
          .toList();
      _citas.sort((a, b) => '$b.fecha $b.hora'.compareTo('$a.fecha $a.hora'));
    });
  }

  Future<void> _cancelarCita(Cita cita) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Cancelar cita'),
        content: const Text('¿Estás seguro de que quieres cancelar esta cita?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final data = await widget.db.getData();
    final citas = data['citas'] as List;
    final index = citas.indexWhere((c) => c['id'] == cita.id);
    if (index != -1) {
      citas[index]['estado'] = 'cancelada';
      await widget.db.saveData(data);
      await _loadCitas();
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cita cancelada'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _getEstadoColor(String estado) {
    switch (estado) {
      case 'pendiente': return '#5A9CE0';
      case 'confirmada': return '#C9A84C';
      case 'completada': return '#4CAF82';
      case 'cancelada': return '#E05A5A';
      default: return '#888888';
    }
  }

  String _formatFecha(String fecha) {
    final parts = fecha.split('-');
    if (parts.length != 3) return fecha;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    if (_citas.isEmpty) {
      return const Center(
        child: Text(
          'No tienes citas registradas',
          style: TextStyle(color: Color(0xFF888888)),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCitas,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _citas.length,
        itemBuilder: (context, index) {
          final cita = _citas[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cita.servicioNombre,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_formatFecha(cita.fecha)} · ${cita.hora}',
                            style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Color(int.parse(_getEstadoColor(cita.estado).substring(1), radix: 16))
                            .withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        cita.estado.toUpperCase(),
                        style: TextStyle(
                          color: Color(int.parse(_getEstadoColor(cita.estado).substring(1), radix: 16)),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'S/ ${cita.precio.toStringAsFixed(0)}',
                      style: const TextStyle(color: Color(0xFFC9A84C), fontWeight: FontWeight.w600),
                    ),
                    if (cita.estado == 'pendiente' || cita.estado == 'confirmada')
                      OutlinedButton(
                        onPressed: () => _cancelarCita(cita),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE05A5A)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        child: const Text('Cancelar', style: TextStyle(color: Color(0xFFE05A5A))),
                      ),
                  ],
                ),
                if (cita.notas.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '📝 ${cita.notas}',
                    style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// Cliente QR Screen
class ClienteQRScreen extends StatelessWidget {
  final Cliente cliente;

  const ClienteQRScreen({super.key, required this.cliente});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                width: 200,
                height: 200,
                color: Colors.white,
                child: Center(
                  child: Text(
                    cliente.id,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Text(
                    'ID: ${cliente.id}',
                    style: const TextStyle(color: Color(0xFF888888), fontSize: 12, letterSpacing: 2),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC9A84C).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      cliente.membresia != 'Ninguna' ? '👑 ${cliente.membresia}' : 'Cliente estándar',
                      style: const TextStyle(color: Color(0xFFC9A84C), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '💡 El barbero escaneará tu código y se registrará automáticamente el servicio en tu historial de puntos.',
                style: TextStyle(color: Color(0xFF888888), fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Cliente Puntos Screen
class ClientePuntosScreen extends StatefulWidget {
  final Cliente cliente;
  final DatabaseService db;
  final VoidCallback onRefresh;

  const ClientePuntosScreen({
    super.key,
    required this.cliente,
    required this.db,
    required this.onRefresh,
  });

  @override
  State<ClientePuntosScreen> createState() => _ClientePuntosScreenState();
}

class _ClientePuntosScreenState extends State<ClientePuntosScreen> {
  late int _puntos;
  late List<HistorialPunto> _historial;

  @override
  void initState() {
    super.initState();
    _puntos = widget.cliente.puntos;
    _historial = widget.cliente.historialPuntos;
  }

  String _getNivel() {
    if (_puntos >= 500) return '🥇 Oro';
    if (_puntos >= 200) return '🥈 Plata';
    return '🥉 Bronce';
  }

  double _getPorcentaje() {
    if (_puntos >= 500) return 1.0;
    if (_puntos >= 200) return (_puntos - 200) / 300;
    return _puntos / 200;
  }

  int _getPuntosFaltantes() {
    if (_puntos >= 500) return 0;
    if (_puntos >= 200) return 500 - _puntos;
    return 200 - _puntos;
  }

  double _getDescuento() {
    if (_puntos >= 500) return 20;
    if (_puntos >= 200) return 10;
    return 5;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        widget.onRefresh();
        setState(() {
          _puntos = widget.cliente.puntos;
          _historial = widget.cliente.historialPuntos;
        });
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A1200), Color(0xFF2A1F00)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFC9A84C)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFC9A84C), width: 3),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$_puntos',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFC9A84C),
                          ),
                        ),
                        const Text('PUNTOS', style: TextStyle(color: Color(0xFF888888), fontSize: 10)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC9A84C).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_getNivel(), style: const TextStyle(color: Color(0xFFC9A84C))),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Próximo nivel: ${_getPuntosFaltantes()} pts más',
                    style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _getPorcentaje(),
                    backgroundColor: const Color(0xFF222222),
                    color: const Color(0xFFC9A84C),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'BENEFICIOS POR NIVEL',
                    style: TextStyle(color: Color(0xFF888888), fontSize: 12, letterSpacing: 1),
                  ),
                  const SizedBox(height: 12),
                  _buildBeneficioRow('🥉', 'Bronce — 0 a 199 pts', '5% descuento'),
                  const Divider(color: Color(0xFFC9A84C), height: 24),
                  _buildBeneficioRow('🥈', 'Plata — 200 a 499 pts', '10% descuento + 1 corte gratis/mes'),
                  const Divider(color: Color(0xFFC9A84C), height: 24),
                  _buildBeneficioRow('🥇', 'Oro — 500+ pts', '20% descuento + prioridad de cita'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TU DESCUENTO ACTUAL',
                    style: TextStyle(color: Color(0xFF888888), fontSize: 12, letterSpacing: 1),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Descuento en servicios', style: TextStyle(fontSize: 14)),
                      Text(
                        '${_getDescuento().toInt()}% OFF',
                        style: const TextStyle(
                          color: Color(0xFFC9A84C),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'HISTORIAL DE PUNTOS',
                    style: TextStyle(color: Color(0xFF888888), fontSize: 12, letterSpacing: 1),
                  ),
                  const SizedBox(height: 12),
                  if (_historial.isEmpty)
                    const Center(
                      child: Text('Sin historial aún', style: TextStyle(color: Color(0xFF888888))),
                    )
                  else
                    ..._historial.reversed.map((h) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFC9A84C).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(child: Text('⭐', style: TextStyle(fontSize: 20))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(h.concepto, style: const TextStyle(fontWeight: FontWeight.w500)),
                                Text(h.fecha, style: const TextStyle(color: Color(0xFF888888), fontSize: 11)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFC9A84C).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('+${h.puntos} pts', style: const TextStyle(color: Color(0xFFC9A84C), fontSize: 11)),
                          ),
                        ],
                      ),
                    )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBeneficioRow(String emoji, String title, String benefit) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              Text(benefit, style: const TextStyle(color: Color(0xFF888888), fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}

// Cliente Perfil Screen
class ClientePerfilScreen extends StatefulWidget {
  final Cliente cliente;
  final DatabaseService db;
  final VoidCallback onRefresh;

  const ClientePerfilScreen({
    super.key,
    required this.cliente,
    required this.db,
    required this.onRefresh,
  });

  @override
  State<ClientePerfilScreen> createState() => _ClientePerfilScreenState();
}

class _ClientePerfilScreenState extends State<ClientePerfilScreen> {
  late TextEditingController _nombreController;
  late TextEditingController _telefonoController;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.cliente.nombre);
    _telefonoController = TextEditingController(text: widget.cliente.telefono);
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  Future<void> _guardarPerfil() async {
    final data = await widget.db.getData();
    final clientes = data['clientes'] as List;
    final index = clientes.indexWhere((c) => c['id'] == widget.cliente.id);
    if (index != -1) {
      clientes[index]['nombre'] = _nombreController.text;
      clientes[index]['telefono'] = _telefonoController.text;
      await widget.db.saveData(data);
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado'), backgroundColor: Colors.green),
        );
      }
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_role');
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Color(0xFFC9A84C),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      widget.cliente.nombre.isNotEmpty ? widget.cliente.nombre[0].toUpperCase() : 'C',
                      style: const TextStyle(color: Colors.black, fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.cliente.nombre,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(widget.cliente.email, style: const TextStyle(color: Color(0xFF888888), fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.cliente.membresia != 'Ninguna'
                        ? const Color(0xFFC9A84C).withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: widget.cliente.membresia == 'Ninguna'
                        ? Border.all(color: const Color(0xFF888888).withOpacity(0.3))
                        : null,
                  ),
                  child: Text(
                    widget.cliente.membresia != 'Ninguna' ? '👑 ${widget.cliente.membresia}' : 'Sin membresía',
                    style: TextStyle(
                      color: widget.cliente.membresia != 'Ninguna' ? const Color(0xFFC9A84C) : const Color(0xFF888888),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'EDITAR PERFIL',
                  style: TextStyle(color: Color(0xFF888888), fontSize: 12, letterSpacing: 1),
                ),
                const SizedBox(height: 16),
                const Text('Nombre completo', style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
                const SizedBox(height: 4),
                TextField(
                  controller: _nombreController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF222222),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Teléfono', style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
                const SizedBox(height: 4),
                TextField(
                  controller: _telefonoController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF222222),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _guardarPerfil,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC9A84C),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Guardar cambios', fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _logout,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE05A5A)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Cerrar sesión', style: TextStyle(color: Color(0xFFE05A5A))),
            ),
          ),
        ],
      ),
    );
  }
}

// Admin Main Screen
class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _selectedIndex = 0;
  late DatabaseService _db;

  @override
  void initState() {
    super.initState();
    _initDb();
  }

  Future<void> _initDb() async {
    final prefs = await SharedPreferences.getInstance();
    _db = DatabaseService(prefs);
    await _db.initData();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('✂️ BarberPro Admin'),
        centerTitle: true,
      ),
      body: _db == null
          ? const Center(child: CircularProgressIndicator())
          : [
              AdminDashboardScreen(db: _db),
              AdminCitasScreen(db: _db),
              AdminClientesScreen(db: _db),
              AdminServiciosScreen(db: _db),
              AdminReportesScreen(db: _db),
            ][_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Panel'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Citas'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Clientes'),
          BottomNavigationBarItem(icon: Icon(Icons.cut), label: 'Servicios'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Reportes'),
        ],
      ),
    );
  }
}

// Admin Dashboard Screen
class AdminDashboardScreen extends StatefulWidget {
  final DatabaseService db;

  const AdminDashboardScreen({super.key, required this.db});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<Cita> _citasHoy = [];
  List<Cliente> _clientes = [];
  List<Servicio> _servicios = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await widget.db.getData();
    final hoy = DateTime.now().toIso8601String().split('T')[0];
    setState(() {
      _citasHoy = (data['citas'] as List)
          .map((c) => Cita.fromJson(c))
          .where((c) => c.fecha == hoy)
          .toList();
      _clientes = (data['clientes'] as List).map((c) => Cliente.fromJson(c)).toList();
      _servicios = (data['servicios'] as List).map((s) => Servicio.fromJson(s)).toList();
    });
  }

  Future<void> _completarCita(Cita cita) async {
    final data = await widget.db.getData();
    final citas = data['citas'] as List;
    final citaIndex = citas.indexWhere((c) => c['id'] == cita.id);
    if (citaIndex != -1) {
      citas[citaIndex]['estado'] = 'completada';
      
      final servicio = _servicios.firstWhere((s) => s.id == cita.servicioId);
      final clientes = data['clientes'] as List;
      final clienteIndex = clientes.indexWhere((c) => c['id'] == cita.clienteId);
      if (clienteIndex != -1) {
        clientes[clienteIndex]['puntos'] = (clientes[clienteIndex]['puntos'] as int) + (servicio.puntos);
        final historial = clientes[clienteIndex]['historialPuntos'] as List;
        historial.add({
          'fecha': DateTime.now().toIso8601String().split('T')[0],
          'concepto': servicio.nombre,
          'puntos': servicio.puntos,
        });
      }
      
      await widget.db.saveData(data);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Servicio completado · Puntos sumados'), backgroundColor: Colors.green),
        );
      }
    }
  }

  String _getEstadoColor(String estado) {
    switch (estado) {
      case 'pendiente': return '#5A9CE0';
      case 'confirmada': return '#C9A84C';
      case 'completada': return '#4CAF82';
      case 'cancelada': return '#E05A5A';
      default: return '#888888';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ingresosHoy = _citasHoy
        .where((c) => c.estado == 'completada')
        .fold<double>(0, (sum, c) => sum + c.precio);
    final vipCount = _clientes.where((c) => c.membresia == 'Premium' || c.membresia == 'VIP Anual').length;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                _buildStatCardAdmin('📅', _citasHoy.length.toString(), 'Citas hoy'),
                const SizedBox(width: 12),
                _buildStatCardAdmin('👥', _clientes.length.toString(), 'Clientes'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatCardAdmin('💰', 'S/${ingresosHoy.toInt()}', 'Ingresos hoy'),
                const SizedBox(width: 12),
                _buildStatCardAdmin('👑', vipCount.toString(), 'VIP activos'),
              ],
            ),
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'CITAS DE HOY',
                style: TextStyle(color: Color(0xFFC9A84C), fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            if (_citasHoy.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Sin citas para hoy', style: TextStyle(color: Color(0xFF888888))),
                ),
              )
            else
              ..._citasHoy.map((cita) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 50,
                      child: Text(
                        cita.hora,
                        style: const TextStyle(color: Color(0xFFC9A84C), fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cita.clienteNombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('${cita.servicioNombre} · S/${cita.precio.toInt()}', style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Color(int.parse(_getEstadoColor(cita.estado).substring(1), radix: 16))
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            cita.estado.toUpperCase(),
                            style: TextStyle(
                              color: Color(int.parse(_getEstadoColor(cita.estado).substring(1), radix: 16)),
                              fontSize: 10,
                            ),
                          ),
                        ),
                        if (cita.estado == 'pendiente' || cita.estado == 'confirmada')
                          const SizedBox(height: 4),
                        if (cita.estado == 'pendiente' || cita.estado == 'confirmada')
                          OutlinedButton(
                            onPressed: () => _completarCita(cita),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.green),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            ),
                            child: const Text('Completar', style: TextStyle(color: Colors.green, fontSize: 11)),
                          ),
                      ],
                    ),
                  ],
                ),
              )),
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'ACCIONES RÁPIDAS',
                style: TextStyle(color: Color(0xFFC9A84C), fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            _buildActionButton('📱 Escanear QR cliente', () => _showQRDialog()),
            const SizedBox(height: 8),
            _buildActionButton('📅 Crear cita manual', () => _showNuevaCitaDialog()),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCardAdmin(String icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFC9A84C))),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Color(0xFF888888), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String text, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFC9A84C)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(text, style: const TextStyle(color: Color(0xFFC9A84C))),
      ),
    );
  }

  void _showQRDialog() {
    showDialog(
      context: context,
      builder: (context) => const RegistrarQRDialog(),
    );
  }

  void _showNuevaCitaDialog() {
    showDialog(
      context: context,
      builder: (context) => NuevaCitaAdminDialog(db: widget.db, onSuccess: _loadData),
    );
  }
}

// Registrar QR Dialog
class RegistrarQRDialog extends StatefulWidget {
  const RegistrarQRDialog({super.key});

  @override
  State<RegistrarQRDialog> createState() => _RegistrarQRDialogState();
}

class _RegistrarQRDialogState extends State<RegistrarQRDialog> {
  late DatabaseService _db;
  String _clienteId = '';
  Cliente? _clienteEncontrado;
  List<Servicio> _servicios = [];
  Servicio? _servicioSeleccionado;

  @override
  void initState() {
    super.initState();
    _initDb();
  }

  Future<void> _initDb() async {
    final prefs = await SharedPreferences.getInstance();
    _db = DatabaseService(prefs);
    await _db.initData();
    final data = await _db.getData();
    setState(() {
      _servicios = (data['servicios'] as List)
          .map((s) => Servicio.fromJson(s))
          .where((s) => s.activo)
          .toList();
    });
  }

  void _buscarCliente() async {
    final data = await _db.getData();
    final clientes = (data['clientes'] as List).map((c) => Cliente.fromJson(c)).toList();
    setState(() {
      _clienteEncontrado = clientes.firstWhere(
        (c) => c.id.toUpperCase() == _clienteId.toUpperCase(),
        orElse: () => null,
      );
    });
  }

  Future<void> _registrarServicio() async {
    if (_clienteEncontrado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cliente no encontrado'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_servicioSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un servicio'), backgroundColor: Colors.red),
      );
      return;
    }

    final data = await _db.getData();
    final clientes = data['clientes'] as List;
    final clienteIndex = clientes.indexWhere((c) => c['id'] == _clienteEncontrado!.id);
    if (clienteIndex != -1) {
      clientes[clienteIndex]['puntos'] = (clientes[clienteIndex]['puntos'] as int) + _servicioSeleccionado!.puntos;
      final historial = clientes[clienteIndex]['historialPuntos'] as List;
      historial.add({
        'fecha': DateTime.now().toIso8601String().split('T')[0],
        'concepto': _servicioSeleccionado!.nombre,
        'puntos': _servicioSeleccionado!.puntos,
      });
      await _db.saveData(data);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ +${_servicioSeleccionado!.puntos} puntos a ${_clienteEncontrado!.nombre}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Registrar Servicio por QR',
              style: TextStyle(color: Color(0xFFC9A84C), fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'ID del cliente',
                labelStyle: const TextStyle(color: Color(0xFF888888)),
                filled: true,
                fillColor: const Color(0xFF222222),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
              onChanged: (value) {
                setState(() => _clienteId = value);
                _buscarCliente();
              },
            ),
            if (_clienteEncontrado != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF222222),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(_clienteEncontrado!.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('${_clienteEncontrado!.puntos} puntos · ${_clienteEncontrado!.membresia}',
                        style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<Servicio>(
              value: _servicioSeleccionado,
              dropdownColor: const Color(0xFF222222),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Servicio realizado',
                labelStyle: const TextStyle(color: Color(0xFF888888)),
                filled: true,
                fillColor: const Color(0xFF222222),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
              items: _servicios.map((s) {
                return DropdownMenuItem(
                  value: s,
                  child: Text('${s.nombre} · S/${s.precio} · +${s.puntos} pts'),
                );
              }).toList(),
              onChanged: (value) => setState(() => _servicioSeleccionado = value),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _registrarServicio,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC9A84C),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Registrar y sumar puntos', fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Nueva Cita Admin Dialog
class NuevaCitaAdminDialog extends StatefulWidget {
  final DatabaseService db;
  final VoidCallback onSuccess;

  const NuevaCitaAdminDialog({super.key, required this.db, required this.onSuccess});

  @override
  State<NuevaCitaAdminDialog> createState() => _NuevaCitaAdminDialogState();
}

class _NuevaCitaAdminDialogState extends State<NuevaCitaAdminDialog> {
  List<Cliente> _clientes = [];
  List<Servicio> _servicios = [];
  Cliente? _clienteSeleccionado;
  Servicio? _servicioSeleccionado;
  DateTime _fecha = DateTime.now();
  String _hora = '09:00';
  String _estado = 'pendiente';

  final List<String> _horas = [
    '09:00', '09:30', '10:00', '10:30', '11:00', '11:30',
    '12:00', '14:00', '14:30', '15:00', '15:30', '16:00', '16:30', '17:00', '17:30', '18:00'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await widget.db.getData();
    setState(() {
      _clientes = (data['clientes'] as List).map((c) => Cliente.fromJson(c)).toList();
      _servicios = (data['servicios'] as List)
          .map((s) => Servicio.fromJson(s))
          .where((s) => s.activo)
          .toList();
    });
  }

  Future<void> _crearCita() async {
    if (_clienteSeleccionado == null || _servicioSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona cliente y servicio'), backgroundColor: Colors.red),
      );
      return;
    }

    final data = await widget.db.getData();
    final nuevaCita = {
      'id': widget.db.generateId('CIT'),
      'clienteId': _clienteSeleccionado!.id,
      'clienteNombre': _clienteSeleccionado!.nombre,
      'servicioId': _servicioSeleccionado!.id,
      'servicioNombre': _servicioSeleccionado!.nombre,
      'fecha': _fecha.toIso8601String().split('T')[0],
      'hora': _hora,
      'estado': _estado,
      'precio': _servicioSeleccionado!.precio,
      'notas': '',
    };
    data['citas'].add(nuevaCita);
    await widget.db.saveData(data);

    if (mounted) {
      Navigator.pop(context);
      widget.onSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cita creada con éxito'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nueva Cita',
              style: TextStyle(color: Color(0xFFC9A84C), fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Cliente>(
              value: _clienteSeleccionado,
              dropdownColor: const Color(0xFF222222),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Cliente',
                labelStyle: const TextStyle(color: Color(0xFF888888)),
                filled: true,
                fillColor: const Color(0xFF222222),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
              items: _clientes.map((c) {
                return DropdownMenuItem(value: c, child: Text(c.nombre));
              }).toList(),
              onChanged: (value) => setState(() => _clienteSeleccionado = value),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Servicio>(
              value: _servicioSeleccionado,
              dropdownColor: const Color(0xFF222222),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Servicio',
                labelStyle: const TextStyle(color: Color(0xFF888888)),
                filled: true,
                fillColor: const Color(0xFF222222),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
              items: _servicios.map((s) {
                return DropdownMenuItem(value: s, child: Text('${s.nombre} · S/${s.precio}'));
              }).toList(),
              onChanged: (value) => setState(() => _servicioSeleccionado = value),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fecha', style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
              subtitle: Text(
                '${_fecha.day}/${_fecha.month}/${_fecha.year}',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _fecha,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 60)),
                  builder: (context, child) {
                    return Theme(
                      data: ThemeData.dark().copyWith(
                        colorScheme: const ColorScheme.dark(primary: Color(0xFFC9A84C)),
                      ),
                      child: child!,
                    );
                  },
                );
                if (date != null) setState(() => _fecha = date);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _hora,
              dropdownColor: const Color(0xFF222222),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Hora',
                labelStyle: const TextStyle(color: Color(0xFF888888)),
                filled: true,
                fillColor: const Color(0xFF222222),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
              items: _horas.map((h) {
                return DropdownMenuItem(value: h, child: Text(h));
              }).toList(),
              onChanged: (value) => setState(() => _hora = value!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _estado,
              dropdownColor: const Color(0xFF222222),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Estado',
                labelStyle: const TextStyle(color: Color(0xFF888888)),
                filled: true,
                fillColor: const Color(0xFF222222),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
              items: const [
                DropdownMenuItem(value: 'pendiente', child: Text('Pendiente')),
                DropdownMenuItem(value: 'confirmada', child: Text('Confirmada')),
              ],
              onChanged: (value) => setState(() => _estado = value!),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _crearCita,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC9A84C),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Crear cita', fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Admin Citas Screen
class AdminCitasScreen extends StatefulWidget {
  final DatabaseService db;

  const AdminCitasScreen({super.key, required this.db});

  @override
  State<AdminCitasScreen> createState() => _AdminCitasScreenState();
}

class _AdminCitasScreenState extends State<AdminCitasScreen> {
  List<Cita> _citas = [];
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _loadCitas();
  }

  Future<void> _loadCitas() async {
    final data = await widget.db.getData();
    setState(() {
      _citas = (data['citas'] as List).map((c) => Cita.fromJson(c)).toList();
      _citas.sort((a, b) => '$b.fecha $b.hora'.compareTo('$a.fecha $a.hora'));
    });
  }

  List<Cita> get _citasFiltradas {
    if (_filtro.isEmpty) return _citas;
    return _citas.where((c) => c.estado == _filtro).toList();
  }

  String _getEstadoColor(String estado) {
    switch (estado) {
      case 'pendiente': return '#5A9CE0';
      case 'confirmada': return '#C9A84C';
      case 'completada': return '#4CAF82';
      case 'cancelada': return '#E05A5A';
      default: return '#888888';
    }
  }

  Future<void> _cambiarEstado(Cita cita, String nuevoEstado) async {
    final data = await widget.db.getData();
    final citas = data['citas'] as List;
    final index = citas.indexWhere((c) => c['id'] == cita.id);
    if (index != -1) {
      citas[index]['estado'] = nuevoEstado;
      
      if (nuevoEstado == 'completada') {
        final servicios = (data['servicios'] as List).map((s) => Servicio.fromJson(s)).toList();
        final servicio = servicios.firstWhere((s) => s.id == cita.servicioId);
        final clientes = data['clientes'] as List;
        final clienteIndex = clientes.indexWhere((c) => c['id'] == cita.clienteId);
        if (clienteIndex != -1) {
          clientes[clienteIndex]['puntos'] = (clientes[clienteIndex]['puntos'] as int) + (servicio.puntos);
          final historial = clientes[clienteIndex]['historialPuntos'] as List;
          historial.add({
            'fecha': DateTime.now().toIso8601String().split('T')[0],
            'concepto': servicio.nombre,
            'puntos': servicio.puntos,
          });
        }
      }
      
      await widget.db.saveData(data);
      await _loadCitas();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Estado actualizado a ${nuevoEstado}'), backgroundColor: Colors.green),
        );
      }
    }
  }

  String _formatFecha(String fecha) {
    final parts = fecha.split('-');
    if (parts.length != 3) return fecha;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: DropdownButtonFormField<String>(
            value: _filtro.isEmpty ? null : _filtro,
            hint: const Text('Todas las citas'),
            dropdownColor: const Color(0xFF222222),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF222222),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
            items: const [
              DropdownMenuItem(value: '', child: Text('Todas')),
              DropdownMenuItem(value: 'pendiente', child: Text('Pendientes')),
              DropdownMenuItem(value: 'confirmada', child: Text('Confirmadas')),
              DropdownMenuItem(value: 'completada', child: Text('Completadas')),
              DropdownMenuItem(value: 'cancelada', child: Text('Canceladas')),
            ],
            onChanged: (value) => setState(() => _filtro = value ?? ''),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadCitas,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _citasFiltradas.length,
              itemBuilder: (context, index) {
                final cita = _citasFiltradas[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(cita.clienteNombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text(cita.servicioNombre, style: const TextStyle(color: Color(0xFF888888), fontSize: 13)),
                                Text(
                                  '${_formatFecha(cita.fecha)} · ${cita.hora}',
                                  style: const TextStyle(color: Color(0xFFC9A84C), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Color(int.parse(_getEstadoColor(cita.estado).substring(1), radix: 16))
                                  .withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              cita.estado.toUpperCase(),
                              style: TextStyle(
                                color: Color(int.parse(_getEstadoColor(cita.estado).substring(1), radix: 16)),
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('S/ ${cita.precio.toInt()}', style: const TextStyle(color: Color(0xFFC9A84C), fontWeight: FontWeight.bold)),
                          Row(
                            children: [
                              if (cita.estado == 'pendiente')
                                OutlinedButton(
                                  onPressed: () => _cambiarEstado(cita, 'confirmada'),
                                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFC9A84C)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                                  child: const Text('Confirmar', style: TextStyle(color: Color(0xFFC9A84C), fontSize: 11)),
                                ),
                              if (cita.estado == 'confirmada')
                                OutlinedButton(
                                  onPressed: () => _cambiarEstado(cita, 'completada'),
                                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.green), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                                  child: const Text('Completar', style: TextStyle(color: Colors.green, fontSize: 11)),
                                ),
                              if (cita.estado != 'cancelada' && cita.estado != 'completada')
                                const SizedBox(width: 8),
                              if (cita.estado != 'cancelada' && cita.estado != 'completada')
                                OutlinedButton(
                                  onPressed: () => _cambiarEstado(cita, 'cancelada'),
                                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFE05A5A)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                                  child: const Text('Cancelar', style: TextStyle(color: Color(0xFFE05A5A), fontSize: 11)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// Admin Clientes Screen
class AdminClientesScreen extends StatefulWidget {
  final DatabaseService db;

  const AdminClientesScreen({super.key, required this.db});

  @override
  State<AdminClientesScreen> createState() => _AdminClientesScreenState();
}

class _AdminClientesScreenState extends State<AdminClientesScreen> {
  List<Cliente> _clientes = [];
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _loadClientes();
  }

  Future<void> _loadClientes() async {
    final data = await widget.db.getData();
    setState(() {
      _clientes = (data['clientes'] as List).map((c) => Cliente.fromJson(c)).toList();
    });
  }

  List<Cliente> get _clientesFiltrados {
    if (_busqueda.isEmpty) return _clientes;
    return _clientes.where((c) =>
        c.nombre.toLowerCase().contains(_busqueda.toLowerCase()) ||
        c.email.toLowerCase().contains(_busqueda.toLowerCase())
    ).toList();
  }

  Future<void> _eliminarCliente(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Eliminar cliente'),
        content: const Text('¿Estás seguro? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    final data = await widget.db.getData();
    data['clientes'] = (data['clientes'] as List).where((c) => c['id'] != id).toList();
    await widget.db.saveData(data);
    await _loadClientes();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cliente eliminado'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '🔍 Buscar cliente...',
              hintStyle: const TextStyle(color: Color(0xFF888888)),
              filled: true,
              fillColor: const Color(0xFF222222),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF888888)),
            ),
            onChanged: (value) => setState(() => _busqueda = value),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadClientes,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _clientesFiltrados.length,
              itemBuilder: (context, index) {
                final cliente = _clientesFiltrados[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: const BoxDecoration(
                          color: Color(0xFFC9A84C),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            cliente.nombre.isNotEmpty ? cliente.nombre[0].toUpperCase() : 'C',
                            style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cliente.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('${cliente.telefono} · ${cliente.email}', style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: cliente.membresia != 'Ninguna'
                                        ? const Color(0xFFC9A84C).withOpacity(0.15)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                    border: cliente.membresia == 'Ninguna'
                                        ? Border.all(color: const Color(0xFF888888).withOpacity(0.3))
                                        : null,
                                  ),
                                  child: Text(
                                    cliente.membresia != 'Ninguna' ? '👑 ${cliente.membresia}' : 'Sin membresía',
                                    style: TextStyle(color: cliente.membresia != 'Ninguna' ? const Color(0xFFC9A84C) : const Color(0xFF888888), fontSize: 10),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF5A9CE0).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text('⭐ ${cliente.puntos} pts', style: const TextStyle(color: Color(0xFF5A9CE0), fontSize: 10)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Color(0xFFE05A5A)),
                        onPressed: () => _eliminarCliente(cliente.id),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// Admin Servicios Screen
class AdminServiciosScreen extends StatefulWidget {
  final DatabaseService db;

  const AdminServiciosScreen({super.key, required this.db});

  @override
  State<AdminServiciosScreen> createState() => _AdminServiciosScreenState();
}

class _AdminServiciosScreenState extends State<AdminServiciosScreen> {
  List<Servicio> _servicios = [];

  @override
  void initState() {
    super.initState();
    _loadServicios();
  }

  Future<void> _loadServicios() async {
    final data = await widget.db.getData();
    setState(() {
      _servicios = (data['servicios'] as List).map((s) => Servicio.fromJson(s)).toList();
    });
  }

  Future<void> _eliminarServicio(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Eliminar servicio'),
        content: const Text('¿Estás seguro?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    final data = await widget.db.getData();
    data['servicios'] = (data['servicios'] as List).where((s) => s['id'] != id).toList();
    await widget.db.saveData(data);
    await _loadServicios();
  }

  void _showNuevoServicioDialog() {
    showDialog(
      context: context,
      builder: (context) => NuevoServicioDialog(db: widget.db, onSuccess: _loadServicios),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _showNuevoServicioDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC9A84C),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('+ Nuevo Servicio', fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadServicios,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _servicios.length,
              itemBuilder: (context, index) {
                final servicio = _servicios[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Text(servicio.icono, style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(servicio.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(servicio.descripcion, style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFC9A84C).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text('S/${servicio.precio.toInt()}', style: const TextStyle(color: Color(0xFFC9A84C), fontSize: 11)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF888888).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text('⏱ ${servicio.duracion}min', style: const TextStyle(color: Color(0xFF888888), fontSize: 11)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF5A9CE0).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text('⭐ ${servicio.puntos}pts', style: const TextStyle(color: Color(0xFF5A9CE0), fontSize: 11)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Color(0xFFE05A5A)),
                        onPressed: () => _eliminarServicio(servicio.id),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// Nuevo Servicio Dialog
class NuevoServicioDialog extends StatefulWidget {
  final DatabaseService db;
  final VoidCallback onSuccess;

  const NuevoServicioDialog({super.key, required this.db, required this.onSuccess});

  @override
  State<NuevoServicioDialog> createState() => _NuevoServicioDialogState();
}

class _NuevoServicioDialogState extends State<NuevoServicioDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _precioController = TextEditingController();
  final _duracionController = TextEditingController();
  final _puntosController = TextEditingController();
  final _iconoController = TextEditingController(text: '✂️');

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _precioController.dispose();
    _duracionController.dispose();
    _puntosController.dispose();
    _iconoController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final nuevoServicio = {
      'id': widget.db.generateId('SVC'),
      'nombre': _nombreController.text,
      'descripcion': _descripcionController.text,
      'precio': double.parse(_precioController.text),
      'duracion': int.parse(_duracionController.text),
      'puntos': int.parse(_puntosController.text),
      'icono': _iconoController.text,
      'activo': true,
    };

    final data = await widget.db.getData();
    data['servicios'].add(nuevoServicio);
    await widget.db.saveData(data);

    if (mounted) {
      Navigator.pop(context);
      widget.onSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Servicio creado con éxito'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        width: 350,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nuevo Servicio',
                style: TextStyle(color: Color(0xFFC9A84C), fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildTextField(_nombreController, 'Nombre del servicio'),
              const SizedBox(height: 12),
              _buildTextField(_descripcionController, 'Descripción'),
              const SizedBox(height: 12),
              _buildTextField(_precioController, 'Precio (S/)', isNumber: true),
              const SizedBox(height: 12),
              _buildTextField(_duracionController, 'Duración (minutos)', isNumber: true),
              const SizedBox(height: 12),
              _buildTextField(_puntosController, 'Puntos que otorga', isNumber: true),
              const SizedBox(height: 12),
              _buildTextField(_iconoController, 'Ícono (emoji)'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC9A84C),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Guardar servicio', fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF888888)),
        filled: true,
        fillColor: const Color(0xFF222222),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
      validator: (value) => value == null || value.isEmpty ? 'Campo requerido' : null,
    );
  }
}

// Admin Reportes Screen
class AdminReportesScreen extends StatefulWidget {
  final DatabaseService db;

  const AdminReportesScreen({super.key, required this.db});

  @override
  State<AdminReportesScreen> createState() => _AdminReportesScreenState();
}

class _AdminReportesScreenState extends State<AdminReportesScreen> {
  List<Cita> _citas = [];
  List<Servicio> _servicios = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await widget.db.getData();
    setState(() {
      _citas = (data['citas'] as List).map((c) => Cita.fromJson(c)).toList();
      _servicios = (data['servicios'] as List).map((s) => Servicio.fromJson(s)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalCitas = _citas.length;
    final completadas = _citas.where((c) => c.estado == 'completada').length;
    final canceladas = _citas.where((c) => c.estado == 'cancelada').length;
    final ingresos = _citas
        .where((c) => c.estado == 'completada')
        .fold<double>(0, (sum, c) => sum + c.precio);

    final Map<String, int> servicioCount = {};
    for (final cita in _citas.where((c) => c.estado == 'completada')) {
      servicioCount[cita.servicioNombre] = (servicioCount[cita.servicioNombre] ?? 0) + 1;
    }
    final sorted = servicioCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxCount = sorted.isEmpty ? 1 : sorted.first.value;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                _buildReportCard('📊', totalCitas.toString(), 'Total citas'),
                const SizedBox(width: 12),
                _buildReportCard('💰', 'S/${ingresos.toInt()}', 'Ingresos totales'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildReportCard('✅', completadas.toString(), 'Completadas'),
                const SizedBox(width: 12),
                _buildReportCard('❌', canceladas.toString(), 'Canceladas'),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SERVICIOS MÁS POPULARES',
                    style: TextStyle(color: Color(0xFF888888), fontSize: 12, letterSpacing: 1),
                  ),
                  const SizedBox(height: 16),
                  if (sorted.isEmpty)
                    const Center(child: Text('Sin datos aún', style: TextStyle(color: Color(0xFF888888))))
                  else
                    ...sorted.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(entry.key, style: const TextStyle(fontSize: 13)),
                              Text(entry.value.toString(), style: const TextStyle(color: Color(0xFFC9A84C), fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: entry.value / maxCount,
                            backgroundColor: const Color(0xFF222222),
                            color: const Color(0xFFC9A84C),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ],
                      ),
                    )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(String icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFC9A84C))),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Color(0xFF888888), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
