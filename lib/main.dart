// ignore_for_file: avoid_classes_with_only_static_members
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:ping_discover_network/ping_discover_network.dart';

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
  
  // Iniciar escaneo de dispositivos en red
  await notifier.escanearRed();

  runApp(_RealApp(notifier: notifier));
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
        nombre: 'Philips Hue',
        tipo: 'Hue',
        habitacion: 'Sala',
        encendido: false,
        ip: '192.168.1.100',
        protocolo: Protocolo.HTTP,
      ),
      Dispositivo(
        id: 2,
        nombre: 'Tasmota Plug',
        tipo: 'Tasmota',
        habitacion: 'Cocina',
        encendido: false,
        ip: '192.168.1.101',
        protocolo: Protocolo.MQTT,
      ),
      Dispositivo(
        id: 3,
        nombre: 'Sonoff Basic',
        tipo: 'Sonoff',
        habitacion: 'Dormitorio',
        encendido: false,
        ip: '192.168.1.102',
        protocolo: Protocolo.HTTP,
      ),
      Dispositivo(
        id: 4,
        nombre: 'Shelly 1PM',
        tipo: 'Shelly',
        habitacion: 'Garaje',
        encendido: false,
        ip: '192.168.1.103',
        protocolo: Protocolo.HTTP,
      ),
    ];

enum Protocolo { HTTP, MQTT, WEBSOCKET, ZIGBEE }

// ═══════════════════════════════════════════════════════════════
// MODELO MEJORADO
// ═══════════════════════════════════════════════════════════════

class Dispositivo {
  final int id;
  final String nombre;
  final String tipo;
  final String habitacion;
  final String? ip;
  final Protocolo protocolo;
  bool encendido;
  int potencia; // Watts actuales
  int brightness; // Brillo 0-100
  int temperature; // Temperatura en °C si aplica

  Dispositivo({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.habitacion,
    this.ip,
    this.protocolo = Protocolo.HTTP,
    this.encendido = false,
    this.potencia = 0,
    this.brightness = 100,
    this.temperature = 0,
  });

  Dispositivo copyWith({
    int? id,
    String? nombre,
    String? tipo,
    String? habitacion,
    String? ip,
    Protocolo? protocolo,
    bool? encendido,
    int? potencia,
    int? brightness,
    int? temperature,
  }) =>
      Dispositivo(
        id: id ?? this.id,
        nombre: nombre ?? this.nombre,
        tipo: tipo ?? this.tipo,
        habitacion: habitacion ?? this.habitacion,
        ip: ip ?? this.ip,
        protocolo: protocolo ?? this.protocolo,
        encendido: encendido ?? this.encendido,
        potencia: potencia ?? this.potencia,
        brightness: brightness ?? this.brightness,
        temperature: temperature ?? this.temperature,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'tipo': tipo,
        'habitacion': habitacion,
        'ip': ip,
        'protocolo': protocolo.index,
        'encendido': encendido,
        'potencia': potencia,
        'brightness': brightness,
        'temperature': temperature,
      };

  factory Dispositivo.fromJson(Map<String, dynamic> j) => Dispositivo(
        id: j['id'] as int,
        nombre: j['nombre'] as String,
        tipo: j['tipo'] as String,
        habitacion: j['habitacion'] as String,
        ip: j['ip'] as String?,
        protocolo: Protocolo.values[j['protocolo'] as int? ?? 0],
        encendido: j['encendido'] as bool? ?? false,
        potencia: j['potencia'] as int? ?? 0,
        brightness: j['brightness'] as int? ?? 100,
        temperature: j['temperature'] as int? ?? 0,
      );

  @override
  bool operator ==(Object other) => other is Dispositivo && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

// ═══════════════════════════════════════════════════════════════
// CONTROLADOR DE DISPOSITIVOS - COMUNICACIÓN REAL
// ═══════════════════════════════════════════════════════════════

class DeviceController {
  static final DeviceController _instance = DeviceController._internal();
  factory DeviceController() => _instance;
  DeviceController._internal();

  // Control por HTTP (Tasmota, Sonoff, Shelly)
  Future<bool> controlHTTP(String ip, bool encender) async {
    try {
      final url = Uri.parse('http://$ip/cm?cmnd=Power%20${encender ? 'On' : 'Off'}');
      final response = await http.get(url).timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error HTTP: $e');
      return false;
    }
  }

  // Control para Philips Hue
  Future<bool> controlHue(String ip, bool encender, {int brightness = 100}) async {
    try {
      final url = Uri.parse('http://$ip/api/newdeveloper/lights/1/state');
      final body = jsonEncode({
        'on': encender,
        'bri': (brightness * 2.54).round(),
      });
      final response = await http.put(url, body: body).timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error Hue: $e');
      return false;
    }
  }

