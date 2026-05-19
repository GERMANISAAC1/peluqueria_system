// ignore_for_file: avoid_classes_with_only_static_members
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════════
// PUNTO DE ENTRADA
// ═══════════════════════════════════════════════════════════════

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  final prefs   = await SharedPreferences.getInstance();
  final inicial = _cargarDesdePrefs(prefs);
  final notifier = DispositivosNotifier(inicial);

  runApp(_RealApp(notifier: notifier));
}

List<Dispositivo> _cargarDesdePrefs(SharedPreferences prefs) {
  try {
    final raw = prefs.getString('dispositivos');
    if (raw == null) return _dispositivosDemo();
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Dispositivo.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return _dispositivosDemo();
  }
}

List<Dispositivo> _dispositivosDemo() => [
      Dispositivo(id: 1, nombre: 'Sala',       tipo: 'Tasmota', habitacion: 'Sala',       encendido: true),
      Dispositivo(id: 2, nombre: 'Cocina',      tipo: 'Celular',  habitacion: 'Cocina',    encendido: false),
      Dispositivo(id: 3, nombre: 'Dormitorio',  tipo: 'Cortina',  habitacion: 'Dormitorio',encendido: false),
      Dispositivo(id: 4, nombre: 'Patio',       tipo: 'Escena',   habitacion: 'Exterior',  encendido: true),
      Dispositivo(id: 5, nombre: 'Garaje',      tipo: 'Tasmota',  habitacion: 'Garaje',    encendido: false),
      Dispositivo(id: 6, nombre: 'Oficina',     tipo: 'Celular',  habitacion: 'Oficina',   encendido: false),
    ];

// ═══════════════════════════════════════════════════════════════
// MODELO — inmutable, serializable, con copyWith
// ═══════════════════════════════════════════════════════════════

class Dispositivo {
  final int    id;
  final String nombre;
  final String tipo;
  final String habitacion;
  final bool   encendido;

  const Dispositivo({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.habitacion,
    this.encendido = false,
  });

  Dispositivo copyWith({
    int?    id,
    String? nombre,
    String? tipo,
    String? habitacion,
    bool?   encendido,
  }) =>
      Dispositivo(
        id:         id         ?? this.id,
        nombre:     nombre     ?? this.nombre,
        tipo:       tipo       ?? this.tipo,
        habitacion: habitacion ?? this.habitacion,
        encendido:  encendido  ?? this.encendido,
      );

  Map<String, dynamic> toJson() => {
        'id':         id,
        'nombre':     nombre,
        'tipo':       tipo,
        'habitacion': habitacion,
        'encendido':  encendido,
      };

  factory Dispositivo.fromJson(Map<String, dynamic> j) => Dispositivo(
        id:         j['id']         as int,
        nombre:     j['nombre']     as String,
        tipo:       j['tipo']       as String,
        habitacion: j['habitacion'] as String,
        encendido:  j['encendido']  as bool? ?? false,
      );

  @override
  bool operator ==(Object other) => other is Dispositivo && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ═══════════════════════════════════════════════════════════════
// ESTADO GLOBAL — ChangeNotifier sin paquetes externos
// ═══════════════════════════════════════════════════════════════

class DispositivosNotifier extends ChangeNotifier {
  List<Dispositivo> _items;
  int _nextId;
  SharedPreferences? _prefs;

  DispositivosNotifier(List<Dispositivo> initial)
      : _items  = List.of(initial),
        _nextId = initial.isEmpty
            ? 1
            : initial.map((d) => d.id).reduce((a, b) => a > b ? a : b) + 1 {
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
  }

  List<Dispositivo> get items => List.unmodifiable(_items);

  int get encendidos  => _items.where((d) => d.encendido).length;
  int get roomsCount  => _items.map((d) => d.habitacion).toSet().length;

  int get consumoWatts {
    var total = 0;
    for (final d in _items) {
      if (d.encendido) total += kTipos[d.tipo]?.wattsPromedio ?? 40;
    }
    return total;
  }

  List<String> get rooms {
    final set = <String>{};
    for (final d in _items) set.add(d.habitacion);
    return ['all', ...set.toList()..sort()];
  }

