// ╔══════════════════════════════════════════════════════════════╗
// ║  DOMÓTICA PRO  v3.0  —  Producción / Flutter 3.41+ / Dart 3 ║
// ║  Fix HTTP LAN, cleartext, rutas firmware, UI habitaciones    ║
// ╚══════════════════════════════════════════════════════════════╝

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ───────────────────────────────────────────────────────────────
// Colores y diseño
// ───────────────────────────────────────────────────────────────
class C {
  static const bg          = Color(0xFF070B14);
  static const surface     = Color(0xFF0D1220);
  static const card        = Color(0xFF131A2E);
  static const cardHi      = Color(0xFF1A2340);
  static const border      = Color(0xFF1E2845);
  static const blue        = Color(0xFF4F8EF7);
  static const blueGlow    = Color(0x264F8EF7);
  static const green       = Color(0xFF2ECC8E);
  static const greenGlow   = Color(0x262ECC8E);
  static const orange      = Color(0xFFFF9142);
  static const orangeGlow  = Color(0x26FF9142);
  static const red         = Color(0xFFFF4D6A);
  static const redGlow     = Color(0x26FF4D6A);
  static const purple      = Color(0xFF9B6DFF);
  static const purpleGlow  = Color(0x269B6DFF);
  static const yellow      = Color(0xFFFFCC44);
  static const yellowGlow  = Color(0x26FFCC44);
  static const t1          = Color(0xFFF0F4FF);
  static const t2          = Color(0xFF7B8DB8);
  static const t3          = Color(0xFF3D4E78);
}

class R {
  static const xs = BorderRadius.all(Radius.circular(8));
  static const sm = BorderRadius.all(Radius.circular(12));
  static const md = BorderRadius.all(Radius.circular(18));
  static const lg = BorderRadius.all(Radius.circular(24));
  static const xl = BorderRadius.all(Radius.circular(32));
}

// ───────────────────────────────────────────────────────────────
// Enums: Tipo de firmware y categoría de artefacto
// ───────────────────────────────────────────────────────────────
enum TipoD { tasmota, sonoff, shelly, celular, otro }

extension TipoDX on TipoD {
  String get label => const {
    TipoD.tasmota: 'Tasmota',
    TipoD.sonoff : 'Sonoff',
    TipoD.shelly : 'Shelly',
    TipoD.celular: 'Celular',
    TipoD.otro   : 'Genérico',
  }[this]!;

  IconData get icon => const {
    TipoD.tasmota: Icons.electrical_services_rounded,
    TipoD.sonoff : Icons.bolt_rounded,
    TipoD.shelly : Icons.router_rounded,
    TipoD.celular: Icons.smartphone_rounded,
    TipoD.otro   : Icons.settings_input_hdmi_rounded,
  }[this]!;

  Color get color => const {
    TipoD.tasmota: C.blue,
    TipoD.sonoff : C.orange,
    TipoD.shelly : C.green,
    TipoD.celular: C.purple,
    TipoD.otro   : C.t2,
  }[this]!;

  static TipoD fromStr(String s) => TipoD.values
      .firstWhere((e) => e.name == s.toLowerCase(), orElse: () => TipoD.otro);
}

enum CatArtefacto { luz, ventilador, televisor, aire, enchufe, calefactor, otro }

extension CatX on CatArtefacto {
  String get label => const {
    CatArtefacto.luz       : 'Luz',
    CatArtefacto.ventilador: 'Ventilador',
    CatArtefacto.televisor : 'Televisor',
    CatArtefacto.aire      : 'A/C',
    CatArtefacto.enchufe   : 'Enchufe',
    CatArtefacto.calefactor: 'Calefactor',
    CatArtefacto.otro      : 'Otro',
  }[this]!;

  IconData get icon => const {
    CatArtefacto.luz       : Icons.light_rounded,
    CatArtefacto.ventilador: Icons.air_rounded,
    CatArtefacto.televisor : Icons.tv_rounded,
    CatArtefacto.aire      : Icons.ac_unit_rounded,
    CatArtefacto.enchufe   : Icons.power_rounded,
    CatArtefacto.calefactor: Icons.local_fire_department_rounded,
    CatArtefacto.otro      : Icons.device_unknown_rounded,
  }[this]!;

  Color get color => const {
    CatArtefacto.luz       : C.yellow,
    CatArtefacto.ventilador: C.blue,
    CatArtefacto.televisor : C.purple,
    CatArtefacto.aire      : C.blue,
    CatArtefacto.enchufe   : C.green,
    CatArtefacto.calefactor: C.orange,
    CatArtefacto.otro      : C.t2,
  }[this]!;

  static CatArtefacto fromStr(String s) => CatArtefacto.values
      .firstWhere((e) => e.name == s, orElse: () => CatArtefacto.otro);
}

// ───────────────────────────────────────────────────────────────
// Modelos: LogEntry y Dispositivo
// ───────────────────────────────────────────────────────────────
class LogEntry {
  final DateTime ts;
  final String   msg;
  final bool     ok;
  LogEntry(this.ts, this.msg, this.ok);
}

