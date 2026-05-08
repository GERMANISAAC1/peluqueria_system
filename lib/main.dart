import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  runApp(const BarberApp());
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
  String categoria;

  Servicio({
    this.id,
    required this.nombre,
    required this.duracion,
    required this.precio,
    required this.puntos,
    required this.categoria,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'duracion': duracion,
      'precio': precio,
      'puntos': puntos,
      'categoria': categoria,
    };
  }

  factory Servicio.fromMap(Map<String, dynamic> map) {
    return Servicio(
      id: map['id'],
      nombre: map['nombre'],
      duracion: map['duracion'],
      precio: map['precio'],
      puntos: map['puntos'],
      categoria: map['categoria'],
    );
  }
}

class Reserva {
  int? id;
  int usuarioId;
  int servicioId;
  DateTime fecha;
  String hora;
  String estado;
  int puntosGanados;
  DateTime createdAt;

  Reserva({
    this.id,
    required this.usuarioId,
    required this.servicioId,
    required this.fecha,
    required this.hora,
    required this.estado,
    required this.puntosGanados,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'usuarioId': usuarioId,
      'servicioId': servicioId,
      'fecha': fecha.toIso8601String(),
      'hora': hora,
      'estado': estado,
      'puntosGanados': puntosGanados,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Reserva.fromMap(Map<String, dynamic> map) {
    return Reserva(
      id: map['id'],
      usuarioId: map['usuarioId'],
      servicioId: map['servicioId'],
      fecha: DateTime.parse(map['fecha']),
      hora: map['hora'],
      estado: map['estado'],
      puntosGanados: map['puntosGanados'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}

class HistorialPuntos {
  int? id;
  int usuarioId;
  int puntos;
  String concepto;
  DateTime fecha;

  HistorialPuntos({
    this.id,
    required this.usuarioId,
    required this.puntos,
    required this.concepto,
    required this.fecha,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'usuarioId': usuarioId,
      'puntos': puntos,
      'concepto': concepto,
      'fecha': fecha.toIso8601String(),
    };
  }

  factory HistorialPuntos.fromMap(Map<String, dynamic> map) {
    return HistorialPuntos(
      id: map['id'],
      usuarioId: map['usuarioId'],
      puntos: map['puntos'],
      concepto: map['concepto'],
      fecha: DateTime.parse(map['fecha']),
    );
  }
}

class Promocion {
  int? id;
  String titulo;
  String descripcion;
  int puntosMultiplicador;
  double descuento;
  DateTime fechaInicio;
  DateTime fechaFin;

  Promocion({
    this.id,
    required this.titulo,
    required this.descripcion,
    required this.puntosMultiplicador,
    required this.descuento,
    required this.fechaInicio,
    required this.fechaFin,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titulo': titulo,
      'descripcion': descripcion,
      'puntosMultiplicador': puntosMultiplicador,
      'descuento': descuento,
      'fechaInicio': fechaInicio.toIso8601String(),
      'fechaFin': fechaFin.toIso8601String(),
    };
  }

  factory Promocion.fromMap(Map<String, dynamic> map) {
    return Promocion(
      id: map['id'],
      titulo: map['titulo'],
      descripcion: map['descripcion'],
      puntosMultiplicador: map['puntosMultiplicador'],
      descuento: map['descuento'],
      fechaInicio: DateTime.parse(map['fechaInicio']),
      fechaFin: DateTime.parse(map['fechaFin']),
    );
  }
}

// ==================== BASE DE DATOS ====================

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('barberia.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Tabla usuarios
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

    // Tabla servicios
    await db.execute('''
      CREATE TABLE servicios(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        duracion INTEGER NOT NULL,
        precio REAL NOT NULL,
        puntos INTEGER NOT NULL,
        categoria TEXT NOT NULL
      )
    ''');

    // Tabla reservas
    await db.execute('''
      CREATE TABLE reservas(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usuarioId INTEGER NOT NULL,
        servicioId INTEGER NOT NULL,
        fecha TEXT NOT NULL,
        hora TEXT NOT NULL,
        estado TEXT NOT NULL,
        puntosGanados INTEGER DEFAULT 0,
        createdAt TEXT NOT NULL,
        FOREIGN KEY(usuarioId) REFERENCES usuarios(id),
        FOREIGN KEY(servicioId) REFERENCES servicios(id)
      )
    ''');

    // Tabla historial puntos
    await db.execute('''
      CREATE TABLE historial_puntos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usuarioId INTEGER NOT NULL,
        puntos INTEGER NOT NULL,
        concepto TEXT NOT NULL,
        fecha TEXT NOT NULL,
        FOREIGN KEY(usuarioId) REFERENCES usuarios(id)
      )
    ''');

    // Tabla promociones
    await db.execute('''
      CREATE TABLE promociones(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        titulo TEXT NOT NULL,
        descripcion TEXT NOT NULL,
        puntosMultiplicador INTEGER DEFAULT 1,
        descuento REAL DEFAULT 0,
        fechaInicio TEXT NOT NULL,
        fechaFin TEXT NOT NULL
      )
    ''');

    // Insertar datos de ejemplo
    await _insertSampleData(db);
  }

  Future<void> _insertSampleData(Database db) async {
    // Usuarios de ejemplo
    await db.insert('usuarios', {
      'nombre': 'Carlos López',
      'email': 'cliente@barberia.com',
      'telefono': '+51 987654321',
      'rol': 'cliente',
      'membresia': 'premium',
      'puntos': 250,
      'fechaRegistro': DateTime.now().toIso8601String(),
    });

    await db.insert('usuarios', {
      'nombre': 'Admin Barber',
      'email': 'admin@barberia.com',
      'telefono': '+51 123456789',
      'rol': 'admin',
      'membresia': 'vip',
      'puntos': 0,
      'fechaRegistro': DateTime.now().toIso8601String(),
    });

    // Servicios de ejemplo
    final servicios = [
      {'nombre': 'Corte Cabello', 'duracion': 30, 'precio': 25.0, 'puntos': 10, 'categoria': 'cabello'},
      {'nombre': 'Barba', 'duracion': 20, 'precio': 15.0, 'puntos': 5, 'categoria': 'barba'},
      {'nombre': 'Corte + Barba', 'duracion': 50, 'precio': 35.0, 'puntos': 15, 'categoria': 'combo'},
      {'nombre': 'Tinte', 'duracion': 90, 'precio': 60.0, 'puntos': 25, 'categoria': 'cabello'},
      {'nombre': 'Peinado', 'duracion': 25, 'precio': 20.0, 'puntos': 8, 'categoria': 'cabello'},
      {'nombre': 'Afeitado Clásico', 'duracion': 30, 'precio': 18.0, 'puntos': 7, 'categoria': 'barba'},
    ];

    for (var servicio in servicios) {
      await db.insert('servicios', servicio);
    }

    // Promociones de ejemplo
    await db.insert('promociones', {
      'titulo': 'Doble Puntos',
      'descripcion': 'Gana el doble de puntos en todos los servicios',
      'puntosMultiplicador': 2,
      'descuento': 0,
      'fechaInicio': DateTime.now().toIso8601String(),
      'fechaFin': DateTime.now().add(Duration(days: 30)).toIso8601String(),
    });
  }

  // CRUD Usuarios
  Future<Usuario> crearUsuario(Usuario usuario) async {
    final db = await database;
    final id = await db.insert('usuarios', usuario.toMap());
    return usuario.copyWith(id: id);
  }

  Future<Usuario?> obtenerUsuarioPorEmail(String email) async {
    final db = await database;
    final result = await db.query(
      'usuarios',
      where: 'email = ?',
      whereArgs: [email],
    );
    if (result.isNotEmpty) {
      return Usuario.fromMap(result.first);
    }
    return null;
  }

  Future<Usuario?> obtenerUsuarioPorId(int id) async {
    final db = await database;
    final result = await db.query(
      'usuarios',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      return Usuario.fromMap(result.first);
    }
    return null;
  }

  Future<int> actualizarUsuario(Usuario usuario) async {
    final db = await database;
    return await db.update(
      'usuarios',
      usuario.toMap(),
      where: 'id = ?',
      whereArgs: [usuario.id],
    );
  }

  // CRUD Servicios
  Future<List<Servicio>> obtenerServicios() async {
    final db = await database;
    final result = await db.query('servicios');
    return result.map((map) => Servicio.fromMap(map)).toList();
  }

  Future<Servicio?> obtenerServicioPorId(int id) async {
    final db = await database;
    final result = await db.query(
      'servicios',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      return Servicio.fromMap(result.first);
    }
    return null;
  }

  Future<int> crearServicio(Servicio servicio) async {
    final db = await database;
    return await db.insert('servicios', servicio.toMap());
  }

  Future<int> actualizarServicio(Servicio servicio) async {
    final db = await database;
    return await db.update(
      'servicios',
      servicio.toMap(),
      where: 'id = ?',
      whereArgs: [servicio.id],
    );
  }

  Future<int> eliminarServicio(int id) async {
    final db = await database;
    return await db.delete(
      'servicios',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // CRUD Reservas
  Future<int> crearReserva(Reserva reserva) async {
    final db = await database;
    return await db.insert('reservas', reserva.toMap());
  }

  Future<List<Reserva>> obtenerReservasPorUsuario(int usuarioId) async {
    final db = await database;
    final result = await db.query(
      'reservas',
      where: 'usuarioId = ?',
      whereArgs: [usuarioId],
      orderBy: 'fecha DESC',
    );
    return result.map((map) => Reserva.fromMap(map)).toList();
  }

  Future<List<Reserva>> obtenerReservasPorFecha(DateTime fecha) async {
    final db = await database;
    final fechaStr = fecha.toIso8601String().split('T')[0];
    final result = await db.query(
      'reservas',
      where: "fecha LIKE ?",
      whereArgs: ['$fechaStr%'],
      orderBy: 'hora ASC',
    );
    return result.map((map) => Reserva.fromMap(map)).toList();
  }

  Future<int> actualizarEstadoReserva(int id, String estado) async {
    final db = await database;
    return await db.update(
      'reservas',
      {'estado': estado},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Sistema de puntos
  Future<void> agregarPuntos(int usuarioId, int puntos, String concepto) async {
    final db = await database;
    
    // Actualizar puntos del usuario
    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE usuarios SET puntos = puntos + ? WHERE id = ?',
        [puntos, usuarioId],
      );
      
      // Registrar en historial
      await txn.insert('historial_puntos', {
        'usuarioId': usuarioId,
        'puntos': puntos,
        'concepto': concepto,
        'fecha': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<List<HistorialPuntos>> obtenerHistorialPuntos(int usuarioId) async {
    final db = await database;
    final result = await db.query(
      'historial_puntos',
      where: 'usuarioId = ?',
      whereArgs: [usuarioId],
      orderBy: 'fecha DESC',
    );
    return result.map((map) => HistorialPuntos.fromMap(map)).toList();
  }

  // Promociones
  Future<List<Promocion>> obtenerPromocionesActivas() async {
    final db = await database;
    final ahora = DateTime.now().toIso8601String();
    final result = await db.query(
      'promociones',
      where: 'fechaInicio <= ? AND fechaFin >= ?',
      whereArgs: [ahora, ahora],
    );
    return result.map((map) => Promocion.fromMap(map)).toList();
  }

  // Estadísticas para admin
  Future<Map<String, dynamic>> obtenerEstadisticas() async {
    final db = await database;
    
    final totalClientes = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM usuarios WHERE rol = "cliente"')
    ) ?? 0;
    
    final citasHoy = await obtenerReservasPorFecha(DateTime.now());
    
    final totalIngresos = Sqflite.firstIntValue(
      await db.rawQuery('''
        SELECT SUM(s.precio) 
        FROM reservas r 
        JOIN servicios s ON r.servicioId = s.id 
        WHERE r.estado = "completado"
      ''')
    ) ?? 0;
    
    return {
      'totalClientes': totalClientes,
      'citasHoy': citasHoy.length,
      'totalIngresos': totalIngresos,
      'puntosEntregados': 0, // Calcular de historial
    };
  }
}

// ==================== PROVIDER ====================

class AuthProvider extends ChangeNotifier {
  Usuario? _usuarioActual;
  
  Usuario? get usuarioActual => _usuarioActual;
  
  Future<bool> login(String email, String rolEsperado) async {
    final usuario = await DatabaseHelper.instance.obtenerUsuarioPorEmail(email);
    
    if (usuario != null && usuario.rol == rolEsperado) {
      _usuarioActual = usuario;
      notifyListeners();
      return true;
    }
    return false;
  }
  
  void logout() {
    _usuarioActual = null;
    notifyListeners();
  }
}

// ==================== WIDGETS COMUNES ====================

class MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color color;

  const MenuCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.color = Colors.blueGrey,
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== PANTALLA DE LOGIN ====================

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blueGrey.shade900, Colors.blueGrey.shade700],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.content_cut,
                    size: 80,
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'BarberPro',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sistema profesional de barbería',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
                const SizedBox(height: 48),
                _buildLoginButton(
                  context,
                  icon: Icons.person,
                  label: 'Entrar como Cliente',
                  color: Colors.green,
                  email: 'cliente@barberia.com',
                  rol: 'cliente',
                ),
                const SizedBox(height: 16),
                _buildLoginButton(
                  context,
                  icon: Icons.admin_panel_settings,
                  label: 'Entrar como Administrador',
                  color: Colors.blue,
                  email: 'admin@barberia.com',
                  rol: 'admin',
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    '¿Olvidaste tu contraseña?',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required String email,
    required String rol,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final success = await authProvider.login(email, rol);
          
          if (success && context.mounted) {
            if (rol == 'cliente') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ClienteHome()),
              );
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const AdminHome()),
              );
            }
          } else if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Credenciales incorrectas')),
            );
          }
        },
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 16)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 55),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

