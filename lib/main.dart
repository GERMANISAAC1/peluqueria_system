// ╔══════════════════════════════════════════════════════════════════╗
// ║  DOMÓTICA PRO  v3.3  —  Multi-red + Linterna remota             ║
// ║  Flutter 3.41+ · Dart 3 · Sin dependencias extra de red         ║
// ╠══════════════════════════════════════════════════════════════════╣
// ║  MODOS DE CONEXIÓN:                                             ║
// ║  1. LAN   — IP privada 192.168.x.x  (misma WiFi)               ║
// ║  2. MÓVIL — IP:puerto directa desde cualquier red               ║
// ║             (ej: http://10.44.38.3:8888/flash/on)              ║
// ║  3. URL   — URL completa (http o https, cualquier dominio)      ║
// ║             (ngrok, Cloudflare Tunnel, DDNS, etc.)              ║
// ╠══════════════════════════════════════════════════════════════════╣
// ║  pubspec.yaml:                                                  ║
// ║    shared_preferences: ^2.3.0                                   ║
// ║    http: ^1.2.0                                                 ║
// ║                                                                 ║
// ║  AndroidManifest.xml — dentro de <application>:                 ║
// ║    android:usesCleartextTraffic="true"                          ║
// ║  Dentro de <manifest>:                                          ║
// ║    <uses-permission android:name="android.permission.INTERNET"/>║
// ╚══════════════════════════════════════════════════════════════════╝

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ════════════════════════════════════════════════════════════════
// TOKENS DE DISEÑO
// ════════════════════════════════════════════════════════════════
class C {
  static const bg         = Color(0xFF070B14);
  static const surface    = Color(0xFF0D1220);
  static const card       = Color(0xFF131A2E);
  static const cardHi     = Color(0xFF1A2340);
  static const border     = Color(0xFF1E2845);
  static const blue       = Color(0xFF4F8EF7);
  static const blueGlow   = Color(0x264F8EF7);
  static const green      = Color(0xFF2ECC8E);
  static const greenGlow  = Color(0x262ECC8E);
  static const orange     = Color(0xFFFF9142);
  static const orangeGlow = Color(0x26FF9142);
  static const red        = Color(0xFFFF4D6A);
  static const redGlow    = Color(0x26FF4D6A);
  static const purple     = Color(0xFF9B6DFF);
  static const purpleGlow = Color(0x269B6DFF);
  static const yellow     = Color(0xFFFFCC44);
  static const yellowGlow = Color(0x26FFCC44);
  static const t1         = Color(0xFFF0F4FF);
  static const t2         = Color(0xFF7B8DB8);
  static const t3         = Color(0xFF3D4E78);
}

class R {
  static const xs = BorderRadius.all(Radius.circular(8));
  static const sm = BorderRadius.all(Radius.circular(12));
  static const md = BorderRadius.all(Radius.circular(18));
  static const lg = BorderRadius.all(Radius.circular(24));
  static const xl = BorderRadius.all(Radius.circular(32));
}

// ════════════════════════════════════════════════════════════════
// MODO DE CONEXIÓN
// ════════════════════════════════════════════════════════════════
enum ModoConexion { lan, movil, url }

extension ModoConexionX on ModoConexion {
  String get label => switch (this) {
        ModoConexion.lan   => 'LAN / WiFi',
        ModoConexion.movil => 'Móvil / IP directa',
        ModoConexion.url   => 'URL completa',
      };
  String get hint => switch (this) {
        ModoConexion.lan   => '192.168.1.100',
        ModoConexion.movil => '10.44.38.3',
        ModoConexion.url   => 'https://mi-tunel.ngrok.io',
      };
  String get descripcion => switch (this) {
        ModoConexion.lan   =>
          'Misma red WiFi. IP privada (192.168.x.x).',
        ModoConexion.movil =>
          'Cualquier red. IP pública o de datos móviles '
          '+ puerto abierto.\nEj: 10.44.38.3:8888',
        ModoConexion.url   =>
          'URL completa. Túneles (ngrok, Cloudflare), '
          'DDNS o cualquier dominio propio.',
      };
  IconData get icon => switch (this) {
        ModoConexion.lan   => Icons.wifi_rounded,
        ModoConexion.movil => Icons.signal_cellular_alt_rounded,
        ModoConexion.url   => Icons.public_rounded,
      };
  Color get color => switch (this) {
        ModoConexion.lan   => C.green,
        ModoConexion.movil => C.orange,
        ModoConexion.url   => C.purple,
      };
  Color get glow => switch (this) {
        ModoConexion.lan   => C.greenGlow,
        ModoConexion.movil => C.orangeGlow,
        ModoConexion.url   => C.purpleGlow,
      };
  static ModoConexion fromStr(String s) => ModoConexion.values
      .firstWhere((e) => e.name == s, orElse: () => ModoConexion.lan);
}

// ════════════════════════════════════════════════════════════════
// ENUMS DISPOSITIVO
// ════════════════════════════════════════════════════════════════
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
        TipoD.celular => C.yellow,
        TipoD.otro    => C.t2,
      };
  // Rutas HTTP según firmware
  String get pathOn => switch (this) {
        TipoD.tasmota => '/cm?cmnd=Power+On',
        TipoD.sonoff  => '/control?cmd=on',
        TipoD.shelly  => '/relay/0?turn=on',
        TipoD.celular => '/flash/on',   // Web Remote Droid
        TipoD.otro    => '/on',
      };
  String get pathOff => switch (this) {
        TipoD.tasmota => '/cm?cmnd=Power+Off',
        TipoD.sonoff  => '/control?cmd=off',
        TipoD.shelly  => '/relay/0?turn=off',
        TipoD.celular => '/flash/off',  // Web Remote Droid
        TipoD.otro    => '/off',
      };
  static TipoD fromStr(String s) => TipoD.values
      .firstWhere((e) => e.name == s.toLowerCase(), orElse: () => TipoD.otro);
}

enum CatArtefacto { luz, ventilador, televisor, aire, enchufe, calefactor, otro }

extension CatX on CatArtefacto {
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
  Color get color => switch (this) {
        CatArtefacto.luz        => C.yellow,
        CatArtefacto.ventilador => C.blue,
        CatArtefacto.televisor  => C.purple,
        CatArtefacto.aire       => C.blue,
        CatArtefacto.enchufe    => C.green,
        CatArtefacto.calefactor => C.orange,
        CatArtefacto.otro       => C.t2,
      };
  static CatArtefacto fromStr(String s) => CatArtefacto.values
      .firstWhere((e) => e.name == s, orElse: () => CatArtefacto.otro);
}