class Dispositivo {
  final int    id;
  String       nombre;
  TipoD        tipo;
  CatArtefacto cat;
  String       ip;
  int          puerto;
  String       habitacion;
  bool         encendido;
  DateTime?    ultimaAccion;
  int          toggleCount;

  Dispositivo({
    required this.id,
    required this.nombre,
    required this.tipo,
    this.cat        = CatArtefacto.enchufe,
    required this.ip,
    this.puerto      = 80,
    this.habitacion  = 'General',
    this.encendido   = false,
    this.ultimaAccion,
    this.toggleCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'nombre': nombre, 'tipo': tipo.name, 'cat': cat.name,
    'ip': ip, 'puerto': puerto, 'habitacion': habitacion,
    'encendido': encendido, 'toggleCount': toggleCount,
    'ultimaAccion': ultimaAccion?.toIso8601String(),
  };

  factory Dispositivo.fromJson(Map<String, dynamic> j) => Dispositivo(
    id:           j['id'],
    nombre:       j['nombre'],
    tipo:         TipoDX.fromStr(j['tipo'] ?? 'otro'),
    cat:          CatX.fromStr(j['cat'] ?? 'otro'),
    ip:           j['ip'],
    puerto:       j['puerto'] ?? 80,
    habitacion:   j['habitacion'] ?? 'General',
    encendido:    j['encendido'] ?? false,
    toggleCount:  j['toggleCount'] ?? 0,
    ultimaAccion: j['ultimaAccion'] != null ? DateTime.tryParse(j['ultimaAccion']) : null,
  );

  Dispositivo copyWith({bool? encendido, DateTime? ultimaAccion, int? toggleCount}) =>
      Dispositivo(
        id: id, nombre: nombre, tipo: tipo, cat: cat,
        ip: ip, puerto: puerto, habitacion: habitacion,
        encendido:    encendido    ?? this.encendido,
        ultimaAccion: ultimaAccion ?? this.ultimaAccion,
        toggleCount:  toggleCount  ?? this.toggleCount,
      );
}

// ───────────────────────────────────────────────────────────────
// Control de red (fix crítico: leer respuesta antes de cerrar)
// ───────────────────────────────────────────────────────────────
class NetCtrl {
  static Future<String> _get(
    String ip,
    int puerto,
    String path, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final socket = await Socket.connect(ip, puerto, timeout: timeout);
    try {
      socket.write(
        'GET $path HTTP/1.0\r\n'
        'Host: $ip\r\n'
        'User-Agent: DomoticaPro/3\r\n'
        'Connection: close\r\n'
        '\r\n',
      );
      await socket.flush();
      final buf = StringBuffer();
      await socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .timeout(timeout)
          .forEach(buf.write);
      return buf.toString();
    } finally {
      await socket.close();
    }
  }

  static String _rutaOn(TipoD t) => const {
    TipoD.tasmota: '/cm?cmnd=Power+On',
    TipoD.sonoff : '/control?cmd=on',
    TipoD.shelly : '/relay/0?turn=on',
    TipoD.celular: '/on',
    TipoD.otro   : '/on',
  }[t]!;

  static String _rutaOff(TipoD t) => const {
    TipoD.tasmota: '/cm?cmnd=Power+Off',
    TipoD.sonoff : '/control?cmd=off',
    TipoD.shelly : '/relay/0?turn=off',
    TipoD.celular: '/off',
    TipoD.otro   : '/off',
  }[t]!;

  static Future<bool> encender(Dispositivo d) async {
    try {
      await _get(d.ip, d.puerto, _rutaOn(d.tipo));
      return true;
    } catch (e) {
      debugPrint('[Net] encender ${d.ip} error: $e');
      return false;
    }
  }

  static Future<bool> apagar(Dispositivo d) async {
    try {
      await _get(d.ip, d.puerto, _rutaOff(d.tipo));
      return true;
    } catch (e) {
      debugPrint('[Net] apagar ${d.ip} error: $e');
      return false;
    }
  }