// ==================== PANTALLA CLIENTE ====================

class ClienteHome extends StatefulWidget {
  const ClienteHome({super.key});

  @override
  State<ClienteHome> createState() => _ClienteHomeState();
}

class _ClienteHomeState extends State<ClienteHome> {
  Usuario? usuario;
  Reserva? proximaCita;
  Servicio? servicioProximaCita;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.usuarioActual != null) {
      usuario = authProvider.usuarioActual;
      
      // Cargar próxima cita
      final reservas = await DatabaseHelper.instance.obtenerReservasPorUsuario(usuario!.id!);
      final proximas = reservas.where((r) => r.estado == 'pendiente' && r.fecha.isAfter(DateTime.now())).toList();
      if (proximas.isNotEmpty) {
        proximaCita = proximas.first;
        servicioProximaCita = await DatabaseHelper.instance.obtenerServicioPorId(proximaCita!.servicioId);
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (usuario == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Barbería'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargarDatos,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tarjeta de bienvenida y puntos
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blueGrey.shade700, Colors.blueGrey.shade900],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.white,
                            child: Text(
                              usuario!.nombre[0],
                              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '¡Hola ${usuario!.nombre.split(' ')[0]}!',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Membresía ${usuario!.membresia.toUpperCase()}',
                                    style: const TextStyle(fontSize: 12, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            children: [
                              const Text('Puntos', style: TextStyle(color: Colors.white70)),
                              const SizedBox(height: 4),
                              Text(
                                '${usuario!.puntos}',
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
                          ),
                          Container(width: 1, height: 40, color: Colors.white24),
                          Column(
                            children: [
                              const Text('Próximo nivel', style: TextStyle(color: Colors.white70)),
                              const SizedBox(height: 4),
                              Text(
                                '${(_getNextLevel(usuario!.puntos))} pts',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: (usuario!.puntos % 500) / 500,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation(Colors.amber),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Próxima cita
              if (proximaCita != null && servicioProximaCita != null)
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(left: BorderSide(color: Colors.green, width: 4)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.event_available, color: Colors.green, size: 30),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Próxima Cita', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text(servicioProximaCita!.nombre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              Text(
                                '${DateFormat('dd/MM/yyyy').format(proximaCita!.fecha)} - ${proximaCita!.hora}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const MisReservasScreen()),
                            ).then((_) => _cargarDatos());
                          },
                          child: const Text('Ver'),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // Menú principal
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.9,
                children: [
                  MenuCard(
                    icon: Icons.calendar_today,
                    title: 'Reservar',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ReservarScreen()),
                      ).then((_) => _cargarDatos());
                    },
                  ),
                  MenuCard(
                    icon: Icons.qr_code_scanner,
                    title: 'Escanear QR',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EscanerQRScreen()),
                      ).then((_) => _cargarDatos());
                    },
                  ),
                  MenuCard(
                    icon: Icons.stars,
                    title: 'Mis Puntos',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MisPuntosScreen()),
                      );
                    },
                  ),
                  MenuCard(
                    icon: Icons.card_membership,
                    title: 'Membresía',
                    color: Colors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => MembresiaScreen(usuario: usuario!)),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _getNextLevel(int puntos) {
    if (puntos < 500) return 500;
    if (puntos < 1500) return 1500;
    return 3000;
  }
}

