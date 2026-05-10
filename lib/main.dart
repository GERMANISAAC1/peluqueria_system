import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import 'dart:math';

// ══════════════════════════════════════════════════
// ENTRY POINT
// ══════════════════════════════════════════════════
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const BarberProApp());
}

// ══════════════════════════════════════════════════
// COLORES
// ══════════════════════════════════════════════════
class C {
  static const gold        = Color(0xFFC9A84C);
  static const goldLight   = Color(0xFFE8D08A);
  static const black       = Color(0xFF0A0A0A);
  static const dark        = Color(0xFF111111);
  static const dark2       = Color(0xFF1A1A1A);
  static const dark3       = Color(0xFF222222);
  static const textPrimary = Color(0xFFF5F0E8);
  static const textMuted   = Color(0xFF888888);
  static const textDim     = Color(0xFF555555);
  static const success     = Color(0xFF4CAF82);
  static const danger      = Color(0xFFE05A5A);
  static const info        = Color(0xFF5A9CE0);
  static const border      = Color(0x33C9A84C);
  static const borderStrong= Color(0x80C9A84C);

  static Color estadoColor(String estado) {
    switch (estado) {
      case 'pendiente':  return C.info;
      case 'confirmada': return C.gold;
      case 'completada': return C.success;
      case 'cancelada':  return C.danger;
      default:           return C.textMuted;
    }
  }
}

// ══════════════════════════════════════════════════
// MODELOS
// ══════════════════════════════════════════════════
class Usuario {
  final String id;
  String nombre;
  String celular;
  String passwordHash;
  final String rol; // 'cliente' | 'admin'
  String? email;
  String membresia;
  int puntos;
  List<HistorialPunto> historialPuntos;

  Usuario({
    required this.id,
    required this.nombre,
    required this.celular,
    required this.passwordHash,
    required this.rol,
    this.email,
    this.membresia = 'Ninguna',
    this.puntos = 0,
    List<HistorialPunto>? historialPuntos,
  }) : historialPuntos = historialPuntos ?? [];

  String get iniciales {
    final p = nombre.trim().split(' ');
    if (p.length >= 2) return '${p[0][0]}${p[1][0]}'.toUpperCase();
    return nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U';
  }

  bool get esVIP => membresia == 'Premium' || membresia == 'VIP Anual';

  String get nivelLoyalty {
    if (puntos >= 500) return '🥇 Oro';
    if (puntos >= 200) return '🥈 Plata';
    return '🥉 Bronce';
  }

  int get puntosParaSiguienteNivel {
    if (puntos >= 500) return 0;
    if (puntos >= 200) return 500 - puntos;
    return 200 - puntos;
  }

  double get progresoNivel {
    if (puntos >= 500) return 1.0;
    if (puntos >= 200) return (puntos - 200) / 300.0;
    return puntos / 200.0;
  }

  double get descuentoPorcentaje {
    if (puntos >= 500) return 20;
    if (puntos >= 200) return 10;
    return 5;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'celular': celular,
    'passwordHash': passwordHash,
    'rol': rol,
    'email': email,
    'membresia': membresia,
    'puntos': puntos,
    'historialPuntos': historialPuntos.map((h) => h.toJson()).toList(),
  };

  factory Usuario.fromJson(Map<String, dynamic> j) => Usuario(
    id: j['id'] as String,
    nombre: j['nombre'] as String,
    celular: j['celular'] as String,
    passwordHash: j['passwordHash'] as String,
    rol: j['rol'] as String,
    email: j['email'] as String?,
    membresia: (j['membresia'] as String?) ?? 'Ninguna',
    puntos: (j['puntos'] as int?) ?? 0,
    historialPuntos: ((j['historialPuntos'] as List?) ?? [])
        .map((h) => HistorialPunto.fromJson(h as Map<String, dynamic>))
        .toList(),
  );
}

class HistorialPunto {
  final String fecha;
  final String concepto;
  final int puntos;

  HistorialPunto({
    required this.fecha,
    required this.concepto,
    required this.puntos,
  });

  Map<String, dynamic> toJson() => {
    'fecha': fecha,
    'concepto': concepto,
    'puntos': puntos,
  };

  factory HistorialPunto.fromJson(Map<String, dynamic> j) => HistorialPunto(
    fecha: j['fecha'] as String,
    concepto: j['concepto'] as String,
    puntos: j['puntos'] as int,
  );
}

class Servicio {
  final String id;
  String nombre;
  String descripcion;
  double precio;
  int duracion;
  int puntos;
  String icono;
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

  factory Servicio.fromJson(Map<String, dynamic> j) => Servicio(
    id: j['id'] as String,
    nombre: j['nombre'] as String,
    descripcion: j['descripcion'] as String,
    precio: (j['precio'] as num).toDouble(),
    duracion: j['duracion'] as int,
    puntos: j['puntos'] as int,
    icono: j['icono'] as String,
    activo: j['activo'] as bool,
  );
}

class Cita {
  final String id;
  final String clienteId;
  final String clienteNombre;
  final String clienteCelular;
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
    required this.clienteCelular,
    required this.servicioId,
    required this.servicioNombre,
    required this.fecha,
    required this.hora,
    required this.estado,
    required this.precio,
    this.notas = '',
  });

  bool get esHoy {
    final hoy = DateTime.now().toIso8601String().split('T')[0];
    return fecha == hoy;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'clienteId': clienteId,
    'clienteNombre': clienteNombre,
    'clienteCelular': clienteCelular,
    'servicioId': servicioId,
    'servicioNombre': servicioNombre,
    'fecha': fecha,
    'hora': hora,
    'estado': estado,
    'precio': precio,
    'notas': notas,
  };

  factory Cita.fromJson(Map<String, dynamic> j) => Cita(
    id: j['id'] as String,
    clienteId: j['clienteId'] as String,
    clienteNombre: j['clienteNombre'] as String,
    clienteCelular: (j['clienteCelular'] as String?) ?? '',
    servicioId: j['servicioId'] as String,
    servicioNombre: j['servicioNombre'] as String,
    fecha: j['fecha'] as String,
    hora: j['hora'] as String,
    estado: j['estado'] as String,
    precio: (j['precio'] as num).toDouble(),
    notas: (j['notas'] as String?) ?? '',
  );
}

class Promocion {
  final String id;
  String titulo;
  String descripcion;
  int descuento;
  String hasta;
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

  factory Promocion.fromJson(Map<String, dynamic> j) => Promocion(
    id: j['id'] as String,
    titulo: j['titulo'] as String,
    descripcion: j['descripcion'] as String,
    descuento: j['descuento'] as int,
    hasta: j['hasta'] as String,
    activa: j['activa'] as bool,
  );
}