// ════════════════════════════════════════════════════════════════
// MODELOS
// ════════════════════════════════════════════════════════════════
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
  ModoConexion modo;
  String ip;        // IP o dominio (LAN / Móvil)
  int puerto;
  String urlBase;   // URL completa base (modo URL), sin path
  String habitacion;
  bool encendido;
  DateTime? ultimaAccion;
  int toggleCount;

  Dispositivo({
    required this.id,
    required this.nombre,
    required this.tipo,
    this.cat       = CatArtefacto.enchufe,
    this.modo      = ModoConexion.lan,
    this.ip        = '',
    this.puerto    = 80,
    this.urlBase   = '',
    this.habitacion  = 'General',
    this.encendido   = false,
    this.ultimaAccion,
    this.toggleCount = 0,
  });

  // Construye la URL de encendido según el modo
  String get urlOn {
    switch (modo) {
      case ModoConexion.url:
        final base = urlBase.trim().replaceAll(RegExp(r'/$'), '');
        return '$base${tipo.pathOn}';
      case ModoConexion.lan:
      case ModoConexion.movil:
        return 'http://${ip.trim()}:$puerto${tipo.pathOn}';
    }
  }

  String get urlOff {
    switch (modo) {
      case ModoConexion.url:
        final base = urlBase.trim().replaceAll(RegExp(r'/$'), '');
        return '$base${tipo.pathOff}';
      case ModoConexion.lan:
      case ModoConexion.movil:
        return 'http://${ip.trim()}:$puerto${tipo.pathOff}';
    }
  }

  // Texto descriptivo de la conexión (para mostrar en tarjeta)
  String get conexionDisplay {
    switch (modo) {
      case ModoConexion.url:    return urlBase.isEmpty ? '—' : urlBase;
      case ModoConexion.lan:
      case ModoConexion.movil:  return '${ip.trim()}:$puerto';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id, 'nombre': nombre, 'tipo': tipo.name, 'cat': cat.name,
        'modo': modo.name, 'ip': ip, 'puerto': puerto, 'urlBase': urlBase,
        'habitacion': habitacion, 'encendido': encendido,
        'toggleCount': toggleCount,
        'ultimaAccion': ultimaAccion?.toIso8601String(),
      };

  factory Dispositivo.fromJson(Map<String, dynamic> j) => Dispositivo(
        id:           j['id'] as int,
        nombre:       j['nombre'] as String,
        tipo:         TipoDX.fromStr(j['tipo'] as String? ?? 'otro'),
        cat:          CatX.fromStr(j['cat'] as String? ?? 'otro'),
        modo:         ModoConexionX.fromStr(j['modo'] as String? ?? 'lan'),
        ip:           j['ip'] as String? ?? '',
        puerto:       j['puerto'] as int? ?? 80,
        urlBase:      j['urlBase'] as String? ?? '',
        habitacion:   j['habitacion'] as String? ?? 'General',
        encendido:    j['encendido'] as bool? ?? false,
        toggleCount:  j['toggleCount'] as int? ?? 0,
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
        id: id, nombre: nombre, tipo: tipo, cat: cat, modo: modo,
        ip: ip, puerto: puerto, urlBase: urlBase, habitacion: habitacion,
        encendido:    encendido    ?? this.encendido,
        ultimaAccion: ultimaAccion ?? this.ultimaAccion,
        toggleCount:  toggleCount  ?? this.toggleCount,
      );
}

// ════════════════════════════════════════════════════════════════
// CONTROLADOR DE RED
//
// Usa http.get() de package:http para TODOS los modos.
// Funciona desde cualquier red:
//   • LAN:   http://192.168.1.x:80/...
//   • Móvil: http://10.44.38.3:8888/flash/on   (datos Claro, etc.)
//   • URL:   https://abc.ngrok.io/...
//
// Por qué http.get() y no TCP raw:
//   - TCP raw cierra sin leer respuesta → firmware descarta el comando
//   - http.get() maneja HTTP completo, redireccionamientos, HTTPS
//   - Compatible con Web Remote Droid y cualquier servidor HTTP
// ════════════════════════════════════════════════════════════════
class NetCtrl {
  static const _timeout = Duration(seconds: 8);

  static Future<bool> _enviar(String url) async {
    try {
      debugPrint('[Net] GET $url');
      final resp = await http.get(Uri.parse(url)).timeout(_timeout);
      debugPrint('[Net] → ${resp.statusCode}');
      return resp.statusCode < 400;
    } catch (e) {
      debugPrint('[Net] Error: $e');
      return false;
    }
  }

  static Future<bool> encender(Dispositivo d) => _enviar(d.urlOn);
  static Future<bool> apagar(Dispositivo d)   => _enviar(d.urlOff);

