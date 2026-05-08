import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PuntosProvider()),
      ],
      child: const BarberApp(),
    ),
  );
}

// ==================== PROVIDERS ====================

class AuthProvider extends ChangeNotifier {
  Usuario? _usuarioActual;
  
  Usuario? get usuarioActual => _usuarioActual;
  
  Future<void> login(String email, String password, BuildContext context) async {
    // Simulación de login
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'usuarios',
      where: 'email = ?',
      whereArgs: [email],
    );
    
    if (maps.isNotEmpty) {
      _usuarioActual = Usuario.fromMap(maps.first);
      notifyListeners();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario no encontrado')),
      );
    }
  }
  
  Future<void> registrarUsuario(Usuario usuario, BuildContext context) async {
    final db = await DatabaseHelper.instance.database;
    usuario.id = await db.insert('usuarios', usuario.toMap());
    _usuarioActual = usuario;
    notifyListeners();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registro exitoso')),
    );
  }
  
  void logout() {
    _usuarioActual = null;
    notifyListeners();
  }
  
  bool get isLoggedIn => _usuarioActual != null;
  bool get isAdmin => _usuarioActual?.rol == 'admin';
}

class PuntosProvider extends ChangeNotifier {
  int puntosActuales = 0;
  
  void agregarPuntos(int puntos) {
    puntosActuales += puntos;
    notifyListeners();
  }
  
  void canjearPuntos(int puntos) {
    if (puntosActuales >= puntos) {
      puntosActuales -= puntos;
      notifyListeners();
    }
  }
}

// ==================== MODELOS ====================

class Usuario {
  int? id;
  String nombre;
  String email;
  String telefono;
  String rol;
  String membresia;
  int puntos;
  DateTime fechaRegistro;

  Usuario({
    this.id,
    required this.nombre,
    required this.email,
    required this.telefono,
    required this.rol,
    required this.membresia,
    required this.puntos,
    required this.fechaRegistro,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'email': email,
      'telefono': telefono,
      'rol': rol,
      'membresia': membresia,
      'puntos': puntos,
      'fechaRegistro': fechaRegistro.toIso8601String(),
    };
  }

  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      id: map['id'],
      nombre: map['nombre'],
      email: map['email'],
      telefono: map['telefono'],
      rol: map['rol'],
      membresia: map['membresia'],
      puntos: map['puntos'],
      fechaRegistro: DateTime.parse(map['fechaRegistro']),
    );
  }
}

class Servicio {
  int? id;
  String nombre;
  int duracion;
  double precio;
  int puntos;

  Servicio({
    this.id,
    required this.nombre,
    required this.duracion,
    required this.precio,
    required this.puntos,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'duracion': duracion,
      'precio': precio,
      'puntos': puntos,
    };
  }

  factory Servicio.fromMap(Map<String, dynamic> map) {
    return Servicio(
      id: map['id'],
      nombre: map['nombre'],
      duracion: map['duracion'],
      precio: map['precio'],
      puntos: map['puntos'],
    );
  }
}

class Reserva {
  int? id;
  int clienteId;
  int servicioId;
  DateTime fecha;
  String hora;
  String estado;
  int? puntosGanados;

  Reserva({
    this.id,
    required this.clienteId,
    required this.servicioId,
    required this.fecha,
    required this.hora,
    required this.estado,
    this.puntosGanados,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clienteId': clienteId,
      'servicioId': servicioId,
      'fecha': fecha.toIso8601String(),
      'hora': hora,
      'estado': estado,
      'puntosGanados': puntosGanados,
    };
  }

  factory Reserva.fromMap(Map<String, dynamic> map) {
    return Reserva(
      id: map['id'],
      clienteId: map['clienteId'],
      servicioId: map['servicioId'],
      fecha: DateTime.parse(map['fecha']),
      hora: map['hora'],
      estado: map['estado'],
      puntosGanados: map['puntosGanados'],
    );
  }
}

