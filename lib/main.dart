// ignore_for_file: avoid_classes_with_only_static_members
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

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

  final prefs = await SharedPreferences.getInstance();
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
      Dispositivo(
        id: 1,
        nombre: 'Sala Principal',
        tipo: 'Tasmota',
        habitacion: 'Sala',
        encendido: false,
        ip: '192.168.1.100',
      ),
      Dispositivo(
        id: 2,
        nombre: 'Cocina Inteligente',
        tipo: 'Tasmota',
        habitacion: 'Cocina',
        encendido: false,
        ip: '192.168.1.101',
      ),
      Dispositivo(
        id: 3,
        nombre: 'Dormitorio',
        tipo: 'Sonoff',
        habitacion: 'Dormitorio',
        encendido: false,
        ip: '192.168.1.102',
      ),
      Dispositivo(
        id: 4,
        nombre: 'Jardín',
        tipo: 'Shelly',
        habitacion: 'Exterior',
        encendido: false,
        ip: '192.168.1.103',
      ),
      Dispositivo(
        id: 5,
        nombre: 'Garaje',
        tipo: 'Tasmota',
        habitacion: 'Garaje',
        encendido: false,
        ip: '192.168.1.104',
      ),
    ];

// ═══════════════════════════════════════════════════════════════
// MODELO
// ═══════════════════════════════════════════════════════════════

class Dispositivo {
  final int id;
  final String nombre;
  final String tipo;
  final String habitacion;
  final String? ip;
  bool encendido;
  int potencia;
  int brillo;

  Dispositivo({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.habitacion,
    this.ip,
    this.encendido = false,
    this.potencia = 0,
    this.brillo = 100,
  });

  Dispositivo copyWith({
    int? id,
    String? nombre,
    String? tipo,
    String? habitacion,
    String? ip,
    bool? encendido,
    int? potencia,
    int? brillo,
  }) =>
      Dispositivo(
        id: id ?? this.id,
        nombre: nombre ?? this.nombre,
        tipo: tipo ?? this.tipo,
        habitacion: habitacion ?? this.habitacion,
        ip: ip ?? this.ip,
        encendido: encendido ?? this.encendido,
        potencia: potencia ?? this.potencia,
        brillo: brillo ?? this.brillo,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'tipo': tipo,
        'habitacion': habitacion,
        'ip': ip,
        'encendido': encendido,
        'potencia': potencia,
        'brillo': brillo,
      };

  factory Dispositivo.fromJson(Map<String, dynamic> j) => Dispositivo(
        id: j['id'] as int,
        nombre: j['nombre'] as String,
        tipo: j['tipo'] as String,
        habitacion: j['habitacion'] as String,
        ip: j['ip'] as String?,
        encendido: j['encendido'] as bool? ?? false,
        potencia: j['potencia'] as int? ?? 0,
        brillo: j['brillo'] as int? ?? 100,
      );

  @override
  bool operator ==(Object other) => other is Dispositivo && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

// ═══════════════════════════════════════════════════════════════
// CONTROLADOR DE DISPOSITIVOS
// ═══════════════════════════════════════════════════════════════

class DeviceController {
  static final DeviceController _instance = DeviceController._internal();
  factory DeviceController() => _instance;
  DeviceController._internal();

  // Control Tasmota por HTTP
  Future<bool> controlTasmota(String ip, bool encender) async {
    try {
      final url = Uri.parse('http://$ip/cm?cmnd=Power%20${encender ? 'On' : 'Off'}');
      final response = await http.get(url).timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error controlando Tasmota: $e');
      return false;
    }
  }

  // Control Sonoff
  Future<bool> controlSonoff(String ip, bool encender) async {
    try {
      final url = Uri.parse('http://$ip/control?cmd=${encender ? 'on' : 'off'}');
      final response = await http.get(url).timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error controlando Sonoff: $e');
      return false;
    }
  }