// ==================== RESERVAR CITA ====================

class ReservarScreen extends StatefulWidget {
  const ReservarScreen({super.key});

  @override
  State<ReservarScreen> createState() => _ReservarScreenState();
}

class _ReservarScreenState extends State<ReservarScreen> {
  List<Servicio> servicios = [];
  Servicio? selectedService;
  DateTime? selectedDate;
  String? selectedTime;
  int currentStep = 0;

  final List<String> horarios = [
    '09:00', '10:00', '11:00', '12:00', '13:00',
    '15:00', '16:00', '17:00', '18:00', '19:00'
  ];

  @override
  void initState() {
    super.initState();
    _cargarServicios();
  }

  Future<void> _cargarServicios() async {
    final lista = await DatabaseHelper.instance.obtenerServicios();
    setState(() {
      servicios = lista;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservar Cita'),
        centerTitle: true,
      ),
      body: servicios.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Stepper(
              type: StepperType.horizontal,
              currentStep: currentStep,
              onStepContinue: () {
                if (currentStep < 2) {
                  setState(() => currentStep++);
                } else {
                  _confirmarReserva();
                }
              },
              onStepCancel: () {
                if (currentStep > 0) setState(() => currentStep--);
              },
              steps: [
                Step(
                  title: const Text('Servicio'),
                  content: _buildServiceStep(),
                  isActive: currentStep >= 0,
                  state: selectedService != null ? StepState.complete : StepState.indexed,
                ),
                Step(
                  title: const Text('Fecha'),
                  content: _buildDateTimeStep(),
                  isActive: currentStep >= 1,
                  state: selectedDate != null && selectedTime != null ? StepState.complete : StepState.indexed,
                ),
                Step(
                  title: const Text('Confirmar'),
                  content: _buildConfirmStep(),
                  isActive: currentStep >= 2,
                ),
              ],
            ),
    );
  }