  // Ping: intenta GET a la URL base para verificar conectividad
  static Future<bool> ping(Dispositivo d) async {
    try {
      final url = d.modo == ModoConexion.url
          ? d.urlBase.trim()
          : 'http://${d.ip.trim()}:${d.puerto}';
      if (url.isEmpty) return false;
      debugPrint('[Net] Ping $url');
      final resp = await http.get(Uri.parse(url)).timeout(_timeout);
      // Cualquier respuesta (incluso 404) = servidor alcanzable
      return resp.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  // Ping simple para el formulario
  static Future<bool> pingRaw({
    required ModoConexion modo,
    required String ip,
    required int puerto,
    required String urlBase,
  }) async {
    try {
      final url = modo == ModoConexion.url
          ? urlBase.trim()
          : 'http://${ip.trim()}:$puerto';
      if (url.isEmpty) return false;
      final resp = await http.get(Uri.parse(url)).timeout(_timeout);
      return resp.statusCode < 500;
    } catch (_) {
      return false;
    }
  }
}

// ════════════════════════════════════════════════════════════════
// REPOSITORIO
// ════════════════════════════════════════════════════════════════
class DispositivoRepo {
  static const _k = 'domotica_v33';

  static List<Dispositivo> cargar(SharedPreferences p) {
    try {
      final raw = p.getString(_k);
      if (raw == null) return [];
      return (jsonDecode(raw) as List)
          .map((e) => Dispositivo.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static void guardar(SharedPreferences p, List<Dispositivo> items) =>
      p.setString(_k, jsonEncode(items.map((d) => d.toJson()).toList()));
}

// ════════════════════════════════════════════════════════════════
// NOTIFIER
// ════════════════════════════════════════════════════════════════
class DispositivosNotifier extends ChangeNotifier {
  final SharedPreferences _prefs;
  List<Dispositivo> _items;
  int _nextId = 1;
  bool _demo  = false;
  final List<LogEntry> _log = [];

  DispositivosNotifier(List<Dispositivo> items, this._prefs)
      : _items = List.of(items) {
    if (_items.isNotEmpty) {
      _nextId = _items.map((d) => d.id).reduce((a, b) => a > b ? a : b) + 1;
    }
  }

  List<Dispositivo> get items      => List.unmodifiable(_items);
  bool              get demo       => _demo;
  List<LogEntry>    get log        => List.unmodifiable(_log.reversed.toList());
  int               get encendidos => _items.where((d) => d.encendido).length;

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
        encendido: !d.encendido,
        ultimaAccion: DateTime.now(),
        toggleCount: d.toggleCount + 1,
      );
      _log_('${d.nombre} ${_items[idx].encendido ? "encendido" : "apagado"}',
          ok: true);
    } else {
      _log_('Error al controlar ${d.nombre}', ok: false);
    }
    notifyListeners();
    _save();
    return ok;
  }

  Future<void> toggleTodos(bool enc) async {
    for (final d in List.of(_items)) {
      if (d.encendido != enc) await toggle(d.id);
    }
  }

  Future<bool> agregar({
    required String nombre,
    required TipoD tipo,
    required CatArtefacto cat,
    required ModoConexion modo,
    required String ip,
    required int puerto,
    required String urlBase,
    required String habitacion,
    bool skipPing = false,
  }) async {
    if (!skipPing) {
      final ok = await NetCtrl.pingRaw(
          modo: modo, ip: ip, puerto: puerto, urlBase: urlBase);
      if (!ok) return false;
    }
    _items.add(Dispositivo(
      id: _nextId++,
      nombre: nombre.trim(),
      tipo: tipo, cat: cat, modo: modo,
      ip: ip.trim(), puerto: puerto,
      urlBase: urlBase.trim(),
      habitacion: habitacion.trim().isEmpty ? 'General' : habitacion.trim(),
    ));
    _log_('Dispositivo "$nombre" agregado', ok: true);
    notifyListeners();
    _save();
    return true;
  }

  void eliminar(int id) {
    final d = _items.firstWhere((x) => x.id == id);
    _items.removeWhere((x) => x.id == id);
    _log_('"${d.nombre}" eliminado', ok: true);
    notifyListeners();
    _save();
  }

  void toggleDemo() { _demo = !_demo; notifyListeners(); }

  void _log_(String msg, {required bool ok}) {
    _log.add(LogEntry(DateTime.now(), msg, ok));
    if (_log.length > 150) _log.removeAt(0);
  }

  void _save() => DispositivoRepo.guardar(_prefs, _items);
}

// ════════════════════════════════════════════════════════════════
// MAIN
// ════════════════════════════════════════════════════════════════
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
  runApp(DomoticaApp(
      notifier: DispositivosNotifier(DispositivoRepo.cargar(prefs), prefs)));
}

// ════════════════════════════════════════════════════════════════
// SNACK helper
// ════════════════════════════════════════════════════════════════
void snack(BuildContext ctx, String msg, {bool error = false}) {
  ScaffoldMessenger.of(ctx).clearSnackBars();
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
    content: Row(children: [
      Icon(error ? Icons.error_rounded : Icons.check_circle_rounded,
          color: error ? C.red : C.green, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(msg, style: const TextStyle(color: C.t1))),
    ]),
    backgroundColor: C.cardHi,
    margin: const EdgeInsets.all(14),
    behavior: SnackBarBehavior.floating,
    shape: const RoundedRectangleBorder(borderRadius: R.sm),
    duration: const Duration(seconds: 4),
  ));
}

// ════════════════════════════════════════════════════════════════
// APP ROOT
// ════════════════════════════════════════════════════════════════
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
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: R.xs,
                  borderSide: const BorderSide(color: C.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: R.xs,
                  borderSide: const BorderSide(color: C.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: R.xs,
                  borderSide: const BorderSide(color: C.blue, width: 1.5)),
              errorBorder: OutlineInputBorder(
                  borderRadius: R.xs,
                  borderSide: const BorderSide(color: C.red)),
              labelStyle: const TextStyle(color: C.t2),
              hintStyle: const TextStyle(color: C.t3),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: C.blue, foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(borderRadius: R.xs),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            snackBarTheme: const SnackBarThemeData(
              backgroundColor: C.cardHi, behavior: SnackBarBehavior.floating),
          ),
          home: Shell(notifier: notifier),
        ),
      );
}

// ════════════════════════════════════════════════════════════════
// SHELL
// ════════════════════════════════════════════════════════════════
class Shell extends StatefulWidget {
  final DispositivosNotifier notifier;
  const Shell({super.key, required this.notifier});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(notifier: widget.notifier),
      HabitacionesPage(notifier: widget.notifier),
      DispositivosPage(notifier: widget.notifier),
      HistorialPage(notifier: widget.notifier),
    ];
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: KeyedSubtree(key: ValueKey(_tab), child: pages[_tab]),
      ),
      bottomNavigationBar:
          _BottomNav(current: _tab, onTap: (i) => setState(() => _tab = i)),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int current;
  final void Function(int) onTap;
  const _BottomNav({required this.current, required this.onTap});
  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.dashboard_rounded,  'Panel'),
      (Icons.home_rounded,       'Habitaciones'),
      (Icons.devices_rounded,    'Dispositivos'),
      (Icons.history_rounded,    'Historial'),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: C.surface,
        border: Border(top: BorderSide(color: C.border, width: 0.5))),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(4, (i) {
              final sel = i == current;
              return GestureDetector(
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? C.blueGlow : Colors.transparent,
                    borderRadius: R.md,
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(items[i].$1,
                        size: 22, color: sel ? C.blue : C.t3),
                    const SizedBox(height: 3),
                    Text(items[i].$2,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: sel ? C.blue : C.t3)),
                  ]),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PÁGINA: DASHBOARD