  // Control Shelly
  Future<bool> controlShelly(String ip, bool encender) async {
    try {
      final url = Uri.parse('http://$ip/relay/0?turn=${encender ? 'on' : 'off'}');
      final response = await http.get(url).timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error controlando Shelly: $e');
      return false;
    }
  }

  // Control genérico
  Future<bool> controlDispositivo(String tipo, String ip, bool encender) async {
    switch (tipo.toLowerCase()) {
      case 'tasmota':
        return await controlTasmota(ip, encender);
      case 'sonoff':
        return await controlSonoff(ip, encender);
      case 'shelly':
        return await controlShelly(ip, encender);
      default:
        return await controlTasmota(ip, encender);
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// ESTADO GLOBAL
// ═══════════════════════════════════════════════════════════════

class DispositivosNotifier extends ChangeNotifier {
  List<Dispositivo> _items;
  int _nextId;
  SharedPreferences? _prefs;
  final DeviceController _controller = DeviceController();

  DispositivosNotifier(List<Dispositivo> initial)
      : _items = List.of(initial),
        _nextId = initial.isEmpty
            ? 1
            : initial.map((d) => d.id).reduce((a, b) => a > b ? a : b) + 1 {
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
  }

  List<Dispositivo> get items => List.unmodifiable(_items);
  
  int get encendidos => _items.where((d) => d.encendido).length;
  
  int get roomsCount => _items.map((d) => d.habitacion).toSet().length;
  
  int get consumoTotal {
    var total = 0;
    for (final d in _items) {
      if (d.encendido) total += d.potencia;
    }
    return total;
  }

  List<String> get rooms {
    final set = <String>{};
    for (final d in _items) set.add(d.habitacion);
    return ['all', ...set.toList()..sort()];
  }

  Future<void> toggle(int id) async {
    final idx = _items.indexWhere((d) => d.id == id);
    if (idx == -1) return;
    
    final dispositivo = _items[idx];
    bool exito = true;
    
    // Intentar controlar el dispositivo real si tiene IP
    if (dispositivo.ip != null && dispositivo.ip!.isNotEmpty) {
      exito = await _controller.controlDispositivo(
        dispositivo.tipo,
        dispositivo.ip!,
        !dispositivo.encendido,
      );
    }
    
    if (exito) {
      _items[idx] = dispositivo.copyWith(encendido: !dispositivo.encendido);
      notifyListeners();
      _persistir();
      
      // Simular potencia si está encendido
      if (_items[idx].encendido) {
        _items[idx] = _items[idx].copyWith(potencia: _simularPotencia(dispositivo.tipo));
        notifyListeners();
      } else {
        _items[idx] = _items[idx].copyWith(potencia: 0);
        notifyListeners();
      }
    } else {
      // Mostrar error
      debugPrint('No se pudo controlar el dispositivo');
    }
  }

  int _simularPotencia(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'tasmota':
        return 60;
      case 'sonoff':
        return 40;
      case 'shelly':
        return 80;
      default:
        return 50;
    }
  }

  void agregar(String nombre, String tipo, String habitacion, {String? ip}) {
    _items.add(Dispositivo(
      id: _nextId++,
      nombre: nombre.trim(),
      tipo: tipo.trim(),
      habitacion: habitacion.trim().isEmpty ? 'General' : habitacion.trim(),
      ip: ip,
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
// INHERITED WIDGET
// ═══════════════════════════════════════════════════════════════

class _DispositivosScope extends InheritedNotifier<DispositivosNotifier> {
  const _DispositivosScope({
    required DispositivosNotifier notifier,
    required super.child,
  }) : super(notifier: notifier);

  static DispositivosNotifier of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_DispositivosScope>();
    assert(scope != null, '_DispositivosScope no encontrado');
    return scope!.notifier!;
  }
}

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
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: const Color(0xFF6C63FF),
          scaffoldBackgroundColor: const Color(0xFF0A0E27),
          useMaterial3: true,
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF6C63FF),
            secondary: Color(0xFFFF6584),
            surface: Color(0xFF141A33),
          ),
          appBarTheme: const AppBarTheme(
            elevation: 0,
            backgroundColor: Colors.transparent,
            centerTitle: true,
          ),
          cardTheme: CardTheme(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        home: const HomePage(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// HOME PAGE
// ═══════════════════════════════════════════════════════════════

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _filterRoom = 'all';
  String _searchQuery = '';

  List<Dispositivo> _getFiltered(List<Dispositivo> items) {
    return items.where((d) {
      final matchRoom = _filterRoom == 'all' || d.habitacion == _filterRoom;
      final matchSearch = _searchQuery.isEmpty ||
          d.nombre.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          d.tipo.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchRoom && matchSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = _DispositivosScope.of(context);
    final items = notifier.items;
    final filtered = _getFiltered(items);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0A0E27),
              const Color(0xFF141A33),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _Header(),
              _StatsBar(notifier: notifier),
              _SearchBar(
                onSearchChanged: (q) => setState(() => _searchQuery = q),
              ),
              _RoomFilter(
                rooms: notifier.rooms,
                selectedRoom: _filterRoom,
                onRoomChanged: (r) => setState(() => _filterRoom = r),
              ),
              Expanded(
                child: _DevicesGrid(
                  items: filtered,
                  onToggle: (id) => notifier.toggle(id),
                  onDelete: (id) => _confirmarEliminar(context, notifier, id),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _FloatingActionButton(
        onAgregar: (nombre, tipo, habitacion, ip) =>
            notifier.agregar(nombre, tipo, habitacion, ip: ip),
      ),
    );
  }

  void _confirmarEliminar(BuildContext context, DispositivosNotifier notifier, int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar dispositivo'),
        content: const Text('¿Estás seguro de que quieres eliminar este dispositivo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      notifier.eliminar(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dispositivo eliminado')),
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// COMPONENTES UI
// ═══════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFFFF6584)],
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.smart_home, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 15),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SmartHome Pro',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Control Total',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2546),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.notifications_none, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  final DispositivosNotifier notifier;
  const _StatsBar({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF4A43CC)],
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                const Icon(Icons.power_settings_new, color: Colors.white, size: 24),
                const SizedBox(height: 5),
                Text(
                  '${notifier.encendidos}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text('Activos', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white24),
          Expanded(
            child: Column(
              children: [
                const Icon(Icons.devices, color: Colors.white, size: 24),
                const SizedBox(height: 5),
                Text(
                  '${notifier.items.length}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text('Dispositivos', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white24),
          Expanded(
            child: Column(
              children: [
                const Icon(Icons.electrical_services, color: Colors.white, size: 24),
                const SizedBox(height: 5),
                Text(
                  '${notifier.consumoTotal}W',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text('Consumo', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final Function(String) onSearchChanged;
  const _SearchBar({required this.onSearchChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E2546),
          borderRadius: BorderRadius.circular(15),
        ),
        child: TextField(
          onChanged: onSearchChanged,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Buscar dispositivo...',
            hintStyle: TextStyle(color: Colors.grey[400]),
            prefixIcon: const Icon(Icons.search, color: Color(0xFF6C63FF)),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(15),
          ),
        ),
      ),
    );
  }
}

class _RoomFilter extends StatelessWidget {
  final List<String> rooms;
  final String selectedRoom;
  final Function(String) onRoomChanged;
  
  const _RoomFilter({
    required this.rooms,
    required this.selectedRoom,
    required this.onRoomChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: rooms.length,
          itemBuilder: (_, i) {
            final room = rooms[i];
            final isSelected = selectedRoom == room;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: FilterChip(
                label: Text(room == 'all' ? 'Todos' : room),
                selected: isSelected,
                onSelected: (_) => onRoomChanged(room),
                backgroundColor: const Color(0xFF1E2546),
                selectedColor: const Color(0xFF6C63FF),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DevicesGrid extends StatelessWidget {
  final List<Dispositivo> items;
  final Function(int) onToggle;
  final Function(int) onDelete;

  const _DevicesGrid({
    required this.items,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.devices_other, size: 80, color: Colors.grey),
            SizedBox(height: 20),
            Text(
              'No hay dispositivos',
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
            SizedBox(height: 10),
            Text(
              'Agrega tu primer dispositivo',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 350,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 1.0,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _DeviceCard(
        dispositivo: items[i],
        onToggle: () => onToggle(items[i].id),
        onDelete: () => onDelete(items[i].id),
      ),
    );
  }
}

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
    final isOn = dispositivo.encendido;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isOn
              ? [const Color(0xFF6C63FF).withOpacity(0.2), const Color(0xFF141A33)]
              : [const Color(0xFF1E2546), const Color(0xFF141A33)],
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: isOn ? const Color(0xFF6C63FF).withOpacity(0.5) : Colors.transparent,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isOn ? const Color(0xFF6C63FF).withOpacity(0.2) : const Color(0xFF2A3050),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    _getIcon(),
                    color: isOn ? const Color(0xFF6C63FF) : Colors.white54,
                    size: 24,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: isOn,
                  onChanged: (_) => onToggle(),
                  activeColor: const Color(0xFF6C63FF),
                ),
              ],
            ),
          ),
          
          // Nombre
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Text(
              dispositivo.nombre,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // Tipo y habitación
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on, size: 12, color: Colors.white54),
                const SizedBox(width: 4),
                Text(
                  dispositivo.habitacion,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const SizedBox(width: 10),
                Icon(Icons.device_unknown, size: 12, color: Colors.white54),
                const SizedBox(width: 4),
                Text(
                  dispositivo.tipo,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          
          const Spacer(),
          
          // Potencia
          if (dispositivo.potencia > 0)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 15),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB347).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.flash_on, size: 12, Color(0xFFFFB347)),
                  const SizedBox(width: 4),
                  Text(
                    '${dispositivo.potencia}W',
                    style: const TextStyle(color: Color(0xFFFFB347), fontSize: 11),
                  ),
                ],
              ),
            ),
          
          // Botón eliminar
          Container(
            margin: const EdgeInsets.all(10),
            child: OutlinedButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Eliminar', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF4757),
                side: const BorderSide(color: Color(0xFFFF4757), width: 0.5),
                backgroundColor: const Color(0xFFFF4757).withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIcon() {
    switch (dispositivo.tipo.toLowerCase()) {
      case 'tasmota':
        return Icons.wifi;
      case 'sonoff':
        return Icons.electric_bolt;
      case 'shelly':
        return Icons.smart_toy;
      default:
        return Icons.device_unknown;
    }
  }
}

class _FloatingActionButton extends StatelessWidget {
  final Function(String, String, String, String?) onAgregar;
  const _FloatingActionButton({required this.onAgregar});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _showAddDialog(context),
      icon: const Icon(Icons.add),
      label: const Text('Agregar'),
      backgroundColor: const Color(0xFF6C63FF),
    );
  }

  void _showAddDialog(BuildContext context) {
    final nombreCtrl = TextEditingController();
    final tipoCtrl = TextEditingController();
    final habitacionCtrl = TextEditingController();
    final ipCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nuevo Dispositivo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre *',
                hintText: 'Ej: Lámpara Sala',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: tipoCtrl,
              decoration: const InputDecoration(
                labelText: 'Tipo',
                hintText: 'Tasmota, Sonoff, Shelly...',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: habitacionCtrl,
              decoration: const InputDecoration(
                labelText: 'Habitación',
                hintText: 'Sala, Cocina...',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ipCtrl,
              decoration: const InputDecoration(
                labelText: 'IP (opcional)',
                hintText: '192.168.1.100',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nombreCtrl.text.isNotEmpty) {
                onAgregar(
                  nombreCtrl.text,
                  tipoCtrl.text.isNotEmpty ? tipoCtrl.text : 'Tasmota',
                  habitacionCtrl.text,
                  ipCtrl.text.isNotEmpty ? ipCtrl.text : null,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }
}
