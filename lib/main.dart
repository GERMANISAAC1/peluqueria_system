import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
  final inicial = await _cargarDesdePrefs(prefs);
  final notifier = DispositivosNotifier(inicial);

  runApp(MyApp(notifier: notifier));
}

Future<List<Dispositivo>> _cargarDesdePrefs(SharedPreferences prefs) async {
  try {
    final raw = prefs.getString('dispositivos');
    if (raw == null) return _dispositivosDemo();
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Dispositivo.fromJson(e)).toList();
  } catch (_) {
    return _dispositivosDemo();
  }
}

List<Dispositivo> _dispositivosDemo() => [
      Dispositivo(
        id: 1,
        nombre: 'Lámpara Sala',
        tipo: 'tasmota',
        ip: '192.168.1.100',
        encendido: false,
      ),
      Dispositivo(
        id: 2,
        nombre: 'Aire Acondicionado',
        tipo: 'tasmota',
        ip: '192.168.1.101',
        encendido: false,
      ),
      Dispositivo(
        id: 3,
        nombre: 'Luces Jardín',
        tipo: 'sonoff',
        ip: '192.168.1.102',
        encendido: false,
      ),
    ];

class Dispositivo {
  final int id;
  final String nombre;
  final String tipo;
  final String ip;
  bool encendido;

  Dispositivo({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.ip,
    this.encendido = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'tipo': tipo,
        'ip': ip,
        'encendido': encendido,
      };

  factory Dispositivo.fromJson(Map<String, dynamic> j) => Dispositivo(
        id: j['id'],
        nombre: j['nombre'],
        tipo: j['tipo'],
        ip: j['ip'],
        encendido: j['encendido'] ?? false,
      );
}

class DeviceController {
  static Future<bool> enviarComando(String ip, String comando) async {
    try {
      final socket = await Socket.connect(ip, 80,
          timeout: const Duration(seconds: 2));
      final request =
          'GET $comando HTTP/1.1\r\nHost: $ip\r\nConnection: close\r\n\r\n';
      socket.add(utf8.encode(request));
      await socket.flush();
      await socket.close();
      return true;
    } catch (e) {
      debugPrint('Error enviando comando a $ip: $e');
      return false;
    }
  }

  static Future<bool> encender(String ip, String tipo) async {
    String comando;
    switch (tipo.toLowerCase()) {
      case 'tasmota':
        comando = '/cm?cmnd=Power%20On';
        break;
      case 'sonoff':
        comando = '/control?cmd=on';
        break;
      case 'shelly':
        comando = '/relay/0?turn=on';
        break;
      default:
        comando = '/on';
    }
    return enviarComando(ip, comando);
  }

  static Future<bool> apagar(String ip, String tipo) async {
    String comando;
    switch (tipo.toLowerCase()) {
      case 'tasmota':
        comando = '/cm?cmnd=Power%20Off';
        break;
      case 'sonoff':
        comando = '/control?cmd=off';
        break;
      case 'shelly':
        comando = '/relay/0?turn=off';
        break;
      default:
        comando = '/off';
    }
    return enviarComando(ip, comando);
  }

  static Future<bool> probarConexion(String ip) async {
    try {
      final socket = await Socket.connect(ip, 80,
          timeout: const Duration(seconds: 2));
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }
}

class DispositivosNotifier extends ChangeNotifier {
  List<Dispositivo> _items = [];
  SharedPreferences? _prefs;
  int _nextId = 1;

  DispositivosNotifier(List<Dispositivo> initial) {
    _items = List.of(initial);
    if (_items.isNotEmpty) {
      _nextId = _items.map((d) => d.id).reduce((a, b) => a > b ? a : b) + 1;
    }
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
  }

  List<Dispositivo> get items => List.unmodifiable(_items);

  Future<bool> toggle(int id) async {
    final index = _items.indexWhere((d) => d.id == id);
    if (index == -1) return false;

    final dispositivo = _items[index];
    bool success;

    if (!dispositivo.encendido) {
      success = await DeviceController.encender(dispositivo.ip, dispositivo.tipo);
      if (success) {
        _items[index] = Dispositivo(
          id: dispositivo.id,
          nombre: dispositivo.nombre,
          tipo: dispositivo.tipo,
          ip: dispositivo.ip,
          encendido: true,
        );
      }
    } else {
      success = await DeviceController.apagar(dispositivo.ip, dispositivo.tipo);
      if (success) {
        _items[index] = Dispositivo(
          id: dispositivo.id,
          nombre: dispositivo.nombre,
          tipo: dispositivo.tipo,
          ip: dispositivo.ip,
          encendido: false,
        );
      }
    }

    if (success) {
      notifyListeners();
      _guardar();
    }
    return success;
  }