  void toggle(int id) {
    final idx = _items.indexWhere((d) => d.id == id);
    if (idx == -1) return;
    _items[idx] = _items[idx].copyWith(encendido: !_items[idx].encendido);
    notifyListeners();
    _persistir();
  }

  void agregar(String nombre, String tipo, String habitacion) {
    _items.add(Dispositivo(
      id:         _nextId++,
      nombre:     nombre.trim(),
      tipo:       tipo,
      habitacion: habitacion.trim().isEmpty ? 'General' : habitacion.trim(),
    ));
    notifyListeners();
    _persistir();
  }

  void eliminar(int id) {
    _items.removeWhere((d) => d.id == id);
    notifyListeners();
    _persistir();
  }

  void _persistir() {
    final json = jsonEncode(_items.map((d) => d.toJson()).toList());
    _prefs?.setString('dispositivos', json);
  }
}

// ═══════════════════════════════════════════════════════════════
// INHERITED WIDGET — propaga el notifier sin paquetes externos
// ═══════════════════════════════════════════════════════════════

class _DispositivosScope
    extends InheritedNotifier<DispositivosNotifier> {
  const _DispositivosScope({
    required DispositivosNotifier notifier,
    required super.child,
  }) : super(notifier: notifier);

  static DispositivosNotifier of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_DispositivosScope>();
    assert(scope != null, '_DispositivosScope no encontrado en el árbol');
    return scope!.notifier!;
  }
}

// ═══════════════════════════════════════════════════════════════
// TEMA / CONSTANTES
// ═══════════════════════════════════════════════════════════════

class AppColors {
  static const bg         = Color(0xFF0A0C10);
  static const bg2        = Color(0xFF111318);
  static const bg3        = Color(0xFF181B22);
  static const card       = Color(0xFF13161D);
  static const cyan       = Color(0xFF00DBB4);
  static const cyanDim    = Color(0x1F00DBB4);
  static const cyanBorder = Color(0x4D00DBB4);
  static const textPri    = Color(0xFFE8EAF0);
  static const textSec    = Color(0xFF8891A4);
  static const textHint   = Color(0xFF50586A);
  static const green      = Color(0xFF06D6A0);
  static const yellow     = Color(0xFFFFD166);
  static const red        = Color(0xFFFF4D6D);
  static const redDim     = Color(0x1FFF4D6D);
  static const redBorder  = Color(0x33FF4D6D);
  static const orange     = Color(0xFFFF9F1C);
  static const blue       = Color(0xFF4EA8DE);
  static const purple     = Color(0xFFC77DFF);
  static const border     = Color(0x12FFFFFF);
}

class TipoInfo {
  final String   label;
  final IconData icon;
  final Color    color;
  final Color    bg;
  final int      wattsPromedio;

  const TipoInfo({
    required this.label,
    required this.icon,
    required this.color,
    required this.bg,
    required this.wattsPromedio,
  });
}

const Map<String, TipoInfo> kTipos = {
  'Tasmota': TipoInfo(label: 'Tasmota', icon: Icons.wifi,              color: AppColors.blue,   bg: Color(0x1F4EA8DE), wattsPromedio: 60),
  'Celular':  TipoInfo(label: 'Celular',  icon: Icons.phone_android,    color: AppColors.purple, bg: Color(0x1FC77DFF), wattsPromedio: 15),
  'Cortina':  TipoInfo(label: 'Cortina',  icon: Icons.curtains,         color: AppColors.yellow, bg: Color(0x1FFFD166), wattsPromedio: 30),
  'Escena':   TipoInfo(label: 'Escena',   icon: Icons.auto_awesome,     color: AppColors.orange, bg: Color(0x1FFF9F1C), wattsPromedio: 5),
  'Sensor':   TipoInfo(label: 'Sensor',   icon: Icons.sensors,          color: AppColors.green,  bg: Color(0x1F06D6A0), wattsPromedio: 2),
  'Cámara':   TipoInfo(label: 'Cámara',   icon: Icons.videocam_rounded, color: AppColors.red,    bg: Color(0x1FFF4D6D), wattsPromedio: 8),
};

// ═══════════════════════════════════════════════════════════════
// APP ROOT
// ═══════════════════════════════════════════════════════════════

