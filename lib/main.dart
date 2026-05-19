import 'dart:async';
import 'package:flutter/material.dart';

void main() {
  runApp(const DomoticaApp());
}

// ─────────────────────────────────────────────
// MODELO
// ─────────────────────────────────────────────

class Dispositivo {
  final int id;
  String nombre;
  String tipo;
  String habitacion;
  bool encendido;

  Dispositivo({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.habitacion,
    this.encendido = false,
  });
}

// ─────────────────────────────────────────────
// TEMA / CONSTANTES
// ─────────────────────────────────────────────

class AppColors {
  static const bg        = Color(0xFF0A0C10);
  static const bg2       = Color(0xFF111318);
  static const bg3       = Color(0xFF181B22);
  static const card      = Color(0xFF13161D);
  static const cyan      = Color(0xFF00DBB4);
  static const cyanDim   = Color(0x1F00DBB4);
  static const cyanGlow  = Color(0x4000DBB4);
  static const textPri   = Color(0xFFE8EAF0);
  static const textSec   = Color(0xFF8891A4);
  static const textHint  = Color(0xFF50586A);
  static const green     = Color(0xFF06D6A0);
  static const yellow    = Color(0xFFFFD166);
  static const red       = Color(0xFFFF4D6D);
  static const orange    = Color(0xFFFF9F1C);
  static const blue      = Color(0xFF4EA8DE);
  static const purple    = Color(0xFFC77DFF);
  static const border    = Color(0x12FFFFFF);
  static const borderGlow= Color(0x4D00DBB4);
}

class TipoInfo {
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;

  const TipoInfo({
    required this.label,
    required this.icon,
    required this.color,
    required this.bg,
  });
}

const Map<String, TipoInfo> kTipos = {
  'Tasmota': TipoInfo(label: 'Tasmota', icon: Icons.wifi,             color: AppColors.blue,   bg: Color(0x1F4EA8DE)),
  'Celular':  TipoInfo(label: 'Celular',  icon: Icons.phone_android,   color: AppColors.purple, bg: Color(0x1FC77DFF)),
  'Cortina':  TipoInfo(label: 'Cortina',  icon: Icons.curtains,        color: AppColors.yellow, bg: Color(0x1FFFD166)),
  'Escena':   TipoInfo(label: 'Escena',   icon: Icons.auto_awesome,    color: AppColors.orange, bg: Color(0x1FFF9F1C)),
  'Sensor':   TipoInfo(label: 'Sensor',   icon: Icons.sensors,         color: AppColors.green,  bg: Color(0x1F06D6A0)),
  'Cámara':   TipoInfo(label: 'Cámara',   icon: Icons.videocam_rounded,color: AppColors.red,    bg: Color(0x1FFF4D6D)),
};

// ─────────────────────────────────────────────
// APP ROOT
// ─────────────────────────────────────────────

class DomoticaApp extends StatelessWidget {
  const DomoticaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Domótica Pro',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: const ColorScheme.dark(primary: AppColors.cyan),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? Colors.black : AppColors.textHint),
          trackColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? AppColors.cyan : AppColors.bg3),
        ),
      ),
      home: const HomePage(),
    );
  }
}