  static Future<bool> ping(String ip, int puerto, {Duration timeout = const Duration(seconds: 4)}) async {
    try {
      final s = await Socket.connect(ip, puerto, timeout: timeout);
      await s.close();
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ───────────────────────────────────────────────────────────────
// Repositorio y Notifier
// ───────────────────────────────────────────────────────────────
class DispositivoRepo {
  static const _k = 'domotica_v3';
  static List<Dispositivo> cargar(SharedPreferences p) {
    try {
      final raw = p.getString(_k);
      if (raw == null) return [];
      return (jsonDecode(raw) as List).map((e) => Dispositivo.fromJson(e)).toList();
    } catch (_) { return []; }
  }
  static void guardar(SharedPreferences p, List<Dispositivo> items) =>
      p.setString(_k, jsonEncode(items.map((d) => d.toJson()).toList()));
}

class DispositivosNotifier extends ChangeNotifier {
  final SharedPreferences _prefs;
  List<Dispositivo>   _items;
  int                 _nextId = 1;
  bool                _demo   = false;
  final List<LogEntry> _log   = [];

  DispositivosNotifier(List<Dispositivo> items, this._prefs)
      : _items = List.of(items) {
    if (_items.isNotEmpty) {
      _nextId = _items.map((d) => d.id).reduce((a, b) => a > b ? a : b) + 1;
    }
  }

  List<Dispositivo>  get items      => List.unmodifiable(_items);
  bool               get demo       => _demo;
  List<LogEntry>     get log        => List.unmodifiable(_log.reversed.toList());
  int                get encendidos => _items.where((d) => d.encendido).length;

  List<String> get habitaciones {
    final set = _items.map((d) => d.habitacion).toSet().toList()..sort();
    return ['Todas', ...set];
  }

  List<Dispositivo> porHabitacion(String h) =>
      h == 'Todas' ? _items : _items.where((d) => d.habitacion == h).toList();

  Future<bool> toggle(int id) async {
    final idx = _items.indexWhere((d) => d.id == id);
    if (idx == -1) return false;
    final d = _items[idx];

    bool ok;
    if (_demo) {
      await Future.delayed(const Duration(milliseconds: 350));
      ok = true;
    } else {
      ok = d.encendido ? await NetCtrl.apagar(d) : await NetCtrl.encender(d);
    }

    if (ok) {
      _items[idx] = d.copyWith(
        encendido:    !d.encendido,
        ultimaAccion: DateTime.now(),
        toggleCount:  d.toggleCount + 1,
      );
      _addLog('${d.nombre} ${_items[idx].encendido ? "encendido" : "apagado"}', ok: true);
    } else {
      _addLog('Error al controlar ${d.nombre} (${d.ip})', ok: false);
    }
    notifyListeners();
    _save();
    return ok;
  }

  Future<void> toggleTodos(bool encender) async {
    for (final d in List.of(_items)) {
      if (d.encendido != encender) await toggle(d.id);
    }
  }

  Future<bool> agregar({
    required String      nombre,
    required TipoD       tipo,
    required CatArtefacto cat,
    required String      ip,
    required int         puerto,
    required String      habitacion,
    bool                 skipPing = false,
  }) async {
    if (!skipPing && !await NetCtrl.ping(ip, puerto)) return false;
    _items.add(Dispositivo(
      id:         _nextId++,
      nombre:     nombre.trim(),
      tipo:       tipo,
      cat:        cat,
      ip:         ip.trim(),
      puerto:     puerto,
      habitacion: habitacion.trim().isEmpty ? 'General' : habitacion.trim(),
    ));
    _addLog('Dispositivo "$nombre" agregado', ok: true);
    notifyListeners();
    _save();
    return true;
  }

  void eliminar(int id) {
    final d = _items.firstWhere((x) => x.id == id);
    _items.removeWhere((x) => x.id == id);
    _addLog('Dispositivo "${d.nombre}" eliminado', ok: true);
    notifyListeners();
    _save();
  }

  void toggleDemo() { _demo = !_demo; notifyListeners(); }

  void _addLog(String msg, {required bool ok}) {
    _log.add(LogEntry(DateTime.now(), msg, ok));
    if (_log.length > 150) _log.removeAt(0);
  }
  void _save() => DispositivoRepo.guardar(_prefs, _items);
}

// ───────────────────────────────────────────────────────────────
// main()
// ───────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF070B14),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  final prefs = await SharedPreferences.getInstance();
  final items = DispositivoRepo.cargar(prefs);
  runApp(DomoticaApp(notifier: DispositivosNotifier(items, prefs)));
}

class DomoticaApp extends StatelessWidget {
  final DispositivosNotifier notifier;
  const DomoticaApp({super.key, required this.notifier});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: notifier,
    builder: (_, __) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Domótica Pro',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: C.bg,
        colorScheme: const ColorScheme.dark(
          primary: C.blue, secondary: C.green,
          surface: C.surface, onSurface: C.t1, onPrimary: Colors.white,
        ),
        cardTheme: const CardThemeData(color: C.card, elevation: 0),
        dividerColor: C.border,
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: C.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: R.xs, borderSide: const BorderSide(color: C.border)),
          enabledBorder: OutlineInputBorder(borderRadius: R.xs, borderSide: const BorderSide(color: C.border)),
          focusedBorder: OutlineInputBorder(borderRadius: R.xs, borderSide: const BorderSide(color: C.blue, width: 1.5)),
          labelStyle: const TextStyle(color: C.t2),
          hintStyle: const TextStyle(color: C.t3),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: C.blue,
            foregroundColor: Colors.white,
            shape: const RoundedRectangleBorder(borderRadius: R.xs),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(backgroundColor: C.cardHi, behavior: SnackBarBehavior.floating),
      ),
      home: const Scaffold(body: Center(child: Text('Carga completa...'))),
    ),
  );
}