// ══════════════════════════════════════════════════
// SERVICIO DE BASE DE DATOS (SharedPreferences)
// ══════════════════════════════════════════════════
class DB {
  static const _key = 'barberpro_v2';
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    if (_prefs!.getString(_key) == null) await _seed();
  }

  static String _hash(String password) {
    // Hash simple con salt — en producción usar bcrypt/argon2
    final bytes = utf8.encode('bpro_salt_2024_$password');
    var hash = 0;
    for (final b in bytes) {
      hash = ((hash << 5) - hash) + b;
      hash &= 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static String _genId(String prefix) {
    final rand = Random().nextInt(99999).toString().padLeft(5, '0');
    return '$prefix${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}$rand';
  }

  static Future<void> _seed() async {
    final hoy = DateTime.now().toIso8601String().split('T')[0];
    final manana = DateTime.now().add(const Duration(days: 1)).toIso8601String().split('T')[0];
    final adminId = _genId('USR');
    final cli1Id  = _genId('USR');
    final cli2Id  = _genId('USR');
    final svc1Id  = _genId('SVC');
    final svc2Id  = _genId('SVC');
    final svc3Id  = _genId('SVC');
    final svc4Id  = _genId('SVC');

    final data = {
      'usuarios': [
        // Admin: celular 999000000 / clave: admin123
        {
          'id': adminId, 'nombre': 'Administrador', 'celular': '999000000',
          'passwordHash': _hash('admin123'), 'rol': 'admin',
          'email': 'admin@barberpro.pe', 'membresia': 'Ninguna', 'puntos': 0,
          'historialPuntos': [],
        },
        // Cliente 1: celular 987654321 / clave: cliente123
        {
          'id': cli1Id, 'nombre': 'Carlos Mendoza', 'celular': '987654321',
          'passwordHash': _hash('cliente123'), 'rol': 'cliente',
          'email': 'carlos@email.com', 'membresia': 'Premium', 'puntos': 320,
          'historialPuntos': [
            {'fecha': hoy, 'concepto': 'Corte clásico', 'puntos': 10},
            {'fecha': hoy, 'concepto': 'Corte + barba', 'puntos': 15},
          ],
        },
        // Cliente 2: celular 976543210 / clave: pedro123
        {
          'id': cli2Id, 'nombre': 'Pedro Sánchez', 'celular': '976543210',
          'passwordHash': _hash('pedro123'), 'rol': 'cliente',
          'email': 'pedro@email.com', 'membresia': 'Básico', 'puntos': 85,
          'historialPuntos': [],
        },
      ],
      'servicios': [
        {'id': svc1Id, 'nombre': 'Corte clásico',    'descripcion': 'Corte tradicional con tijera y peine', 'precio': 25.0, 'duracion': 30, 'puntos': 10, 'icono': '✂️', 'activo': true},
        {'id': svc2Id, 'nombre': 'Corte + barba',    'descripcion': 'Corte completo y arreglo de barba',    'precio': 40.0, 'duracion': 50, 'puntos': 15, 'icono': '🪒', 'activo': true},
        {'id': svc3Id, 'nombre': 'Afeitado clásico', 'descripcion': 'Afeitado con navaja y toalla caliente','precio': 30.0, 'duracion': 40, 'puntos': 12, 'icono': '🔥', 'activo': true},
        {'id': svc4Id, 'nombre': 'Degradado fade',   'descripcion': 'Fade profesional a máquina',           'precio': 35.0, 'duracion': 45, 'puntos': 13, 'icono': '💈', 'activo': true},
      ],
      'citas': [
        {'id': _genId('CIT'), 'clienteId': cli1Id, 'clienteNombre': 'Carlos Mendoza', 'clienteCelular': '987654321', 'servicioId': svc1Id, 'servicioNombre': 'Corte clásico', 'fecha': hoy,    'hora': '10:00', 'estado': 'confirmada', 'precio': 25.0, 'notas': ''},
        {'id': _genId('CIT'), 'clienteId': cli2Id, 'clienteNombre': 'Pedro Sánchez',  'clienteCelular': '976543210', 'servicioId': svc2Id, 'servicioNombre': 'Corte + barba', 'fecha': hoy,    'hora': '11:00', 'estado': 'pendiente',  'precio': 40.0, 'notas': ''},
        {'id': _genId('CIT'), 'clienteId': cli1Id, 'clienteNombre': 'Carlos Mendoza', 'clienteCelular': '987654321', 'servicioId': svc3Id, 'servicioNombre': 'Afeitado clásico','fecha': manana,'hora': '15:30', 'estado': 'pendiente',  'precio': 30.0, 'notas': 'Sin prisa'},
      ],
      'promociones': [
        {'id': _genId('PRO'), 'titulo': 'Martes de descuento', 'descripcion': '20% off en todos los cortes los martes', 'descuento': 20, 'hasta': '2025-12-31', 'activa': true},
        {'id': _genId('PRO'), 'titulo': 'Combo Verano',        'descripcion': 'Corte + barba a precio especial S/ 35',   'descuento': 15, 'hasta': '2026-03-31', 'activa': true},
      ],
    };
    await _prefs!.setString(_key, jsonEncode(data));
  }

  // ── LECTURA ──────────────────────────────
  static Map<String, dynamic> _raw() =>
      jsonDecode(_prefs!.getString(_key)!) as Map<String, dynamic>;

  static Future<void> _save(Map<String, dynamic> data) async =>
      await _prefs!.setString(_key, jsonEncode(data));

  // ── USUARIOS ─────────────────────────────
  static List<Usuario> usuarios() {
    final raw = _raw();
    return (raw['usuarios'] as List)
        .map((u) => Usuario.fromJson(u as Map<String, dynamic>))
        .toList();
  }

  static Usuario? loginCheck(String celular, String password) {
    return usuarios().where((u) =>
        u.celular == celular && u.passwordHash == _hash(password)
    ).firstOrNull;
  }

  static bool celularExiste(String celular) =>
      usuarios().any((u) => u.celular == celular);

  static Future<Usuario> registrar({
    required String nombre,
    required String celular,
    required String password,
    String? email,
  }) async {
    final raw = _raw();
    final nuevo = Usuario(
      id: _genId('USR'),
      nombre: nombre,
      celular: celular,
      passwordHash: _hash(password),
      rol: 'cliente',
      email: email,
    );
    (raw['usuarios'] as List).add(nuevo.toJson());
    await _save(raw);
    return nuevo;
  }

  static Future<void> actualizarUsuario(Usuario u) async {
    final raw = _raw();
    final list = raw['usuarios'] as List;
    final idx = list.indexWhere((x) => (x as Map)['id'] == u.id);
    if (idx != -1) list[idx] = u.toJson();
    await _save(raw);
  }

  static Future<void> eliminarUsuario(String id) async {
    final raw = _raw();
    raw['usuarios'] = (raw['usuarios'] as List)
        .where((u) => (u as Map)['id'] != id)
        .toList();
    await _save(raw);
  }

  static Future<void> agregarPuntos(String usuarioId, int puntos, String concepto) async {
    final raw = _raw();
    final list = raw['usuarios'] as List;
    final idx = list.indexWhere((u) => (u as Map)['id'] == usuarioId);
    if (idx != -1) {
      final u = list[idx] as Map<String, dynamic>;
      u['puntos'] = ((u['puntos'] as int?) ?? 0) + puntos;
      (u['historialPuntos'] as List).add({
        'fecha': DateTime.now().toIso8601String().split('T')[0],
        'concepto': concepto,
        'puntos': puntos,
      });
    }
    await _save(raw);
  }

  // ── SERVICIOS ────────────────────────────
  static List<Servicio> servicios({bool soloActivos = false}) {
    final raw = _raw();
    var list = (raw['servicios'] as List)
        .map((s) => Servicio.fromJson(s as Map<String, dynamic>))
        .toList();
    if (soloActivos) list = list.where((s) => s.activo).toList();
    return list;
  }

  static Future<void> agregarServicio(Servicio s) async {
    final raw = _raw();
    (raw['servicios'] as List).add(s.toJson());
    await _save(raw);
  }

  static Future<void> eliminarServicio(String id) async {
    final raw = _raw();
    raw['servicios'] = (raw['servicios'] as List)
        .where((s) => (s as Map)['id'] != id)
        .toList();
    await _save(raw);
  }

  // ── CITAS ────────────────────────────────
  static List<Cita> citas({String? clienteId, String? estado, String? fecha}) {
    final raw = _raw();
    var list = (raw['citas'] as List)
        .map((c) => Cita.fromJson(c as Map<String, dynamic>))
        .toList();
    if (clienteId != null) list = list.where((c) => c.clienteId == clienteId).toList();
    if (estado != null)    list = list.where((c) => c.estado == estado).toList();
    if (fecha != null)     list = list.where((c) => c.fecha == fecha).toList();
    list.sort((a, b) {
      final cmp = b.fecha.compareTo(a.fecha);
      return cmp != 0 ? cmp : b.hora.compareTo(a.hora);
    });
    return list;
  }

  static List<Cita> citasHoy() {
    final hoy = DateTime.now().toIso8601String().split('T')[0];
    return citas(fecha: hoy)
      ..sort((a, b) => a.hora.compareTo(b.hora));
  }

  static Future<void> agregarCita(Cita c) async {
    final raw = _raw();
    (raw['citas'] as List).add(c.toJson());
    await _save(raw);
  }

  static Future<void> cambiarEstadoCita(String id, String estado) async {
    final raw = _raw();
    final list = raw['citas'] as List;
    final idx = list.indexWhere((c) => (c as Map)['id'] == id);
    if (idx != -1) (list[idx] as Map<String, dynamic>)['estado'] = estado;
    await _save(raw);
  }

  static Future<void> completarCita(String citaId) async {
    final raw = _raw();
    final cList = raw['citas'] as List;
    final idx = cList.indexWhere((c) => (c as Map)['id'] == citaId);
    if (idx == -1) return;
    final citaMap = cList[idx] as Map<String, dynamic>;
    citaMap['estado'] = 'completada';

    // Sumar puntos al cliente
    final svcId = citaMap['servicioId'] as String;
    final svc = (raw['servicios'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((s) => s['id'] == svcId, orElse: () => {});
    if (svc.isNotEmpty) {
      final pts = svc['puntos'] as int;
      final nombre = svc['nombre'] as String;
      final uList = raw['usuarios'] as List;
      final uIdx = uList.indexWhere((u) => (u as Map)['id'] == citaMap['clienteId']);
      if (uIdx != -1) {
        final u = uList[uIdx] as Map<String, dynamic>;
        u['puntos'] = ((u['puntos'] as int?) ?? 0) + pts;
        (u['historialPuntos'] as List).add({
          'fecha': DateTime.now().toIso8601String().split('T')[0],
          'concepto': nombre,
          'puntos': pts,
        });
      }
    }
    await _save(raw);
  }

  static bool horarioOcupado(String fecha, String hora) {
    return citas(fecha: fecha).any((c) =>
        c.hora == hora && c.estado != 'cancelada');
  }

  // ── PROMOCIONES ──────────────────────────
  static List<Promocion> promociones() {
    final raw = _raw();
    return (raw['promociones'] as List)
        .map((p) => Promocion.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  static Future<void> agregarPromocion(Promocion p) async {
    final raw = _raw();
    (raw['promociones'] as List).add(p.toJson());
    await _save(raw);
  }

  static Future<void> eliminarPromocion(String id) async {
    final raw = _raw();
    raw['promociones'] = (raw['promociones'] as List)
        .where((p) => (p as Map)['id'] != id)
        .toList();
    await _save(raw);
  }

  // ── HELPERS ──────────────────────────────
  static String genId(String prefix) => _genId(prefix);

  static String formatFecha(String fecha) {
    final p = fecha.split('-');
    if (p.length != 3) return fecha;
    return '${p[2]}/${p[1]}/${p[0]}';
  }
}

// ══════════════════════════════════════════════════
// SESSION MANAGER
// ══════════════════════════════════════════════════
class Session {
  static Usuario? current;

  static Future<void> save(Usuario u) async {
    current = u;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_id', u.id);
    await prefs.setString('session_rol', u.rol);
  }

  static Future<Usuario?> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('session_id');
    if (id == null) return null;
    return DB.usuarios().where((u) => u.id == id).firstOrNull;
  }

  static Future<void> clear() async {
    current = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_id');
    await prefs.remove('session_rol');
  }
}

// ══════════════════════════════════════════════════
// APP ROOT
// ══════════════════════════════════════════════════
class BarberProApp extends StatelessWidget {
  const BarberProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BarberPro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: C.gold,
        scaffoldBackgroundColor: C.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: C.dark,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: C.gold, fontSize: 20, fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: C.textPrimary),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: C.dark,
          selectedItemColor: C.gold,
          unselectedItemColor: C.textMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: C.dark3,
          labelStyle: const TextStyle(color: C.textMuted),
          hintStyle: const TextStyle(color: C.textDim),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: C.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: C.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: C.gold, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: C.danger),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: C.danger),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: C.gold,
            foregroundColor: C.black,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: C.gold,
            side: const BorderSide(color: C.borderStrong),
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        colorScheme: const ColorScheme.dark(
          primary: C.gold,
          secondary: C.goldLight,
          surface: C.dark2,
          error: C.danger,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// ══════════════════════════════════════════════════
// SPLASH SCREEN
// ══════════════════════════════════════════════════
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    _init();
  }

  Future<void> _init() async {
    await DB.init();
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    final user = await Session.restore();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => user != null
            ? (user.rol == 'admin'
                ? AdminMainScreen(usuario: user)
                : ClienteMainScreen(usuario: user))
            : const LoginScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.black,
      body: FadeTransition(
        opacity: _fade,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LogoWidget(size: 100),
              SizedBox(height: 24),
              Text(
                'BARBERPRO',
                style: TextStyle(
                  color: C.gold, fontSize: 26,
                  fontWeight: FontWeight.bold, letterSpacing: 6,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Sistema de gestión profesional',
                style: TextStyle(color: C.textMuted, fontSize: 13),
              ),
              SizedBox(height: 48),
              SizedBox(
                width: 28, height: 28,
                child: CircularProgressIndicator(
                  color: C.gold, strokeWidth: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// WIDGETS REUTILIZABLES
// ══════════════════════════════════════════════════
class _LogoWidget extends StatelessWidget {
  final double size;
  const _LogoWidget({this.size = 80});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: C.gold, width: 2),
        color: C.gold.withValues(alpha: 0.08),
      ),
      child: Center(
        child: Text('✂️', style: TextStyle(fontSize: size * 0.46)),
      ),
    );
  }
}

class _GoldCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? borderColor;
  final VoidCallback? onTap;

  const _GoldCard({
    required this.child,
    this.padding,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: C.dark2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? C.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _EstadoBadge extends StatelessWidget {
  final String estado;
  const _EstadoBadge(this.estado);

  @override
  Widget build(BuildContext context) {
    final color = C.estadoColor(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        estado.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String icon;
  final String value;
  final String label;

  const _StatCard({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: C.dark2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.border),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: C.gold)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: C.textMuted, fontSize: 11), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

void _snack(BuildContext ctx, String msg, {bool error = false}) {
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: error ? C.danger : C.success,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ));
}

// ══════════════════════════════════════════════════
// LOGIN SCREEN
// ══════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _celCtrl  = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _verPass   = false;
  bool _loading   = false;

  @override
  void dispose() {
    _celCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 400)); // UX feedback

    final usuario = DB.loginCheck(
      _celCtrl.text.trim(),
      _passCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (usuario == null) {
      _snack(context, 'Celular o clave incorrectos', error: true);
      return;
    }

    await Session.save(usuario);
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => usuario.rol == 'admin'
            ? AdminMainScreen(usuario: usuario)
            : ClienteMainScreen(usuario: usuario),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.2,
            colors: [Color(0xFF1A1200), C.black],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _LogoWidget(size: 90),
                    const SizedBox(height: 20),
                    const Text('BarberPro',
                        style: TextStyle(color: C.gold, fontSize: 36, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text('Sistema de gestión profesional',
                        style: TextStyle(color: C.textMuted, fontSize: 13)),
                    const SizedBox(height: 48),

                    // Celular
                    TextFormField(
                      controller: _celCtrl,
                      keyboardType: TextInputType.phone,
                      maxLength: 9,
                      style: const TextStyle(color: C.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Número de celular',
                        prefixIcon: Icon(Icons.phone_android, color: C.textMuted),
                        counterText: '',
                      ),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Ingresa tu celular';
                        if (v.length != 9) return 'El celular debe tener 9 dígitos';
                        if (!v.startsWith('9')) return 'El celular debe empezar con 9';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Contraseña
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: !_verPass,
                      style: const TextStyle(color: C.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Clave de acceso',
                        prefixIcon: const Icon(Icons.lock_outline, color: C.textMuted),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _verPass ? Icons.visibility_off : Icons.visibility,
                            color: C.textMuted,
                          ),
                          onPressed: () => setState(() => _verPass = !_verPass),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Ingresa tu clave';
                        if (v.length < 4) return 'Mínimo 4 caracteres';
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),

                    // Botón Ingresar
                    _loading
                        ? const SizedBox(
                            height: 52,
                            child: Center(child: CircularProgressIndicator(color: C.gold)),
                          )
                        : ElevatedButton(
                            onPressed: _login,
                            child: const Text('Ingresar'),
                          ),
                    const SizedBox(height: 16),

                    // Ir a registro
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('¿No tienes cuenta? ',
                            style: TextStyle(color: C.textMuted, fontSize: 13)),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const RegisterScreen()),
                          ),
                          child: const Text('Regístrate',
                              style: TextStyle(
                                  color: C.gold, fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Credenciales de demo
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: C.dark2,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: C.border),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cuentas de prueba:',
                              style: TextStyle(color: C.gold, fontSize: 12, fontWeight: FontWeight.w600)),
                          SizedBox(height: 6),
                          Text('👑 Admin:    999000000 / admin123',
                              style: TextStyle(color: C.textMuted, fontSize: 11)),
                          Text('👤 Cliente:  987654321 / cliente123',
                              style: TextStyle(color: C.textMuted, fontSize: 11)),
                          Text('👤 Cliente:  976543210 / pedro123',
                              style: TextStyle(color: C.textMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// REGISTER SCREEN
// ══════════════════════════════════════════════════
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _nomCtrl   = TextEditingController();
  final _celCtrl   = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  bool _verPass    = false;
  bool _loading    = false;

  @override
  void dispose() {
    _nomCtrl.dispose(); _celCtrl.dispose(); _emailCtrl.dispose();
    _passCtrl.dispose(); _pass2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    if (DB.celularExiste(_celCtrl.text.trim())) {
      setState(() => _loading = false);
      if (mounted) _snack(context, 'Ese número ya está registrado', error: true);
      return;
    }

    final usuario = await DB.registrar(
      nombre: _nomCtrl.text.trim(),
      celular: _celCtrl.text.trim(),
      password: _passCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
    );
    await Session.save(usuario);

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => ClienteMainScreen(usuario: usuario)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 8),
              const _LogoWidget(size: 70),
              const SizedBox(height: 24),

              // Nombre
              TextFormField(
                controller: _nomCtrl,
                style: const TextStyle(color: C.textPrimary),
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  prefixIcon: Icon(Icons.person_outline, color: C.textMuted),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Ingresa tu nombre';
                  if (v.trim().length < 3) return 'Mínimo 3 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Celular
              TextFormField(
                controller: _celCtrl,
                keyboardType: TextInputType.phone,
                maxLength: 9,
                style: const TextStyle(color: C.textPrimary),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Número de celular',
                  prefixIcon: Icon(Icons.phone_android, color: C.textMuted),
                  counterText: '',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Ingresa tu celular';
                  if (v.length != 9) return '9 dígitos requeridos';
                  if (!v.startsWith('9')) return 'Debe empezar con 9';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Email (opcional)
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: C.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Email (opcional)',
                  prefixIcon: Icon(Icons.email_outlined, color: C.textMuted),
                ),
              ),
              const SizedBox(height: 14),

              // Contraseña
              TextFormField(
                controller: _passCtrl,
                obscureText: !_verPass,
                style: const TextStyle(color: C.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Clave de acceso',
                  prefixIcon: const Icon(Icons.lock_outline, color: C.textMuted),
                  suffixIcon: IconButton(
                    icon: Icon(_verPass ? Icons.visibility_off : Icons.visibility,
                        color: C.textMuted),
                    onPressed: () => setState(() => _verPass = !_verPass),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Ingresa una clave';
                  if (v.length < 6) return 'Mínimo 6 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Confirmar contraseña
              TextFormField(
                controller: _pass2Ctrl,
                obscureText: !_verPass,
                style: const TextStyle(color: C.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Confirmar clave',
                  prefixIcon: Icon(Icons.lock_outline, color: C.textMuted),
                ),
                validator: (v) {
                  if (v != _passCtrl.text) return 'Las claves no coinciden';
                  return null;
                },
              ),
              const SizedBox(height: 28),

              _loading
                  ? const SizedBox(
                      height: 52,
                      child: Center(child: CircularProgressIndicator(color: C.gold)),
                    )
                  : ElevatedButton(
                      onPressed: _registrar,
                      child: const Text('Crear cuenta'),
                    ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Ya tengo cuenta — Iniciar sesión',
                    style: TextStyle(color: C.textMuted)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// CLIENTE — MAIN SCREEN (con estado compartido)
// ══════════════════════════════════════════════════
class ClienteMainScreen extends StatefulWidget {
  final Usuario usuario;
  const ClienteMainScreen({super.key, required this.usuario});

  @override
  State<ClienteMainScreen> createState() => _ClienteMainScreenState();
}

class _ClienteMainScreenState extends State<ClienteMainScreen> {
  int _tab = 0;
  late Usuario _usuario;

  @override
  void initState() {
    super.initState();
    _usuario = widget.usuario;
  }

  void _refresh() {
    final updated = DB.usuarios().where((u) => u.id == _usuario.id).firstOrNull;
    if (updated != null) setState(() => _usuario = updated);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _ClienteInicioTab(usuario: _usuario, onRefresh: _refresh),
      _ClienteCitasTab(usuario: _usuario, onRefresh: _refresh),
      _ClienteQRTab(usuario: _usuario),
      _ClientePuntosTab(usuario: _usuario),
      _ClienteMembresiaTab(usuario: _usuario, onRefresh: _refresh),
      _ClientePerfilTab(usuario: _usuario, onRefresh: _refresh),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('✂️ BarberPro'),
        automaticallyImplyLeading: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: C.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: C.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.star, size: 14, color: C.gold),
                const SizedBox(width: 4),
                Text('${_usuario.puntos} pts',
                    style: const TextStyle(color: C.gold, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
      body: screens[_tab],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) {
          _refresh();
          setState(() => _tab = i);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined),      activeIcon: Icon(Icons.home),            label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), activeIcon: Icon(Icons.calendar_today), label: 'Citas'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_outlined),   activeIcon: Icon(Icons.qr_code),         label: 'QR'),
          BottomNavigationBarItem(icon: Icon(Icons.star_outline),       activeIcon: Icon(Icons.star),            label: 'Puntos'),
          BottomNavigationBarItem(icon: Icon(Icons.workspace_premium_outlined), activeIcon: Icon(Icons.workspace_premium), label: 'Membresía'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline),     activeIcon: Icon(Icons.person),          label: 'Perfil'),
        ],
      ),
    );
  }
}

// ── TAB: INICIO ──────────────────────────────────
class _ClienteInicioTab extends StatefulWidget {
  final Usuario usuario;
  final VoidCallback onRefresh;
  const _ClienteInicioTab({required this.usuario, required this.onRefresh});

  @override
  State<_ClienteInicioTab> createState() => _ClienteInicioTabState();
}

class _ClienteInicioTabState extends State<_ClienteInicioTab> {
  List<Cita> _misCitas = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _misCitas = DB.citas(clienteId: widget.usuario.id);
    });
  }

  Cita? get _proximaCita {
    final hoy = DateTime.now().toIso8601String().split('T')[0];
    final futuras = _misCitas.where((c) =>
        c.estado != 'cancelada' && c.fecha.compareTo(hoy) >= 0
    ).toList()
      ..sort((a, b) {
        final fc = a.fecha.compareTo(b.fecha);
        return fc != 0 ? fc : a.hora.compareTo(b.hora);
      });
    return futuras.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final prox = _proximaCita;
    return RefreshIndicator(
      color: C.gold,
      onRefresh: () async { _load(); widget.onRefresh(); },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Card próxima cita
          _GoldCard(
            borderColor: C.gold,
            padding: const EdgeInsets.all(18),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1A1200), Color(0xFF2A1F00)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Text('📅', style: TextStyle(fontSize: 36)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('PRÓXIMA CITA',
                            style: TextStyle(color: C.textMuted, fontSize: 11, letterSpacing: 1)),
                        const SizedBox(height: 4),
                        Text(
                          prox != null
                              ? '${DB.formatFecha(prox.fecha)} · ${prox.hora}'
                              : 'Sin citas programadas',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        if (prox != null)
                          Text(prox.servicioNombre,
                              style: const TextStyle(color: C.gold, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Estadísticas
          Row(children: [
            _StatCard(icon: '📅', value: _misCitas.length.toString(), label: 'Citas totales'),
            const SizedBox(width: 12),
            _StatCard(icon: '⭐', value: widget.usuario.puntos.toString(), label: 'Mis puntos'),
          ]),
          const SizedBox(height: 20),

          const Text('ACCESO RÁPIDO',
              style: TextStyle(color: C.gold, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15,
            children: [
              _quickCard('✂️', 'Reservar cita', 'Elige tu servicio', () {
                showDialog(
                  context: context,
                  builder: (_) => _ReservarCitaDialog(
                    usuario: widget.usuario,
                    onSuccess: () { _load(); widget.onRefresh(); },
                  ),
                );
              }),
              _quickCard('📱', 'Mi QR', 'Código de cliente', null),
              _quickCard('⭐', 'Mis puntos', 'Programa de lealtad', null),
              _quickCard('👑', 'Membresía', 'Planes y beneficios', null),
            ],
          ),

          // Promociones activas
          const SizedBox(height: 20),
          const Text('PROMOCIONES ACTIVAS',
              style: TextStyle(color: C.gold, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...DB.promociones().where((p) => p.activa).map((p) => _GoldCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: C.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${p.descuento}%',
                      style: const TextStyle(color: C.gold, fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(p.descripcion,
                          style: const TextStyle(color: C.textMuted, fontSize: 12)),
                      Text('Válido hasta: ${DB.formatFecha(p.hasta)}',
                          style: const TextStyle(color: C.textDim, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _quickCard(String ico, String titulo, String sub, VoidCallback? onTap) {
    return _GoldCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(ico, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text(titulo,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              textAlign: TextAlign.center),
          Text(sub,
              style: const TextStyle(color: C.textMuted, fontSize: 11),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── TAB: CITAS ────────────────────────────────────
class _ClienteCitasTab extends StatefulWidget {
  final Usuario usuario;
  final VoidCallback onRefresh;
  const _ClienteCitasTab({required this.usuario, required this.onRefresh});

  @override
  State<_ClienteCitasTab> createState() => _ClienteCitasTabState();
}

class _ClienteCitasTabState extends State<_ClienteCitasTab> {
  List<Cita> _citas = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() => _citas = DB.citas(clienteId: widget.usuario.id));
  }

  Future<void> _cancelar(Cita c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: C.dark2,
        title: const Text('Cancelar cita', style: TextStyle(color: C.gold)),
        content: const Text('¿Confirmas la cancelación?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('No', style: TextStyle(color: C.textMuted))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Sí', style: TextStyle(color: C.danger))),
        ],
      ),
    );
    if (ok != true) return;
    await DB.cambiarEstadoCita(c.id, 'cancelada');
    _load();
    widget.onRefresh();
    if (mounted) _snack(context, 'Cita cancelada', error: true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text('Mis Citas',
                    style: TextStyle(color: C.gold, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Nueva'),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(100, 40), padding: const EdgeInsets.symmetric(horizontal: 14)),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => _ReservarCitaDialog(
                    usuario: widget.usuario,
                    onSuccess: () { _load(); widget.onRefresh(); },
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _citas.isEmpty
              ? const Center(child: Text('No tienes citas registradas', style: TextStyle(color: C.textMuted)))
              : RefreshIndicator(
                  color: C.gold,
                  onRefresh: () async => _load(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _citas.length,
                    itemBuilder: (_, i) {
                      final c = _citas[i];
                      return _GoldCard(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(c.servicioNombre,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      const SizedBox(height: 3),
                                      Text('${DB.formatFecha(c.fecha)} · ${c.hora}',
                                          style: const TextStyle(color: C.textMuted, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                _EstadoBadge(c.estado),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('S/ ${c.precio.toStringAsFixed(0)}',
                                    style: const TextStyle(color: C.gold, fontWeight: FontWeight.bold, fontSize: 16)),
                                if (c.estado == 'pendiente' || c.estado == 'confirmada')
                                  OutlinedButton(
                                    onPressed: () => _cancelar(c),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: C.danger),
                                      minimumSize: const Size(90, 34),
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                    ),
                                    child: const Text('Cancelar', style: TextStyle(color: C.danger, fontSize: 12)),
                                  ),
                              ],
                            ),
                            if (c.notas.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(children: [
                                const Icon(Icons.notes, size: 14, color: C.textMuted),
                                const SizedBox(width: 6),
                                Expanded(child: Text(c.notas,
                                    style: const TextStyle(color: C.textMuted, fontSize: 12))),
                              ]),
                            ],
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

// ── TAB: QR ───────────────────────────────────────
class _ClienteQRTab extends StatelessWidget {
  final Usuario usuario;
  const _ClienteQRTab({required this.usuario});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Mi Código QR',
                style: TextStyle(color: C.gold, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Muestra este código al barbero para registrar tu servicio',
                style: TextStyle(color: C.textMuted, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: usuario.id,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            _GoldCard(
              child: Column(
                children: [
                  Text('ID: ${usuario.id}',
                      style: const TextStyle(color: C.textMuted, fontSize: 11, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Text(usuario.nombre,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: C.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: C.border),
                    ),
                    child: Text(
                      usuario.membresia != 'Ninguna'
                          ? '👑 ${usuario.membresia}'
                          : '👤 Cliente estándar',
                      style: const TextStyle(color: C.gold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            _GoldCard(
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: C.textMuted, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'El barbero escaneará tu código y se registrará automáticamente el servicio en tu historial de puntos.',
                      style: TextStyle(color: C.textMuted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── TAB: PUNTOS ───────────────────────────────────
class _ClientePuntosTab extends StatelessWidget {
  final Usuario usuario;
  const _ClientePuntosTab({required this.usuario});

  @override
  Widget build(BuildContext context) {
    final u = DB.usuarios().where((x) => x.id == usuario.id).firstOrNull ?? usuario;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Círculo de puntos
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1A1200), Color(0xFF2A1F00)]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: C.gold),
          ),
          child: Column(
            children: [
              Container(
                width: 110, height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: C.gold, width: 3),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${u.puntos}',
                        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: C.gold)),
                    const Text('PUNTOS',
                        style: TextStyle(color: C.textMuted, fontSize: 10, letterSpacing: 1)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: C.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(u.nivelLoyalty,
                    style: const TextStyle(color: C.gold, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 14),
              if (u.puntosParaSiguienteNivel > 0)
                Text('${u.puntosParaSiguienteNivel} pts para el siguiente nivel',
                    style: const TextStyle(color: C.textMuted, fontSize: 12))
              else
                const Text('¡Nivel máximo alcanzado!',
                    style: TextStyle(color: C.gold, fontSize: 12)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: u.progresoNivel,
                  minHeight: 8,
                  backgroundColor: C.dark3,
                  valueColor: const AlwaysStoppedAnimation<Color>(C.gold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Descuento actual
        _GoldCard(
          child: Row(
            children: [
              const Icon(Icons.local_offer, color: C.gold),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tu descuento actual',
                        style: TextStyle(color: C.textMuted, fontSize: 12)),
                    Text('En todos los servicios',
                        style: TextStyle(color: C.textPrimary, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Text('${u.descuentoPorcentaje.toInt()}% OFF',
                  style: const TextStyle(color: C.gold, fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
        ),

        // Beneficios
        _GoldCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('BENEFICIOS POR NIVEL',
                  style: TextStyle(color: C.textMuted, fontSize: 12, letterSpacing: 1)),
              const SizedBox(height: 14),
              _beneficioRow('🥉', 'Bronce — 0 a 199 pts', '5% descuento en servicios'),
              const Divider(color: C.border, height: 20),
              _beneficioRow('🥈', 'Plata — 200 a 499 pts', '10% descuento + 1 corte gratis/mes'),
              const Divider(color: C.border, height: 20),
              _beneficioRow('🥇', 'Oro — 500+ pts', '20% descuento + prioridad de cita'),
            ],
          ),
        ),

        // Historial
        _GoldCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('HISTORIAL DE PUNTOS',
                  style: TextStyle(color: C.textMuted, fontSize: 12, letterSpacing: 1)),
              const SizedBox(height: 12),
              if (u.historialPuntos.isEmpty)
                const Center(child: Text('Sin historial aún', style: TextStyle(color: C.textMuted)))
              else
                ...u.historialPuntos.reversed.map((h) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: C.gold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(child: Text('⭐', style: TextStyle(fontSize: 18))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(h.concepto,
                                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                            Text(h.fecha,
                                style: const TextStyle(color: C.textMuted, fontSize: 11)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: C.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('+${h.puntos} pts',
                            style: const TextStyle(color: C.gold, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _beneficioRow(String emoji, String titulo, String beneficio) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              Text(beneficio, style: const TextStyle(color: C.textMuted, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── TAB: MEMBRESÍA ────────────────────────────────
class _ClienteMembresiaTab extends StatefulWidget {
  final Usuario usuario;
  final VoidCallback onRefresh;
  const _ClienteMembresiaTab({required this.usuario, required this.onRefresh});

  @override
  State<_ClienteMembresiaTab> createState() => _ClienteMembresiaTabState();
}

class _ClienteMembresiaTabState extends State<_ClienteMembresiaTab> {
  late Usuario _u;

  @override
  void initState() {
    super.initState();
    _u = widget.usuario;
  }

  Future<void> _activar(String plan) async {
    _u.membresia = plan;
    await DB.actualizarUsuario(_u);
    setState(() {});
    widget.onRefresh();
    if (mounted) _snack(context, '¡Plan $plan activado! 👑');
  }

  @override
  Widget build(BuildContext context) {
    final u = DB.usuarios().where((x) => x.id == _u.id).firstOrNull ?? _u;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Membresía',
            style: TextStyle(color: C.gold, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        // Estado actual
        if (u.membresia != 'Ninguna')
          _GoldCard(
            borderColor: C.gold,
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Text('👑', style: TextStyle(fontSize: 32)),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('MEMBRESÍA ACTIVA',
                        style: TextStyle(color: C.textMuted, fontSize: 11, letterSpacing: 1)),
                    Text('Plan ${u.membresia}',
                        style: const TextStyle(color: C.gold, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          )
        else
          _GoldCard(
            child: const Text('Sin membresía activa',
                style: TextStyle(color: C.textMuted), textAlign: TextAlign.center),
          ),

        const SizedBox(height: 8),

        // Plan Básico
        _planCard('Plan Básico', 'S/49', '/mes',
            '4 cortes al mes · Reserva anticipada',
            ['✅ 4 cortes de cabello', '✅ Reserva anticipada', '✅ 5% descuento en productos'],
            'Básico', C.border),

        // Plan Premium
        _planCard('Plan Premium', 'S/89', '/mes',
            'Servicios ilimitados · VIP',
            ['✅ Cortes ilimitados', '✅ Afeitado clásico incluido', '✅ 15% descuento en productos', '✅ Prioridad en citas'],
            'Premium', const Color(0xFF808080)),

        // Plan VIP Anual
        _planCard('Plan VIP Anual', 'S/790', '/año',
            'Todo incluido · Ahorra S/278',
            ['✅ Todo del plan Premium', '✅ Kit de productos de bienvenida', '✅ 25% descuento permanente', '✅ Barbero personal asignado'],
            'VIP Anual', C.gold),
      ],
    );
  }

  Widget _planCard(String nombre, String precio, String periodo, String subtitulo,
      List<String> items, String planKey, Color borderColor) {
    final activo = (DB.usuarios().where((x) => x.id == _u.id).firstOrNull ?? _u).membresia == planKey;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: C.dark2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: activo ? C.gold : borderColor, width: activo ? 2 : 1),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(nombre,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(text: precio,
                        style: const TextStyle(color: C.gold, fontSize: 22, fontWeight: FontWeight.bold)),
                    TextSpan(text: periodo,
                        style: const TextStyle(color: C.textMuted, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitulo, style: const TextStyle(color: C.textMuted, fontSize: 12)),
          const SizedBox(height: 14),
          ...items.map((i) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(i, style: const TextStyle(fontSize: 13, color: C.textPrimary)),
          )),
          const SizedBox(height: 14),
          activo
              ? Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: C.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: C.success),
                  ),
                  child: const Text('✅ Plan activo',
                      style: TextStyle(color: C.success, fontWeight: FontWeight.bold)),
                )
              : ElevatedButton(
                  onPressed: () => _activar(planKey),
                  child: Text('Activar $nombre'),
                ),
        ],
      ),
    );
  }
}

// ── TAB: PERFIL ───────────────────────────────────
class _ClientePerfilTab extends StatefulWidget {
  final Usuario usuario;
  final VoidCallback onRefresh;
  const _ClientePerfilTab({required this.usuario, required this.onRefresh});

  @override
  State<_ClientePerfilTab> createState() => _ClientePerfilTabState();
}

class _ClientePerfilTabState extends State<_ClientePerfilTab> {
  late TextEditingController _nomCtrl;
  late TextEditingController _emailCtrl;
  final _passCtrl  = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  bool _verPass = false;

  @override
  void initState() {
    super.initState();
    final u = widget.usuario;
    _nomCtrl   = TextEditingController(text: u.nombre);
    _emailCtrl = TextEditingController(text: u.email ?? '');
  }

  @override
  void dispose() {
    _nomCtrl.dispose(); _emailCtrl.dispose();
    _passCtrl.dispose(); _pass2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final u = widget.usuario;
    u.nombre = _nomCtrl.text.trim().isEmpty ? u.nombre : _nomCtrl.text.trim();
    u.email  = _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim();
    await DB.actualizarUsuario(u);
    widget.onRefresh();
    if (mounted) _snack(context, 'Perfil actualizado ✓');
  }

  Future<void> _cambiarClave() async {
    if (_passCtrl.text.length < 6) {
      _snack(context, 'Mínimo 6 caracteres', error: true); return;
    }
    if (_passCtrl.text != _pass2Ctrl.text) {
      _snack(context, 'Las claves no coinciden', error: true); return;
    }
    // En producción: usar bcrypt. Aquí re-usamos el mismo hash
    final raw = DB._raw();
    final list = raw['usuarios'] as List;
    final idx = list.indexWhere((u) => (u as Map)['id'] == widget.usuario.id);
    if (idx != -1) {
      // ignore: invalid_use_of_visible_for_testing_member
      (list[idx] as Map<String, dynamic>)['passwordHash'] =
          DB._hash(_passCtrl.text.trim());
    }
    await DB._save(raw);
    _passCtrl.clear(); _pass2Ctrl.clear();
    if (mounted) _snack(context, 'Clave actualizada ✓');
  }

  Future<void> _logout() async {
    await Session.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.usuario;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Avatar
        _GoldCard(
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: C.gold,
                child: Text(u.iniciales,
                    style: const TextStyle(color: C.black, fontSize: 28, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              Text(u.nombre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('+51 ${u.celular}', style: const TextStyle(color: C.textMuted, fontSize: 13)),
              if (u.email != null && u.email!.isNotEmpty)
                Text(u.email!, style: const TextStyle(color: C.textDim, fontSize: 12)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: u.esVIP ? C.gold.withValues(alpha: 0.12) : C.dark3,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: u.esVIP ? C.border : C.textDim),
                ),
                child: Text(
                  u.membresia != 'Ninguna' ? '👑 ${u.membresia}' : 'Sin membresía',
                  style: TextStyle(
                      color: u.esVIP ? C.gold : C.textMuted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        // Editar perfil
        _GoldCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('EDITAR PERFIL',
                  style: TextStyle(color: C.textMuted, fontSize: 12, letterSpacing: 1)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nomCtrl,
                style: const TextStyle(color: C.textPrimary),
                decoration: const InputDecoration(labelText: 'Nombre completo'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: C.textPrimary),
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _guardar, child: const Text('Guardar cambios')),
            ],
          ),
        ),

        // Cambiar clave
        _GoldCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CAMBIAR CLAVE',
                  style: TextStyle(color: C.textMuted, fontSize: 12, letterSpacing: 1)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passCtrl,
                obscureText: !_verPass,
                style: const TextStyle(color: C.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Nueva clave',
                  suffixIcon: IconButton(
                    icon: Icon(_verPass ? Icons.visibility_off : Icons.visibility, color: C.textMuted),
                    onPressed: () => setState(() => _verPass = !_verPass),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pass2Ctrl,
                obscureText: !_verPass,
                style: const TextStyle(color: C.textPrimary),
                decoration: const InputDecoration(labelText: 'Confirmar nueva clave'),
              ),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _cambiarClave, child: const Text('Actualizar clave')),
            ],
          ),
        ),

        // Logout
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout, color: C.danger),
          label: const Text('Cerrar sesión', style: TextStyle(color: C.danger)),
          style: OutlinedButton.styleFrom(
              side: const BorderSide(color: C.danger),
              minimumSize: const Size(double.infinity, 52)),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════
// RESERVAR CITA — DIALOG
// ══════════════════════════════════════════════════
class _ReservarCitaDialog extends StatefulWidget {
  final Usuario usuario;
  final VoidCallback onSuccess;
  const _ReservarCitaDialog({required this.usuario, required this.onSuccess});

  @override
  State<_ReservarCitaDialog> createState() => _ReservarCitaDialogState();
}

class _ReservarCitaDialogState extends State<_ReservarCitaDialog> {
  List<Servicio> _servicios = [];
  Servicio? _svcSel;
  DateTime _fecha = DateTime.now();
  String? _horaSel;
  final _notasCtrl = TextEditingController();

  final _horas = [
    '09:00','09:30','10:00','10:30','11:00','11:30',
    '12:00','14:00','14:30','15:00','15:30','16:00','16:30','17:00','17:30','18:00',
  ];

  @override
  void initState() {
    super.initState();
    _servicios = DB.servicios(soloActivos: true);
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    if (_svcSel == null) { _snack(context, 'Selecciona un servicio', error: true); return; }
    if (_horaSel == null) { _snack(context, 'Selecciona un horario', error: true); return; }

    final fechaStr = _fecha.toIso8601String().split('T')[0];
    if (DB.horarioOcupado(fechaStr, _horaSel!)) {
      _snack(context, 'Horario no disponible', error: true); return;
    }

    final cita = Cita(
      id: DB.genId('CIT'),
      clienteId: widget.usuario.id,
      clienteNombre: widget.usuario.nombre,
      clienteCelular: widget.usuario.celular,
      servicioId: _svcSel!.id,
      servicioNombre: _svcSel!.nombre,
      fecha: fechaStr,
      hora: _horaSel!,
      estado: 'pendiente',
      precio: _svcSel!.precio,
      notas: _notasCtrl.text.trim(),
    );
    await DB.agregarCita(cita);
    if (!mounted) return;
    Navigator.pop(context);
    widget.onSuccess();
    _snack(context, '¡Cita reservada con éxito! 📅');
  }

  @override
  Widget build(BuildContext context) {
    final fechaStr = _fecha.toIso8601String().split('T')[0];
    return Dialog(
      backgroundColor: C.dark2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: C.border)),
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Reservar Cita',
                    style: TextStyle(color: C.gold, fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: C.textMuted)),
              ],
            ),
            const SizedBox(height: 16),

            const Text('SERVICIO', style: TextStyle(color: C.textMuted, fontSize: 11, letterSpacing: 1)),
            const SizedBox(height: 8),
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _servicios.length,
                itemBuilder: (_, i) {
                  final s = _servicios[i];
                  final sel = _svcSel?.id == s.id;
                  return GestureDetector(
                    onTap: () => setState(() => _svcSel = s),
                    child: Container(
                      width: 90,
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: C.dark3,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: sel ? C.gold : C.border, width: sel ? 2 : 1),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(s.icono, style: const TextStyle(fontSize: 22)),
                          const SizedBox(height: 4),
                          Text(s.nombre,
                              style: TextStyle(fontSize: 11, color: sel ? C.gold : C.textPrimary),
                              textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('S/${s.precio.toInt()}',
                              style: const TextStyle(color: C.gold, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            const Text('FECHA', style: TextStyle(color: C.textMuted, fontSize: 11, letterSpacing: 1)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _fecha,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 60)),
                  builder: (ctx, child) => Theme(
                    data: ThemeData.dark().copyWith(
                        colorScheme: const ColorScheme.dark(primary: C.gold)),
                    child: child!,
                  ),
                );
                if (d != null) setState(() { _fecha = d; _horaSel = null; });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: C.dark3,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: C.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: C.textMuted),
                    const SizedBox(width: 10),
                    Text(DB.formatFecha(fechaStr),
                        style: const TextStyle(color: C.textPrimary, fontSize: 14)),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down, color: C.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text('HORARIO', style: TextStyle(color: C.textMuted, fontSize: 11, letterSpacing: 1)),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.8,
              ),
              itemCount: _horas.length,
              itemBuilder: (_, i) {
                final h = _horas[i];
                final ocupado = DB.horarioOcupado(fechaStr, h);
                final sel = _horaSel == h;
                return GestureDetector(
                  onTap: ocupado ? null : () => setState(() => _horaSel = h),
                  child: Container(
                    decoration: BoxDecoration(
                      color: sel ? C.gold : C.dark3,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: ocupado ? C.danger.withValues(alpha: 0.4) : (sel ? C.gold : C.border),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(h,
                        style: TextStyle(
                          color: sel ? C.black : (ocupado ? C.danger : C.textPrimary),
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                        )),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            const Text('NOTAS (OPCIONAL)', style: TextStyle(color: C.textMuted, fontSize: 11, letterSpacing: 1)),
            const SizedBox(height: 8),
            TextField(
              controller: _notasCtrl,
              style: const TextStyle(color: C.textPrimary),
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'Indicaciones especiales...'),
            ),

            if (_svcSel != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: C.gold.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: C.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_svcSel!.nombre,
                        style: const TextStyle(color: C.textMuted, fontSize: 13)),
                    Text('S/ ${_svcSel!.precio.toStringAsFixed(0)}',
                        style: const TextStyle(color: C.gold, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _confirmar,
              child: const Text('✅ Confirmar reserva'),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// ADMIN — MAIN SCREEN
// ══════════════════════════════════════════════════
class AdminMainScreen extends StatefulWidget {
  final Usuario usuario;
  const AdminMainScreen({super.key, required this.usuario});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      _AdminDashboardTab(onRefresh: () => setState(() {})),
      _AdminCitasTab(onRefresh: () => setState(() {})),
      _AdminClientesTab(onRefresh: () => setState(() {})),
      _AdminServiciosTab(onRefresh: () => setState(() {})),
      _AdminPromocionesTab(onRefresh: () => setState(() {})),
      _AdminReportesTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('✂️ Admin — BarberPro'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: C.textMuted),
            onPressed: () async {
              await Session.clear();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
          ),
        ],
      ),
      body: screens[_tab],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined),   activeIcon: Icon(Icons.dashboard),    label: 'Panel'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), activeIcon: Icon(Icons.calendar_today), label: 'Citas'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline),       activeIcon: Icon(Icons.people),       label: 'Clientes'),
          BottomNavigationBarItem(icon: Icon(Icons.cut_outlined),         activeIcon: Icon(Icons.cut),          label: 'Servicios'),
          BottomNavigationBarItem(icon: Icon(Icons.local_offer_outlined), activeIcon: Icon(Icons.local_offer),  label: 'Promos'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined),   activeIcon: Icon(Icons.bar_chart),    label: 'Reportes'),
        ],
      ),
    );
  }
}

// ── ADMIN: DASHBOARD ──────────────────────────────
class _AdminDashboardTab extends StatefulWidget {
  final VoidCallback onRefresh;
  const _AdminDashboardTab({required this.onRefresh});

  @override
  State<_AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<_AdminDashboardTab> {
  void _reload() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final citasHoy = DB.citasHoy();
    final clientes = DB.usuarios().where((u) => u.rol == 'cliente').toList();
    final ingresosHoy = citasHoy
        .where((c) => c.estado == 'completada')
        .fold<double>(0, (s, c) => s + c.precio);
    final vip = clientes.where((c) => c.esVIP).length;

    return RefreshIndicator(
      color: C.gold,
      onRefresh: () async => _reload(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stats
          Row(children: [
            _StatCard(icon: '📅', value: citasHoy.length.toString(),  label: 'Citas hoy'),
            const SizedBox(width: 12),
            _StatCard(icon: '👥', value: clientes.length.toString(),  label: 'Clientes'),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _StatCard(icon: '💰', value: 'S/${ingresosHoy.toInt()}',  label: 'Ingresos hoy'),
            const SizedBox(width: 12),
            _StatCard(icon: '👑', value: vip.toString(),              label: 'VIP activos'),
          ]),
          const SizedBox(height: 20),

          // Citas de hoy
          const Text('CITAS DE HOY',
              style: TextStyle(color: C.gold, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (citasHoy.isEmpty)
            const _GoldCard(child: Center(child: Text('Sin citas para hoy', style: TextStyle(color: C.textMuted))))
          else
            ...citasHoy.map((c) => _GoldCard(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: C.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(c.hora,
                        style: const TextStyle(color: C.gold, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.clienteNombre,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('${c.servicioNombre} · S/${c.precio.toInt()}',
                            style: const TextStyle(color: C.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _EstadoBadge(c.estado),
                      if (c.estado == 'pendiente' || c.estado == 'confirmada') ...[
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () async {
                            await DB.completarCita(c.id);
                            _reload();
                            if (mounted) _snack(context, '✓ Servicio completado · Puntos sumados');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: C.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: C.success),
                            ),
                            child: const Text('✓ Completar',
                                style: TextStyle(color: C.success, fontSize: 11)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            )),

          const SizedBox(height: 20),
          const Text('ACCIONES RÁPIDAS',
              style: TextStyle(color: C.gold, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Escanear QR / Registrar servicio'),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => _RegistrarQRDialog(onSuccess: _reload),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Crear cita manual'),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => _NuevaCitaAdminDialog(onSuccess: _reload),
            ),
          ),
        ],
      ),
    );
  }
}

// ── ADMIN: CITAS ──────────────────────────────────
class _AdminCitasTab extends StatefulWidget {
  final VoidCallback onRefresh;
  const _AdminCitasTab({required this.onRefresh});

  @override
  State<_AdminCitasTab> createState() => _AdminCitasTabState();
}

class _AdminCitasTabState extends State<_AdminCitasTab> {
  String _filtro = '';

  List<Cita> get _lista {
    final all = DB.citas(estado: _filtro.isEmpty ? null : _filtro);
    return all;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _filtro.isEmpty ? '' : _filtro,
                  dropdownColor: C.dark3,
                  style: const TextStyle(color: C.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Filtrar por estado',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Todas')),
                    DropdownMenuItem(value: 'pendiente', child: Text('Pendientes')),
                    DropdownMenuItem(value: 'confirmada', child: Text('Confirmadas')),
                    DropdownMenuItem(value: 'completada', child: Text('Completadas')),
                    DropdownMenuItem(value: 'cancelada', child: Text('Canceladas')),
                  ],
                  onChanged: (v) => setState(() => _filtro = v ?? ''),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(50, 48), padding: EdgeInsets.zero),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => _NuevaCitaAdminDialog(
                      onSuccess: () => setState(() {})),
                ),
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        Expanded(
          child: _lista.isEmpty
              ? const Center(child: Text('Sin citas', style: TextStyle(color: C.textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _lista.length,
                  itemBuilder: (_, i) {
                    final c = _lista[i];
                    return _GoldCard(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c.clienteNombre,
                                        style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text(c.servicioNombre,
                                        style: const TextStyle(color: C.textMuted, fontSize: 13)),
                                    Text('${DB.formatFecha(c.fecha)} · ${c.hora}',
                                        style: const TextStyle(color: C.gold, fontSize: 12)),
                                  ],
                                ),
                              ),
                              _EstadoBadge(c.estado),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('S/ ${c.precio.toInt()}',
                                  style: const TextStyle(color: C.gold, fontWeight: FontWeight.bold)),
                              Wrap(
                                spacing: 6,
                                children: [
                                  if (c.estado == 'pendiente')
                                    _accionBtn('Confirmar', C.gold, () async {
                                      await DB.cambiarEstadoCita(c.id, 'confirmada');
                                      setState(() {});
                                    }),
                                  if (c.estado == 'confirmada')
                                    _accionBtn('Completar', C.success, () async {
                                      await DB.completarCita(c.id);
                                      setState(() {});
                                      if (mounted) _snack(context, 'Completada · Puntos sumados');
                                    }),
                                  if (c.estado == 'pendiente')
                                    _accionBtn('Completar', C.success, () async {
                                      await DB.completarCita(c.id);
                                      setState(() {});
                                      if (mounted) _snack(context, 'Completada · Puntos sumados');
                                    }),
                                  if (c.estado != 'cancelada' && c.estado != 'completada')
                                    _accionBtn('Cancelar', C.danger, () async {
                                      await DB.cambiarEstadoCita(c.id, 'cancelada');
                                      setState(() {});
                                    }),
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
      ],
    );
  }

  Widget _accionBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ── ADMIN: CLIENTES ───────────────────────────────
class _AdminClientesTab extends StatefulWidget {
  final VoidCallback onRefresh;
  const _AdminClientesTab({required this.onRefresh});

  @override
  State<_AdminClientesTab> createState() => _AdminClientesTabState();
}

class _AdminClientesTabState extends State<_AdminClientesTab> {
  String _q = '';

  List<Usuario> get _lista {
    final todos = DB.usuarios().where((u) => u.rol == 'cliente').toList();
    if (_q.isEmpty) return todos;
    return todos.where((u) =>
        u.nombre.toLowerCase().contains(_q.toLowerCase()) ||
        u.celular.contains(_q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  style: const TextStyle(color: C.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Buscar por nombre o celular...',
                    prefixIcon: Icon(Icons.search, color: C.textMuted),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _q = v),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(50, 48), padding: EdgeInsets.zero),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => _NuevoClienteDialog(onSuccess: () => setState(() {})),
                ),
                child: const Icon(Icons.person_add),
              ),
            ],
          ),
        ),
        Expanded(
          child: _lista.isEmpty
              ? const Center(child: Text('Sin clientes', style: TextStyle(color: C.textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _lista.length,
                  itemBuilder: (_, i) {
                    final u = _lista[i];
                    return _GoldCard(
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: C.gold,
                            child: Text(u.iniciales,
                                style: const TextStyle(color: C.black, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(u.nombre,
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text('+51 ${u.celular}',
                                    style: const TextStyle(color: C.textMuted, fontSize: 12)),
                                if (u.email != null)
                                  Text(u.email!,
                                      style: const TextStyle(color: C.textDim, fontSize: 11)),
                                const SizedBox(height: 4),
                                Wrap(spacing: 6, children: [
                                  _chipBadge(
                                    u.membresia != 'Ninguna' ? '👑 ${u.membresia}' : 'Sin membresía',
                                    u.esVIP ? C.gold : C.textMuted,
                                  ),
                                  _chipBadge('⭐ ${u.puntos} pts', C.info),
                                ]),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: C.danger),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  backgroundColor: C.dark2,
                                  title: const Text('Eliminar cliente',
                                      style: TextStyle(color: C.gold)),
                                  content: const Text('¿Confirmas la eliminación?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false),
                                        child: const Text('No')),
                                    TextButton(onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Sí', style: TextStyle(color: C.danger))),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                await DB.eliminarUsuario(u.id);
                                setState(() {});
                                if (mounted) _snack(context, 'Cliente eliminado', error: true);
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _chipBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10)),
    );
  }
}

// ── ADMIN: SERVICIOS ──────────────────────────────
class _AdminServiciosTab extends StatefulWidget {
  final VoidCallback onRefresh;
  const _AdminServiciosTab({required this.onRefresh});

  @override
  State<_AdminServiciosTab> createState() => _AdminServiciosTabState();
}

class _AdminServiciosTabState extends State<_AdminServiciosTab> {
  @override
  Widget build(BuildContext context) {
    final lista = DB.servicios();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Nuevo Servicio'),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => _NuevoServicioDialog(onSuccess: () => setState(() {})),
            ),
          ),
        ),
        Expanded(
          child: lista.isEmpty
              ? const Center(child: Text('Sin servicios', style: TextStyle(color: C.textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: lista.length,
                  itemBuilder: (_, i) {
                    final s = lista[i];
                    return _GoldCard(
                      child: Row(
                        children: [
                          Text(s.icono, style: const TextStyle(fontSize: 32)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.nombre,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                Text(s.descripcion,
                                    style: const TextStyle(color: C.textMuted, fontSize: 12)),
                                const SizedBox(height: 6),
                                Wrap(spacing: 6, children: [
                                  _badge('S/${s.precio.toInt()}', C.gold),
                                  _badge('⏱ ${s.duracion}min', C.textMuted),
                                  _badge('⭐ ${s.puntos}pts', C.info),
                                ]),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: C.danger),
                            onPressed: () async {
                              await DB.eliminarServicio(s.id);
                              setState(() {});
                              if (mounted) _snack(context, 'Servicio eliminado', error: true);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}

// ── ADMIN: PROMOCIONES ────────────────────────────
class _AdminPromocionesTab extends StatefulWidget {
  final VoidCallback onRefresh;
  const _AdminPromocionesTab({required this.onRefresh});

  @override
  State<_AdminPromocionesTab> createState() => _AdminPromocionesTabState();
}

class _AdminPromocionesTabState extends State<_AdminPromocionesTab> {
  @override
  Widget build(BuildContext context) {
    final lista = DB.promociones();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Nueva Promoción'),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => _NuevaPromoDialog(onSuccess: () => setState(() {})),
            ),
          ),
        ),
        Expanded(
          child: lista.isEmpty
              ? const Center(child: Text('Sin promociones', style: TextStyle(color: C.textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: lista.length,
                  itemBuilder: (_, i) {
                    final p = lista[i];
                    return _GoldCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: C.gold.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('${p.descuento}%',
                                    style: const TextStyle(
                                        color: C.gold, fontWeight: FontWeight.bold, fontSize: 20)),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.titulo,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    Text(p.descripcion,
                                        style: const TextStyle(color: C.textMuted, fontSize: 12)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: C.danger),
                                onPressed: () async {
                                  await DB.eliminarPromocion(p.id);
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 12, color: C.textMuted),
                              const SizedBox(width: 6),
                              Text('Válido hasta: ${DB.formatFecha(p.hasta)}',
                                  style: const TextStyle(color: C.textDim, fontSize: 12)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (p.activa ? C.success : C.textMuted).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(p.activa ? 'Activa' : 'Inactiva',
                                    style: TextStyle(
                                        color: p.activa ? C.success : C.textMuted, fontSize: 11)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ── ADMIN: REPORTES ───────────────────────────────
class _AdminReportesTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final todasCitas = DB.citas();
    final completadas = todasCitas.where((c) => c.estado == 'completada').toList();
    final canceladas  = todasCitas.where((c) => c.estado == 'cancelada').length;
    final ingresos = completadas.fold<double>(0, (s, c) => s + c.precio);

    final Map<String, int> conteo = {};
    for (final c in completadas) {
      conteo[c.servicioNombre] = (conteo[c.servicioNombre] ?? 0) + 1;
    }
    final sorted = conteo.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = sorted.isEmpty ? 1 : sorted.first.value;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Reportes',
            style: TextStyle(color: C.gold, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(children: [
          _StatCard(icon: '📊', value: todasCitas.length.toString(), label: 'Total citas'),
          const SizedBox(width: 12),
          _StatCard(icon: '💰', value: 'S/${ingresos.toInt()}', label: 'Ingresos totales'),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _StatCard(icon: '✅', value: completadas.length.toString(), label: 'Completadas'),
          const SizedBox(width: 12),
          _StatCard(icon: '❌', value: canceladas.toString(), label: 'Canceladas'),
        ]),
        const SizedBox(height: 20),
        _GoldCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('SERVICIOS MÁS POPULARES',
                  style: TextStyle(color: C.textMuted, fontSize: 12, letterSpacing: 1)),
              const SizedBox(height: 16),
              if (sorted.isEmpty)
                const Center(child: Text('Sin datos aún', style: TextStyle(color: C.textMuted)))
              else
                ...sorted.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(e.key, style: const TextStyle(fontSize: 13))),
                          Text('${e.value}',
                              style: const TextStyle(color: C.gold, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          value: e.value / maxVal,
                          minHeight: 6,
                          backgroundColor: C.dark3,
                          valueColor: const AlwaysStoppedAnimation<Color>(C.gold),
                        ),
                      ),
                    ],
                  ),
                )),
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════
// DIALOGS DE ADMIN
// ══════════════════════════════════════════════════

// Registrar QR / Sumar puntos manualmente
class _RegistrarQRDialog extends StatefulWidget {
  final VoidCallback onSuccess;
  const _RegistrarQRDialog({required this.onSuccess});

  @override
  State<_RegistrarQRDialog> createState() => _RegistrarQRDialogState();
}

class _RegistrarQRDialogState extends State<_RegistrarQRDialog> {
  final _celCtrl = TextEditingController();
  Usuario? _clienteEncontrado;
  Servicio? _svcSel;

  @override
  void dispose() {
    _celCtrl.dispose();
    super.dispose();
  }

  void _buscar() {
    final cel = _celCtrl.text.trim();
    final found = DB.usuarios()
        .where((u) => u.celular == cel && u.rol == 'cliente')
        .firstOrNull;
    setState(() => _clienteEncontrado = found);
  }

  Future<void> _registrar() async {
    if (_clienteEncontrado == null) {
      _snack(context, 'Cliente no encontrado', error: true); return;
    }
    if (_svcSel == null) {
      _snack(context, 'Selecciona un servicio', error: true); return;
    }
    await DB.agregarPuntos(
        _clienteEncontrado!.id, _svcSel!.puntos, _svcSel!.nombre);
    if (!mounted) return;
    Navigator.pop(context);
    widget.onSuccess();
    _snack(context, '+${_svcSel!.puntos} pts sumados a ${_clienteEncontrado!.nombre} ⭐');
  }

  @override
  Widget build(BuildContext context) {
    final servicios = DB.servicios(soloActivos: true);
    return Dialog(
      backgroundColor: C.dark2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), side: const BorderSide(color: C.border)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Registrar Servicio por QR',
                    style: TextStyle(color: C.gold, fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: C.textMuted)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _celCtrl,
                    keyboardType: TextInputType.phone,
                    maxLength: 9,
                    style: const TextStyle(color: C.textPrimary),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Celular del cliente',
                      counterText: '',
                      prefixIcon: Icon(Icons.phone_android, color: C.textMuted),
                    ),
                    onChanged: (_) => _buscar(),
                  ),
                ),
              ],
            ),
            if (_clienteEncontrado != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: C.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: C.success.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: C.gold, radius: 20,
                      child: Text(_clienteEncontrado!.iniciales,
                          style: const TextStyle(color: C.black, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_clienteEncontrado!.nombre,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('⭐ ${_clienteEncontrado!.puntos} pts · ${_clienteEncontrado!.membresia}',
                            style: const TextStyle(color: C.textMuted, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('SERVICIO REALIZADO',
                  style: TextStyle(color: C.textMuted, fontSize: 11, letterSpacing: 1)),
              const SizedBox(height: 8),
              DropdownButtonFormField<Servicio>(
                value: _svcSel,
                dropdownColor: C.dark3,
                style: const TextStyle(color: C.textPrimary),
                hint: const Text('Selecciona un servicio',
                    style: TextStyle(color: C.textMuted)),
                decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                items: servicios.map((s) => DropdownMenuItem(
                  value: s,
                  child: Text('${s.icono} ${s.nombre} · +${s.puntos}pts'),
                )).toList(),
                onChanged: (v) => setState(() => _svcSel = v),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _registrar,
                child: const Text('✅ Registrar y sumar puntos'),
              ),
            ] else if (_celCtrl.text.length == 9) ...[
              const SizedBox(height: 12),
              const Text('Cliente no encontrado',
                  style: TextStyle(color: C.danger, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
}

// Nueva cita (admin)
class _NuevaCitaAdminDialog extends StatefulWidget {
  final VoidCallback onSuccess;
  const _NuevaCitaAdminDialog({required this.onSuccess});

  @override
  State<_NuevaCitaAdminDialog> createState() => _NuevaCitaAdminDialogState();
}

class _NuevaCitaAdminDialogState extends State<_NuevaCitaAdminDialog> {
  final _horas = ['09:00','09:30','10:00','10:30','11:00','11:30',
      '12:00','14:00','14:30','15:00','15:30','16:00','16:30','17:00','17:30','18:00'];

  Usuario? _cliSel;
  Servicio? _svcSel;
  DateTime _fecha = DateTime.now();
  String _hora = '09:00';
  String _estado = 'pendiente';

  @override
  Widget build(BuildContext context) {
    final clientes = DB.usuarios().where((u) => u.rol == 'cliente').toList();
    final servicios = DB.servicios(soloActivos: true);

    return Dialog(
      backgroundColor: C.dark2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), side: const BorderSide(color: C.border)),
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Nueva Cita',
                    style: TextStyle(color: C.gold, fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: C.textMuted)),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Usuario>(
              value: _cliSel,
              dropdownColor: C.dark3,
              style: const TextStyle(color: C.textPrimary),
              hint: const Text('Selecciona cliente', style: TextStyle(color: C.textMuted)),
              decoration: const InputDecoration(labelText: 'Cliente'),
              items: clientes.map((c) => DropdownMenuItem(
                value: c, child: Text(c.nombre),
              )).toList(),
              onChanged: (v) => setState(() => _cliSel = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Servicio>(
              value: _svcSel,
              dropdownColor: C.dark3,
              style: const TextStyle(color: C.textPrimary),
              hint: const Text('Selecciona servicio', style: TextStyle(color: C.textMuted)),
              decoration: const InputDecoration(labelText: 'Servicio'),
              items: servicios.map((s) => DropdownMenuItem(
                value: s, child: Text('${s.nombre} · S/${s.precio.toInt()}'),
              )).toList(),
              onChanged: (v) => setState(() => _svcSel = v),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _fecha,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 60)),
                  builder: (ctx, child) => Theme(
                    data: ThemeData.dark().copyWith(
                        colorScheme: const ColorScheme.dark(primary: C.gold)),
                    child: child!,
                  ),
                );
                if (d != null) setState(() => _fecha = d);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Fecha'),
                child: Text(DB.formatFecha(_fecha.toIso8601String().split('T')[0]),
                    style: const TextStyle(color: C.textPrimary)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _hora,
              dropdownColor: C.dark3,
              style: const TextStyle(color: C.textPrimary),
              decoration: const InputDecoration(labelText: 'Hora'),
              items: _horas.map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
              onChanged: (v) => setState(() => _hora = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _estado,
              dropdownColor: C.dark3,
              style: const TextStyle(color: C.textPrimary),
              decoration: const InputDecoration(labelText: 'Estado'),
              items: const [
                DropdownMenuItem(value: 'pendiente', child: Text('Pendiente')),
                DropdownMenuItem(value: 'confirmada', child: Text('Confirmada')),
              ],
              onChanged: (v) => setState(() => _estado = v!),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (_cliSel == null || _svcSel == null) {
                  _snack(context, 'Completa todos los campos', error: true); return;
                }
                final cita = Cita(
                  id: DB.genId('CIT'),
                  clienteId: _cliSel!.id,
                  clienteNombre: _cliSel!.nombre,
                  clienteCelular: _cliSel!.celular,
                  servicioId: _svcSel!.id,
                  servicioNombre: _svcSel!.nombre,
                  fecha: _fecha.toIso8601String().split('T')[0],
                  hora: _hora,
                  estado: _estado,
                  precio: _svcSel!.precio,
                );
                await DB.agregarCita(cita);
                if (!mounted) return;
                Navigator.pop(context);
                widget.onSuccess();
                _snack(context, 'Cita creada ✓');
              },
              child: const Text('✅ Crear cita'),
            ),
          ],
        ),
      ),
    );
  }
}

// Nuevo cliente (admin)
class _NuevoClienteDialog extends StatefulWidget {
  final VoidCallback onSuccess;
  const _NuevoClienteDialog({required this.onSuccess});

  @override
  State<_NuevoClienteDialog> createState() => _NuevoClienteDialogState();
}

class _NuevoClienteDialogState extends State<_NuevoClienteDialog> {
  final _formKey   = GlobalKey<FormState>();
  final _nomCtrl   = TextEditingController();
  final _celCtrl   = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  String _membresia = 'Ninguna';

  @override
  void dispose() {
    _nomCtrl.dispose(); _celCtrl.dispose();
    _emailCtrl.dispose(); _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: C.dark2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), side: const BorderSide(color: C.border)),
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Nuevo Cliente',
                      style: TextStyle(color: C.gold, fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: C.textMuted)),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nomCtrl,
                style: const TextStyle(color: C.textPrimary),
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre completo'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _celCtrl,
                keyboardType: TextInputType.phone,
                maxLength: 9,
                style: const TextStyle(color: C.textPrimary),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Celular', counterText: ''),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  if (v.length != 9) return '9 dígitos';
                  if (!v.startsWith('9')) return 'Empieza con 9';
                  if (DB.celularExiste(v)) return 'Ya registrado';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: C.textPrimary),
                decoration: const InputDecoration(labelText: 'Email (opcional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passCtrl,
                obscureText: true,
                style: const TextStyle(color: C.textPrimary),
                decoration: const InputDecoration(labelText: 'Clave de acceso'),
                validator: (v) => (v == null || v.length < 4) ? 'Mínimo 4 caracteres' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _membresia,
                dropdownColor: C.dark3,
                style: const TextStyle(color: C.textPrimary),
                decoration: const InputDecoration(labelText: 'Membresía inicial'),
                items: ['Ninguna','Básico','Premium','VIP Anual'].map((m) =>
                    DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) => setState(() => _membresia = v!),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  final u = await DB.registrar(
                    nombre: _nomCtrl.text.trim(),
                    celular: _celCtrl.text.trim(),
                    password: _passCtrl.text.trim(),
                    email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
                  );
                  u.membresia = _membresia;
                  await DB.actualizarUsuario(u);
                  if (!mounted) return;
                  Navigator.pop(context);
                  widget.onSuccess();
                  _snack(context, 'Cliente registrado ✓');
                },
                child: const Text('✅ Registrar cliente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Nuevo servicio
class _NuevoServicioDialog extends StatefulWidget {
  final VoidCallback onSuccess;
  const _NuevoServicioDialog({required this.onSuccess});

  @override
  State<_NuevoServicioDialog> createState() => _NuevoServicioDialogState();
}

class _NuevoServicioDialogState extends State<_NuevoServicioDialog> {
  final _formKey    = GlobalKey<FormState>();
  final _nomCtrl    = TextEditingController();
  final _descCtrl   = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _durCtrl    = TextEditingController();
  final _ptsCtrl    = TextEditingController();
  final _icoCtrl    = TextEditingController(text: '✂️');

  @override
  void dispose() {
    _nomCtrl.dispose(); _descCtrl.dispose(); _precioCtrl.dispose();
    _durCtrl.dispose(); _ptsCtrl.dispose(); _icoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: C.dark2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), side: const BorderSide(color: C.border)),
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Nuevo Servicio',
                      style: TextStyle(color: C.gold, fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: C.textMuted)),
                ],
              ),
              const SizedBox(height: 16),
              _field(_nomCtrl, 'Nombre del servicio'),
              _field(_descCtrl, 'Descripción'),
              _field(_precioCtrl, 'Precio (S/)', isNum: true),
              _field(_durCtrl, 'Duración (minutos)', isNum: true),
              _field(_ptsCtrl, 'Puntos que otorga', isNum: true),
              _field(_icoCtrl, 'Ícono (emoji)'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  final s = Servicio(
                    id: DB.genId('SVC'),
                    nombre: _nomCtrl.text.trim(),
                    descripcion: _descCtrl.text.trim(),
                    precio: double.tryParse(_precioCtrl.text) ?? 0,
                    duracion: int.tryParse(_durCtrl.text) ?? 30,
                    puntos: int.tryParse(_ptsCtrl.text) ?? 5,
                    icono: _icoCtrl.text.trim().isEmpty ? '✂️' : _icoCtrl.text.trim(),
                  );
                  await DB.agregarServicio(s);
                  if (!mounted) return;
                  Navigator.pop(context);
                  widget.onSuccess();
                  _snack(context, 'Servicio creado ✓');
                },
                child: const Text('✅ Guardar servicio'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {bool isNum = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        style: const TextStyle(color: C.textPrimary),
        decoration: InputDecoration(labelText: label),
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
      ),
    );
  }
}

// Nueva promoción
class _NuevaPromoDialog extends StatefulWidget {
  final VoidCallback onSuccess;
  const _NuevaPromoDialog({required this.onSuccess});

  @override
  State<_NuevaPromoDialog> createState() => _NuevaPromoDialogState();
}

class _NuevaPromoDialogState extends State<_NuevaPromoDialog> {
  final _formKey   = GlobalKey<FormState>();
  final _titCtrl   = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _descPCtrl = TextEditingController();
  DateTime _hasta  = DateTime.now().add(const Duration(days: 30));

  @override
  void dispose() {
    _titCtrl.dispose(); _descCtrl.dispose(); _descPCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: C.dark2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), side: const BorderSide(color: C.border)),
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Nueva Promoción',
                      style: TextStyle(color: C.gold, fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: C.textMuted)),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titCtrl,
                style: const TextStyle(color: C.textPrimary),
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                style: const TextStyle(color: C.textPrimary),
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Descripción'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descPCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: C.textPrimary),
                decoration: const InputDecoration(labelText: 'Descuento (%)'),
                validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _hasta,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (ctx, child) => Theme(
                      data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(primary: C.gold)),
                      child: child!,
                    ),
                  );
                  if (d != null) setState(() => _hasta = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Válida hasta'),
                  child: Text(DB.formatFecha(_hasta.toIso8601String().split('T')[0]),
                      style: const TextStyle(color: C.textPrimary)),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  final p = Promocion(
                    id: DB.genId('PRO'),
                    titulo: _titCtrl.text.trim(),
                    descripcion: _descCtrl.text.trim(),
                    descuento: int.tryParse(_descPCtrl.text) ?? 0,
                    hasta: _hasta.toIso8601String().split('T')[0],
                  );
                  await DB.agregarPromocion(p);
                  if (!mounted) return;
                  Navigator.pop(context);
                  widget.onSuccess();
                  _snack(context, 'Promoción publicada ✓');
                },
                child: const Text('✅ Publicar promoción'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// EXTENSIÓN INTERNA (acceso controlado al DB)
// ══════════════════════════════════════════════════
extension _DBInternal on DB {
  static Map<String, dynamic> _raw() => DB._raw();
  static Future<void> _save(Map<String, dynamic> data) => DB._save(data);
  static String _hash(String p) => DB._hash(p);
}