// ════════════════════════════════════════════════════════════════
class DashboardPage extends StatefulWidget {
  final DispositivosNotifier notifier;
  const DashboardPage({super.key, required this.notifier});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }
  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.notifier, _pulse]),
      builder: (_, __) {
        final n = widget.notifier;
        final total = n.items.length;
        final enc = n.encendidos;
        final pct = total == 0 ? 0.0 : enc / total;
        return CustomScrollView(slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: C.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: _DashHeader(enc: enc, total: total)),
            title: const Text('Domótica Pro',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700, color: C.t1)),
            actions: [
              _IconBtn(
                icon: enc > 0
                    ? Icons.power_settings_new_rounded
                    : Icons.power_rounded,
                color: enc > 0 ? C.red : C.green,
                tooltip: enc > 0 ? 'Apagar todo' : 'Encender todo',
                onTap: () => n.toggleTodos(enc == 0),
              ),
              const SizedBox(width: 4),
              _DemoChip(demo: n.demo, pulse: _pulse, onTap: n.toggleDemo),
              const SizedBox(width: 8),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(children: [
                  _StatCard('Encendidos', enc.toString(),
                      Icons.power_rounded, C.green, C.greenGlow),
                  const SizedBox(width: 10),
                  _StatCard('Apagados', (total - enc).toString(),
                      Icons.power_off_rounded, C.red, C.redGlow),
                  const SizedBox(width: 10),
                  _StatCard('Total', total.toString(),
                      Icons.devices_rounded, C.blue, C.blueGlow),
                ]),
                const SizedBox(height: 16),
                _ActivityBar(pct: pct, enc: enc, total: total),
                const SizedBox(height: 22),
                const _SectionHeader('Artefactos'),
                const SizedBox(height: 12),
                _CatGrid(notifier: n),
                const SizedBox(height: 22),
                const _SectionHeader('Habitaciones'),
                const SizedBox(height: 12),
                if (n.items.isEmpty)
                  const _EmptyState()
                else
                  ..._buildHabs(n),
                if (n.log.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const _SectionHeader('Última actividad'),
                  const SizedBox(height: 10),
                  ...n.log.take(4).map((e) => _LogTile(e: e)),
                ],
              ]),
            ),
          ),
        ]);
      },
    );
  }

  List<Widget> _buildHabs(DispositivosNotifier n) {
    final map = <String, List<Dispositivo>>{};
    for (final d in n.items) map.putIfAbsent(d.habitacion, () => []).add(d);
    final entries = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries
        .map((e) => _HabCardCompact(
              nombre: e.key,
              dispositivos: e.value,
              notifier: n,
            ))
        .toList();
  }
}

// ── Dashboard widgets ────────────────────────────────────────────
class _DashHeader extends StatelessWidget {
  final int enc, total;
  const _DashHeader({required this.enc, required this.total});
  @override
  Widget build(BuildContext context) {
    final h = DateTime.now().hour;
    final saludo = h < 12
        ? 'Buenos días ☀️'
        : h < 18
            ? 'Buenas tardes 🌤️'
            : 'Buenas noches 🌙';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1528), C.bg],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 72, 20, 20),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(saludo, style: const TextStyle(fontSize: 13, color: C.t2)),
              const SizedBox(height: 6),
              Text('$enc dispositivos',
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w800, color: C.t1)),
              Text('activos de $total en red',
                  style: const TextStyle(fontSize: 14, color: C.t2)),
            ],
          ),
        ),
        SizedBox(
          width: 64,
          height: 64,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
              value: total == 0 ? 0 : enc / total,
              backgroundColor: C.border,
              valueColor: const AlwaysStoppedAnimation(C.blue),
              strokeWidth: 5,
              strokeCap: StrokeCap.round,
            ),
            Text(
              '${total == 0 ? 0 : (enc * 100 ~/ total)}%',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: C.t1),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _DemoChip extends StatelessWidget {
  final bool demo;
  final Animation<double> pulse;
  final VoidCallback onTap;
  const _DemoChip(
      {required this.demo, required this.pulse, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: demo ? C.orangeGlow : C.surface,
            borderRadius: R.xs,
            border: Border.all(
                color: demo ? C.orange.withOpacity(0.5) : C.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.science_rounded,
                size: 13, color: demo ? C.orange : C.t3),
            const SizedBox(width: 5),
            Text('DEMO',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: demo ? C.orange : C.t3)),
          ]),
        ),
      );
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color, glow;
  const _StatCard(this.label, this.value, this.icon, this.color, this.glow);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: C.card,
              borderRadius: R.sm,
              border: Border.all(color: C.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: glow, borderRadius: R.xs),
                child: Icon(icon, color: color, size: 15)),
            const SizedBox(height: 10),
            Text(value,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, color: C.t2)),
          ]),
        ),
      );
}

class _ActivityBar extends StatelessWidget {
  final double pct;
  final int enc, total;
  const _ActivityBar(
      {required this.pct, required this.enc, required this.total});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: C.card,
            borderRadius: R.sm,
            border: Border.all(color: C.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Actividad global',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: C.t1)),
            Text('${(pct * 100).round()}%',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: C.blue)),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: R.xl,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct),
              duration: const Duration(milliseconds: 700),
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: C.border,
                valueColor: const AlwaysStoppedAnimation(C.blue),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('$enc de $total dispositivos activos',
              style: const TextStyle(fontSize: 11, color: C.t2)),
        ]),
      );
}

class _CatGrid extends StatelessWidget {
  final DispositivosNotifier notifier;
  const _CatGrid({required this.notifier});
  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        children: CatArtefacto.values.map((cat) {
          final lista =
              notifier.items.where((d) => d.cat == cat).toList();
          final enc = lista.where((d) => d.encendido).length;
          final on = enc > 0;
          final col = cat.color;
          return Container(
            decoration: BoxDecoration(
              color: on ? col.withOpacity(0.14) : C.card,
              borderRadius: R.sm,
              border: Border.all(
                  color: on ? col.withOpacity(0.35) : C.border,
                  width: on ? 1.5 : 0.5),
            ),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(cat.icon, size: 22, color: on ? col : C.t3),
                  const SizedBox(height: 5),
                  Text(cat.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: on ? col : C.t3)),
                  if (lista.isNotEmpty)
                    Text('$enc/${lista.length}',
                        style: TextStyle(
                            fontSize: 8, color: on ? col : C.t3)),
                ]),
          );
        }).toList(),
      );
}

class _HabCardCompact extends StatefulWidget {
  final String nombre;
  final List<Dispositivo> dispositivos;
  final DispositivosNotifier notifier;
  const _HabCardCompact(
      {required this.nombre,
      required this.dispositivos,
      required this.notifier});
  @override
  State<_HabCardCompact> createState() => _HabCardCompactState();
}

class _HabCardCompactState extends State<_HabCardCompact> {
  bool _exp = true;
  @override
  Widget build(BuildContext context) {
    final enc = widget.dispositivos.where((d) => d.encendido).length;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: C.card, borderRadius: R.sm, border: Border.all(color: C.border)),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _exp = !_exp),
          borderRadius: R.sm,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Icon(_habIcon(widget.nombre), color: C.blue, size: 18),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(widget.nombre,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: C.t1))),
              _Chip(enc: enc, total: widget.dispositivos.length),
              const SizedBox(width: 6),
              Icon(
                  _exp
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: C.t2, size: 18),
            ]),
          ),
        ),
        if (_exp) ...[
          const Divider(height: 1, color: C.border),
          ...widget.dispositivos
              .map((d) => _MiniTile(d: d, notifier: widget.notifier)),
        ],
      ]),
    );
  }

  IconData _habIcon(String n) {
    final l = n.toLowerCase();
    if (l.contains('sala'))   return Icons.weekend_rounded;
    if (l.contains('cocina')) return Icons.kitchen_rounded;
    if (l.contains('baño') || l.contains('bano'))  return Icons.bathtub_rounded;
    if (l.contains('dorm') || l.contains('cuarto') || l.contains('habit'))
      return Icons.bed_rounded;
    if (l.contains('garaje')) return Icons.garage_rounded;
    if (l.contains('jardin') || l.contains('jardín') || l.contains('patio'))
      return Icons.yard_rounded;
    if (l.contains('oficina')) return Icons.computer_rounded;
    return Icons.home_rounded;
  }
}

