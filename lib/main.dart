// ============================================================
//  DOMÓTICA PRO — Producción v2.1
//  Arquitectura: ChangeNotifier + SharedPreferences
//  Diseño: Glassmorphism Dark Premium
//  Correcciones: control de red con HttpClient, panel por habitaciones, edición
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────
// PUNTO DE ENTRADA
// ─────────────────────────────────────────────────────────
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
    systemNavigationBarColor: Color(0xFF0A0E1A),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  final prefs = await SharedPreferences.getInstance();
  final inicial = DispositivoRepo.cargarDesdePrefs(prefs);
  final notifier = DispositivosNotifier(inicial, prefs);
  runApp(DomoticaApp(notifier: notifier));
}

// ─────────────────────────────────────────────────────────
// CONSTANTES DE DISEÑO
// ─────────────────────────────────────────────────────────
class AppColors {
  static const bg         = Color(0xFF070B14);
  static const surface    = Color(0xFF0F1527);
  static const surfaceAlt = Color(0xFF141929);
  static const card       = Color(0xFF1A2035);
  static const border     = Color(0xFF252D45);
  static const accent     = Color(0xFF4F8EF7);
  static const accentGlow = Color(0x334F8EF7);
  static const green      = Color(0xFF2ECC8E);
  static const greenGlow  = Color(0x332ECC8E);
  static const orange     = Color(0xFFFF9142);
  static const orangeGlow = Color(0x33FF9142);
  static const red        = Color(0xFFFF5B7A);
  static const redGlow    = Color(0x33FF5B7A);
  static const purple     = Color(0xFF9B6DFF);
  static const purpleGlow = Color(0x339B6DFF);
  static const textPrimary   = Color(0xFFF0F4FF);
  static const textSecondary = Color(0xFF8B96B8);
  static const textMuted     = Color(0xFF4A5578);
}

class AppRadius {
  static const sm = BorderRadius.all(Radius.circular(10));
  static const md = BorderRadius.all(Radius.circular(16));
  static const lg = BorderRadius.all(Radius.circular(24));
  static const xl = BorderRadius.all(Radius.circular(32));
}

// ─────────────────────────────────────────────────────────
// MODELOS
// ─────────────────────────────────────────────────────────
enum TipoDispositivo { tasmota, sonoff, shelly, celular, otro }

extension TipoDispositivoExt on TipoDispositivo {
  String get nombre => switch (this) {
    TipoDispositivo.tasmota => 'Tasmota',
    TipoDispositivo.sonoff  => 'Sonoff',
    TipoDispositivo.shelly  => 'Shelly',
    TipoDispositivo.celular => 'Celular',
    TipoDispositivo.otro    => 'Otro',
  };
  IconData get icon => switch (this) {
    TipoDispositivo.tasmota => Icons.electrical_services_rounded,
    TipoDispositivo.sonoff  => Icons.bolt_rounded,
    TipoDispositivo.shelly  => Icons.wifi_rounded,
    TipoDispositivo.celular => Icons.smartphone_rounded,
    TipoDispositivo.otro    => Icons.device_unknown_rounded,
  };
  Color get color => switch (this) {
    TipoDispositivo.tasmota => AppColors.accent,
    TipoDispositivo.sonoff  => AppColors.orange,
    TipoDispositivo.shelly  => AppColors.green,
    TipoDispositivo.celular => AppColors.purple,
    TipoDispositivo.otro    => AppColors.textSecondary,
  };
  static TipoDispositivo fromString(String s) {
    return TipoDispositivo.values.firstWhere(
      (e) => e.name == s.toLowerCase(),
      orElse: () => TipoDispositivo.otro,
    );
  }
}

class LogEntry {
  final DateTime tiempo;
  final String mensaje;
  final bool exito;
  LogEntry({required this.tiempo, required this.mensaje, required this.exito});
}

class Dispositivo {
  final int id;
  String nombre;
  final TipoDispositivo tipo;
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
    'ip': ip,
    'puerto': puerto,
    'habitacion': habitacion,
    'encendido': encendido,
    'toggleCount': toggleCount,
    'ultimaAccion': ultimaAccion?.toIso8601String(),
  };

  factory Dispositivo.fromJson(Map<String, dynamic> j) => Dispositivo(
    id: j['id'],
    nombre: j['nombre'],
    tipo: TipoDispositivoExt.fromString(j['tipo'] ?? 'otro'),
    ip: j['ip'],
    puerto: j['puerto'] ?? 80,
    habitacion: j['habitacion'] ?? 'General',
    encendido: j['encendido'] ?? false,
    toggleCount: j['toggleCount'] ?? 0,
    ultimaAccion: j['ultimaAccion'] != null
        ? DateTime.tryParse(j['ultimaAccion'])
        : null,
  );

  Dispositivo copyWith({
    String? nombre,
    String? ip,
    int? puerto,
    String? habitacion,
    bool? encendido,
    DateTime? ultimaAccion,
    int? toggleCount,
  }) => Dispositivo(
    id: id,
    nombre: nombre ?? this.nombre,
    tipo: tipo,
    ip: ip ?? this.ip,
    puerto: puerto ?? this.puerto,
    habitacion: habitacion ?? this.habitacion,
    encendido: encendido ?? this.encendido,
    ultimaAccion: ultimaAccion ?? this.ultimaAccion,
    toggleCount: toggleCount ?? this.toggleCount,
  );
}