// ─────────────────────────────────────────────
// HOME PAGE
// ─────────────────────────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  // --- Estado ---
  final List<Dispositivo> _dispositivos = [
    Dispositivo(id: 1, nombre: 'Sala',       tipo: 'Tasmota', habitacion: 'Sala',       encendido: true),
    Dispositivo(id: 2, nombre: 'Cocina',     tipo: 'Celular',  habitacion: 'Cocina',     encendido: false),
    Dispositivo(id: 3, nombre: 'Dormitorio', tipo: 'Cortina',  habitacion: 'Dormitorio', encendido: false),
    Dispositivo(id: 4, nombre: 'Patio',      tipo: 'Escena',   habitacion: 'Exterior',   encendido: true),
    Dispositivo(id: 5, nombre: 'Garaje',     tipo: 'Tasmota',  habitacion: 'Garaje',     encendido: false),
    Dispositivo(id: 6, nombre: 'Oficina',    tipo: 'Celular',  habitacion: 'Oficina',    encendido: false),
  ];

  int _nextId = 7;
  String _filterEstado = 'all';   // all | on | off
  String _filterRoom   = 'all';
  String _searchQuery  = '';
  late Timer _clockTimer;
  String _clockStr = '';

  // Form controllers
  final _nombreCtrl    = TextEditingController();
  final _habitCtrl     = TextEditingController();
  String _tipoForm     = 'Tasmota';

  @override
  void initState() {
    super.initState();
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _nombreCtrl.dispose();
    _habitCtrl.dispose();
    super.dispose();
  }

  void _updateClock() {
    final n = DateTime.now();
    setState(() {
      _clockStr =
          '${n.hour.toString().padLeft(2,'0')}:${n.minute.toString().padLeft(2,'0')}:${n.second.toString().padLeft(2,'0')}';
    });
  }

  // --- Cómputos ---
  List<String> get _rooms {
    final set = <String>{'all'};
    for (final d in _dispositivos) set.add(d.habitacion);
    return set.toList();
  }

  List<Dispositivo> get _filtered {
    return _dispositivos.where((d) {
      final matchRoom   = _filterRoom == 'all' || d.habitacion == _filterRoom;
      final matchEstado = _filterEstado == 'all' ||
          (_filterEstado == 'on'  &&  d.encendido) ||
          (_filterEstado == 'off' && !d.encendido);
      final q = _searchQuery.toLowerCase();
      final matchSearch = q.isEmpty ||
          d.nombre.toLowerCase().contains(q) ||
          d.habitacion.toLowerCase().contains(q) ||
          d.tipo.toLowerCase().contains(q);
      return matchRoom && matchEstado && matchSearch;
    }).toList();
  }

  int get _encendidos => _dispositivos.where((d) => d.encendido).length;
  int get _rooms_count => _dispositivos.map((d) => d.habitacion).toSet().length;
  int get _consumo     => _encendidos * 47;

  // --- Acciones ---
  void _toggle(Dispositivo d) => setState(() => d.encendido = !d.encendido);

  void _eliminar(Dispositivo d) {
    setState(() => _dispositivos.remove(d));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${d.nombre} eliminado'),
        backgroundColor: AppColors.bg2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _agregar() {
    if (_nombreCtrl.text.trim().isEmpty) return;
    setState(() {
      _dispositivos.add(Dispositivo(
        id: _nextId++,
        nombre:     _nombreCtrl.text.trim(),
        tipo:       _tipoForm,
        habitacion: _habitCtrl.text.trim().isEmpty ? 'General' : _habitCtrl.text.trim(),
      ));
    });
    _nombreCtrl.clear();
    _habitCtrl.clear();
    _tipoForm = 'Tasmota';
    Navigator.pop(context);
  }

  void _mostrarFormulario() {
    _nombreCtrl.clear();
    _habitCtrl.clear();
    _tipoForm = 'Tasmota';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _FormularioSheet(
        nombreCtrl: _nombreCtrl,
        habitCtrl:  _habitCtrl,
        tipoInicial: _tipoForm,
        onTipoChanged: (t) => _tipoForm = t,
        onAgregar: _agregar,
      ),
    );
  }

  // ─── BUILD ───

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          _buildHeader(),
          _buildStatsBar(),
          Expanded(
            child: Row(
              children: [
                _buildSidebar(),
                Expanded(
                  child: Column(
                    children: [
                      _buildToolbar(),
                      Expanded(child: _buildGrid(filtered)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarFormulario,
        backgroundColor: AppColors.cyan,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Agregar', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      ),
    );
  }

  // ─── HEADER ───

  Widget _buildHeader() {
    return Container(
      height: 64,
      color: AppColors.bg2,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Logo
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.cyanDim,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderGlow),
            ),
            child: const Icon(Icons.home_rounded, color: AppColors.cyan, size: 20),
          ),
          const SizedBox(width: 10),
          const Text(
            'DOMÓTICA PRO',
            style: TextStyle(
              color: AppColors.cyan,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const Spacer(),
          // Status
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: AppColors.green,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.green.withOpacity(0.5), blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 8),
          const Text('SISTEMA ACTIVO', style: TextStyle(color: AppColors.textSec, fontSize: 12, letterSpacing: 0.5)),
          const SizedBox(width: 16),
          // Clock
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.cyanDim,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.borderGlow),
            ),
            child: Text(
              _clockStr,
              style: const TextStyle(
                color: AppColors.cyan,
                fontSize: 14,
                fontFamily: 'monospace',
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── STATS BAR ───

  Widget _buildStatsBar() {
    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: AppColors.bg2,
        border: Border(
          top:    BorderSide(color: AppColors.border),
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          _StatCell(icon: Icons.memory_rounded,    iconColor: AppColors.cyan,   label: 'Dispositivos', value: '${_dispositivos.length}'),
          _divider(),
          _StatCell(icon: Icons.power_rounded,     iconColor: AppColors.green,  label: 'Encendidos',   value: '$_encendidos', valueColor: AppColors.green),
          _divider(),
          _StatCell(icon: Icons.house_rounded,     iconColor: AppColors.yellow, label: 'Habitaciones', value: '$_rooms_count'),
          _divider(),
          _StatCell(icon: Icons.bolt_rounded,      iconColor: AppColors.yellow, label: 'Consumo',      value: '${_consumo}W', valueColor: AppColors.yellow),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, color: AppColors.border);

  // ─── SIDEBAR ───

  Widget _buildSidebar() {
    final iconMap = <String, IconData>{
      'all': Icons.grid_view_rounded,
      'Sala': Icons.weekend_rounded,
      'Cocina': Icons.kitchen_rounded,
      'Dormitorio': Icons.bed_rounded,
      'Exterior': Icons.park_rounded,
      'Garaje': Icons.garage_rounded,
      'Oficina': Icons.desk_rounded,
      'General': Icons.home_rounded,
    };

    return Container(
      width: 190,
      color: AppColors.bg2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text('HABITACIONES',
              style: TextStyle(color: AppColors.textHint, fontSize: 10, letterSpacing: 1.5)),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: _rooms.map((r) {
                final isActive = _filterRoom == r;
                final count = r == 'all'
                    ? _dispositivos.length
                    : _dispositivos.where((d) => d.habitacion == r).length;
                final icon = iconMap[r] ?? Icons.home_rounded;
                final label = r == 'all' ? 'Todos' : r;

                return GestureDetector(
                  onTap: () => setState(() => _filterRoom = r),
                  child: Container(
                    height: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.cyanDim : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(
                          color: isActive ? AppColors.cyan : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Icon(icon, size: 15,
                          color: isActive ? AppColors.cyan : AppColors.textSec),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(label,
                            style: TextStyle(
                              color: isActive ? AppColors.cyan : AppColors.textSec,
                              fontSize: 13, fontWeight: FontWeight.w500,
                            )),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.bg3,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('$count',
                            style: const TextStyle(
                              color: AppColors.textSec,
                              fontSize: 11, fontFamily: 'monospace')),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── TOOLBAR ───

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.bg2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.search, color: AppColors.textHint, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: const TextStyle(color: AppColors.textPri, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Buscar dispositivo...',
                        hintStyle: TextStyle(color: AppColors.textHint),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _FilterChip(label: 'Todos',    active: _filterEstado == 'all', onTap: () => setState(() => _filterEstado = 'all')),
          const SizedBox(width: 6),
          _FilterChip(label: 'Activos',  active: _filterEstado == 'on',  onTap: () => setState(() => _filterEstado = 'on')),
          const SizedBox(width: 6),
          _FilterChip(label: 'Inactivos',active: _filterEstado == 'off', onTap: () => setState(() => _filterEstado = 'off')),
        ],
      ),
    );
  }

  // ─── GRID ───

  Widget _buildGrid(List<Dispositivo> list) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.devices_other_rounded, size: 52, color: AppColors.textHint.withOpacity(0.5)),
            const SizedBox(height: 12),
            const Text('Sin dispositivos', style: TextStyle(color: AppColors.textSec, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('Agrega uno con el botón inferior', style: TextStyle(color: AppColors.textHint, fontSize: 13)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 210,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: list.length,
      itemBuilder: (_, i) => _DeviceCard(
        dispositivo: list[i],
        onToggle: () => _toggle(list[i]),
        onDelete: () => _eliminar(list[i]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// WIDGETS REUTILIZABLES
// ─────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color? valueColor;

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
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(),
                  style: const TextStyle(color: AppColors.textHint, fontSize: 10, letterSpacing: 1)),
                Text(value,
                  style: TextStyle(
                    color: valueColor ?? AppColors.textPri,
                    fontSize: 22, fontWeight: FontWeight.w700, height: 1.1,
                  )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 38, padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? AppColors.cyanDim : AppColors.bg2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? AppColors.borderGlow : AppColors.border),
        ),
        alignment: Alignment.center,
        child: Text(label,
          style: TextStyle(
            color: active ? AppColors.cyan : AppColors.textSec,
            fontSize: 13, fontWeight: FontWeight.w600,
          )),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DEVICE CARD
// ─────────────────────────────────────────────

class _DeviceCard extends StatelessWidget {
  final Dispositivo dispositivo;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _DeviceCard({
    required this.dispositivo,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final d = dispositivo;
    final info = kTipos[d.tipo] ?? kTipos['Tasmota']!;
    final isOn = d.encendido;

    final iconColor = isOn ? info.color : AppColors.textHint;
    final iconBg    = isOn ? info.bg     : const Color(0x0FFFFFFF);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOn ? AppColors.cyan.withOpacity(0.25) : AppColors.border,
          width: isOn ? 1.2 : 1,
        ),
        boxShadow: isOn
            ? [BoxShadow(color: AppColors.cyan.withOpacity(0.07), blurRadius: 16, spreadRadius: 2)]
            : [],
      ),
      child: Column(
        children: [
          // Top accent bar
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 3,
            decoration: BoxDecoration(
              color: isOn ? info.color : Colors.transparent,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon + Toggle row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: iconBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(info.icon, color: iconColor, size: 26),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: onToggle,
                        child: Column(
                          children: [
                            Switch(
                              value: isOn,
                              onChanged: (_) => onToggle(),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            Text(
                              isOn ? 'ON' : 'OFF',
                              style: TextStyle(
                                color: isOn ? AppColors.cyan : AppColors.textHint,
                                fontSize: 10,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Name
                  Text(d.nombre,
                    style: const TextStyle(
                      color: AppColors.textPri,
                      fontSize: 16, fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),

                  // Room
                  Row(
                    children: [
                      const Icon(Icons.place_rounded, color: AppColors.textHint, size: 11),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(d.habitacion,
                          style: const TextStyle(color: AppColors.textHint, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Tipo + status tags
                  Row(
                    children: [
                      _Tag(label: d.tipo, color: info.color),
                      const SizedBox(width: 6),
                      _Tag(
                        label: isOn ? '● Activo' : '○ Off',
                        color: isOn ? AppColors.green : AppColors.textHint,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Delete button
                  SizedBox(
                    width: double.infinity,
                    height: 30,
                    child: OutlinedButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded, size: 13),
                      label: const Text('Eliminar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.red,
                        side: const BorderSide(color: Color(0x33FF4D6D)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
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
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Text(label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
    );
  }
}

// ─────────────────────────────────────────────
// FORMULARIO (Bottom Sheet)
// ─────────────────────────────────────────────

class _FormularioSheet extends StatefulWidget {
  final TextEditingController nombreCtrl;
  final TextEditingController habitCtrl;
  final String tipoInicial;
  final ValueChanged<String> onTipoChanged;
  final VoidCallback onAgregar;

  const _FormularioSheet({
    required this.nombreCtrl,
    required this.habitCtrl,
    required this.tipoInicial,
    required this.onTipoChanged,
    required this.onAgregar,
  });

  @override
  State<_FormularioSheet> createState() => _FormularioSheetState();
}

class _FormularioSheetState extends State<_FormularioSheet> {
  late String _tipo;

  @override
  void initState() {
    super.initState();
    _tipo = widget.tipoInicial;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Row(
              children: const [
                Icon(Icons.device_hub_rounded, color: AppColors.cyan, size: 22),
                SizedBox(width: 10),
                Text('Nuevo Dispositivo',
                  style: TextStyle(color: AppColors.cyan, fontSize: 20, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 22),

            // Nombre
            _FormLabel('Nombre del dispositivo'),
            const SizedBox(height: 6),
            _FormField(controller: widget.nombreCtrl, hint: 'Ej: Lámpara sala'),
            const SizedBox(height: 16),

            // Habitación
            _FormLabel('Habitación'),
            const SizedBox(height: 6),
            _FormField(controller: widget.habitCtrl, hint: 'Ej: Sala, Cocina, Dormitorio...'),
            const SizedBox(height: 16),

            // Tipo
            _FormLabel('Tipo de dispositivo'),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.6,
              children: kTipos.entries.map((e) {
                final isSelected = _tipo == e.key;
                return GestureDetector(
                  onTap: () {
                    setState(() => _tipo = e.key);
                    widget.onTipoChanged(e.key);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isSelected ? e.value.bg : AppColors.bg3,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? e.value.color.withOpacity(0.5) : AppColors.border,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(e.value.icon,
                          size: 16,
                          color: isSelected ? e.value.color : AppColors.textSec),
                        const SizedBox(width: 6),
                        Text(e.key,
                          style: TextStyle(
                            color: isSelected ? e.value.color : AppColors.textSec,
                            fontSize: 13, fontWeight: FontWeight.w600,
                          )),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSec,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: widget.onAgregar,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Agregar', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FormLabel extends StatelessWidget {
  final String text;
  const _FormLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textHint, fontSize: 10, letterSpacing: 1.5));
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const _FormField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: AppColors.textPri, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textHint),
        filled: true,
        fillColor: AppColors.bg3,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          borderSide: const BorderSide(color: AppColors.borderGlow, width: 1.5),
        ),
      ),
    );
  }
}