  void agregar(String nombre, String tipo, String ip) {
    _items.add(Dispositivo(
      id: _nextId++,
      nombre: nombre,
      tipo: tipo.toLowerCase(),
      ip: ip,
    ));
    notifyListeners();
    _guardar();
  }

  void eliminar(int id) {
    _items.removeWhere((d) => d.id == id);
    notifyListeners();
    _guardar();
  }

  void _guardar() {
    final json = jsonEncode(_items.map((d) => d.toJson()).toList());
    _prefs?.setString('dispositivos', json);
  }
}

class MyApp extends StatelessWidget {
  final DispositivosNotifier notifier;
  const MyApp({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Domótica Pro',
      theme: ThemeData.dark(),
      home: HomePage(notifier: notifier),
    );
  }
}

class HomePage extends StatefulWidget {
  final DispositivosNotifier notifier;
  const HomePage({required this.notifier});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _tipoCtrl = TextEditingController();
  final _ipCtrl = TextEditingController();
  String? _errorMessage;

  void _mostrarSnackBar(String mensaje, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _agregarDispositivo() async {
    if (_formKey.currentState!.validate()) {
      final nombre = _nombreCtrl.text.trim();
      final tipo = _tipoCtrl.text.trim().isEmpty ? 'tasmota' : _tipoCtrl.text.trim();
      final ip = _ipCtrl.text.trim();

      final ok = await DeviceController.probarConexion(ip);
      if (!ok) {
        _mostrarSnackBar('No se pudo conectar a $ip. Verifica la IP.', isError: true);
        return;
      }

      widget.notifier.agregar(nombre, tipo, ip);
      _nombreCtrl.clear();
      _tipoCtrl.clear();
      _ipCtrl.clear();
      Navigator.pop(context);
      _mostrarSnackBar('Dispositivo agregado correctamente');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Control Domótico'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _mostrarAyuda(context),
          ),
        ],
      ),
      body: widget.notifier.items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.devices_other, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No hay dispositivos', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _mostrarDialogAgregar(),
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar dispositivo'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {},
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: widget.notifier.items.length,
                itemBuilder: (context, index) {
                  final d = widget.notifier.items[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Icon(
                        d.encendido ? Icons.power : Icons.power_off,
                        color: d.encendido ? Colors.green : Colors.red,
                      ),
                      title: Text(d.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${d.tipo} | ${d.ip}'),
                      trailing: Switch(
                        value: d.encendido,
                        onChanged: (_) async {
                          final success = await widget.notifier.toggle(d.id);
                          if (!success && mounted) {
                            _mostrarSnackBar('No se pudo controlar ${d.nombre}', isError: true);
                          }
                        },
                      ),
                      onLongPress: () => _confirmarEliminar(d.id, d.nombre),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: widget.notifier.items.isNotEmpty
          ? FloatingActionButton(
              onPressed: _mostrarDialogAgregar,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _mostrarAyuda(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ayuda'),
        content: const Text(
          '1. Agrega dispositivos con su IP.\n'
          '2. Tipos soportados: tasmota, sonoff, shelly.\n'
          '3. Los dispositivos deben estar en la misma red WiFi.\n'
          '4. Mantén presionado un dispositivo para eliminarlo.\n'
          '5. Si no funciona, verifica que la IP sea correcta.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  void _confirmarEliminar(int id, String nombre) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar'),
        content: Text('¿Eliminar "$nombre"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              widget.notifier.eliminar(id);
              Navigator.pop(context);
              _mostrarSnackBar('Dispositivo eliminado');
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogAgregar() {
    _nombreCtrl.clear();
    _tipoCtrl.clear();
    _ipCtrl.clear();
    _errorMessage = null;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Agregar Dispositivo'),
            content: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre *',
                      hintText: 'Ej: Lámpara Sala',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _tipoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      hintText: 'tasmota, sonoff, shelly',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _ipCtrl,
                    decoration: InputDecoration(
                      labelText: 'IP *',
                      hintText: '192.168.1.100',
                      errorText: _errorMessage,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'IP requerida';
                      final pattern = r'^(\d{1,3}\.){3}\d{1,3}$';
                      if (!RegExp(pattern).hasMatch(v.trim())) return 'IP inválida';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final ip = _ipCtrl.text.trim();
                      if (ip.isEmpty) {
                        setState(() => _errorMessage = 'Ingresa una IP primero');
                        return;
                      }
                      final ok = await DeviceController.probarConexion(ip);
                      if (ok) {
                        setState(() => _errorMessage = null);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✓ Conexión exitosa')),
                        );
                      } else {
                        setState(() => _errorMessage = 'No responde. Verifica IP');
                      }
                    },
                    icon: const Icon(Icons.network_check),
                    label: const Text('Probar conexión'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: _agregarDispositivo,
                child: const Text('Agregar'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _tipoCtrl.dispose();
    _ipCtrl.dispose();
    super.dispose();
  }
}