// ==================== BASE DE DATOS ====================

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'barberia.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE usuarios(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        telefono TEXT NOT NULL,
        rol TEXT NOT NULL,
        membresia TEXT NOT NULL,
        puntos INTEGER DEFAULT 0,
        fechaRegistro TEXT NOT NULL
      )
    ''');
    
    await db.execute('''
      CREATE TABLE servicios(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        duracion INTEGER NOT NULL,
        precio REAL NOT NULL,
        puntos INTEGER NOT NULL
      )
    ''');
    
    await db.execute('''
      CREATE TABLE reservas(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clienteId INTEGER NOT NULL,
        servicioId INTEGER NOT NULL,
        fecha TEXT NOT NULL,
        hora TEXT NOT NULL,
        estado TEXT NOT NULL,
        puntosGanados INTEGER,
        FOREIGN KEY (clienteId) REFERENCES usuarios(id),
        FOREIGN KEY (servicioId) REFERENCES servicios(id)
      )
    ''');
    
    // Insertar datos de prueba
    await db.insert('usuarios', {
      'nombre': 'Admin Barbería',
      'email': 'admin@barberia.com',
      'telefono': '123456789',
      'rol': 'admin',
      'membresia': 'vip',
      'puntos': 0,
      'fechaRegistro': DateTime.now().toIso8601String(),
    });
    
    await db.insert('usuarios', {
      'nombre': 'Cliente Demo',
      'email': 'cliente@demo.com',
      'telefono': '987654321',
      'rol': 'cliente',
      'membresia': 'basic',
      'puntos': 150,
      'fechaRegistro': DateTime.now().toIso8601String(),
    });
    
    final servicios = [
      {'nombre': 'Corte de Cabello', 'duracion': 30, 'precio': 15.0, 'puntos': 10},
      {'nombre': 'Barba', 'duracion': 20, 'precio': 10.0, 'puntos': 5},
      {'nombre': 'Corte + Barba', 'duracion': 50, 'precio': 22.0, 'puntos': 15},
      {'nombre': 'Tinte', 'duracion': 90, 'precio': 45.0, 'puntos': 25},
      {'nombre': 'Peinado', 'duracion': 25, 'precio': 12.0, 'puntos': 8},
    ];
    
    for (var servicio in servicios) {
      await db.insert('servicios', servicio);
    }
  }
}

// ==================== WIDGETS REUTILIZABLES ====================

class BotonPrincipal extends StatelessWidget {
  final IconData icono;
  final String texto;
  final String subtitulo;
  final VoidCallback onTap;

  const BotonPrincipal({
    super.key,
    required this.icono,
    required this.texto,
    required this.subtitulo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, size: 40, color: Colors.deepPurple),
              const SizedBox(height: 12),
              Text(texto, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(subtitulo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== PANTALLA PRINCIPAL ====================

class BarberApp extends StatelessWidget {
  const BarberApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Barbería Moderna',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.isLoggedIn) {
            return auth.isAdmin ? const AdminDashboard() : const ClienteDashboard();
          }
          return const LoginScreen();
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ==================== PANTALLA DE LOGIN ====================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegistering = false;
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.deepPurple.shade900, Colors.deepPurple.shade300],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.content_cut, size: 80, color: Colors.deepPurple),
                      const SizedBox(height: 16),
                      Text(
                        _isRegistering ? 'Crear Cuenta' : 'Bienvenido',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isRegistering ? 'Regístrate para comenzar' : 'Inicia sesión en tu cuenta',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 32),
                      
                      if (_isRegistering) ...[
                        TextField(
                          controller: _nombreController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre completo',
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _telefonoController,
                          decoration: const InputDecoration(
                            labelText: 'Teléfono',
                            prefixIcon: Icon(Icons.phone),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      
                      TextField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 24),
                      
                      ElevatedButton(
                        onPressed: _handleAuth,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(_isRegistering ? 'Registrarse' : 'Iniciar Sesión'),
                      ),
                      const SizedBox(height: 16),
                      
                      TextButton(
                        onPressed: () => setState(() => _isRegistering = !_isRegistering),
                        child: Text(_isRegistering ? '¿Ya tienes cuenta? Inicia sesión' : '¿No tienes cuenta? Regístrate'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleAuth() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    if (_isRegistering) {
      final usuario = Usuario(
        nombre: _nombreController.text,
        email: _emailController.text,
        telefono: _telefonoController.text,
        rol: 'cliente',
        membresia: 'basic',
        puntos: 0,
        fechaRegistro: DateTime.now(),
      );
      await auth.registrarUsuario(usuario, context);
    } else {
      await auth.login(_emailController.text, _passwordController.text, context);
    }
  }
}

// ==================== DASHBOARD CLIENTE ====================

class ClienteDashboard extends StatelessWidget {
  const ClienteDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Barbería'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
            },
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final usuario = auth.usuarioActual!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.deepPurple.shade100,
                              child: Text(
                                usuario.nombre[0].toUpperCase(),
                                style: const TextStyle(fontSize: 30, color: Colors.deepPurple),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('¡Hola ${usuario.nombre}!', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                  Text(usuario.email, style: const TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [Colors.deepPurple, Colors.deepPurple.shade300]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Mis Puntos', style: TextStyle(color: Colors.white70)),
                                  Text('Total acumulado', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                ],
                              ),
                              Text('${usuario.puntos}', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Servicios Rápidos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                FutureBuilder<List<Servicio>>(
                  future: _getServicios(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    return Column(
                      children: snapshot.data!.map((servicio) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.content_cut, color: Colors.deepPurple),
                          title: Text(servicio.nombre),
                          subtitle: Text('${servicio.duracion} min • ${servicio.puntos} puntos'),
                          trailing: Text('\$${servicio.precio.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          onTap: () => _reservarServicio(context, servicio),
                        ),
                      )).toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<List<Servicio>> _getServicios() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query('servicios');
    return maps.map((map) => Servicio.fromMap(map)).toList();
  }

  void _reservarServicio(BuildContext context, Servicio servicio) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ReservaDialog(servicio: servicio),
      ),
    );
  }
}

// ==================== DIÁLOGO DE RESERVA ====================

class ReservaDialog extends StatefulWidget {
  final Servicio servicio;
  const ReservaDialog({super.key, required this.servicio});

  @override
  State<ReservaDialog> createState() => _ReservaDialogState();
}

class _ReservaDialogState extends State<ReservaDialog> {
  DateTime? _fechaSeleccionada;
  String? _horaSeleccionada;
  
  final List<String> horarios = ['09:00', '10:00', '11:00', '12:00', '14:00', '15:00', '16:00', '17:00'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.servicio.nombre, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Text('Selecciona fecha y hora', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: CalendarDatePicker(
              initialDate: DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 30)),
              onDateChanged: (date) => setState(() => _fechaSeleccionada = date),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: horarios.map((hora) => FilterChip(
              label: Text(hora),
              selected: _horaSeleccionada == hora,
              onSelected: (selected) => setState(() => _horaSeleccionada = selected ? hora : null),
            )).toList(),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _fechaSeleccionada != null && _horaSeleccionada != null ? () => _confirmarReserva(context) : null,
            child: const Text('Confirmar Reserva'),
          ),
        ],
      ),
    );
  }

  void _confirmarReserva(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final db = await DatabaseHelper.instance.database;
    
    final reserva = Reserva(
      clienteId: auth.usuarioActual!.id!,
      servicioId: widget.servicio.id!,
      fecha: _fechaSeleccionada!,
      hora: _horaSeleccionada!,
      estado: 'pendiente',
      puntosGanados: widget.servicio.puntos,
    );
    
    await db.insert('reservas', reserva.toMap());
    
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Reserva confirmada para ${DateFormat('dd/MM/yyyy').format(_fechaSeleccionada!)} a las $_horaSeleccionada')),
      );
    }
  }
}

// ==================== DASHBOARD ADMIN ====================

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  
  final List<Widget> _pages = const [
    AdminInicio(),
    AdminServicios(),
    AdminReservas(),
    AdminClientes(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Admin'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Provider.of<AuthProvider>(context, listen: false).logout(),
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.content_cut), label: 'Servicios'),
          NavigationDestination(icon: Icon(Icons.calendar_today), label: 'Reservas'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Clientes'),
        ],
      ),
    );
  }
}

class AdminInicio extends StatelessWidget {
  const AdminInicio({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: _getEstadisticas(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final stats = snapshot.data!;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              _buildStatCard('Citas Hoy', stats['citasHoy'] ?? 0, Icons.calendar_today, Colors.blue),
              _buildStatCard('Clientes', stats['totalClientes'] ?? 0, Icons.people, Colors.green),
              _buildStatCard('Servicios', stats['totalServicios'] ?? 0, Icons.content_cut, Colors.orange),
              _buildStatCard('Puntos', stats['totalPuntos'] ?? 0, Icons.stars, Colors.purple),
            ],
          ),
        );
      },
    );
  }
  
  Future<Map<String, int>> _getEstadisticas() async {
    final db = await DatabaseHelper.instance.database;
    final clientes = await db.query('usuarios', where: 'rol = ?', whereArgs: ['cliente']);
    final servicios = await db.query('servicios');
    final citasHoy = await db.query('reservas', where: 'fecha LIKE ?', whereArgs: ['${DateTime.now().toIso8601String().substring(0, 10)}%']);
    final totalPuntos = await db.rawQuery('SELECT SUM(puntos) as total FROM usuarios');
    
    return {
      'citasHoy': citasHoy.length,
      'totalClientes': clientes.length,
      'totalServicios': servicios.length,
      'totalPuntos': totalPuntos.first['total'] as int? ?? 0,
    };
  }
  
  Widget _buildStatCard(String title, int value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(value.toString(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class AdminServicios extends StatefulWidget {
  const AdminServicios({super.key});

  @override
  State<AdminServicios> createState() => _AdminServiciosState();
}

class _AdminServiciosState extends State<AdminServicios> {
  List<Servicio> servicios = [];
  
  @override
  void initState() {
    super.initState();
    _cargarServicios();
  }
  
  Future<void> _cargarServicios() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('servicios');
    setState(() {
      servicios = maps.map((m) => Servicio.fromMap(m)).toList();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: servicios.length,
      itemBuilder: (context, index) {
        final servicio = servicios[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.content_cut, color: Colors.deepPurple),
            title: Text(servicio.nombre),
            subtitle: Text('${servicio.duracion} min • ${servicio.puntos} puntos'),
            trailing: Text('\$${servicio.precio.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }
}

class AdminReservas extends StatelessWidget {
  const AdminReservas({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getReservasConDetalles(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final reservas = snapshot.data!;
        if (reservas.isEmpty) return const Center(child: Text('No hay reservas'));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reservas.length,
          itemBuilder: (context, index) {
            final r = reservas[index];
            return Card(
              child: ListTile(
                leading: CircleAvatar(child: Text(r['cliente_nombre'][0])),
                title: Text(r['servicio_nombre']),
                subtitle: Text('${DateFormat('dd/MM/yyyy').format(DateTime.parse(r['fecha']))} a las ${r['hora']}'),
                trailing: Chip(
                  label: Text(r['estado']),
                  backgroundColor: r['estado'] == 'pendiente' ? Colors.orange : Colors.green,
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  Future<List<Map<String, dynamic>>> _getReservasConDetalles() async {
    final db = await DatabaseHelper.instance.database;
    return await db.rawQuery('''
      SELECT r.*, u.nombre as cliente_nombre, s.nombre as servicio_nombre 
      FROM reservas r
      JOIN usuarios u ON r.clienteId = u.id
      JOIN servicios s ON r.servicioId = s.id
      ORDER BY r.fecha DESC
    ''');
  }
}

class AdminClientes extends StatelessWidget {
  const AdminClientes({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Usuario>>(
      future: _getClientes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final clientes = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: clientes.length,
          itemBuilder: (context, index) {
            final cliente = clientes[index];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.deepPurple.shade100,
                  child: Text(cliente.nombre[0].toUpperCase()),
                ),
                title: Text(cliente.nombre),
                subtitle: Text('${cliente.email} • ${cliente.puntos} puntos'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getMembresiaColor(cliente.membresia),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(cliente.membresia.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10)),
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  Future<List<Usuario>> _getClientes() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('usuarios', where: 'rol = ?', whereArgs: ['cliente']);
    return maps.map((m) => Usuario.fromMap(m)).toList();
  }
  
  Color _getMembresiaColor(String membresia) {
    switch (membresia) {
      case 'premium': return Colors.gold;
      case 'vip': return Colors.deepPurple;
      default: return Colors.brown;
    }
  }
}
