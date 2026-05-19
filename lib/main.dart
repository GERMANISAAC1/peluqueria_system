// ignore_for_file: avoid_classes_with_only_static_members
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

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

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  
  final prefs = await SharedPreferences.getInstance();
  final inicial = await _cargarDesdePrefs(prefs);
  final notifier = DispositivosNotifier(inicial);

  runApp(MyApp(notifier: notifier));
}

Future<List<Dispositivo>> _cargarDesdePrefs(SharedPreferences prefs) async {
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
        tipo: 'Luz',
        habitacion: 'Sala',
        encendido: false,
        icono: Icons.lightbulb_outline,
        color: Colors.amber,
      ),
      Dispositivo(
        id: 2,
        nombre: 'TV Samsung',
        tipo: 'TV',
        habitacion: 'Sala',
        encendido: false,
        icono: Icons.tv,
        color: Colors.blue,
      ),
      Dispositivo(
        id: 3,
        nombre: 'Aire Acondicionado',
        tipo: 'Clima',
        habitacion: 'Dormitorio',
        encendido: false,
        icono: Icons.ac_unit,
        color: Colors.cyan,
      ),
      Dispositivo(
        id: 4,
        nombre: 'Luces Jardín',
        tipo: 'Luz',
        habitacion: 'Exterior',
        encendido: false,
        icono: Icons.lightbulb_outline,
        color: Colors.amber,
      ),
      Dispositivo(
        id: 5,
        nombre: 'Ventilador',
        tipo: 'Ventilador',
        habitacion: 'Oficina',
        encendido: false,
        icono: Icons.wind_power,
        color: Colors.green,
      ),
    ];

// ═══════════════════════════════════════════════════════════════
// MODELO MEJORADO
// ═══════════════════════════════════════════════════════════════

class Dispositivo {
  final int id;
  final String nombre;
  final String tipo;
  final String habitacion;
  final IconData icono;
  final Color color;
  bool encendido;
  int potencia;
  int brillo;
  DateTime? ultimoCambio;
  List<ConsumoRegistro> historialConsumo;

  Dispositivo({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.habitacion,
    required this.icono,
    required this.color,
    this.encendido = false,
    this.potencia = 0,
    this.brillo = 100,
    this.ultimoCambio,
    List<ConsumoRegistro>? historialConsumo,
  }) : historialConsumo = historialConsumo ?? [];