  // Control para Shelly
  Future<bool> controlShelly(String ip, bool encender) async {
    try {
      final url = Uri.parse('http://$ip/relay/0?turn=${encender ? 'on' : 'off'}');
      final response = await http.get(url).timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error Shelly: $e');
      return false;
    }
  }

  // Obtener potencia actual
  Future<int> getPotencia(String ip, String tipo) async {
    try {
      if (tipo == 'Shelly') {
        final url = Uri.parse('http://$ip/status');
        final response = await http.get(url).timeout(const Duration(seconds: 2));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['meters'][0]['power'] as int? ?? 0;
        }
      } else if (tipo == 'Tasmota') {
        final url = Uri.parse('http://$ip/cm?cmnd=Status%208');
        final response = await http.get(url).timeout(const Duration(seconds: 2));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['StatusSNS']['ENERGY']['Power'] as int? ?? 0;
        }
      }
    } catch (e) {
      debugPrint('Error getPotencia: $e');
    }
    return 0;
  }
}

// ═══════════════════════════════════════════════════════════════
// ESTADO GLOBAL MEJORADO
// ═══════════════════════════════════════════════════════════════

class DispositivosNotifier extends ChangeNotifier {
  List<Dispositivo> _items;
  int _nextId;
  SharedPreferences? _prefs;
  final DeviceController _controller = DeviceController();
  Timer? _monitorTimer;

  DispositivosNotifier(List<Dispositivo> initial)
      : _items = List.of(initial),
        _nextId = initial.isEmpty
            ? 1
            : initial.map((d) => d.id).reduce((a, b) => a > b ? a : b) + 1 {
    _initPrefs();
    _iniciarMonitor();
  }