// ─────────────────────────────────────────────────────────
// REPOSITORIO (persistencia)
// ─────────────────────────────────────────────────────────
class DispositivoRepo {
  static List<Dispositivo> cargarDesdePrefs(SharedPreferences p) {
    try {
      final raw = p.getString('dispositivos_v2');
      if (raw == null) return [];
      final List list = jsonDecode(raw);
      return list.map((e) => Dispositivo.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static void guardar(SharedPreferences p, List<Dispositivo> items) {
    p.setString('dispositivos_v2', jsonEncode(items.map((d) => d.toJson()).toList()));
  }
}

// ─────────────────────────────────────────────────────────
// CONTROLADOR DE RED (HttpClient, más fiable)
// ─────────────────────────────────────────────────────────
class ControladorRed {
  // Envía un comando GET y verifica código HTTP 2xx
  static Future<bool> _sendCommand(String ip, int puerto, String path) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      final request = await client.get(ip, puerto, path);
      request.headers.add('Connection', 'close');
      final response = await request.close();
      await response.drain(); // Leer toda la respuesta para asegurar que el servidor procesa
      client.close();
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      return false;
    }
  }

  static String _pathEncender(TipoDispositivo t) => switch (t) {
    TipoDispositivo.tasmota => '/cm?cmnd=Power%20On',
    TipoDispositivo.sonoff  => '/control?cmd=on',
    TipoDispositivo.shelly  => '/relay/0?turn=on',
    _                       => '/on',
  };

  static String _pathApagar(TipoDispositivo t) => switch (t) {
    TipoDispositivo.tasmota => '/cm?cmnd=Power%20Off',
    TipoDispositivo.sonoff  => '/control?cmd=off',
    TipoDispositivo.shelly  => '/relay/0?turn=off',
    _                       => '/off',
  };

  static Future<bool> encender(Dispositivo d) => _sendCommand(
      d.ip, d.puerto,
      d.tipo == TipoDispositivo.celular ? '/on' : _pathEncender(d.tipo));

  static Future<bool> apagar(Dispositivo d) => _sendCommand(
      d.ip, d.puerto,
      d.tipo == TipoDispositivo.celular ? '/off' : _pathApagar(d.tipo));

  static Future<bool> probar(String ip, int puerto) async {
    try {
      final socket = await Socket.connect(ip, puerto, timeout: const Duration(seconds: 2));
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ─────────────────────────────────────────────────────────
// STATE NOTIFIER
// ─────────────────────────────────────────────────────────
class DispositivosNotifier extends ChangeNotifier {
  List<Dispositivo> _items = [];
  final SharedPreferences _prefs;
  int _nextId = 1;
  bool _modoDemo = false;
  bool _cargando = false;
  final List<LogEntry> _log = [];

  DispositivosNotifier(List<Dispositivo> inicial, this._prefs) {
    _items = List.of(inicial);
    if (_items.isNotEmpty) {
      _nextId = _items.map((d) => d.id).reduce((a, b) => a > b ? a : b) + 1;
    }
  }

  List<Dispositivo> get items       => List.unmodifiable(_items);
  bool             get modoDemo     => _modoDemo;
  bool             get cargando     => _cargando;
  List<LogEntry>   get log          => List.unmodifiable(_log.reversed.toList());
  List<String>     get habitaciones =>
      ['Todas', ..._items.map((d) => d.habitacion).toSet().toList()..sort()];

  int get encendidos => _items.where((d) => d.encendido).length;
  int get apagados   => _items.where((d) => !d.encendido).length;

  void toggleModoDemo() {
    _modoDemo = !_modoDemo;
    notifyListeners();
  }

  Future<bool> toggle(int id) async {
    final idx = _items.indexWhere((d) => d.id == id);
    if (idx == -1) return false;
    final d = _items[idx];

    _cargando = true;
    notifyListeners();

    bool ok;
    if (_modoDemo) {
      await Future.delayed(const Duration(milliseconds: 400));
      ok = true;
    } else {
      ok = d.encendido
          ? await ControladorRed.apagar(d)
          : await ControladorRed.encender(d);
    }

    if (ok) {
      _items[idx] = d.copyWith(
        encendido: !d.encendido,
        ultimaAccion: DateTime.now(),
        toggleCount: d.toggleCount + 1,
      );
      _agregarLog('${d.nombre} ${_items[idx].encendido ? "encendido" : "apagado"}',
          exito: true);
    } else {
      _agregarLog('Error al controlar ${d.nombre}', exito: false);
    }

    _cargando = false;
    notifyListeners();
    _guardar();
    return ok;
  }

  Future<bool> toggleTodos(bool encender) async {
    bool alguno = false;
    for (final d in _items) {
      if (d.encendido != encender) {
        final ok = await toggle(d.id);
        if (ok) alguno = true;
      }
    }
    return alguno;
  }

  Future<bool> agregar({
    required String nombre,
    required TipoDispositivo tipo,
    required String ip,
    required int puerto,
    required String habitacion,
    bool skipPing = false,
  }) async {
    if (!skipPing && !_modoDemo) {
      final ok = await ControladorRed.probar(ip, puerto);
      if (!ok) return false;
    }
    _items.add(Dispositivo(
      id: _nextId++,
      nombre: nombre.trim(),
      tipo: tipo,
      ip: ip.trim(),
      puerto: puerto,
      habitacion: habitacion.trim().isEmpty ? 'General' : habitacion.trim(),
    ));
    _agregarLog('Dispositivo "${nombre.trim()}" agregado', exito: true);
    notifyListeners();
    _guardar();
    return true;
  }

  Future<bool> actualizar(Dispositivo dispositivoActualizado) async {
    final idx = _items.indexWhere((d) => d.id == dispositivoActualizado.id);
    if (idx == -1) return false;
    // Mantener el estado encendido y contador original (solo se actualizan datos fijos)
    final original = _items[idx];
    _items[idx] = dispositivoActualizado.copyWith(
      encendido: original.encendido,
      ultimaAccion: original.ultimaAccion,
      toggleCount: original.toggleCount,
    );
    _agregarLog('Dispositivo "${dispositivoActualizado.nombre}" actualizado', exito: true);
    notifyListeners();
    _guardar();
    return true;
  }

  void eliminar(int id) {
    final d = _items.firstWhere((x) => x.id == id, orElse: () => _items.first);
    _items.removeWhere((x) => x.id == id);
    _agregarLog('Dispositivo "${d.nombre}" eliminado', exito: true);
    notifyListeners();
    _guardar();
  }

  void limpiarLog() {
    _log.clear();
    notifyListeners();
  }

  void _agregarLog(String msg, {required bool exito}) {
    _log.add(LogEntry(tiempo: DateTime.now(), mensaje: msg, exito: exito));
    if (_log.length > 100) _log.removeAt(0);
  }

  void _guardar() => DispositivoRepo.guardar(_prefs, _items);
}

// ─────────────────────────────────────────────────────────
// APP ROOT
// ─────────────────────────────────────────────────────────
class DomoticaApp extends StatelessWidget {
  final DispositivosNotifier notifier;
  const DomoticaApp({super.key, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: notifier,
      builder: (_, __) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Domótica Pro',
        theme: _buildTheme(),
        home: MainShell(notifier: notifier),
      ),
    );
  }

  ThemeData _buildTheme() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.green,
      surface: AppColors.surface,
      onPrimary: Colors.white,
      onSurface: AppColors.textPrimary,
    ),
    fontFamily: 'SF Pro Display',
    cardTheme: const CardThemeData(
      color: AppColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    dividerColor: AppColors.border,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceAlt,
      border: OutlineInputBorder(
        borderRadius: AppRadius.sm,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.sm,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.sm,
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      hintStyle: const TextStyle(color: AppColors.textMuted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sm),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.card,
      contentTextStyle: TextStyle(color: AppColors.textPrimary),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

// ─────────────────────────────────────────────────────────
// SHELL PRINCIPAL (navegación inferior con 4 pestañas)
// ─────────────────────────────────────────────────────────
class MainShell extends StatefulWidget {
  final DispositivosNotifier notifier;
  const MainShell({super.key, required this.notifier});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(notifier: widget.notifier),
      RoomsPage(notifier: widget.notifier),
      DispositivosPage(notifier: widget.notifier),
      HistorialPage(notifier: widget.notifier),
    ];

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: KeyedSubtree(key: ValueKey(_tab), child: pages[_tab]),
      ),
      bottomNavigationBar: _NavBar(
        current: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int current;
  final void Function(int) onTap;
  const _NavBar({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.dashboard_rounded,   label: 'Panel',      index: 0, current: current, onTap: onTap),
              _NavItem(icon: Icons.meeting_room_rounded, label: 'Habitaciones', index: 1, current: current, onTap: onTap),
              _NavItem(icon: Icons.devices_rounded,     label: 'Dispositivos', index: 2, current: current, onTap: onTap),
              _NavItem(icon: Icons.history_rounded,     label: 'Historial',   index: 3, current: current, onTap: onTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String   label;
  final int      index;
  final int      current;
  final void Function(int) onTap;
  const _NavItem({
    required this.icon, required this.label, required this.index,
    required this.current, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.accentGlow : Colors.transparent,
          borderRadius: AppRadius.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: active ? AppColors.accent : AppColors.textMuted,
                size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? AppColors.accent : AppColors.textMuted,
                )),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// PÁGINA: DASHBOARD (resumen)
// ─────────────────────────────────────────────────────────
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
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notifier;
    return AnimatedBuilder(
      animation: n,
      builder: (_, __) {
        final items = n.items;
        final enc   = n.encendidos;
        final total = items.length;
        final porcentaje = total == 0 ? 0.0 : enc / total;

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 180,
              pinned: true,
              backgroundColor: AppColors.bg,
              flexibleSpace: FlexibleSpaceBar(
                background: _DashHeader(
                  pulse: _pulse,
                  encendidos: enc,
                  total: total,
                  modoDemo: n.modoDemo,
                  onToggleDemo: n.toggleModoDemo,
                ),
              ),
              title: const Text('Domótica Pro',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              actions: [
                _AccionRapidaBtn(
                  icon: Icons.power_settings_new_rounded,
                  color: enc > 0 ? AppColors.red : AppColors.green,
                  tooltip: enc > 0 ? 'Apagar todo' : 'Encender todo',
                  onPressed: () => n.toggleTodos(enc == 0),
                ),
                const SizedBox(width: 8),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Row(children: [
                      _StatCard(label: 'Encendidos', value: enc.toString(),
                          icon: Icons.power_rounded, color: AppColors.green,
                          glow: AppColors.greenGlow, flex: 1),
                      const SizedBox(width: 12),
                      _StatCard(label: 'Apagados', value: (total - enc).toString(),
                          icon: Icons.power_off_rounded, color: AppColors.red,
                          glow: AppColors.redGlow, flex: 1),
                      const SizedBox(width: 12),
                      _StatCard(label: 'Total', value: total.toString(),
                          icon: Icons.devices_rounded, color: AppColors.accent,
                          glow: AppColors.accentGlow, flex: 1),
                    ]),
                    const SizedBox(height: 20),
                    _ActivityBar(porcentaje: porcentaje, encendidos: enc, total: total),
                    const SizedBox(height: 24),
                    if (items.isNotEmpty) ...[
                      _SectionTitle('Últimos dispositivos'),
                      const SizedBox(height: 12),
                      ...items.reversed.take(3).map((d) => _RecentDeviceTile(
                          dispositivo: d, notifier: n)),
                    ] else
                      _EmptyDashboard(),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
// PÁGINA: HABITACIONES (control principal)
// ─────────────────────────────────────────────────────────
class RoomsPage extends StatelessWidget {
  final DispositivosNotifier notifier;
  const RoomsPage({super.key, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: notifier,
      builder: (_, __) {
        final roomsMap = <String, List<Dispositivo>>{};
        for (final d in notifier.items) {
          roomsMap.putIfAbsent(d.habitacion, () => []).add(d);
        }
        final rooms = roomsMap.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));

        return Scaffold(
          backgroundColor: AppColors.bg,
          body: CustomScrollView(
            slivers: [
              const SliverAppBar(
                pinned: true,
                backgroundColor: AppColors.surface,
                title: Text('Habitaciones',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              if (rooms.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text('No hay dispositivos',
                      style: TextStyle(color: AppColors.textSecondary))),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final room = rooms[i];
                        return _RoomCard(
                          nombre: room.key,
                          dispositivos: room.value,
                          notifier: notifier,
                        );
                      },
                      childCount: rooms.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RoomCard extends StatelessWidget {
  final String nombre;
  final List<Dispositivo> dispositivos;
  final DispositivosNotifier notifier;
  const _RoomCard({
    required this.nombre, required this.dispositivos, required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    final encendidos = dispositivos.where((d) => d.encendido).length;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(_habitacionIcon(nombre), color: AppColors.accent, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(nombre,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                ),
                _ChipStatus(enc: encendidos, total: dispositivos.length),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: dispositivos.map((d) => _RoomDeviceTile(
                  dispositivo: d, notifier: notifier)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  IconData _habitacionIcon(String nombre) {
    final n = nombre.toLowerCase();
    if (n.contains('sala'))     return Icons.weekend_rounded;
    if (n.contains('cocina'))   return Icons.kitchen_rounded;
    if (n.contains('baño'))     return Icons.bathtub_rounded;
    if (n.contains('cuarto') || n.contains('dormit') || n.contains('habit'))
                                return Icons.bed_rounded;
    if (n.contains('garaje'))   return Icons.garage_rounded;
    if (n.contains('jardín') || n.contains('jardin') || n.contains('patio'))
                                return Icons.yard_rounded;
    if (n.contains('oficina'))  return Icons.computer_rounded;
    return Icons.home_rounded;
  }
}

class _RoomDeviceTile extends StatefulWidget {
  final Dispositivo dispositivo;
  final DispositivosNotifier notifier;
  const _RoomDeviceTile({required this.dispositivo, required this.notifier});

  @override
  State<_RoomDeviceTile> createState() => _RoomDeviceTileState();
}

class _RoomDeviceTileState extends State<_RoomDeviceTile> {
  bool _toggling = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.dispositivo;
    final color = d.tipo.color;
    return SizedBox(
      width: 140,
      child: Card(
        color: AppColors.surfaceAlt,
        shape: RoundedRectangleBorder(
            borderRadius: AppRadius.sm,
            side: BorderSide(color: d.encendido ? color : AppColors.border, width: 0.5)),
        child: InkWell(
          borderRadius: AppRadius.sm,
          onTap: _toggling ? null : () async {
            setState(() => _toggling = true);
            await widget.notifier.toggle(d.id);
            if (mounted) setState(() => _toggling = false);
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Icon(d.tipo.icon, size: 32, color: d.encendido ? color : AppColors.textMuted),
                const SizedBox(height: 8),
                Text(d.nombre,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                if (_toggling)
                  const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else
                  Switch(
                    value: d.encendido,
                    onChanged: (_) {},
                    activeColor: Colors.white,
                    activeTrackColor: color,
                    inactiveTrackColor: AppColors.border,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// PÁGINA: DISPOSITIVOS (gestión + edición)
// ─────────────────────────────────────────────────────────
class DispositivosPage extends StatefulWidget {
  final DispositivosNotifier notifier;
  const DispositivosPage({super.key, required this.notifier});

  @override
  State<DispositivosPage> createState() => _DispositivosPageState();
}

class _DispositivosPageState extends State<DispositivosPage> {
  String _habitacionFiltro = 'Todas';
  String _busqueda = '';

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_rounded : Icons.check_circle_rounded,
            color: error ? AppColors.red : AppColors.green, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: AppColors.card,
      margin: const EdgeInsets.all(12),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.sm),
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.notifier,
      builder: (_, __) {
        final n = widget.notifier;
        final habs = n.habitaciones;
        var items = n.items.where((d) {
          final matchHab = _habitacionFiltro == 'Todas' ||
              d.habitacion == _habitacionFiltro;
          final matchBusq = _busqueda.isEmpty ||
              d.nombre.toLowerCase().contains(_busqueda.toLowerCase()) ||
              d.ip.contains(_busqueda);
          return matchHab && matchBusq;
        }).toList();

        return Scaffold(
          backgroundColor: AppColors.bg,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: AppColors.surface,
                title: const Text('Dispositivos',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(110),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      children: [
                        TextField(
                          onChanged: (v) => setState(() => _busqueda = v),
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Buscar dispositivo o IP...',
                            prefixIcon: const Icon(Icons.search_rounded,
                                color: AppColors.textMuted, size: 20),
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 34,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: habs.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (_, i) {
                              final h = habs[i];
                              final sel = h == _habitacionFiltro;
                              return GestureDetector(
                                onTap: () => setState(() => _habitacionFiltro = h),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: sel ? AppColors.accent : AppColors.surfaceAlt,
                                    borderRadius: AppRadius.xl,
                                    border: Border.all(color: sel ? AppColors.accent : AppColors.border),
                                  ),
                                  child: Text(h,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: sel ? Colors.white : AppColors.textSecondary)),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (items.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text('Sin resultados',
                      style: TextStyle(color: AppColors.textSecondary))),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _DeviceCard(
                        dispositivo: items[i],
                        notifier: n,
                        onSnack: _snack,
                      ),
                      childCount: items.length,
                    ),
                  ),
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _mostrarOpciones(context),
            backgroundColor: AppColors.accent,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar'),
          ),
        );
      },
    );
  }

  void _mostrarOpciones(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('¿Qué tipo de dispositivo?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            _TipoBtn(
              icon: Icons.electrical_services_rounded,
              label: 'IoT — Tasmota / Sonoff / Shelly',
              sub: 'Conexión directa por red local',
              color: AppColors.accent,
              onTap: () {
                Navigator.pop(ctx);
                _abrirForm(ctx, esCelular: false);
              },
            ),
            const SizedBox(height: 12),
            _TipoBtn(
              icon: Icons.smartphone_rounded,
              label: 'Celular con linterna',
              sub: 'Puerto personalizable, rutas /on y /off',
              color: AppColors.purple,
              onTap: () {
                Navigator.pop(ctx);
                _abrirForm(ctx, esCelular: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _abrirForm(BuildContext ctx, {required bool esCelular, Dispositivo? editar}) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _FormAgregarDispositivo(
        esCelular: esCelular,
        notifier: widget.notifier,
        onSnack: _snack,
        editar: editar,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// TARJETA DE DISPOSITIVO (con edición y eliminación)
// ─────────────────────────────────────────────────────────
class _DeviceCard extends StatefulWidget {
  final Dispositivo dispositivo;
  final DispositivosNotifier notifier;
  final void Function(String, {bool error}) onSnack;
  const _DeviceCard({
    required this.dispositivo, required this.notifier, required this.onSnack,
  });

  @override
  State<_DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<_DeviceCard>
    with SingleTickerProviderStateMixin {
  bool _toggling = false;
  late AnimationController _glow;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.dispositivo;
    final color = d.encendido ? d.tipo.color : AppColors.textMuted;

    return GestureDetector(
      onLongPress: () => _mostrarMenu(context, d),
      child: AnimatedBuilder(
        animation: _glow,
        builder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: AppRadius.md,
            border: Border.all(
              color: d.encendido
                  ? d.tipo.color.withOpacity(0.3 + _glow.value * 0.15)
                  : AppColors.border,
              width: d.encendido ? 1.5 : 0.5,
            ),
            boxShadow: d.encendido
                ? [BoxShadow(color: d.tipo.color.withOpacity(0.08 + _glow.value * 0.06),
                            blurRadius: 12, spreadRadius: 1)]
                : [],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: d.encendido ? d.tipo.color.withOpacity(0.18) : AppColors.surfaceAlt,
                        borderRadius: AppRadius.sm,
                      ),
                      child: Icon(d.tipo.icon, size: 24,
                          color: d.encendido ? d.tipo.color : AppColors.textMuted),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.nombre,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          Row(children: [
                            _Badge(d.tipo.nombre, color: d.tipo.color),
                            const SizedBox(width: 8),
                            _Badge(d.habitacion, color: AppColors.textSecondary),
                          ]),
                        ],
                      ),
                    ),
                    if (_toggling)
                      const SizedBox(width: 28, height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      _PulseSwitch(
                        value: d.encendido,
                        color: d.tipo.color,
                        onChanged: (_) async {
                          setState(() => _toggling = true);
                          final ok = await widget.notifier.toggle(d.id);
                          if (mounted) {
                            setState(() => _toggling = false);
                            if (!ok) widget.onSnack('Error al controlar ${d.nombre}', error: true);
                          }
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _InfoChip(icon: Icons.wifi_rounded,
                        label: d.tipo == TipoDispositivo.celular ? '${d.ip}:${d.puerto}' : d.ip),
                    const SizedBox(width: 8),
                    _InfoChip(icon: Icons.toggle_on_rounded, label: '${d.toggleCount} cambios'),
                    const Spacer(),
                    if (d.ultimaAccion != null)
                      _InfoChip(icon: Icons.access_time_rounded,
                          label: _tiempoRelativo(d.ultimaAccion!)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarMenu(BuildContext ctx, Dispositivo d) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: AppColors.accent),
              title: const Text('Editar dispositivo'),
              onTap: () {
                Navigator.pop(ctx);
                _abrirFormEditar(ctx, d);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: AppColors.red),
              title: const Text('Eliminar dispositivo'),
              onTap: () {
                Navigator.pop(ctx);
                _confirmarEliminar(ctx, d);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _abrirFormEditar(BuildContext ctx, Dispositivo d) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _FormAgregarDispositivo(
        esCelular: d.tipo == TipoDispositivo.celular,
        notifier: widget.notifier,
        onSnack: widget.onSnack,
        editar: d,
      ),
    );
  }

  void _confirmarEliminar(BuildContext ctx, Dispositivo d) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
        title: const Text('Eliminar dispositivo'),
        content: Text('¿Eliminar "${d.nombre}"?\nEsta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              widget.notifier.eliminar(d.id);
              Navigator.pop(ctx);
              widget.onSnack('Dispositivo eliminado');
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  String _tiempoRelativo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'hace ${diff.inSeconds}s';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes}m';
    if (diff.inHours < 24)   return 'hace ${diff.inHours}h';
    return 'hace ${diff.inDays}d';
  }
}

// ─────────────────────────────────────────────────────────
// FORMULARIO AGREGAR / EDITAR DISPOSITIVO
// ─────────────────────────────────────────────────────────
class _FormAgregarDispositivo extends StatefulWidget {
  final bool esCelular;
  final DispositivosNotifier notifier;
  final void Function(String, {bool error}) onSnack;
  final Dispositivo? editar;
  const _FormAgregarDispositivo({
    required this.esCelular, required this.notifier, required this.onSnack,
    this.editar,
  });

  @override
  State<_FormAgregarDispositivo> createState() => _FormAgregarDispositivoState();
}

class _FormAgregarDispositivoState extends State<_FormAgregarDispositivo> {
  final _formKey    = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _ipCtrl     = TextEditingController();
  final _puertoCtrl = TextEditingController();
  final _habCtrl    = TextEditingController();
  TipoDispositivo _tipo = TipoDispositivo.tasmota;
  bool _guardando   = false;
  bool _probando    = false;
  bool? _pingOk;

  static const tiposIot = [
    TipoDispositivo.tasmota,
    TipoDispositivo.sonoff,
    TipoDispositivo.shelly,
    TipoDispositivo.otro,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.editar != null) {
      final d = widget.editar!;
      _nombreCtrl.text = d.nombre;
      _ipCtrl.text = d.ip;
      _puertoCtrl.text = d.puerto.toString();
      _habCtrl.text = d.habitacion;
      _tipo = d.tipo;
    } else {
      if (widget.esCelular) {
        _tipo = TipoDispositivo.celular;
        _puertoCtrl.text = '8080';
      } else {
        _puertoCtrl.text = '80';
        _habCtrl.text = 'General';
      }
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose(); _ipCtrl.dispose();
    _puertoCtrl.dispose(); _habCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Icon(widget.esCelular ? Icons.smartphone_rounded : Icons.electrical_services_rounded,
                    color: widget.esCelular ? AppColors.purple : AppColors.accent, size: 22),
                const SizedBox(width: 10),
                Text(widget.editar != null
                    ? 'Editar dispositivo'
                    : (widget.esCelular ? 'Agregar celular' : 'Agregar dispositivo IoT'),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 20),
              _Label('Nombre'), TextFormField(controller: _nombreCtrl,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null),
              const SizedBox(height: 14),
              if (!widget.esCelular && widget.editar == null) ...[
                _Label('Tipo'), Wrap(spacing: 8, runSpacing: 8,
                  children: tiposIot.map((t) => GestureDetector(
                    onTap: () => setState(() => _tipo = t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _tipo == t ? t.color.withOpacity(0.2) : AppColors.surfaceAlt,
                        borderRadius: AppRadius.sm,
                        border: Border.all(color: _tipo == t ? t.color : AppColors.border),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(t.icon, size: 14, color: _tipo == t ? t.color : AppColors.textMuted),
                        const SizedBox(width: 6),
                        Text(t.nombre, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                            color: _tipo == t ? t.color : AppColors.textSecondary)),
                      ]),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 14),
              ],
              _Label('IP'), TextFormField(controller: _ipCtrl,
                  onChanged: (_) => setState(() => _pingOk = null),
                  validator: (v) => v == null || v.trim().isEmpty ? 'IP requerida' : null),
              const SizedBox(height: 14),
              _Label('Puerto'), TextFormField(controller: _puertoCtrl, keyboardType: TextInputType.number,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null),
              const SizedBox(height: 14),
              _Label('Habitación'), TextFormField(controller: _habCtrl),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _probando ? null : _probarConexion,
                icon: _probando ? const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(_pingOk == null ? Icons.network_check_rounded
                        : (_pingOk! ? Icons.check_circle_rounded : Icons.error_rounded),
                        size: 18, color: _pingOk == null ? AppColors.textSecondary
                        : (_pingOk! ? AppColors.green : AppColors.red)),
                label: Text(_probando ? 'Probando...'
                    : (_pingOk == null ? 'Probar conexión'
                        : (_pingOk! ? 'Conexión exitosa' : 'Sin respuesta')),
                    style: TextStyle(color: _pingOk == null ? AppColors.textSecondary
                        : (_pingOk! ? AppColors.green : AppColors.red))),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _pingOk == null ? AppColors.border
                      : (_pingOk! ? AppColors.green : AppColors.red)),
                  shape: const RoundedRectangleBorder(borderRadius: AppRadius.sm),
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity,
                child: ElevatedButton(
                  onPressed: _guardando ? null : _guardar,
                  child: _guardando ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Guardar'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _probarConexion() async {
    final ip = _ipCtrl.text.trim();
    final puerto = int.tryParse(_puertoCtrl.text.trim()) ?? 80;
    if (ip.isEmpty) { widget.onSnack('Ingresa una IP', error: true); return; }
    setState(() { _probando = true; _pingOk = null; });
    final ok = await ControladorRed.probar(ip, puerto);
    if (mounted) setState(() { _probando = false; _pingOk = ok; });
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    bool ok;
    if (widget.editar != null) {
      final editado = widget.editar!.copyWith(
        nombre: _nombreCtrl.text.trim(),
        ip: _ipCtrl.text.trim(),
        puerto: int.parse(_puertoCtrl.text.trim()),
        habitacion: _habCtrl.text.trim().isEmpty ? 'General' : _habCtrl.text.trim(),
      );
      ok = await widget.notifier.actualizar(editado);
    } else {
      ok = await widget.notifier.agregar(
        nombre: _nombreCtrl.text,
        tipo: _tipo,
        ip: _ipCtrl.text,
        puerto: int.parse(_puertoCtrl.text.trim()),
        habitacion: _habCtrl.text,
        skipPing: widget.notifier.modoDemo,
      );
    }
    if (mounted) {
      setState(() => _guardando = false);
      if (ok) {
        Navigator.pop(context);
        widget.onSnack(widget.editar != null ? 'Dispositivo actualizado' : 'Dispositivo agregado');
      } else {
        widget.onSnack('No se pudo conectar al dispositivo', error: true);
      }
    }
  }
}

// ─────────────────────────────────────────────────────────
// PÁGINA: HISTORIAL
// ─────────────────────────────────────────────────────────
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
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            title: const Text('Historial', style: TextStyle(fontWeight: FontWeight.w700)),
            actions: [
              if (log.isNotEmpty)
                TextButton(onPressed: notifier.limpiarLog, child: const Text('Limpiar')),
            ],
          ),
          body: log.isEmpty
              ? const Center(child: Text('Sin actividad registrada',
                    style: TextStyle(color: AppColors.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: log.length,
                  itemBuilder: (_, i) => _LogTile(entry: log[i]),
                ),
        );
      },
    );
  }
}

class _LogTile extends StatelessWidget {
  final LogEntry entry;
  const _LogTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.sm,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(width: 32, height: 32,
            decoration: BoxDecoration(
              color: (entry.exito ? AppColors.green : AppColors.red).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(entry.exito ? Icons.check_rounded : Icons.close_rounded,
                size: 16, color: entry.exito ? AppColors.green : AppColors.red),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.mensaje, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                const SizedBox(height: 3),
                Text(_fmt(entry.tiempo), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inSeconds < 60) return 'hace ${diff.inSeconds}s';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes}m';
    if (diff.inHours < 24)   return 'hace ${diff.inHours}h';
    return '${t.day}/${t.month}/${t.year} ${t.hour}:${t.minute.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────
// WIDGETS COMPARTIDOS
// ─────────────────────────────────────────────────────────

class _PulseSwitch extends StatelessWidget {
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;
  const _PulseSwitch({required this.value, required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeColor: Colors.white,
      activeTrackColor: color,
      inactiveThumbColor: AppColors.textMuted,
      inactiveTrackColor: AppColors.surfaceAlt,
      trackOutlineColor: WidgetStateProperty.resolveWith((states) =>
          value ? color.withOpacity(0.4) : AppColors.border),
    );
  }
}

class _AccionRapidaBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;
  const _AccionRapidaBtn({required this.icon, required this.color,
    required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(width: 36, height: 36,
          decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: AppRadius.sm,
              border: Border.all(color: color.withOpacity(0.3))),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: AppRadius.xl),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: AppColors.textMuted),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
    ]);
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
        color: AppColors.textSecondary, letterSpacing: 0.5));
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: AppColors.textSecondary)));
  }
}

class _TipoBtn extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final Color color;
  final VoidCallback onTap;
  const _TipoBtn({required this.icon, required this.label,
    required this.sub, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: AppRadius.sm,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: AppRadius.sm),
              child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 3),
            Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ])),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// WIDGETS FALTANTES PARA DASHBOARD
// ─────────────────────────────────────────────────────────
class _DashHeader extends StatelessWidget {
  final Animation<double> pulse;
  final int encendidos, total;
  final bool modoDemo;
  final VoidCallback onToggleDemo;
  const _DashHeader({required this.pulse, required this.encendidos,
    required this.total, required this.modoDemo, required this.onToggleDemo});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF0D1528), Color(0xFF070B14)])),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 56, 16, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_saludo(), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text('$encendidos de $total activos',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
              ])),
          AnimatedBuilder(animation: pulse, builder: (_, __) => GestureDetector(
            onTap: onToggleDemo,
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: modoDemo ? Color.lerp(AppColors.orangeGlow,
                    AppColors.orange.withOpacity(0.15), pulse.value)! : AppColors.surfaceAlt,
                borderRadius: AppRadius.sm,
                border: Border.all(color: modoDemo ? AppColors.orange.withOpacity(0.5) : AppColors.border),
              ),
              child: Row(children: [
                Icon(Icons.science_rounded, size: 14,
                    color: modoDemo ? AppColors.orange : AppColors.textMuted),
                const SizedBox(width: 6),
                Text('DEMO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: modoDemo ? AppColors.orange : AppColors.textMuted)),
              ]),
            ),
          )),
        ]),
      ),
    );
  }

  String _saludo() { final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días ☀️';
    if (h < 18) return 'Buenas tardes 🌤️';
    return 'Buenas noches 🌙';
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color, glow;
  final int flex;
  const _StatCard({required this.label, required this.value, required this.icon,
    required this.color, required this.glow, required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(flex: flex,
      child: Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: AppRadius.md,
            border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: glow, borderRadius: AppRadius.sm),
              child: Icon(icon, color: color, size: 16)),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ]),
      ),
    );
  }
}

class _ActivityBar extends StatelessWidget {
  final double porcentaje;
  final int encendidos, total;
  const _ActivityBar({required this.porcentaje, required this.encendidos, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: AppRadius.md,
          border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Actividad global', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Text('${(porcentaje * 100).round()}%', style: const TextStyle(fontSize: 13,
              fontWeight: FontWeight.w700, color: AppColors.accent)),
        ]),
        const SizedBox(height: 12),
        ClipRRect(borderRadius: AppRadius.xl,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: porcentaje),
            duration: const Duration(milliseconds: 600),
            builder: (_, val, __) => LinearProgressIndicator(value: val, minHeight: 8,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent)),
          ),
        ),
        const SizedBox(height: 8),
        Text('$encendidos de $total dispositivos activos',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ]),
    );
  }
}