  Dispositivo copyWith({
    int? id,
    String? nombre,
    String? tipo,
    String? habitacion,
    IconData? icono,
    Color? color,
    bool? encendido,
    int? potencia,
    int? brillo,
    DateTime? ultimoCambio,
    List<ConsumoRegistro>? historialConsumo,
  }) {
    return Dispositivo(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      tipo: tipo ?? this.tipo,
      habitacion: habitacion ?? this.habitacion,
      icono: icono ?? this.icono,
      color: color ?? this.color,
      encendido: encendido ?? this.encendido,
      potencia: potencia ?? this.potencia,
      brillo: brillo ?? this.brillo,
      ultimoCambio: ultimoCambio ?? this.ultimoCambio,
      historialConsumo: historialConsumo ?? this.historialConsumo,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'tipo': tipo,
    'habitacion': habitacion,
    'icono': icono.codePoint,
    'color': color.value,
    'encendido': encendido,
    'potencia': potencia,
    'brillo': brillo,
    'ultimoCambio': ultimoCambio?.toIso8601String(),
    'historialConsumo': historialConsumo.map((e) => e.toJson()).toList(),
  };

  factory Dispositivo.fromJson(Map<String, dynamic> j) {
    return Dispositivo(
      id: j['id'] as int,
      nombre: j['nombre'] as String,
      tipo: j['tipo'] as String,
      habitacion: j['habitacion'] as String,
      icono: IconData(j['icono'] as int, fontFamily: 'MaterialIcons'),
      color: Color(j['color'] as int),
      encendido: j['encendido'] as bool? ?? false,
      potencia: j['potencia'] as int? ?? 0,
      brillo: j['brillo'] as int? ?? 100,
      ultimoCambio: j['ultimoCambio'] != null 
          ? DateTime.parse(j['ultimoCambio'] as String) 
          : null,
      historialConsumo: (j['historialConsumo'] as List? ?? [])
          .map((e) => ConsumoRegistro.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  bool operator ==(Object other) => other is Dispositivo && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

class ConsumoRegistro {
  final DateTime fecha;
  final int watts;

  ConsumoRegistro({
    required this.fecha,
    required this.watts,
  });

  Map<String, dynamic> toJson() => {
    'fecha': fecha.toIso8601String(),
    'watts': watts,
  };

  factory ConsumoRegistro.fromJson(Map<String, dynamic> j) {
    return ConsumoRegistro(
      fecha: DateTime.parse(j['fecha'] as String),
      watts: j['watts'] as int,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ESTADO GLOBAL MEJORADO
// ═══════════════════════════════════════════════════════════════

class DispositivosNotifier extends ChangeNotifier {
  List<Dispositivo> _items;
  int _nextId;
  SharedPreferences? _prefs;
  Timer? _monitoreoTimer;
  String _filtroHabitacion = 'all';
  String _busqueda = '';

  DispositivosNotifier(List<Dispositivo> initial)
      : _items = List.of(initial),
        _nextId = initial.isEmpty 
            ? 1 
            : initial.map((d) => d.id).reduce((a, b) => a > b ? a : b) + 1 {
    _initPrefs();
    _iniciarMonitoreo();
  }

  void _iniciarMonitoreo() {
    _monitoreoTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _actualizarConsumos();
    });
  }

  Future<void> _actualizarConsumos() async {
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].encendido) {
        final consumo = _calcularConsumo(_items[i]);
        if (consumo != _items[i].potencia) {
          _items[i] = _items[i].copyWith(potencia: consumo);
          _items[i].historialConsumo.add(ConsumoRegistro(
            fecha: DateTime.now(),
            watts: consumo,
          ));
          
          // Mantener solo últimos 100 registros
          if (_items[i].historialConsumo.length > 100) {
            _items[i].historialConsumo.removeAt(0);
          }
          
          notifyListeners();
        }
      }
    }
    _persistir();
  }

  int _calcularConsumo(Dispositivo dispositivo) {
    switch (dispositivo.tipo.toLowerCase()) {
      case 'luz':
        return (40 * dispositivo.brillo ~/ 100);
      case 'tv':
        return 120;
      case 'clima':
        return 1500;
      case 'ventilador':
        return 60;
      default:
        return 50;
    }
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
  }

  List<Dispositivo> get items => List.unmodifiable(_items);
  
  List<Dispositivo> get itemsFiltrados {
    return _items.where((d) {
      final matchHabitacion = _filtroHabitacion == 'all' || d.habitacion == _filtroHabitacion;
      final matchBusqueda = _busqueda.isEmpty ||
          d.nombre.toLowerCase().contains(_busqueda.toLowerCase()) ||
          d.tipo.toLowerCase().contains(_busqueda.toLowerCase());
      return matchHabitacion && matchBusqueda;
    }).toList();
  }
  
  int get encendidos => _items.where((d) => d.encendido).length;
  int get roomsCount => _items.map((d) => d.habitacion).toSet().length;
  
  int get consumoTotal {
    var total = 0;
    for (final d in _items) {
      if (d.encendido) total += d.potencia;
    }
    return total;
  }

  double get costoEstimado {
    const costoPorKwh = 0.15; // $0.15 por kWh
    return (consumoTotal / 1000.0) * costoPorKwh;
  }

  List<String> get rooms {
    final set = <String>{};
    for (final d in _items) set.add(d.habitacion);
    return ['all', ...set.toList()..sort()];
  }

  void setFiltroHabitacion(String habitacion) {
    _filtroHabitacion = habitacion;
    notifyListeners();
  }

  void setBusqueda(String busqueda) {
    _busqueda = busqueda;
    notifyListeners();
  }

  Future<void> toggle(int id) async {
    final idx = _items.indexWhere((d) => d.id == id);
    if (idx == -1) return;
    
    HapticFeedback.lightImpact();
    
    _items[idx] = _items[idx].copyWith(
      encendido: !_items[idx].encendido,
      ultimoCambio: DateTime.now(),
    );
    
    if (_items[idx].encendido) {
      _items[idx] = _items[idx].copyWith(
        potencia: _calcularConsumo(_items[idx]),
      );
      _items[idx].historialConsumo.add(ConsumoRegistro(
        fecha: DateTime.now(),
        watts: _items[idx].potencia,
      ));
    } else {
      _items[idx] = _items[idx].copyWith(potencia: 0);
    }
    
    notifyListeners();
    _persistir();
  }

  void setBrightness(int id, int brillo) {
    final idx = _items.indexWhere((d) => d.id == id);
    if (idx == -1) return;
    
    _items[idx] = _items[idx].copyWith(brillo: brillo);
    if (_items[idx].encendido) {
      _items[idx] = _items[idx].copyWith(
        potencia: _calcularConsumo(_items[idx]),
      );
    }
    notifyListeners();
    _persistir();
  }

  void agregar(String nombre, String tipo, String habitacion, IconData icono, Color color) {
    _items.add(Dispositivo(
      id: _nextId++,
      nombre: nombre.trim(),
      tipo: tipo,
      habitacion: habitacion.trim().isEmpty ? 'General' : habitacion.trim(),
      icono: icono,
      color: color,
    ));
    notifyListeners();
    _persistir();
  }

  void eliminar(int id) {
    _items.removeWhere((d) => d.id == id);
    notifyListeners();
    _persistir();
  }

  List<ConsumoRegistro> getHistorialConsumo(int id) {
    final idx = _items.indexWhere((d) => d.id == id);
    if (idx == -1) return [];
    return _items[idx].historialConsumo;
  }

  Future<void> _persistir() async {
    try {
      final json = jsonEncode(_items.map((d) => d.toJson()).toList());
      await _prefs?.setString('dispositivos', json);
    } catch (e) {
      debugPrint('Error guardando: $e');
    }
  }
  
  @override
  void dispose() {
    _monitoreoTimer?.cancel();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════
// WIDGET DE ESTADO
// ═══════════════════════════════════════════════════════════════

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

// ═══════════════════════════════════════════════════════════════
// APP PRINCIPAL
// ═══════════════════════════════════════════════════════════════

class MyApp extends StatelessWidget {
  final DispositivosNotifier notifier;
  const MyApp({required this.notifier, super.key});

  @override
  Widget build(BuildContext context) {
    return DispositivosScope(
      notifier: notifier,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SmartHome Pro 2.0',
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: const Color(0xFF6C63FF),
          scaffoldBackgroundColor: const Color(0xFF0A0E27),
          useMaterial3: true,
          fontFamily: GoogleFonts.poppins().fontFamily,
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

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = DispositivosScope.of(context);

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
              _Header(notifier: notifier),
              _StatsBar(notifier: notifier),
              _SearchBar(notifier: notifier),
              _RoomFilter(notifier: notifier),
              Expanded(
                child: _DevicesGrid(notifier: notifier),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(notifier),
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
        backgroundColor: const Color(0xFF6C63FF),
      ),
    );
  }

  void _showAddDialog(DispositivosNotifier notifier) {
    final nombreCtrl = TextEditingController();
    final tipoCtrl = TextEditingController();
    final habitacionCtrl = TextEditingController();
    IconData iconoSeleccionado = Icons.device_unknown;
    Color colorSeleccionado = Colors.blue;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Nuevo Dispositivo'),
            content: SizedBox(
              width: 300,
              child: Column(
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
                  const SizedBox(height: 10),
                  const Text('Icono:'),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(iconoSeleccionado, color: colorSeleccionado),
                        onPressed: () => _showIconPicker(context, (icon) {
                          setState(() => iconoSeleccionado = icon);
                        }),
                      ),
                      const SizedBox(width: 10),
                      const Text('Color:'),
                      IconButton(
                        icon: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: colorSeleccionado,
                            shape: BoxShape.circle,
                          ),
                        ),
                        onPressed: () => _showColorPicker(context, (color) {
                          setState(() => colorSeleccionado = color);
                        }),
                      ),
                    ],
                  ),
                ],
              ),
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
                      iconoSeleccionado,
                      colorSeleccionado,
                    );
                    Navigator.pop(context);
                  }
                },
                child: const Text('Agregar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showIconPicker(BuildContext context, Function(IconData) onSelected) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Selecciona un icono'),
        content: SizedBox(
          width: 300,
          height: 300,
          child: GridView.count(
            crossAxisCount: 4,
            children: [
              Icons.lightbulb_outline,
              Icons.tv,
              Icons.ac_unit,
              Icons.wind_power,
              Icons.speaker,
              Icons.fridge,
              Icons.kitchen,
              Icons.washing_machine,
            ].map((icon) {
              return IconButton(
                icon: Icon(icon),
                onPressed: () {
                  onSelected(icon);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext context, Function(Color) onSelected) {
    final colors = [
      Colors.blue, Colors.red, Colors.green, Colors.amber,
      Colors.purple, Colors.orange, Colors.cyan, Colors.pink,
    ];
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Selecciona un color'),
        content: Wrap(
          children: colors.map((color) {
            return GestureDetector(
              onTap: () {
                onSelected(color);
                Navigator.pop(context);
              },
              child: Container(
                margin: const EdgeInsets.all(8),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// COMPONENTES UI
// ═══════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  final DispositivosNotifier notifier;
  const _Header({required this.notifier});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final horaActual = DateFormat('HH:mm').format(now);
    final fechaActual = DateFormat('EEEE, d MMMM', 'es_ES').format(now);

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SmartHome Pro 2.0',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '$fechaActual | $horaActual',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
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
                  style: GoogleFonts.poppins(
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
                  style: GoogleFonts.poppins(
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
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '\$${notifier.costoEstimado.toStringAsFixed(2)}/h',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final DispositivosNotifier notifier;
  const _SearchBar({required this.notifier});

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
          onChanged: notifier.setBusqueda,
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
  final DispositivosNotifier notifier;
  const _RoomFilter({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: notifier.rooms.length,
          itemBuilder: (_, i) {
            final room = notifier.rooms[i];
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: FilterChip(
                label: Text(room == 'all' ? 'Todos' : room),
                selected: room == 'all' 
                    ? notifier.rooms.first == room 
                    : true,
                onSelected: (_) => notifier.setFiltroHabitacion(room),
                backgroundColor: const Color(0xFF1E2546),
                selectedColor: const Color(0xFF6C63FF),
                labelStyle: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
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
  final DispositivosNotifier notifier;
  const _DevicesGrid({required this.notifier});

  @override
  Widget build(BuildContext context) {
    final items = notifier.itemsFiltrados;
    
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.devices_other, size: 80, color: Colors.grey[600]),
            const SizedBox(height: 20),
            Text(
              'No hay dispositivos',
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Presiona el botón + para agregar',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey,
              ),
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
        childAspectRatio: 0.9,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _DeviceCard(
        dispositivo: items[i],
        onToggle: () => notifier.toggle(items[i].id),
        onDelete: () => _confirmDelete(context, notifier, items[i].id),
        onBrightnessChange: items[i].tipo == 'Luz' 
            ? (brightness) => notifier.setBrightness(items[i].id, brightness)
            : null,
      ),
    );
  }

  void _confirmDelete(BuildContext context, DispositivosNotifier notifier, int id) async {
    final confirm = await showDialog<bool>(
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
    
    if (confirm == true) {
      notifier.eliminar(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dispositivo eliminado')),
        );
      }
    }
  }
}

class _DeviceCard extends StatelessWidget {
  final Dispositivo dispositivo;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final Function(int)? onBrightnessChange;

  const _DeviceCard({
    required this.dispositivo,
    required this.onToggle,
    required this.onDelete,
    this.onBrightnessChange,
  });

  @override
  Widget build(BuildContext context) {
    final isOn = dispositivo.encendido;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isOn
              ? [dispositivo.color.withOpacity(0.3), const Color(0xFF141A33)]
              : [const Color(0xFF1E2546), const Color(0xFF141A33)],
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: isOn ? dispositivo.color.withOpacity(0.5) : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: isOn ? [
          BoxShadow(
            color: dispositivo.color.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ] : [],
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
                    color: isOn ? dispositivo.color.withOpacity(0.2) : const Color(0xFF2A3050),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    dispositivo.icono,
                    color: isOn ? dispositivo.color : Colors.white54,
                    size: 24,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: isOn,
                  onChanged: (_) => onToggle(),
                  activeColor: dispositivo.color,
                ),
              ],
            ),
          ),
          
          // Nombre
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Text(
              dispositivo.nombre,
              style: GoogleFonts.poppins(
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
                Text(
                  dispositivo.tipo,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          
          const Spacer(),
          
          // Control de brillo para luces
          if (onBrightnessChange != null && isOn)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                children: [
                  Icon(Icons.brightness_low, size: 16, color: Colors.white54),
                  Expanded(
                    child: Slider(
                      value: dispositivo.brillo.toDouble(),
                      min: 0,
                      max: 100,
                      activeColor: dispositivo.color,
                      onChanged: (val) => onBrightnessChange!(val.toInt()),
                    ),
                  ),
                  Icon(Icons.brightness_high, size: 16, color: Colors.white54),
                ],
              ),
            ),
          
          // Potencia
          if (dispositivo.potencia > 0)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 15),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: dispositivo.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flash_on, size: 12, color: dispositivo.color),
                  const SizedBox(width: 4),
                  Text(
                    '${dispositivo.potencia}W',
                    style: TextStyle(color: dispositivo.color, fontSize: 11),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 8),
          
          // Botón eliminar
          Container(
            margin: const EdgeInsets.all(10),
            child: OutlinedButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Eliminar', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red, width: 0.5),
                backgroundColor: Colors.red.withOpacity(0.1),
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
}