  void _iniciarMonitor() {
    _monitorTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _actualizarPotencia();
    });
  }

  Future<void> _actualizarPotencia() async {
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].encendido && _items[i].ip != null) {
        final potencia = await _controller.getPotencia(_items[i].ip!, _items[i].tipo);
        if (potencia != _items[i].potencia) {
          _items[i] = _items[i].copyWith(potencia: potencia);
          notifyListeners();
        }
      }
    }
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

  // Escanear red automáticamente
  Future<void> escanearRed() async {
    final info = NetworkInfo();
    final wifiIP = await info.getWifiIP();
    if (wifiIP != null) {
      final subnet = wifiIP.substring(0, wifiIP.lastIndexOf('.'));
      final stream = NetworkAnalyzer.discover(subnet, 80, timeout: 200);
      
      stream.listen((NetworkAddress addr) {
        if (addr.exists) {
          _detectarDispositivo(addr.ip);
        }
      });
    }
  }

  Future<void> _detectarDispositivo(String ip) async {
    // Detectar Tasmota
    try {
      final url = Uri.parse('http://$ip/cm?cmnd=Status%200');
      final response = await http.get(url).timeout(const Duration(milliseconds: 500));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data.containsKey('Status')) {
          final nombre = data['Status']['DeviceName'] ?? 'Tasmota';
          if (!_items.any((d) => d.ip == ip)) {
            _items.add(Dispositivo(
              id: _nextId++,
              nombre: nombre,
              tipo: 'Tasmota',
              habitacion: 'Descubierto',
              ip: ip,
              protocolo: Protocolo.HTTP,
            ));
            notifyListeners();
            _persistir();
          }
        }
      }
    } catch (_) {}
  }

  Future<void> toggle(int id) async {
    final idx = _items.indexWhere((d) => d.id == id);
    if (idx == -1) return;
    
    final dispositivo = _items[idx];
    bool exito = false;
    
    if (dispositivo.ip != null) {
      switch (dispositivo.tipo) {
        case 'Hue':
          exito = await _controller.controlHue(dispositivo.ip!, !dispositivo.encendido);
          break;
        case 'Shelly':
          exito = await _controller.controlShelly(dispositivo.ip!, !dispositivo.encendido);
          break;
        default:
          exito = await _controller.controlHTTP(dispositivo.ip!, !dispositivo.encendido);
      }
    }
    
    if (exito || dispositivo.ip == null) {
      _items[idx] = dispositivo.copyWith(encendido: !dispositivo.encendido);
      notifyListeners();
      _persistir();
      
      // Actualizar potencia después de encender
      if (_items[idx].encendido && _items[idx].ip != null) {
        final potencia = await _controller.getPotencia(_items[idx].ip!, _items[idx].tipo);
        if (potencia > 0) {
          _items[idx] = _items[idx].copyWith(potencia: potencia);
          notifyListeners();
        }
      }
    }
  }

  Future<void> setBrightness(int id, int brightness) async {
    final idx = _items.indexWhere((d) => d.id == id);
    if (idx == -1) return;
    
    if (_items[idx].ip != null && _items[idx].tipo == 'Hue') {
      await _controller.controlHue(_items[idx].ip!, _items[idx].encendido, brightness: brightness);
    }
    
    _items[idx] = _items[idx].copyWith(brightness: brightness);
    notifyListeners();
    _persistir();
  }

  void agregar(String nombre, String tipo, String habitacion, {String? ip}) {
    _items.add(Dispositivo(
      id: _nextId++,
      nombre: nombre.trim(),
      tipo: tipo,
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
  
  @override
  void dispose() {
    _monitorTimer?.cancel();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════
// UI MEJORADA Y MÁS ATRACTIVA
// ═══════════════════════════════════════════════════════════════

class AppColors {
  static const primary = Color(0xFF6C63FF);
  static const primaryLight = Color(0xFF8B84FF);
  static const primaryDark = Color(0xFF4A43CC);
  static const secondary = Color(0xFFFF6584);
  static const success = Color(0xFF00E5A0);
  static const warning = Color(0xFFFFB347);
  static const error = Color(0xFFFF4757);
  static const background = Color(0xFF0A0E27);
  static const surface = Color(0xFF141A33);
  static const surfaceLight = Color(0xFF1E2546);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF8A93B3);
  static const textHint = Color(0xFF4A526B);
  static const gradient1 = Color(0xFF6C63FF);
  static const gradient2 = Color(0xFF4A43CC);
  static const gradient3 = Color(0xFFFF6584);
}

class _RealApp extends StatelessWidget {
  final DispositivosNotifier notifier;
  const _RealApp({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return _DispositivosScope(
      notifier: notifier,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SmartHome Pro',
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: AppColors.primary,
          scaffoldBackgroundColor: AppColors.background,
          fontFamily: 'Poppins',
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            secondary: AppColors.secondary,
            surface: AppColors.surface,
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
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        home: const HomePage(),
      ),
    );
  }
}

class _DispositivosScope extends InheritedNotifier<DispositivosNotifier> {
  const _DispositivosScope({
    required DispositivosNotifier notifier,
    required super.child,
  }) : super(notifier: notifier);

  static DispositivosNotifier of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_DispositivosScope>();
    assert(scope != null);
    return scope!.notifier!;
  }
}

// ═══════════════════════════════════════════════════════════════
// HOME PAGE MEJORADA
// ═══════════════════════════════════════════════════════════════

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _filterRoom = 'all';
  String _searchQuery = '';

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
    final notifier = _DispositivosScope.of(context);
    final items = notifier.items;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.background,
              AppColors.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _ModernHeader(),
              _EnergyStats(notifier: notifier),
              _SearchAndFilter(
                searchQuery: _searchQuery,
                onSearchChanged: (q) => setState(() => _searchQuery = q),
                selectedRoom: _filterRoom,
                onRoomChanged: (r) => setState(() => _filterRoom = r),
                rooms: notifier.rooms,
              ),
              Expanded(
                child: _DevicesGrid(
                  items: _getFiltered(items, _filterRoom, _searchQuery),
                  onToggle: notifier.toggle,
                  onDelete: notifier.eliminar,
                  onBrightnessChange: notifier.setBrightness,
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

  List<Dispositivo> _getFiltered(List<Dispositivo> items, String room, String query) {
    return items.where((d) {
      final matchRoom = room == 'all' || d.habitacion == room;
      final matchSearch = query.isEmpty ||
          d.nombre.toLowerCase().contains(query.toLowerCase());
      return matchRoom && matchSearch;
    }).toList();
  }
}

// ═══════════════════════════════════════════════════════════════
// COMPONENTES MODERNOS
// ═══════════════════════════════════════════════════════════════

class _ModernHeader extends StatelessWidget {
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
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
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
                const Text(
                  'Bienvenido de vuelta',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const Text(
                  'Casa Inteligente',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.notifications_none, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _EnergyStats extends StatelessWidget {
  final DispositivosNotifier notifier;
  const _EnergyStats({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
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
                const Text('Consumo Actual', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white24),
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
                const Text('Dispositivos Activos', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchAndFilter extends StatelessWidget {
  final String searchQuery;
  final Function(String) onSearchChanged;
  final String selectedRoom;
  final Function(String) onRoomChanged;
  final List<String> rooms;

  const _SearchAndFilter({
    required this.searchQuery,
    required this.onSearchChanged,
    required this.selectedRoom,
    required this.onRoomChanged,
    required this.rooms,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(15),
            ),
            child: TextField(
              onChanged: onSearchChanged,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Buscar dispositivo...',
                hintStyle: TextStyle(color: AppColors.textHint),
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(15),
              ),
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
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
                    backgroundColor: AppColors.surface,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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

class _DevicesGrid extends StatelessWidget {
  final List<Dispositivo> items;
  final Function(int) onToggle;
  final Function(int) onDelete;
  final Function(int, int) onBrightnessChange;

  const _DevicesGrid({
    required this.items,
    required this.onToggle,
    required this.onDelete,
    required this.onBrightnessChange,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.devices_other, size: 80, color: AppColors.textHint),
            const SizedBox(height: 20),
            Text(
              'No hay dispositivos',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text(
              'Agrega tu primer dispositivo',
              style: TextStyle(color: AppColors.textHint),
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
        childAspectRatio: 1.1,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _DeviceCard(
        dispositivo: items[i],
        onToggle: () => onToggle(items[i].id),
        onDelete: () => onDelete(items[i].id),
        onBrightnessChange: (brightness) => onBrightnessChange(items[i].id, brightness),
      ),
    );
  }
}

class _DeviceCard extends StatefulWidget {
  final Dispositivo dispositivo;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final Function(int) onBrightnessChange;

  const _DeviceCard({
    required this.dispositivo,
    required this.onToggle,
    required this.onDelete,
    required this.onBrightnessChange,
  });

  @override
  State<_DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<_DeviceCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOn = widget.dispositivo.encendido;
    final tipoInfo = _getTipoInfo(widget.dispositivo.tipo);
    
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: (_) => _animationController.forward(),
            onTapUp: (_) => _animationController.reverse(),
            onTapCancel: () => _animationController.reverse(),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isOn
                        ? [AppColors.primary.withOpacity(0.2), AppColors.surface]
                        : [AppColors.surface, AppColors.surface],
                  ),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: isOn ? AppColors.primary.withOpacity(0.5) : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    // Header con icono
                    Container(
                      padding: const EdgeInsets.all(15),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isOn ? AppColors.primary.withOpacity(0.2) : AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(
                              tipoInfo.icon,
                              color: isOn ? AppColors.primary : AppColors.textSecondary,
                              size: 24,
                            ),
                          ),
                          const Spacer(),
                          Switch(
                            value: isOn,
                            onChanged: (_) => widget.onToggle(),
                            activeColor: AppColors.primary,
                            activeTrackColor: AppColors.primary.withOpacity(0.5),
                          ),
                        ],
                      ),
                    ),
                    
                    // Nombre del dispositivo
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: Text(
                        widget.dispositivo.nombre,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                    // Habitación
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, size: 12, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Text(
                            widget.dispositivo.habitacion,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Info de potencia
                    if (widget.dispositivo.potencia > 0)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 15),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.flash_on, size: 12, color: AppColors.warning),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.dispositivo.potencia}W',
                              style: TextStyle(color: AppColors.warning, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 8),
                    
                    // Slider de brillo para Hue
                    if (widget.dispositivo.tipo == 'Hue' && isOn)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: Row(
                          children: [
                            Icon(Icons.brightness_low, size: 16, color: AppColors.textSecondary),
                            Expanded(
                              child: Slider(
                                value: widget.dispositivo.brightness.toDouble(),
                                min: 0,
                                max: 100,
                                activeColor: AppColors.primary,
                                onChanged: (val) => widget.onBrightnessChange(val.toInt()),
                              ),
                            ),
                            Icon(Icons.brightness_high, size: 16, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    
                    // Botón eliminar
                    Container(
                      margin: const EdgeInsets.all(10),
                      child: OutlinedButton.icon(
                        onPressed: widget.onDelete,
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Eliminar', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: BorderSide(color: AppColors.error.withOpacity(0.5)),
                          backgroundColor: AppColors.error.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  (IconData icon, Color color) _getTipoInfo(String tipo) {
    switch (tipo) {
      case 'Hue':
        return (Icons.lightbulb, AppColors.warning);
      case 'Tasmota':
        return (Icons.wifi, AppColors.primary);
      case 'Shelly':
        return (Icons.electric_bolt, AppColors.success);
      default:
        return (Icons.device_unknown, AppColors.textSecondary);
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
      label: const Text('Agregar Dispositivo'),
      backgroundColor: AppColors.primary,
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
                labelText: 'Nombre',
                hintText: 'Ej: Lámpara Sala',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: tipoCtrl,
              decoration: const InputDecoration(
                labelText: 'Tipo',
                hintText: 'Hue, Tasmota, Shelly...',
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
                  tipoCtrl.text,
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