class _Chip extends StatelessWidget {
  final int enc, total;
  const _Chip({required this.enc, required this.total});
  @override
  Widget build(BuildContext context) {
    final c = enc == 0 ? C.t3 : enc == total ? C.green : C.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: c.withOpacity(0.15), borderRadius: R.xl),
      child: Text('$enc/$total',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: c)),
    );
  }
}

class _MiniTile extends StatefulWidget {
  final Dispositivo d;
  final DispositivosNotifier notifier;
  const _MiniTile({required this.d, required this.notifier});
  @override
  State<_MiniTile> createState() => _MiniTileState();
}

class _MiniTileState extends State<_MiniTile> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: d.encendido ? d.tipo.color.withOpacity(0.18) : C.surface,
            borderRadius: R.xs,
          ),
          child: Icon(d.cat.icon,
              size: 17, color: d.encendido ? d.tipo.color : C.t3),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.nombre,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: C.t1)),
            Text(d.conexionDisplay,
                style: const TextStyle(fontSize: 11, color: C.t3)),
          ]),
        ),
        if (_busy)
          const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: C.blue))
        else
          _Sw(
            val: d.encendido,
            color: d.tipo.color,
            onChange: (_) async {
              setState(() => _busy = true);
              await widget.notifier.toggle(d.id);
              if (mounted) setState(() => _busy = false);
            },
          ),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                  color: C.blueGlow, shape: BoxShape.circle),
              child: const Icon(Icons.devices_other_rounded,
                  size: 44, color: C.blue),
            ),
            const SizedBox(height: 16),
            const Text('Sin dispositivos',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: C.t1)),
            const SizedBox(height: 6),
            const Text('Agrega dispositivos desde\nla pestaña Dispositivos',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: C.t2)),
          ]),
        ),
      );
}

// ════════════════════════════════════════════════════════════════
// PÁGINA: HABITACIONES
// ════════════════════════════════════════════════════════════════
class HabitacionesPage extends StatefulWidget {
  final DispositivosNotifier notifier;
  const HabitacionesPage({super.key, required this.notifier});
  @override
  State<HabitacionesPage> createState() => _HabPageState();
}

class _HabPageState extends State<HabitacionesPage> {
  String _sel = 'Todas';
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.notifier,
      builder: (_, __) {
        final n = widget.notifier;
        final habs = n.habitaciones;
        if (!habs.contains(_sel)) _sel = 'Todas';
        final items = n.porHabitacion(_sel);
        return Scaffold(
          backgroundColor: C.bg,
          body: CustomScrollView(slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: C.surface,
              title: const Text('Habitaciones',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: C.t1)),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: _HabTabs(
                    habs: habs,
                    sel: _sel,
                    onSel: (h) => setState(() => _sel = h)),
              ),
            ),
            if (items.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.device_unknown_rounded,
                          size: 44, color: C.t3),
                      const SizedBox(height: 12),
                      Text(
                        _sel == 'Todas'
                            ? 'Sin dispositivos aún'
                            : 'No hay dispositivos en $_sel',
                        style: const TextStyle(color: C.t2),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding:
                    const EdgeInsets.fromLTRB(16, 16, 16, 100),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _DevTile(
                        d: items[i], notifier: n),
                    childCount: items.length,
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                ),
              ),
          ]),
        );
      },
    );
  }
}

class _HabTabs extends StatelessWidget {
  final List<String> habs;
  final String sel;
  final void Function(String) onSel;
  const _HabTabs(
      {required this.habs, required this.sel, required this.onSel});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 46,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 6),
          itemCount: habs.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final h = habs[i];
            final active = h == sel;
            return GestureDetector(
              onTap: () => onSel(h),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? C.blue : C.surface,
                  borderRadius: R.xl,
                  border: Border.all(
                      color: active ? C.blue : C.border),
                ),
                child: Text(h,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: active ? Colors.white : C.t2)),
              ),
            );
          },
        ),
      );
}

class _DevTile extends StatefulWidget {
  final Dispositivo d;
  final DispositivosNotifier notifier;
  const _DevTile({required this.d, required this.notifier});
  @override
  State<_DevTile> createState() => _DevTileState();
}

class _DevTileState extends State<_DevTile>
    with SingleTickerProviderStateMixin {
  bool _busy = false;
  late final AnimationController _glow;
  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }
  @override
  void dispose() { _glow.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final col = d.tipo.color;
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, __) => GestureDetector(
        onTap: _busy ? null : _doToggle,
        onLongPress: () => _confirmDelete(context, d),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: d.encendido
                ? col.withOpacity(0.12 + _glow.value * 0.05)
                : C.card,
            borderRadius: R.md,
            border: Border.all(
              color: d.encendido
                  ? col.withOpacity(0.45)
                  : C.border,
              width: d.encendido ? 1.5 : 0.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(
                          color: d.encendido
                              ? col.withOpacity(0.22)
                              : C.surface,
                          borderRadius: R.sm,
                        ),
                        child: Icon(d.cat.icon,
                            size: 24,
                            color: d.encendido ? col : C.t3),
                      ),
                      if (_busy)
                        const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: C.blue))
                      else
                        GestureDetector(
                          onTap: _doToggle,
                          child: Container(
                            width: 34, height: 34,
                            decoration: BoxDecoration(
                              color: d.encendido ? col : C.surface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: d.encendido ? col : C.border),
                            ),
                            child: Icon(
                                Icons.power_settings_new_rounded,
                                size: 16,
                                color: d.encendido
                                    ? Colors.white
                                    : C.t2),
                          ),
                        ),
                    ]),
                const Spacer(),
                Text(d.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: d.encendido ? C.t1 : C.t2)),
                const SizedBox(height: 4),
                Row(children: [
                  _MicroBadge(d.tipo.label, col: d.tipo.color),
                  const SizedBox(width: 6),
                  Text(d.encendido ? 'ON' : 'OFF',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: d.encendido ? col : C.t3)),
                ]),
                const SizedBox(height: 4),
                // Muestra el ícono del modo de conexión
                Row(children: [
                  Icon(d.modo.icon, size: 10, color: d.modo.color),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(d.conexionDisplay,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 9, color: C.t3)),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _doToggle() async {
    setState(() => _busy = true);
    await widget.notifier.toggle(widget.d.id);
    if (mounted) setState(() => _busy = false);
  }

  void _confirmDelete(BuildContext context, Dispositivo d) =>
      showDialog(
        context: context,
        builder: (_) => _DeleteDialog(
          nombre: d.nombre,
          onConfirm: () {
            widget.notifier.eliminar(d.id);
            Navigator.pop(context);
          },
        ),
      );
}