  Widget _buildServiceStep() {
    return Column(
      children: servicios.map((service) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            leading: const Icon(Icons.content_cut, size: 30),
            title: Text(service.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${service.duracion} min • ${service.puntos} puntos'),
            trailing: Text(
              'S/ ${service.precio.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
            selected: selectedService == service,
            selectedTileColor: Colors.blueGrey.withOpacity(0.1),
            onTap: () => setState(() => selectedService = service),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateTimeStep() {
    return Column(
      children: [
        CalendarDatePicker(
          initialDate: DateTime.now().add(const Duration(days: 1)),
          firstDate: DateTime.now().add(const Duration(days: 1)),
          lastDate: DateTime.now().add(const Duration(days: 30)),
          onDateSelected: (date) => setState(() => selectedDate = date),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: horarios.map((time) {
            return FilterChip(
              label: Text(time),
              selected: selectedTime == time,
              onSelected: (selected) {
                setState(() => selectedTime = selected ? time : null);
              },
              selectedColor: Colors.blueGrey,
              checkmarkColor: Colors.white,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildConfirmStep() {
    if (selectedService == null) return const SizedBox();
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConfirmRow(Icons.content_cut, 'Servicio', selectedService!.nombre),
            const Divider(),
            _buildConfirmRow(Icons.calendar_today, 'Fecha', DateFormat('dd/MM/yyyy').format(selectedDate!)),
            const Divider(),
            _buildConfirmRow(Icons.access_time, 'Hora', selectedTime!),
            const Divider(),
            _buildConfirmRow(Icons.attach_money, 'Total', 'S/ ${selectedService!.precio.toStringAsFixed(2)}'),
            const Divider(),
            _buildConfirmRow(Icons.stars, 'Puntos a ganar', '${selectedService!.puntos} puntos'),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Colors.blueGrey),
          const SizedBox(width: 16),
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Future<void> _confirmarReserva() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final usuario = authProvider.usuarioActual;
    
    if (usuario == null || selectedService == null || selectedDate == null || selectedTime == null) return;
    
    final reserva = Reserva(
      usuarioId: usuario.id!,
      servicioId: selectedService!.id!,
      fecha: selectedDate!,
      hora: selectedTime!,
      estado: 'pendiente',
      puntosGanados: selectedService!.puntos,
      createdAt: DateTime.now(),
    );
    
    await DatabaseHelper.instance.crearReserva(reserva);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ ¡Cita reservada exitosamente!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    }
  }
}

// ==================== ESCANER QR ====================

class EscanerQRScreen extends StatefulWidget {
  const EscanerQRScreen({super.key});

  @override
  State<EscanerQRScreen> createState() => _EscanerQRScreenState();
}

class _EscanerQRScreenState extends State<EscanerQRScreen> {
  final MobileScannerController cameraController = MobileScannerController();
  bool isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear QR'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: cameraController,
              builder: (context, state, child) {
                if (state.hasCameraPermission && state.error != null) {
                  return const Icon(Icons.error);
                }
                return Icon(
                  cameraController.value.isTorchOn ? Icons.flash_on : Icons.flash_off,
                );
              },
            ),
            onPressed: () => cameraController.toggleTorch(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: MobileScanner(
              controller: cameraController,
              onDetect: (capture) async {
                if (isProcessing) return;
                
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null && !isProcessing) {
                    isProcessing = true;
                    await _procesarQR(barcode.rawValue!);
                    isProcessing = false;
                  }
                }
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.blueGrey.shade50,
            child: Column(
              children: [
                const Icon(Icons.qr_code_scanner, size: 40, color: Colors.blueGrey),
                const SizedBox(height: 10),
                const Text(
                  'Escanela el código QR del administrador',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  'para validar tu servicio y ganar puntos',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _procesarQR(String qrData) async {
    try {
      final data = jsonDecode(qrData);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final usuario = authProvider.usuarioActual;
      
      if (usuario == null) return;
      
      // Verificar que el QR es para este usuario
      if (data['usuarioId'] == usuario.id) {
        // Agregar puntos
        await DatabaseHelper.instance.agregarPuntos(
          usuario.id!,
          data['puntos'],
          'Servicio: ${data['servicio']}',
        );
        
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.celebration, color: Colors.green, size: 30),
                  SizedBox(width: 10),
                  Text('¡Felicidades!'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stars, size: 60, color: Colors.amber),
                  const SizedBox(height: 16),
                  Text('Has ganado ${data['puntos']} puntos', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('por tu servicio de ${data['servicio']}'),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('¡Genial!', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }
      } else {
        _mostrarError('QR no válido para este usuario');
      }
    } catch (e) {
      _mostrarError('QR inválido');
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ $mensaje'), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}

// ==================== MIS PUNTOS ====================

class MisPuntosScreen extends StatefulWidget {
  const MisPuntosScreen({super.key});

  @override
  State<MisPuntosScreen> createState() => _MisPuntosScreenState();
}

class _MisPuntosScreenState extends State<MisPuntosScreen> {
  List<HistorialPuntos> historial = [];
  Usuario? usuario;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    usuario = authProvider.usuarioActual;
    
    if (usuario != null) {
      historial = await DatabaseHelper.instance.obtenerHistorialPuntos(usuario!.id!);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (usuario == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Puntos'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.blueGrey.shade50,
            child: Column(
              children: [
                const Text('Puntos Totales', style: TextStyle(color: Colors.blueGrey)),
                Text(
                  '${usuario!.puntos}',
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (usuario!.puntos % 500) / 500,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: const AlwaysStoppedAnimation(Colors.amber),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_getNextLevel(usuario!.puntos)} puntos para el próximo nivel',
                  style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                ),
              ],
            ),
          ),
          Expanded(
            child: historial.isEmpty
                ? const Center(child: Text('No hay historial de puntos'))
                : ListView.builder(
                    itemCount: historial.length,
                    itemBuilder: (context, index) {
                      final item = historial[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: item.puntos > 0 ? Colors.green : Colors.red,
                          child: Icon(
                            item.puntos > 0 ? Icons.add : Icons.remove,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(item.concepto),
                        subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(item.fecha)),
                        trailing: Text(
                          '${item.puntos > 0 ? '+' : ''}${item.puntos}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: item.puntos > 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  int _getNextLevel(int puntos) {
    if (puntos < 500) return 500 - puntos;
    if (puntos < 1500) return 1500 - puntos;
    return 3000 - puntos;
  }
}

// ==================== MEMBRESÍA ====================

class MembresiaScreen extends StatefulWidget {
  final Usuario usuario;

  const MembresiaScreen({super.key, required this.usuario});

  @override
  State<MembresiaScreen> createState() => _MembresiaScreenState();
}

class _MembresiaScreenState extends State<MembresiaScreen> {
  final Map<String, dynamic> planes = {
    'basic': {'nombre': 'Básico', 'descuento': 5, 'color': Colors.brown},
    'premium': {'nombre': 'Premium', 'descuento': 10, 'color': Colors.amber},
    'vip': {'nombre': 'VIP', 'descuento': 20, 'color': Colors.blueGrey},
  };

  @override
  Widget build(BuildContext context) {
    final planActual = planes[widget.usuario.membresia];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Membresía'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [planActual['color'], planActual['color'].withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Icon(Icons.card_membership, size: 60, color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    'Plan ${planActual['nombre']}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${planActual['descuento']}% de descuento en todos los servicios',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${widget.usuario.puntos} puntos acumulados',
                      style: TextStyle(color: planActual['color'], fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Beneficios exclusivos',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildBeneficio('🎯', 'Puntos extra', 'Gana ${planActual['descuento'] * 2}% más de puntos'),
          _buildBeneficio('🎁', 'Regalos', 'Cortes gratis en tu cumpleaños'),
          _buildBeneficio('⭐', 'Prioridad', 'Acceso a horarios exclusivos'),
          _buildBeneficio('🔔', 'Promociones', 'Recibe ofertas especiales'),
          const SizedBox(height: 24),
          if (widget.usuario.membresia != 'vip')
            ElevatedButton(
              onPressed: () {
                _mostrarDialogoMejora();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('MEJORAR MEMBRESÍA', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Widget _buildBeneficio(String emoji, String titulo, String descripcion) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Text(emoji, style: const TextStyle(fontSize: 30)),
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(descripcion),
      ),
    );
  }

  void _mostrarDialogoMejora() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mejorar Membresía'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('Para mejorar tu membresía necesitas:'),
            SizedBox(height: 16),
            Text('• 500 puntos para Premium', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('• 1500 puntos para VIP', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Text('¡Sigue acumulando puntos!'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

// ==================== MIS RESERVAS ====================

class MisReservasScreen extends StatefulWidget {
  const MisReservasScreen({super.key});

  @override
  State<MisReservasScreen> createState() => _MisReservasScreenState();
}

class _MisReservasScreenState extends State<MisReservasScreen> {
  List<Reserva> reservas = [];
  Map<int, Servicio> serviciosMap = {};

  @override
  void initState() {
    super.initState();
    _cargarReservas();
  }

  Future<void> _cargarReservas() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final usuario = authProvider.usuarioActual;
    
    if (usuario != null) {
      reservas = await DatabaseHelper.instance.obtenerReservasPorUsuario(usuario.id!);
      
      for (var reserva in reservas) {
        if (!serviciosMap.containsKey(reserva.servicioId)) {
          final servicio = await DatabaseHelper.instance.obtenerServicioPorId(reserva.servicioId);
          if (servicio != null) {
            serviciosMap[reserva.servicioId] = servicio;
          }
        }
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Reservas'),
        centerTitle: true,
      ),
      body: reservas.isEmpty
          ? const Center(child: Text('No tienes reservas'))
          : ListView.builder(
              itemCount: reservas.length,
              itemBuilder: (context, index) {
                final reserva = reservas[index];
                final servicio = serviciosMap[reserva.servicioId];
                
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getEstadoColor(reserva.estado),
                      child: Icon(_getEstadoIcon(reserva.estado), color: Colors.white),
                    ),
                    title: Text(servicio?.nombre ?? 'Servicio'),
                    subtitle: Text(
                      '${DateFormat('dd/MM/yyyy').format(reserva.fecha)} - ${reserva.hora}\nEstado: ${reserva.estado}',
                    ),
                    trailing: reserva.estado == 'pendiente'
                        ? TextButton(
                            onPressed: () => _cancelarReserva(reserva.id!),
                            child: const Text('Cancelar', style: TextStyle(color: Colors.red)),
                          )
                        : null,
                  ),
                );
              },
            ),
    );
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'pendiente': return Colors.orange;
      case 'completado': return Colors.green;
      case 'cancelado': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _getEstadoIcon(String estado) {
    switch (estado) {
      case 'pendiente': return Icons.schedule;
      case 'completado': return Icons.check_circle;
      case 'cancelado': return Icons.cancel;
      default: return Icons.info;
    }
  }

  Future<void> _cancelarReserva(int id) async {
    await DatabaseHelper.instance.actualizarEstadoReserva(id, 'cancelado');
    await _cargarReservas();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reserva cancelada'), backgroundColor: Colors.orange),
      );
    }
  }
}

// ==================== PANEL ADMIN ====================

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  Map<String, dynamic> estadisticas = {};
  List<Reserva> citasHoy = [];

  @override
  void initState() {
    super.initState();
    _cargarEstadisticas();
  }

  Future<void> _cargarEstadisticas() async {
    estadisticas = await DatabaseHelper.instance.obtenerEstadisticas();
    citasHoy = await DatabaseHelper.instance.obtenerReservasPorFecha(DateTime.now());
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Admin'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargarEstadisticas,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dashboard cards
              Row(
                children: [
                  _buildDashboardCard('Clientes', '${estadisticas['totalClientes'] ?? 0}', Icons.people, Colors.blue),
                  const SizedBox(width: 12),
                  _buildDashboardCard('Citas Hoy', '${estadisticas['citasHoy'] ?? 0}', Icons.calendar_today, Colors.green),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildDashboardCard('Ingresos', 'S/ ${estadisticas['totalIngresos'] ?? 0}', Icons.money, Colors.orange),
                  const SizedBox(width: 12),
                  _buildDashboardCard('Servicios', '${servicios.length}', Icons.content_cut, Colors.purple),
                ],
              ),
              const SizedBox(height: 24),
              
              // Sección de acciones rápidas
              const Text('Acciones Rápidas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildActionButton(Icons.qr_code, 'Generar QR', Colors.purple, () => _generarQRDialog()),
              const SizedBox(height: 8),
              _buildActionButton(Icons.add, 'Agregar Servicio', Colors.green, () => _agregarServicioDialog()),
              const SizedBox(height: 8),
              _buildActionButton(Icons.list, 'Ver Servicios', Colors.blue, () => _verServiciosDialog()),
              const SizedBox(height: 8),
              _buildActionButton(Icons.people, 'Ver Clientes', Colors.orange, () => _verClientesDialog()),
              
              const SizedBox(height: 24),
              
              // Citas de hoy
              const Text('Citas de Hoy', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (citasHoy.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No hay citas para hoy')))),
              ...citasHoy.map((reserva) => _buildCitaCard(reserva)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildCitaCard(Reserva reserva) {
    return FutureBuilder<Servicio?>(
      future: DatabaseHelper.instance.obtenerServicioPorId(reserva.servicioId),
      builder: (context, snapshot) {
        final servicio = snapshot.data;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.person),
            title: Text(servicio?.nombre ?? 'Servicio'),
            subtitle: Text('Hora: ${reserva.hora} • ${reserva.estado}'),
            trailing: IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green),
              onPressed: () => _completarCita(reserva),
            ),
          ),
        );
      },
    );
  }

  Future<void> _completarCita(Reserva reserva) async {
    await DatabaseHelper.instance.actualizarEstadoReserva(reserva.id!, 'completado');
    await DatabaseHelper.instance.agregarPuntos(
      reserva.usuarioId,
      reserva.puntosGanados,
      'Servicio completado',
    );
    await _cargarEstadisticas();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Cita completada y puntos otorgados'), backgroundColor: Colors.green),
      );
    }
  }

  void _generarQRDialog() async {
    final clientes = await DatabaseHelper.instance.obtenerTodosClientes();
    final serviciosList = await DatabaseHelper.instance.obtenerServicios();
    
    int? selectedClienteId;
    int? selectedServicioId;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Generar QR'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Cliente'),
                items: clientes.map((c) => DropdownMenuItem(value: c.id, child: Text(c.nombre))).toList(),
                onChanged: (value) => setState(() => selectedClienteId = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Servicio'),
                items: serviciosList.map((s) => DropdownMenuItem(value: s.id, child: Text(s.nombre))).toList(),
                onChanged: (value) => setState(() => selectedServicioId = value),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                if (selectedClienteId != null && selectedServicioId != null) {
                  final servicio = serviciosList.firstWhere((s) => s.id == selectedServicioId);
                  _mostrarQR(selectedClienteId!, servicio);
                  Navigator.pop(context);
                }
              },
              child: const Text('Generar'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarQR(int clienteId, Servicio servicio) {
    final qrData = jsonEncode({
      'usuarioId': clienteId,
      'servicio': servicio.nombre,
      'puntos': servicio.puntos,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Código QR'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 200.0,
            ),
            const SizedBox(height: 16),
            Text('Cliente ID: $clienteId'),
            Text('Servicio: ${servicio.nombre}'),
            Text('Puntos: ${servicio.puntos}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _agregarServicioDialog() {
    final nombreController = TextEditingController();
    final duracionController = TextEditingController();
    final precioController = TextEditingController();
    final puntosController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo Servicio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nombreController, decoration: const InputDecoration(labelText: 'Nombre')),
            TextField(controller: duracionController, decoration: const InputDecoration(labelText: 'Duración (min)'), keyboardType: TextInputType.number),
            TextField(controller: precioController, decoration: const InputDecoration(labelText: 'Precio'), keyboardType: TextInputType.number),
            TextField(controller: puntosController, decoration: const InputDecoration(labelText: 'Puntos'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final servicio = Servicio(
                nombre: nombreController.text,
                duracion: int.parse(duracionController.text),
                precio: double.parse(precioController.text),
                puntos: int.parse(puntosController.text),
                categoria: 'general',
              );
              await DatabaseHelper.instance.crearServicio(servicio);
              await _cargarEstadisticas();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Servicio agregado')));
              }
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  void _verServiciosDialog() async {
    final serviciosList = await DatabaseHelper.instance.obtenerServicios();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lista de Servicios'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: serviciosList.length,
            itemBuilder: (context, index) {
              final s = serviciosList[index];
              return ListTile(
                title: Text(s.nombre),
                subtitle: Text('S/ ${s.precio} • ${s.duracion} min'),
                trailing: Text('${s.puntos} pts'),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  void _verClientesDialog() async {
    final clientes = await DatabaseHelper.instance.obtenerTodosClientes();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clientes'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: clientes.length,
            itemBuilder: (context, index) {
              final c = clientes[index];
              return ListTile(
                leading: CircleAvatar(child: Text(c.nombre[0])),
                title: Text(c.nombre),
                subtitle: Text('${c.puntos} puntos • ${c.membresia}'),
                trailing: Text(c.telefono),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  List<Servicio> get servicios => const [];
}

// Extensiones y helpers
extension CopyWith on Usuario {
  Usuario copyWith({
    int? id,
    String? nombre,
    String? email,
    String? telefono,
    String? rol,
    String? membresia,
    int? puntos,
    DateTime? fechaRegistro,
  }) {
    return Usuario(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      email: email ?? this.email,
      telefono: telefono ?? this.telefono,
      rol: rol ?? this.rol,
      membresia: membresia ?? this.membresia,
      puntos: puntos ?? this.puntos,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
    );
  }
}

// Extensión para DatabaseHelper con métodos adicionales
extension DatabaseHelperExtension on DatabaseHelper {
  Future<List<Usuario>> obtenerTodosClientes() async {
    final db = await database;
    final result = await db.query('usuarios', where: 'rol = ?', whereArgs: ['cliente']);
    return result.map((map) => Usuario.fromMap(map)).toList();
  }
}