class _RealApp extends StatelessWidget {
  final DispositivosNotifier notifier;
  const _RealApp({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return _DispositivosScope(
      notifier: notifier,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Domótica Pro',
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: AppColors.bg,
          colorScheme: const ColorScheme.dark(primary: AppColors.cyan),
          snackBarTheme: SnackBarThemeData(
            backgroundColor: AppColors.bg2,
            contentTextStyle: const TextStyle(color: AppColors.textPri),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            behavior: SnackBarBehavior.floating,
          ),
          switchTheme: SwitchThemeData(
            thumbColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? Colors.black : AppColors.textHint,
            ),
            trackColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? AppColors.cyan : AppColors.bg3,
            ),
          ),
          dialogTheme: DialogTheme(
            backgroundColor: AppColors.bg2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        home: const HomePage(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// HOME PAGE — orquestación y estado local de UI
// ═══════════════════════════════════════════════════════════════

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _filterEstado = 'all';
  String _filterRoom   = 'all';
  String _searchQuery  = '';

  // Caché de lista filtrada para evitar recalcular en cada build
  List<Dispositivo>? _cachedFiltered;
  String? _cFe, _cFr, _cSq;
  int?    _cHash;

  List<Dispositivo> _getFiltered(List<Dispositivo> items) {
    final hash = Object.hashAll(
      items.map((d) => Object.hash(d.id, d.encendido, d.nombre, d.habitacion)),
    );
    if (_cachedFiltered != null &&
        _cFe == _filterEstado &&
        _cFr == _filterRoom   &&
        _cSq == _searchQuery  &&
        _cHash == hash) {
      return _cachedFiltered!;
    }
    final q = _searchQuery.toLowerCase();
    _cachedFiltered = items.where((d) {
      final matchRoom   = _filterRoom   == 'all' || d.habitacion == _filterRoom;
      final matchEstado = _filterEstado == 'all' ||
          (_filterEstado == 'on'  &&  d.encendido) ||
          (_filterEstado == 'off' && !d.encendido);
      final matchSearch = q.isEmpty ||
          d.nombre.toLowerCase().contains(q) ||
          d.habitacion.toLowerCase().contains(q) ||
          d.tipo.toLowerCase().contains(q);
      return matchRoom && matchEstado && matchSearch;
    }).toList();
    _cFe = _filterEstado; _cFr = _filterRoom;
    _cSq = _searchQuery;  _cHash = hash;
    return _cachedFiltered!;
  }

  void _invalidateCache() => _cachedFiltered = null;

  // ── Acciones ──────────────────────────────────────────────────

  void _toggleDispositivo(int id) =>
      _DispositivosScope.of(context).toggle(id);

  Future<void> _confirmarEliminar(Dispositivo d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar dispositivo',
            style: TextStyle(color: AppColors.textPri, fontSize: 17, fontWeight: FontWeight.w700)),
        content: Text(
          '¿Eliminar "${d.nombre}"? No se puede deshacer.',
          style: const TextStyle(color: AppColors.textSec, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSec)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar',
                style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      _DispositivosScope.of(context).eliminar(d.id);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('"${d.nombre}" eliminado')));
    }
  }