class _MicroBadge extends StatelessWidget {
  final String text;
  final Color col;
  const _MicroBadge(this.text, {required this.col});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: col.withOpacity(0.14), borderRadius: R.xl),
        child: Text(text,
            style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w700, color: col)),
      );
}

// ════════════════════════════════════════════════════════════════
// PÁGINA: DISPOSITIVOS
// ════════════════════════════════════════════════════════════════
class DispositivosPage extends StatefulWidget {
  final DispositivosNotifier notifier;
  const DispositivosPage({super.key, required this.notifier});
  @override
  State<DispositivosPage> createState() => _DispPageState();
}

class _DispPageState extends State<DispositivosPage> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.notifier,
      builder: (_, __) {
        final n = widget.notifier;
        final q = _query.toLowerCase();
        final filtered = n.items
            .where((d) =>
                d.nombre.toLowerCase().contains(q) ||
                d.ip.contains(q) ||
                d.urlBase.toLowerCase().contains(q) ||
                d.habitacion.toLowerCase().contains(q))
            .toList();
        return Scaffold(
          backgroundColor: C.bg,
          body: CustomScrollView(slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: C.surface,
              title: const Text('Dispositivos',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: C.t1)),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: TextField(
                    onChanged: (v) =>
                        setState(() => _query = v),
                    style: const TextStyle(
                        color: C.t1, fontSize: 14),
                    decoration: InputDecoration(
                      hintText:
                          'Buscar nombre, IP, habitación...',
                      prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: C.t3, size: 20),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                  Icons.clear_rounded,
                                  color: C.t3, size: 18),
                              onPressed: () =>
                                  setState(() => _query = ''))
                          : null,
                    ),
                  ),
                ),
              ),
            ),
            if (filtered.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off_rounded,
                          size: 42, color: C.t3),
                      const SizedBox(height: 10),
                      Text(
                        n.items.isEmpty
                            ? 'Sin dispositivos aún'
                            : 'Sin resultados',
                        style: const TextStyle(color: C.t2),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding:
                    const EdgeInsets.fromLTRB(16, 16, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _DispCard(
                        d: filtered[i], notifier: n),
                    childCount: filtered.length,
                  ),
                ),
              ),
          ]),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddSheet(context),
            backgroundColor: C.blue,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        );
      },
    );
  }

  void _showAddSheet(BuildContext context) =>
      showModalBottomSheet(
        context: context,
        backgroundColor: C.surface,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(24))),
        builder: (_) => _AddForm(notifier: widget.notifier),
      );
}

class _DispCard extends StatefulWidget {
  final Dispositivo d;
  final DispositivosNotifier notifier;
  const _DispCard({required this.d, required this.notifier});
  @override
  State<_DispCard> createState() => _DispCardState();
}

class _DispCardState extends State<_DispCard>
    with SingleTickerProviderStateMixin {
  bool _busy = false;
  late final AnimationController _glow;
  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }
  @override
  void dispose() { _glow.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final col = d.tipo.color;
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: C.card,
          borderRadius: R.sm,
          border: Border.all(
            color: d.encendido
                ? col.withOpacity(0.4 + _glow.value * 0.15)
                : C.border,
            width: d.encendido ? 1.5 : 0.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: d.encendido
                      ? col.withOpacity(0.18)
                      : C.surface,
                  borderRadius: R.xs,
                ),
                child: Icon(d.cat.icon,
                    size: 22,
                    color: d.encendido ? col : C.t3),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.nombre,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: C.t1)),
                    const SizedBox(height: 3),
                    Row(children: [
                      _MicroBadge(d.tipo.label, col: col),
                      const SizedBox(width: 6),
                      _MicroBadge(d.habitacion, col: C.t2),
                      const SizedBox(width: 6),
                      // Badge del modo de conexión
                      _MicroBadge(d.modo.label,
                          col: d.modo.color),
                    ]),
                  ],
                ),
              ),
              if (_busy)
                const SizedBox(
                    width: 26, height: 26,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: C.blue))
              else
                _Sw(
                    val: d.encendido,
                    color: col,
                    onChange: (_) => _toggle()),
            ]),
            const SizedBox(height: 10),
            const Divider(height: 1, color: C.border),
            const SizedBox(height: 8),
            Row(children: [
              Icon(d.modo.icon,
                  size: 12, color: d.modo.color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(d.conexionDisplay,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: C.t3)),
              ),
              const SizedBox(width: 8),
              _IChip(Icons.toggle_on_rounded,
                  '${d.toggleCount} ops'),
              const SizedBox(width: 8),
              if (d.ultimaAccion != null)
                _IChip(Icons.schedule_rounded,
                    _rel(d.ultimaAccion!)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => _DeleteDialog(
                    nombre: d.nombre,
                    onConfirm: () {
                      widget.notifier.eliminar(d.id);
                      Navigator.pop(context);
                    },
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                      color: C.redGlow, borderRadius: R.xs),
                  child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 15, color: C.red),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _toggle() async {
    setState(() => _busy = true);
    final ok = await widget.notifier.toggle(widget.d.id);
    if (mounted) {
      setState(() => _busy = false);
      if (!ok) snack(context, 'Error al controlar ${widget.d.nombre}', error: true);
    }
  }

  String _rel(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    return '${d.inHours}h';
  }
}

// ════════════════════════════════════════════════════════════════
// FORMULARIO AGREGAR
// ════════════════════════════════════════════════════════════════
class _AddForm extends StatefulWidget {
  final DispositivosNotifier notifier;
  const _AddForm({required this.notifier});
  @override
  State<_AddForm> createState() => _AddFormState();
}

class _AddFormState extends State<_AddForm> {
  final _fk      = GlobalKey<FormState>();
  final _cNombre = TextEditingController();
  final _cIp     = TextEditingController();
  final _cPuerto = TextEditingController(text: '80');
  final _cUrl    = TextEditingController();
  final _cHab    = TextEditingController(text: 'General');

  TipoD        _tipo = TipoD.tasmota;
  CatArtefacto _cat  = CatArtefacto.enchufe;
  ModoConexion _modo = ModoConexion.lan;
  bool _saving  = false;
  bool _pinging = false;
  bool? _pingOk;

