// ignore_for_file: avoid_classes_with_only_static_members
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  runApp(MyApp(notifier: notifier));
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
      Dispositivo(id: 1, nombre: 'Lámpara Sala', tipo: 'Luz', habitacion: 'Sala', encendido: false),
      Dispositivo(id: 2, nombre: 'TV Cocina', tipo: 'TV', habitacion: 'Cocina', encendido: false),
      Dispositivo(id: 3, nombre: 'Aire Acondicionado', tipo: 'Clima', habitacion: 'Dormitorio', encendido: false),
      Dispositivo(id: 4, nombre: 'Luces Jardín', tipo: 'Luz', habitacion: 'Exterior', encendido: false),
      Dispositivo(id: 5, nombre: 'Ventilador', tipo: 'Ventilador', habitacion: 'Oficina', encendido: false),
    ];

class Dispositivo {
  final int id;
  final String nombre;
  final String tipo;
  final String habitacion;
  bool encendido;

  Dispositivo({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.habitacion,
    this.encendido = false,
  });

  Dispositivo copyWith({
    int? id,
    String? nombre,
    String? tipo,
    String? habitacion,
    bool? encendido,
  }) {
    return Dispositivo(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      tipo: tipo ?? this.tipo,
      habitacion: habitacion ?? this.habitacion,
      encendido: encendido ?? this.encendido,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'tipo': tipo,
    'habitacion': habitacion,
    'encendido': encendido,
  };

  factory Dispositivo.fromJson(Map<String, dynamic> j) {
    return Dispositivo(
      id: j['id'] as int,
      nombre: j['nombre'] as String,
      tipo: j['tipo'] as String,
      habitacion: j['habitacion'] as String,
      encendido: j['encendido'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is Dispositivo && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class DispositivosNotifier extends ChangeNotifier {
  List<Dispositivo> _items;
  int _nextId;
  SharedPreferences? _prefs;

  DispositivosNotifier(List<Dispositivo> initial)
      : _items = List.of(initial),
        _nextId = initial.isEmpty ? 1 : initial.map((d) => d.id).reduce((a, b) => a > b ? a : b) + 1 {
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
  }

  List<Dispositivo> get items => List.unmodifiable(_items);

  int get encendidos => _items.where((d) => d.encendido).length;

  int get roomsCount => _items.map((d) => d.habitacion).toSet().length;

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
      id: _nextId++,
      nombre: nombre.trim(),
      tipo: tipo,
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

class DispositivosScope extends InheritedNotifier<DispositivosNotifier> {
  const DispositivosScope({
    required DispositivosNotifier notifier,
    required super.child,
  }) : super(notifier: notifier);

  static DispositivosNotifier of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<DispositivosScope>();
    assert(scope != null, 'DispositivosScope no encontrado');
    return scope!.notifier!;
  }
}

class MyApp extends StatelessWidget {
  final DispositivosNotifier notifier;
  const MyApp({required this.notifier, super.key});

  @override
  Widget build(BuildContext context) {
    return DispositivosScope(
      notifier: notifier,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Domótica Pro',
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: Colors.blue,
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
        ),
        home: const HomePage(),
      ),
    );
  }
}

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
          d.nombre.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchRoom && matchSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = DispositivosScope.of(context);
    final filtered = _getFiltered(notifier.items);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Domótica Pro'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          _StatsBar(notifier: notifier),
          _RoomFilter(
            rooms: notifier.rooms,
            selectedRoom: _filterRoom,
            onRoomChanged: (r) => setState(() => _filterRoom = r),
          ),
          Expanded(
            child: _DevicesGrid(
              items: filtered,
              onToggle: (id) => notifier.toggle(id),
              onDelete: (id) => _confirmDelete(notifier, id),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(notifier),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Buscar dispositivo'),
        content: TextField(
          autofocus: true,
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: const InputDecoration(
            hintText: 'Nombre del dispositivo...',
          ),
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

  void _confirmDelete(DispositivosNotifier notifier, int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar'),
        content: const Text('¿Eliminar este dispositivo?'),
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
    if (confirm == true) {
      notifier.eliminar(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dispositivo eliminado')),
        );
      }
    }
  }

  void _showAddDialog(DispositivosNotifier notifier) {
    final nombreCtrl = TextEditingController();
    final tipoCtrl = TextEditingController();
    final habitacionCtrl = TextEditingController();

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
                labelText: 'Nombre',
                hintText: 'Ej: Lámpara Sala',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: tipoCtrl,
              decoration: const InputDecoration(
                labelText: 'Tipo',
                hintText: 'Luz, TV, Clima...',
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
                notifier.agregar(
                  nombreCtrl.text,
                  tipoCtrl.text.isNotEmpty ? tipoCtrl.text : 'General',
                  habitacionCtrl.text,
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

class _StatsBar extends StatelessWidget {
  final DispositivosNotifier notifier;
  const _StatsBar({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _StatCard(
            title: 'Dispositivos',
            value: '${notifier.items.length}',
            icon: Icons.devices,
            color: Colors.blue,
          ),
          const SizedBox(width: 12),
          _StatCard(
            title: 'Encendidos',
            value: '${notifier.encendidos}',
            icon: Icons.power_settings_new,
            color: Colors.green,
          ),
          const SizedBox(width: 12),
          _StatCard(
            title: 'Habitaciones',
            value: '${notifier.roomsCount}',
            icon: Icons.home,
            color: Colors.orange,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
          ],
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
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: rooms.length,
        itemBuilder: (_, i) {
          final room = rooms[i];
          final isSelected = selectedRoom == room;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(room == 'all' ? 'Todos' : room),
              selected: isSelected,
              onSelected: (_) => onRoomChanged(room),
              backgroundColor: Colors.grey[900],
              selectedColor: Colors.blue,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[400],
              ),
            ),
          );
        },
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
            Icon(Icons.devices_other, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No hay dispositivos',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Presiona el botón + para agregar',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
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

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isOn ? Colors.blue[900] : Colors.grey[900],
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getIcon(dispositivo.tipo),
                size: 40,
                color: isOn ? Colors.blue[300] : Colors.grey[500],
              ),
              const SizedBox(height: 12),
              Text(
                dispositivo.nombre,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isOn ? Colors.white : Colors.grey[300],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                dispositivo.habitacion,
                style: TextStyle(
                  fontSize: 11,
                  color: isOn ? Colors.blue[200] : Colors.grey[500],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Switch(
                    value: isOn,
                    onChanged: (_) => onToggle(),
                    activeColor: Colors.blue,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: Colors.red[400],
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIcon(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'luz':
        return Icons.lightbulb_outline;
      case 'tv':
        return Icons.tv;
      case 'clima':
        return Icons.ac_unit;
      case 'ventilador':
        return Icons.wind_power;
      default:
        return Icons.device_unknown;
    }
  }
}
