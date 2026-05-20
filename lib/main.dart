// ╔═══════════════════════════════════════════════════════════════╗
// ║  DOMÓTICA PRO  v4.0  —  Producción libre de errores          ║
// ║  Flutter 3.41+ / Dart 3+                                     ║
// ║                                                               ║
// ║  CARACTERÍSTICA NUEVA: linterna del propio celular            ║
// ║  controlada con el plugin torch_light                         ║
// ║                                                               ║
// ║  pubspec.yaml → dependencies:                                 ║
// ║    shared_preferences: ^2.3.0                                 ║
// ║    torch_light: ^1.0.0                                        ║
// ║                                                               ║
// ║  AndroidManifest.xml → en <application>:                      ║
// ║    android:usesCleartextTraffic="true"                        ║
// ║  Permisos adicionales:                                        ║
// ║    <uses-permission                                           ║
// ║      android:name="android.permission.CAMERA"/>               ║
// ║    <uses-feature                                              ║
// ║      android:name="android.hardware.camera.flash"             ║
// ║      android:required="false"/>                               ║
// ╚═══════════════════════════════════════════════════════════════╝

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torch_light/torch_light.dart';

// ═══════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════
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

// ═══════════════════════════════════════════════════════════════
// DESIGN TOKENS
// ═══════════════════════════════════════════════════════════════
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

// ═══════════════════════════════════════════════════════════════
// ENUMS
// ═══════════════════════════════════════════════════════════════
enum TipoD { tasmota, sonoff, shelly, celular, otro }

extension TipoDX on TipoD {
  String get label => switch (this) {
        TipoD.tasmota => 'Tasmota',
        TipoD.sonoff  => 'Sonoff',
        TipoD.shelly  => 'Shelly',
        TipoD.celular => 'Celular',
        TipoD.otro    => 'Genérico',
      };
  IconData get icon => switch (this) {
        TipoD.tasmota => Icons.electrical_services_rounded,
        TipoD.sonoff  => Icons.bolt_rounded,
        TipoD.shelly  => Icons.router_rounded,
        TipoD.celular => Icons.smartphone_rounded,
        TipoD.otro    => Icons.settings_input_hdmi_rounded,
      };
  Color get color => switch (this) {
        TipoD.tasmota => C.blue,
        TipoD.sonoff  => C.orange,
        TipoD.shelly  => C.green,
        TipoD.celular => C.purple,
        TipoD.otro    => C.t2,
      };

  static TipoD fromStr(String s) => TipoD.values
      .firstWhere((e) => e.name == s.toLowerCase(),
          orElse: () => TipoD.otro);
}

enum CatArtefacto {
  luz, ventilador, televisor, aire, enchufe, calefactor, otro
}

extension CatArtefactoX on CatArtefacto {
  String get label => switch (this) {
        CatArtefacto.luz        => 'Luz',
        CatArtefacto.ventilador => 'Ventilador',
        CatArtefacto.televisor  => 'Televisor',
        CatArtefacto.aire       => 'A/C',
        CatArtefacto.enchufe    => 'Enchufe',
        CatArtefacto.calefactor => 'Calefactor',
        CatArtefacto.otro       => 'Otro',
      };
  IconData get icon => switch (this) {
        CatArtefacto.luz        => Icons.light_rounded,
        CatArtefacto.ventilador => Icons.air_rounded,
        CatArtefacto.televisor  => Icons.tv_rounded,
        CatArtefacto.aire       => Icons.ac_unit_rounded,
        CatArtefacto.enchufe    => Icons.power_rounded,
        CatArtefacto.calefactor => Icons.local_fire_department_rounded,
        CatArtefacto.otro       => Icons.device_unknown_rounded,
      };
  Color get catColor => switch (this) {
        CatArtefacto.luz        => C.yellow,
        CatArtefacto.ventilador => C.blue,
        CatArtefacto.televisor  => C.purple,
        CatArtefacto.aire       => C.blue,
        CatArtefacto.enchufe    => C.green,
        CatArtefacto.calefactor => C.orange,
        CatArtefacto.otro       => C.t2,
      };

  static CatArtefacto fromStr(String s) => CatArtefacto.values
      .firstWhere((e) => e.name == s,
          orElse: () => CatArtefacto.otro);
}

// ═══════════════════════════════════════════════════════════════
// MODELOS
// ═══════════════════════════════════════════════════════════════
class LogEntry {
  final DateTime ts;
  final String msg;
  final bool ok;
  LogEntry(this.ts, this.msg, this.ok);
}

class Dispositivo {
  final int id;
  String nombre;
  TipoD tipo;
  CatArtefacto cat;
  String ip;
  int puerto;
  String habitacion;
  bool encendido;
  DateTime? ultimaAccion;
  int toggleCount;