  void _mostrarFormulario() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _FormularioSheet(
        onAgregar: (nombre, tipo, habitacion) =>
            _DispositivosScope.of(context).agregar(nombre, tipo, habitacion),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final notifier = _DispositivosScope.of(context);
    final items    = notifier.items;
    final filtered = _getFiltered(items);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;

        return Scaffold(
          backgroundColor: AppColors.bg,
          body: SafeArea(
            child: Column(
              children: [
                _Header(isWide: isWide),
                _StatsBar(notifier: notifier),
                Expanded(
                  child: Row(
                    children: [
                      if (isWide)
                        _Sidebar(
                          rooms:         notifier.rooms,
                          allItems:      items,
                          selectedRoom:  _filterRoom,
                          onRoomChanged: (r) => setState(() {
                            _filterRoom = r;
                            _invalidateCache();
                          }),
                        ),
                      Expanded(
                        child: Column(
                          children: [
                            _Toolbar(
                              filterEstado:    _filterEstado,
                              searchQuery:     _searchQuery,
                              showAddButton:   isWide,
                              onFilterChanged: (f) => setState(() {
                                _filterEstado = f;
                                _invalidateCache();
                              }),
                              onSearchChanged: (q) => setState(() {
                                _searchQuery = q;
                                _invalidateCache();
                              }),
                              onAgregar: _mostrarFormulario,
                            ),
                            Expanded(
                              child: _DevicesGrid(
                                items:    filtered,
                                onToggle: _toggleDispositivo,
                                onDelete: _confirmarEliminar,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: !isWide
              ? FloatingActionButton.extended(
                  onPressed:       _mostrarFormulario,
                  backgroundColor: AppColors.cyan,
                  foregroundColor: Colors.black,
                  icon:  const Icon(Icons.add),
                  label: const Text('Agregar',
                      style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                )
              : null,
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// HEADER
// ═══════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  final bool isWide;
  const _Header({required this.isWide});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      color: AppColors.bg2,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: AppColors.cyanDim,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AppColors.cyanBorder),
            ),
            child: const Icon(Icons.home_rounded, color: AppColors.cyan, size: 18),
          ),
          const SizedBox(width: 10),
          const Text('DOMÓTICA PRO',
              style: TextStyle(
                color: AppColors.cyan, fontSize: 16,
                fontWeight: FontWeight.w800, letterSpacing: 1.5,
              )),
          const Spacer(),
          Container(
            width: 7, height: 7,
            decoration: BoxDecoration(
              color: AppColors.green, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.green.withValues(alpha: 0.5), blurRadius: 5)],
            ),
          ),
          if (isWide) ...[
            const SizedBox(width: 7),
            const Text('ONLINE',
                style: TextStyle(color: AppColors.textSec, fontSize: 11, letterSpacing: 0.5)),
          ],
          const SizedBox(width: 14),
          // Reloj aislado — no propaga rebuilds al árbol
          const _ClockWidget(),
        ],
      ),
    );
  }
}

/// Widget de reloj con Timer propio. Rebuild aislado cada segundo.
class _ClockWidget extends StatefulWidget {
  const _ClockWidget();

  @override
  State<_ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<_ClockWidget> {
  late Timer  _timer;
  late String _time;

  @override
  void initState() {
    super.initState();
    _time  = _fmt(DateTime.now());
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _time = _fmt(DateTime.now())),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _fmt(DateTime n) =>
      '${n.hour.toString().padLeft(2,'0')}:'
      '${n.minute.toString().padLeft(2,'0')}:'
      '${n.second.toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cyanDim,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.cyanBorder),
      ),
      child: Text(_time,
          style: const TextStyle(
            color: AppColors.cyan, fontSize: 13,
            fontFamily: 'monospace', letterSpacing: 1,
          )),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// STATS BAR
// ═══════════════════════════════════════════════════════════════

class _StatsBar extends StatelessWidget {
  final DispositivosNotifier notifier;
  const _StatsBar({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: AppColors.bg2,
        border: Border(
          top:    BorderSide(color: AppColors.border),
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          _StatCell(icon: Icons.memory_rounded,  iconColor: AppColors.cyan,   label: 'Dispositivos', value: '${notifier.items.length}'),
          _vDiv(),
          _StatCell(icon: Icons.power_rounded,   iconColor: AppColors.green,  label: 'Encendidos',   value: '${notifier.encendidos}',  valueColor: AppColors.green),
          _vDiv(),
          _StatCell(icon: Icons.house_rounded,   iconColor: AppColors.yellow, label: 'Habitaciones', value: '${notifier.roomsCount}'),
          _vDiv(),
          _StatCell(icon: Icons.bolt_rounded,    iconColor: AppColors.yellow, label: 'Consumo',      value: '${notifier.consumoWatts}W', valueColor: AppColors.yellow),
        ],
      ),
    );
  }

  Widget _vDiv() => Container(width: 1, color: AppColors.border);
}

class _StatCell extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   label;
  final String   value;
  final Color?   valueColor;

  const _StatCell({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(),
                      style: const TextStyle(
                          color: AppColors.textHint, fontSize: 9, letterSpacing: 1)),
                  Text(value,
                      style: TextStyle(
                        color: valueColor ?? AppColors.textPri,
                        fontSize: 19, fontWeight: FontWeight.w700, height: 1.1,
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SIDEBAR
// ═══════════════════════════════════════════════════════════════

class _Sidebar extends StatelessWidget {
  final List<String>             rooms;
  final List<Dispositivo>        allItems;
  final String                   selectedRoom;
  final ValueChanged<String>     onRoomChanged;

  const _Sidebar({
    required this.rooms,
    required this.allItems,
    required this.selectedRoom,
    required this.onRoomChanged,
  });

  static const _iconMap = <String, IconData>{
    'all':        Icons.grid_view_rounded,
    'Sala':       Icons.weekend_rounded,
    'Cocina':     Icons.kitchen_rounded,
    'Dormitorio': Icons.bed_rounded,
    'Exterior':   Icons.park_rounded,
    'Garaje':     Icons.garage_rounded,
    'Oficina':    Icons.desk_rounded,
    'General':    Icons.home_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 185,
      color: AppColors.bg2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 13, 14, 5),
            child: Text('HABITACIONES',
                style: TextStyle(color: AppColors.textHint, fontSize: 9, letterSpacing: 1.5)),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: rooms.length,
              itemBuilder: (_, i) {
                final r       = rooms[i];
                final active  = selectedRoom == r;
                final count   = r == 'all'
                    ? allItems.length
                    : allItems.where((d) => d.habitacion == r).length;
                final label   = r == 'all' ? 'Todos' : r;
                final icon    = _iconMap[r] ?? Icons.home_rounded;

                return Semantics(
                  label: 'Habitación $label, $count dispositivos',
                  selected: active,
                  button: true,
                  child: GestureDetector(
                    onTap: () => onRoomChanged(r),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 130),
                      height: 38,
                      margin: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: active ? AppColors.cyanDim : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border(
                          left: BorderSide(
                            color: active ? AppColors.cyan : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          Icon(icon, size: 14,
                              color: active ? AppColors.cyan : AppColors.textSec),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(label,
                                style: TextStyle(
                                  color: active ? AppColors.cyan : AppColors.textSec,
                                  fontSize: 13, fontWeight: FontWeight.w500,
                                )),
                          ),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.bg3,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('$count',
                                style: const TextStyle(
                                  color: AppColors.textSec,
                                  fontSize: 10, fontFamily: 'monospace',
                                )),
                          ),
                        ],
                      ),
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
}

// ═══════════════════════════════════════════════════════════════
// TOOLBAR
// ═══════════════════════════════════════════════════════════════

class _Toolbar extends StatelessWidget {
  final String               filterEstado;
  final String               searchQuery;
  final bool                 showAddButton;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback         onAgregar;

  const _Toolbar({
    required this.filterEstado,
    required this.searchQuery,
    required this.showAddButton,
    required this.onFilterChanged,
    required this.onSearchChanged,
    required this.onAgregar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                onChanged: onSearchChanged,
                style: const TextStyle(color: AppColors.textPri, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Buscar dispositivo...',
                  hintStyle: const TextStyle(color: AppColors.textHint),
                  prefixIcon:
                      const Icon(Icons.search, color: AppColors.textHint, size: 16),
                  filled: true,
                  fillColor: AppColors.bg2,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.cyanBorder, width: 1.5),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _FilterChip(label: 'Todos',     value: 'all', current: filterEstado, onTap: onFilterChanged),
          const SizedBox(width: 5),
          _FilterChip(label: 'Activos',   value: 'on',  current: filterEstado, onTap: onFilterChanged),
          const SizedBox(width: 5),
          _FilterChip(label: 'Inactivos', value: 'off', current: filterEstado, onTap: onFilterChanged),
          if (showAddButton) ...[
            const SizedBox(width: 8),
            SizedBox(
              height: 36,
              child: ElevatedButton.icon(
                onPressed: onAgregar,
                icon:  const Icon(Icons.add, size: 16),
                label: const Text('Agregar',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cyan,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String               label;
  final String               value;
  final String               current;
  final ValueChanged<String> onTap;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = current == value;
    return Semantics(
      button: true, selected: active, label: 'Filtrar $label',
      child: GestureDetector(
        onTap: () => onTap(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: active ? AppColors.cyanDim : AppColors.bg2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: active ? AppColors.cyanBorder : AppColors.border),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                color: active ? AppColors.cyan : AppColors.textSec,
                fontSize: 12, fontWeight: FontWeight.w600,
              )),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// GRID DE DISPOSITIVOS
// ═══════════════════════════════════════════════════════════════

class _DevicesGrid extends StatelessWidget {
  final List<Dispositivo>                items;
  final ValueChanged<int>                onToggle;
  final Future<void> Function(Dispositivo) onDelete;

  const _DevicesGrid({
    required this.items,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.devices_other_rounded, size: 48,
                color: AppColors.textHint.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            const Text('Sin dispositivos',
                style: TextStyle(
                    color: AppColors.textSec, fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('Agrega uno con el botón +',
                style: TextStyle(color: AppColors.textHint, fontSize: 13)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 80),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 205,
        crossAxisSpacing: 11,
        mainAxisSpacing: 11,
        childAspectRatio: 0.78,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _DeviceCard(
        key:      ValueKey(items[i].id),
        d:        items[i],
        onToggle: () => onToggle(items[i].id),
        onDelete: () => onDelete(items[i]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// DEVICE CARD
// ═══════════════════════════════════════════════════════════════

class _DeviceCard extends StatelessWidget {
  final Dispositivo              d;
  final VoidCallback             onToggle;
  final Future<void> Function()  onDelete;

  const _DeviceCard({
    super.key,
    required this.d,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final info   = kTipos[d.tipo] ?? kTipos['Tasmota']!;
    final isOn   = d.encendido;
    final iconClr = isOn ? info.color : AppColors.textHint;
    final iconBg  = isOn ? info.bg    : const Color(0x0FFFFFFF);

    return Semantics(
      label: '${d.nombre}, ${d.habitacion}, ${d.tipo}, ${isOn ? "encendido" : "apagado"}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isOn ? AppColors.cyan.withValues(alpha: 0.25) : AppColors.border,
            width: isOn ? 1.2 : 1.0,
          ),
          boxShadow: isOn
              ? [BoxShadow(
                  color: AppColors.cyan.withValues(alpha: 0.07),
                  blurRadius: 14, spreadRadius: 1)]
              : const [],
        ),
        child: Column(
          children: [
            // Barra accent superior
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 3,
              decoration: BoxDecoration(
                color: isOn ? info.color : Colors.transparent,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icono + Switch
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: iconBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(info.icon, color: iconClr, size: 22),
                        ),
                        const Spacer(),
                        Column(
                          children: [
                            Semantics(
                              label: '${isOn ? "Apagar" : "Encender"} ${d.nombre}',
                              toggled: isOn,
                              child: Switch(
                                value: isOn,
                                onChanged: (_) => onToggle(),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            Text(
                              isOn ? 'ON' : 'OFF',
                              style: TextStyle(
                                color: isOn ? AppColors.cyan : AppColors.textHint,
                                fontSize: 9, fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Nombre
                    Text(d.nombre,
                        style: const TextStyle(
                          color: AppColors.textPri,
                          fontSize: 15, fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),

                    // Habitación
                    Row(children: [
                      const Icon(Icons.place_rounded, color: AppColors.textHint, size: 10),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(d.habitacion,
                            style: const TextStyle(color: AppColors.textHint, fontSize: 10),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),

                    const Spacer(),

                    // Tags tipo + estado
                    Wrap(
                      spacing: 4,
                      runSpacing: 3,
                      children: [
                        _Tag(label: d.tipo, color: info.color),
                        _Tag(
                          label: isOn ? '● Activo' : '○ Off',
                          color: isOn ? AppColors.green : AppColors.textHint,
                        ),
                      ],
                    ),

                    // Consumo estimado (solo si encendido)
                    if (isOn) ...[
                      const SizedBox(height: 5),
                      Text('~${info.wattsPromedio}W estimado',
                          style: TextStyle(
                            color: AppColors.yellow.withValues(alpha: 0.7),
                            fontSize: 9,
                          )),
                    ],

                    const SizedBox(height: 8),

                    // Eliminar con confirmación
                    SizedBox(
                      width: double.infinity,
                      height: 28,
                      child: OutlinedButton.icon(
                        onPressed: onDelete,
                        icon:  const Icon(Icons.delete_outline_rounded, size: 12),
                        label: const Text('Eliminar',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.red,
                          side: const BorderSide(color: AppColors.redBorder),
                          backgroundColor: AppColors.redDim,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7)),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// WIDGETS ATÓMICOS
// ═══════════════════════════════════════════════════════════════

class _Tag extends StatelessWidget {
  final String label;
  final Color  color;

  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color:  color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(label,
          style: TextStyle(
            color: color, fontSize: 10,
            fontWeight: FontWeight.w600, letterSpacing: 0.3,
          )),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// FORMULARIO — controllers locales, Form + validación real
// ═══════════════════════════════════════════════════════════════

class _FormularioSheet extends StatefulWidget {
  final void Function(String nombre, String tipo, String habitacion) onAgregar;

  const _FormularioSheet({required this.onAgregar});

  @override
  State<_FormularioSheet> createState() => _FormularioSheetState();
}

class _FormularioSheetState extends State<_FormularioSheet> {
  final _formKey    = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();  // locales — sin fuga de estado
  final _habitCtrl  = TextEditingController();
  String _tipo = 'Tasmota';

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _habitCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    widget.onAgregar(_nombreCtrl.text, _tipo, _habitCtrl.text);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, bottom + 20),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 38, height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 18),

              // Título
              const Row(children: [
                Icon(Icons.device_hub_rounded, color: AppColors.cyan, size: 20),
                SizedBox(width: 9),
                Text('Nuevo dispositivo',
                    style: TextStyle(
                        color: AppColors.cyan,
                        fontSize: 19, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 20),

              // Nombre — con validación real
              const _FormLabel('Nombre del dispositivo'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nombreCtrl,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: AppColors.textPri, fontSize: 14),
                autofocus: true,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'El nombre es requerido';
                  if (v.trim().length < 2)           return 'Mínimo 2 caracteres';
                  if (v.trim().length > 40)          return 'Máximo 40 caracteres';
                  return null;
                },
                decoration: _inputDeco('Ej: Lámpara sala'),
              ),
              const SizedBox(height: 14),

              // Habitación — opcional con validación de longitud
              const _FormLabel('Habitación (opcional)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _habitCtrl,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: AppColors.textPri, fontSize: 14),
                validator: (v) {
                  if (v != null && v.trim().length > 30) return 'Máximo 30 caracteres';
                  return null;
                },
                decoration: _inputDeco('Ej: Sala, Cocina, Dormitorio...'),
              ),
              const SizedBox(height: 14),

              // Tipo
              const _FormLabel('Tipo de dispositivo'),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 7,
                mainAxisSpacing: 7,
                childAspectRatio: 1.6,
                children: kTipos.entries.map((e) {
                  final sel = _tipo == e.key;
                  return Semantics(
                    label: 'Tipo ${e.key}', selected: sel, button: true,
                    child: GestureDetector(
                      onTap: () => setState(() => _tipo = e.key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 130),
                        decoration: BoxDecoration(
                          color: sel ? e.value.bg : AppColors.bg3,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: sel
                                ? e.value.color.withValues(alpha: 0.5)
                                : AppColors.border,
                            width: sel ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(e.value.icon, size: 15,
                                color: sel ? e.value.color : AppColors.textSec),
                            const SizedBox(width: 5),
                            Text(e.key,
                                style: TextStyle(
                                  color: sel ? e.value.color : AppColors.textSec,
                                  fontSize: 12, fontWeight: FontWeight.w600,
                                )),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),

              // Botones
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSec,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancelar',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _submit,
                    icon:  const Icon(Icons.check_rounded, size: 17),
                    label: const Text('Agregar',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textHint),
        filled: true,
        fillColor: AppColors.bg3,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.cyanBorder, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.red, width: 1.5),
        ),
        errorStyle: const TextStyle(color: AppColors.red, fontSize: 11),
      );
}

class _FormLabel extends StatelessWidget {
  final String text;
  const _FormLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(),
        style: const TextStyle(
            color: AppColors.textHint, fontSize: 9, letterSpacing: 1.5));
  }
}