class _RecentDeviceTile extends StatelessWidget {
  final Dispositivo dispositivo;
  final DispositivosNotifier notifier;
  const _RecentDeviceTile({required this.dispositivo, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: AppRadius.sm,
          border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Icon(dispositivo.tipo.icon, color: dispositivo.tipo.color, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(dispositivo.nombre,
            style: const TextStyle(fontWeight: FontWeight.w500))),
        _PulseSwitch(value: dispositivo.encendido, color: dispositivo.tipo.color,
            onChanged: (_) => notifier.toggle(dispositivo.id)),
      ]),
    );
  }
}

class _EmptyDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(margin: const EdgeInsets.symmetric(vertical: 32),
      child: Center(child: Column(children: [
        Container(padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(color: AppColors.accentGlow, shape: BoxShape.circle),
            child: const Icon(Icons.devices_other_rounded, size: 52, color: AppColors.accent)),
        const SizedBox(height: 16),
        const Text('Sin dispositivos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('Agrega tu primer dispositivo\ndesde la pestaña Dispositivos',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      ])),
    );
  }
}

class _ChipStatus extends StatelessWidget {
  final int enc, total;
  const _ChipStatus({required this.enc, required this.total});

  @override
  Widget build(BuildContext context) {
    final color = enc == 0
        ? AppColors.textMuted
        : enc == total
            ? AppColors.green
            : AppColors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: AppRadius.xl,
      ),
      child: Text('$enc/$total',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