  @override
  void dispose() {
    _cNombre.dispose(); _cIp.dispose(); _cPuerto.dispose();
    _cUrl.dispose(); _cHab.dispose();
    super.dispose();
  }

  String _infoRuta() {
    final rutas = switch (_tipo) {
      TipoD.tasmota => 'ON: /cm?cmnd=Power+On\nOFF: /cm?cmnd=Power+Off',
      TipoD.sonoff  => 'ON: /control?cmd=on\nOFF: /control?cmd=off',
      TipoD.shelly  => 'ON: /relay/0?turn=on\nOFF: /relay/0?turn=off',
      TipoD.celular => 'ON: /flash/on\nOFF: /flash/off\n(Web Remote Droid)',
      TipoD.otro    => 'ON: /on\nOFF: /off',
    };
    final modo = switch (_modo) {
      ModoConexion.lan   => 'Misma red WiFi. IP privada 192.168.x.x',
      ModoConexion.movil =>
        'Desde CUALQUIER red (datos Claro, WiFi ajena, etc.).\n'
        'La IP debe ser pública o de datos móviles con puerto abierto.',
      ModoConexion.url   =>
        'URL completa. Funciona desde cualquier red.\n'
        'Usa ngrok, Cloudflare Tunnel, DDNS o tu dominio propio.',
    };
    return '$rutas\n\n$modo';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20, right: 20, top: 20),
      child: Form(
        key: _fk,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: C.border, borderRadius: R.xl),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Agregar dispositivo',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: C.t1)),
              const SizedBox(height: 20),

              // ── Nombre ────────────────────────────────────────
              const _Lbl('Nombre'),
              TextFormField(
                controller: _cNombre,
                style: const TextStyle(color: C.t1),
                decoration:
                    const InputDecoration(hintText: 'Ej: Lámpara sala'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 14),

              // ── Firmware ──────────────────────────────────────
              const _Lbl('Firmware / Tipo'),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: TipoD.values.map((t) {
                  final sel = t == _tipo;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _tipo = t;
                      if (t == TipoD.celular) _cPuerto.text = '8888';
                      else if (_modo != ModoConexion.url) _cPuerto.text = '80';
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel
                            ? t.color.withOpacity(0.2)
                            : C.surface,
                        borderRadius: R.xs,
                        border: Border.all(
                            color: sel ? t.color : C.border),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(t.icon,
                            size: 13,
                            color: sel ? t.color : C.t3),
                        const SizedBox(width: 5),
                        Text(t.label,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: sel ? t.color : C.t2)),
                      ]),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // ── Artefacto ─────────────────────────────────────
              const _Lbl('Tipo de artefacto'),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: CatArtefacto.values.map((c) {
                  final sel = c == _cat;
                  final col = c.color;
                  return GestureDetector(
                    onTap: () => setState(() => _cat = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel ? col.withOpacity(0.18) : C.surface,
                        borderRadius: R.xs,
                        border: Border.all(
                            color: sel ? col : C.border),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(c.icon,
                            size: 13, color: sel ? col : C.t3),
                        const SizedBox(width: 5),
                        Text(c.label,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: sel ? col : C.t2)),
                      ]),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // ── MODO DE CONEXIÓN ──────────────────────────────
              const _Lbl('Modo de conexión'),
              ...ModoConexion.values.map((m) {
                final sel = m == _modo;
                return GestureDetector(
                  onTap: () => setState(() {
                    _modo = m;
                    _pingOk = null;
                    if (m == ModoConexion.movil &&
                        _tipo == TipoD.celular) {
                      _cPuerto.text = '8888';
                    }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: sel
                          ? m.color.withOpacity(0.10)
                          : C.surface,
                      borderRadius: R.sm,
                      border: Border.all(
                          color: sel ? m.color : C.border,
                          width: sel ? 1.5 : 0.5),
                    ),
                    child: Row(children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: sel
                              ? m.color.withOpacity(0.18)
                              : C.card,
                          borderRadius: R.xs,
                        ),
                        child: Icon(m.icon,
                            size: 16,
                            color: sel ? m.color : C.t3),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(m.label,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: sel ? m.color : C.t1)),
                            const SizedBox(height: 2),
                            Text(m.descripcion,
                                style: const TextStyle(
                                    fontSize: 10, color: C.t2)),
                          ],
                        ),
                      ),
                      if (sel)
                        Icon(Icons.check_circle_rounded,
                            size: 18, color: m.color),
                    ]),
                  ),
                );
              }),
              const SizedBox(height: 6),

              // ── Campos según modo ─────────────────────────────
              if (_modo == ModoConexion.url) ...[
                const _Lbl('URL base del dispositivo'),
                TextFormField(
                  controller: _cUrl,
                  style: const TextStyle(color: C.t1),
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                      hintText: 'https://abc123.ngrok.io'),
                  onChanged: (_) => setState(() => _pingOk = null),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'URL requerida';
                    }
                    if (!v.trim().startsWith('http')) {
                      return 'Debe empezar con http o https';
                    }
                    return null;
                  },
                ),
              ] else ...[
                _Lbl(_modo == ModoConexion.lan
                    ? 'Dirección IP local'
                    : 'IP del dispositivo (datos móviles)'),
                TextFormField(
                  controller: _cIp,
                  style: const TextStyle(color: C.t1),
                  keyboardType:
                      const TextInputType.numberWithOptions(
                          decimal: true),
                  decoration: InputDecoration(
                      hintText: _modo.hint),
                  onChanged: (_) =>
                      setState(() => _pingOk = null),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'IP requerida';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                const _Lbl('Puerto'),
                TextFormField(
                  controller: _cPuerto,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: C.t1),
                  decoration: InputDecoration(
                    hintText: _tipo == TipoD.celular
                        ? '8888'
                        : '80',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Requerido';
                    }
                    if (int.tryParse(v.trim()) == null) {
                      return 'Solo números';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 14),

              // ── Habitación ────────────────────────────────────
              const _Lbl('Habitación / Zona'),
              TextFormField(
                controller: _cHab,
                style: const TextStyle(color: C.t1),
                decoration: const InputDecoration(
                    hintText: 'Sala, Cocina, Dormitorio...'),
              ),
              const SizedBox(height: 16),

              // ── Info ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _modo.glow,
                  borderRadius: R.xs,
                  border: Border.all(
                      color: _modo.color.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_rounded,
                        size: 14, color: _modo.color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_infoRuta(),
                          style: const TextStyle(
                              fontSize: 11, color: C.t2)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Ping ──────────────────────────────────────────
              OutlinedButton.icon(
                onPressed: _pinging ? null : _doPing,
                icon: _pinging
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: C.blue))
                    : Icon(
                        _pingOk == null
                            ? Icons.network_check_rounded
                            : _pingOk!
                                ? Icons.check_circle_rounded
                                : Icons.error_rounded,
                        size: 16,
                        color: _pingOk == null
                            ? C.t2
                            : _pingOk!
                                ? C.green
                                : C.red),
                label: Text(
                  _pinging
                      ? 'Verificando conexión...'
                      : _pingOk == null
                          ? 'Probar conexión'
                          : _pingOk!
                              ? 'Conexión OK ✓'
                              : 'Sin respuesta ✗',
                  style: TextStyle(
                      color: _pingOk == null
                          ? C.t2
                          : _pingOk!
                              ? C.green
                              : C.red),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  side: BorderSide(
                      color: _pingOk == null
                          ? C.border
                          : _pingOk!
                              ? C.green
                              : C.red),
                  shape: const RoundedRectangleBorder(
                      borderRadius: R.xs),
                ),
              ),
              const SizedBox(height: 10),

              // ── Guardar ───────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _doSave,
                  child: _saving
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white))
                      : const Text('Agregar dispositivo'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _doPing() async {
    setState(() { _pinging = true; _pingOk = null; });
    final ok = await NetCtrl.pingRaw(
      modo:    _modo,
      ip:      _cIp.text.trim(),
      puerto:  int.tryParse(_cPuerto.text.trim()) ?? 80,
      urlBase: _cUrl.text.trim(),
    );
    if (mounted) setState(() { _pinging = false; _pingOk = ok; });
  }

  Future<void> _doSave() async {
    if (!_fk.currentState!.validate()) return;
    setState(() => _saving = true);
    final ok = await widget.notifier.agregar(
      nombre:    _cNombre.text,
      tipo:      _tipo,
      cat:       _cat,
      modo:      _modo,
      ip:        _cIp.text,
      puerto:    int.tryParse(_cPuerto.text.trim()) ?? 80,
      urlBase:   _cUrl.text,
      habitacion: _cHab.text,
      skipPing:  widget.notifier.demo,
    );
    if (mounted) {
      setState(() => _saving = false);
      if (ok) {
        Navigator.pop(context);
        snack(context, 'Dispositivo agregado correctamente ✓');
      } else {
        final msg = switch (_modo) {
          ModoConexion.lan   =>
            'Sin respuesta.\nVerifica que estés en la misma red WiFi y que usesCleartextTraffic="true" esté en el AndroidManifest.',
          ModoConexion.movil =>
            'Sin respuesta desde ${_cIp.text}:${_cPuerto.text}.\nVerifica que la IP sea pública y el puerto esté abierto en el dispositivo.',
          ModoConexion.url   =>
            'Sin respuesta desde la URL.\nVerifica que el túnel (ngrok, Cloudflare, etc.) esté activo.',
        };
        snack(context, msg, error: true);
      }
    }
  }
}