  Dispositivo({
    required this.id,
    required this.nombre,
    required this.tipo,
    this.cat = CatArtefacto.enchufe,
    required this.ip,
    this.puerto = 80,
    this.habitacion = 'General',
    this.encendido = false,
    this.ultimaAccion,
    this.toggleCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'tipo': tipo.name,
        'cat': cat.name,
        'ip': ip,
        'puerto': puerto,
        'habitacion': habitacion,
        'encendido': encendido,
        'toggleCount': toggleCount,
        'ultimaAccion': ultimaAccion?.toIso8601String(),
      };

  factory Dispositivo.fromJson(Map<String, dynamic> j) => Dispositivo(
        id: j['id'] as int,
        nombre: j['nombre'] as String,
        tipo: TipoDX.fromStr(j['tipo'] as String? ?? 'otro'),
        cat: CatArtefactoX.fromStr(j['cat'] as String? ?? 'otro'),
        ip: j['ip'] as String,
        puerto: j['puerto'] as int? ?? 80,
        habitacion: j['habitacion'] as String? ?? 'General',
        encendido: j['encendido'] as bool? ?? false,
        toggleCount: j['toggleCount'] as int? ?? 0,
        ultimaAccion: j['ultimaAccion'] != null
            ? DateTime.tryParse(j['ultimaAccion'] as String)
            : null,
      );

  Dispositivo copyWith({
    bool? encendido,
    DateTime? ultimaAccion,
    int? toggleCount,
  }) =>
      Dispositivo(
        id: id,
        nombre: nombre,
        tipo: tipo,
        cat: cat,
        ip: ip,
        puerto: puerto,
        habitacion: habitacion,
        encendido: encendido ?? this.encendido,
        ultimaAccion: ultimaAccion ?? this.ultimaAccion,
        toggleCount: toggleCount ?? this.toggleCount,
      );
}

// ═══════════════════════════════════════════════════════════════
// LINTERNA LOCAL  (propio celular via torch_light)
// ═══════════════════════════════════════════════════════════════
class LinternaLocal {
  static bool _encendida = false;

  static bool get encendida => _encendida;

  static Future<bool> toggle() async {
    try {
      if (_encendida) {
        await TorchLight.disableTorch();
        _encendida = false;
      } else {
        await TorchLight.enableTorch();
        _encendida = true;
      }
      return true;
    } on Exception {
      return false;
    }
  }

  static Future<bool> encender() async {
    try {
      await TorchLight.enableTorch();
      _encendida = true;
      return true;
    } on Exception {
      return false;
    }
  }

  static Future<bool> apagar() async {
    try {
      await TorchLight.disableTorch();
      _encendida = false;
      return true;
    } on Exception {
      return false;
    }
  }