// ════════════════════════════════════════════════════════════════
// PÁGINA: HISTORIAL
// ════════════════════════════════════════════════════════════════
class HistorialPage extends StatelessWidget {
  final DispositivosNotifier notifier;
  const HistorialPage({super.key, required this.notifier});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: notifier,
      builder: (_, __) {
        final log = notifier.log;
        return Scaffold(
          backgroundColor: C.bg,
          appBar: AppBar(
            backgroundColor: C.surface,
            title: const Text('Historial',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: C.t1)),
          ),
          body: log.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_rounded,
                          size: 46, color: C.t3),
                      SizedBox(height: 12),
                      Text('Sin actividad aún',
                          style: TextStyle(color: C.t2)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: log.length,
                  itemBuilder: (_, i) =>
                      _LogTile(e: log[i]),
                ),
        );
      },
    );
  }
}

class _LogTile extends StatelessWidget {
  final LogEntry e;
  const _LogTile({required this.e});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: C.card,
          borderRadius: R.xs,
          border: Border.all(color: C.border),
        ),
        child: Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: (e.ok ? C.green : C.red).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              e.ok ? Icons.check_rounded : Icons.close_rounded,
              size: 15, color: e.ok ? C.green : C.red,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.msg,
                    style: const TextStyle(
                        fontSize: 13, color: C.t1)),
                const SizedBox(height: 2),
                Text(_fmt(e.ts),
                    style: const TextStyle(
                        fontSize: 11, color: C.t3)),
              ],
            ),
          ),
        ]),
      );

  String _fmt(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'hace ${d.inSeconds}s';
    if (d.inMinutes < 60) return 'hace ${d.inMinutes}m';
    if (d.inHours < 24)   return 'hace ${d.inHours}h';
    return '${t.day}/${t.month}/${t.year} '
        '${t.hour}:${t.minute.toString().padLeft(2, '0')}';
  }
}

// ════════════════════════════════════════════════════════════════
// WIDGETS REUTILIZABLES
// ════════════════════════════════════════════════════════════════
class _Sw extends StatelessWidget {
  final bool val;
  final Color color;
  final ValueChanged<bool> onChange;
  const _Sw(
      {required this.val,
      required this.color,
      required this.onChange});
  @override
  Widget build(BuildContext context) => Switch(
        value: val,
        onChanged: onChange,
        activeColor: Colors.white,
        activeTrackColor: color,
        inactiveThumbColor: C.t3,
        inactiveTrackColor: C.surface,
        trackOutlineColor: WidgetStateProperty.resolveWith(
            (s) => val ? color.withOpacity(0.4) : C.border),
      );
}

class _IChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _IChip(this.icon, this.label);
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: C.t3),
        const SizedBox(width: 3),
        Text(label,
            style: const TextStyle(fontSize: 11, color: C.t3)),
      ]);
}

class _Lbl extends StatelessWidget {
  final String text;
  const _Lbl(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: C.t2)),
      );
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: C.t2,
          letterSpacing: 0.3));
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _IconBtn(
      {required this.icon,
      required this.color,
      required this.tooltip,
      required this.onTap});
  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: R.xs,
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
        ),
      );
}

class _DeleteDialog extends StatelessWidget {
  final String nombre;
  final VoidCallback onConfirm;
  const _DeleteDialog(
      {required this.nombre, required this.onConfirm});
  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: C.card,
        shape: const RoundedRectangleBorder(borderRadius: R.md),
        title: const Text('Eliminar dispositivo',
            style: TextStyle(color: C.t1, fontSize: 16)),
        content: Text(
          '¿Eliminar "$nombre"?\nNo se puede deshacer.',
          style: const TextStyle(color: C.t2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: onConfirm,
            style:
                TextButton.styleFrom(foregroundColor: C.red),
            child: const Text('Eliminar'),
          ),
        ],
      );
}