  static Future<bool> disponible() async {
    try {
      return await TorchLight.isTorchAvailable();
    } on Exception {
      return false;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// CONTROLADOR DE RED — HTTP raw sobre TCP
//
// FIX crítico respecto a versiones anteriores:
//   1. Se usa HTTP/1.0 + Connection:close para forzar que el
//      servidor cierre la conexión tras responder.
//   2. Se LEE toda la respuesta antes de cerrar el socket.
//      (Sin esto, Tasmota/Shelly descartan el comando.)
//   3. Rutas Tasmota: Power+On (no Power%20On).
//   4. Timeout 5s (era 2s, insuficiente en WiFi congestionado).
//   5. Android: agregar usesCleartextTraffic="true" en Manifest.
// ═══════════════════════════════════════════════════════════════
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
        'User-Agent: DomoticaPro/4\r\n'
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

  static String _rutaOn(TipoD tipo) => switch (tipo) {
        TipoD.tasmota => '/cm?cmnd=Power+On',
        TipoD.sonoff  => '/control?cmd=on',
        TipoD.shelly  => '/relay/0?turn=on',
        TipoD.celular => '/on',
        TipoD.otro    => '/on',
      };

  static String _rutaOff(TipoD tipo) => switch (tipo) {
        TipoD.tasmota => '/cm?cmnd=Power+Off',
        TipoD.sonoff  => '/control?cmd=off',
        TipoD.shelly  => '/relay/0?turn=off',
        TipoD.celular => '/off',
        TipoD.otro    => '/off',
      };

  static Future<bool> encender(Dispositivo d) async {
    try {
      await _get(d.ip, d.puerto, _rutaOn(d.tipo));
      return true;
    } catch (e) {
      debugPrint('[NetCtrl] encender ${d.ip} -> $e');
      return false;
    }
  }

  static Future<bool> apagar(Dispositivo d) async {
    try {
      await _get(d.ip, d.puerto, _rutaOff(d.tipo));
      return true;
    } catch (e) {
      debugPrint('[NetCtrl] apagar ${d.ip} -> $e');
      return false;
    }
  }

  static Future<bool> ping(
    String ip,
    int puerto, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      final s = await Socket.connect(ip, puerto, timeout: timeout);
      await s.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Solo Tasmota soporta consulta de estado vía HTTP GET.
  static Future<bool?> consultarEstado(Dispositivo d) async {
    if (d.tipo != TipoD.tasmota) return null;
    try {
      final resp = await _get(d.ip, d.puerto, '/cm?cmnd=Power');
      if (resp.contains('"ON"')) return true;
      if (resp.contains('"OFF"')) return false;
      return null;
    } catch (_) {
      return null;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// REPOSITORIO
// ═══════════════════════════════════════════════════════════════
class DispositivoRepo {
  static const _key = 'domotica_v4';

  static List<Dispositivo> cargar(SharedPreferences p) {
    try {
      final raw = p.getString(_key);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Dispositivo.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static void guardar(SharedPreferences p, List<Dispositivo> items) {
    p.setString(
        _key, jsonEncode(items.map((d) => d.toJson()).toList()));
  }
}

// ═══════════════════════════════════════════════════════════════
// NOTIFIER — estado global
// ═══════════════════════════════════════════════════════════════
class DispositivosNotifier extends ChangeNotifier {
  final SharedPreferences _prefs;
  List<Dispositivo> _items;
  int _nextId = 1;
  bool _demo = false;
  bool _linternaLocal = false;
  final List<LogEntry> _log = [];

  DispositivosNotifier(List<Dispositivo> items, this._prefs)
      : _items = List.of(items) {
    if (_items.isNotEmpty) {
      _nextId =
          _items.map((d) => d.id).reduce((a, b) => a > b ? a : b) + 1;
    }
  }

  // Getters
  List<Dispositivo> get items      => List.unmodifiable(_items);
  bool              get demo       => _demo;
  bool              get linternaLocal => _linternaLocal;
  List<LogEntry>    get log        =>
      List.unmodifiable(_log.reversed.toList());
  int               get encendidos =>
      _items.where((d) => d.encendido).length;

  List<String> get habitaciones {
    final list = _items.map((d) => d.habitacion).toSet().toList()
      ..sort();
    return ['Todas', ...list];
  }

  List<Dispositivo> porHabitacion(String h) => h == 'Todas'
      ? List.of(_items)
      : _items.where((d) => d.habitacion == h).toList();

  // ── Toggle dispositivo de red ───────────────────────────────
  Future<bool> toggle(int id) async {
    final idx = _items.indexWhere((d) => d.id == id);
    if (idx == -1) return false;
    final d = _items[idx];
    bool ok;
    if (_demo) {
      await Future.delayed(const Duration(milliseconds: 350));
      ok = true;
    } else {
      ok = d.encendido
          ? await NetCtrl.apagar(d)
          : await NetCtrl.encender(d);
    }
    if (ok) {
      _items[idx] = d.copyWith(
        encendido: !d.encendido,
        ultimaAccion: DateTime.now(),
        toggleCount: d.toggleCount + 1,
      );
      _log_(
        '${d.nombre} ${_items[idx].encendido ? "encendido" : "apagado"}',
        ok: true,
      );
      _save();
    } else {
      _log_('Error al controlar ${d.nombre} (${d.ip})', ok: false);
    }
    notifyListeners();
    return ok;
  }

  // ── Toggle linterna local ───────────────────────────────────
  Future<bool> toggleLinternaLocal() async {
    bool ok;
    if (_demo) {
      await Future.delayed(const Duration(milliseconds: 200));
      _linternaLocal = !_linternaLocal;
      ok = true;
    } else {
      ok = await LinternaLocal.toggle();
      if (ok) _linternaLocal = LinternaLocal.encendida;
    }
    _log_(
      'Linterna propia ${_linternaLocal ? "encendida" : "apagada"}',
      ok: ok,
    );
    notifyListeners();
    return ok;
  }

  Future<void> toggleTodos(bool encender) async {
    final ids = _items
        .where((d) => d.encendido != encender)
        .map((d) => d.id)
        .toList();
    for (final id in ids) {
      await toggle(id);
    }
  }

  // ── Agregar dispositivo ─────────────────────────────────────
  Future<bool> agregar({
    required String nombre,
    required TipoD tipo,
    required CatArtefacto cat,
    required String ip,
    required int puerto,
    required String habitacion,
    bool skipPing = false,
  }) async {
    if (!skipPing) {
      final ok = await NetCtrl.ping(ip, puerto);
      if (!ok) return false;
    }
    _items.add(Dispositivo(
      id: _nextId++,
      nombre: nombre.trim(),
      tipo: tipo,
      cat: cat,
      ip: ip.trim(),
      puerto: puerto,
      habitacion:
          habitacion.trim().isEmpty ? 'General' : habitacion.trim(),
    ));
    _log_('Dispositivo "$nombre" agregado', ok: true);
    notifyListeners();
    _save();
    return true;
  }

  void eliminar(int id) {
    final d = _items.firstWhere((x) => x.id == id);
    _items.removeWhere((x) => x.id == id);
    _log_('Dispositivo "${d.nombre}" eliminado', ok: true);
    notifyListeners();
    _save();
  }

  void toggleDemo() {
    _demo = !_demo;
    notifyListeners();
  }

  void _log_(String msg, {required bool ok}) {
    _log.add(LogEntry(DateTime.now(), msg, ok));
    if (_log.length > 150) _log.removeAt(0);
  }

  void _save() => DispositivoRepo.guardar(_prefs, _items);
}
