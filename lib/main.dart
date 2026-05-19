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
  final dispositivosGuardados = _cargarDesdePrefs(prefs);
  final notifier = DispositivosNotifier(dispositivosGuardados);

  runApp(MyApp(notifier: notifier));
}

List<Dispositivo> _cargarDesdePrefs(SharedPreferences prefs) {
  try {
    final raw = prefs.getString('dispositivos');
    if (raw == null) return [];
    final List list = jsonDecode(raw);
    return list.map((e) => Dispositivo.fromJson(e)).toList();
  } catch (e) {
    return [];
  }
}

// Modelo de dispositivo
class Dispositivo {
  final int id;
  final String nombre;
  final String tipo;    // tasmota, sonoff, shelly
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

  factory Dispositivo.fromJson(Map<String, dynamic> json) => Dispositivo(
    id: json['id'],
    nombre: json['nombre'],
    tipo: json['tipo'],
    ip: json['ip'],
    encendido: json['encendido'] ?? false,
  );
}

// Controlador de dispositivos reales (sin paquete http)
class ControladorReal {
  static Future<bool> enviarComando(String ip, String path) async {
    try {
      final socket = await Socket.connect(ip, 80, timeout: const Duration(seconds: 2));
      final request = 'GET $path HTTP/1.1\r\nHost: $ip\r\nConnection: close\r\n\r\n';
      socket.add(utf8.encode(request));
      await socket.flush();
      await socket.close();
      return true;
    } catch (e) {
      debugPrint('Error enviando comando a $ip: $e');
      return false;
    }
  }

  static Future<bool> encender(String tipo, String ip) async {
    String path;
    switch (tipo.toLowerCase()) {
      case 'tasmota':
        path = '/cm?cmnd=Power%20On';
        break;
      case 'sonoff':
        path = '/control?cmd=on';
        break;
      case 'shelly':
        path = '/relay/0?turn=on';
        break;
      default:
        path = '/on';
    }
    return enviarComando(ip, path);
  }

  static Future<bool> apagar(String tipo, String ip) async {
    String path;
    switch (tipo.toLowerCase()) {
      case 'tasmota':
        path = '/cm?cmnd=Power%20Off';
        break;
      case 'sonoff':
        path = '/control?cmd=off';
        break;
      case 'shelly':
        path = '/relay/0?turn=off';
        break;
      default:
        path = '/off';
    }
    return enviarComando(ip, path);
  }

  // Probar si el dispositivo responde en el puerto 80
  static Future<bool> probarConexion(String ip) async {
    try {
      final socket = await Socket.connect(ip, 80, timeout: const Duration(seconds: 1));
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }
}

// Estado global (ChangeNotifier)
class DispositivosNotifier extends ChangeNotifier {
  List<Dispositivo> _items = [];
  SharedPreferences? _prefs;
  int _nextId = 1;

  DispositivosNotifier(List<Dispositivo> inicial) {
    _items = List.of(inicial);
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

    final d = _items[index];
    bool exito;

    if (!d.encendido) {
      exito = await ControladorReal.encender(d.tipo, d.ip);
      if (exito) _items[index] = Dispositivo(id: d.id, nombre: d.nombre, tipo: d.tipo, ip: d.ip, encendido: true);
    } else {
      exito = await ControladorReal.apagar(d.tipo, d.ip);
      if (exito) _items[index] = Dispositivo(id: d.id, nombre: d.nombre, tipo: d.tipo, ip: d.ip, encendido: false);
    }

    if (exito) {
      notifyListeners();
      _guardar();
    }
    return exito;
  }

  Future<bool> agregar(String nombre, String tipo, String ip) async {
    // Verificar que el dispositivo responde antes de agregar
    final ok = await ControladorReal.probarConexion(ip);
    if (!ok) return false;

    _items.add(Dispositivo(
      id: _nextId++,
      nombre: nombre.trim(),
      tipo: tipo.toLowerCase(),
      ip: ip.trim(),
    ));
    notifyListeners();
    _guardar();
    return true;
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

// Aplicación principal
class MyApp extends StatelessWidget {
  final DispositivosNotifier notifier;
  const MyApp({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Domótica Real',
      theme: ThemeData.dark(useMaterial3: true),
      home: HomePage(notifier: notifier),
    );
  }
}

// Pantalla principal
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
  bool _probando = false;

  void _mostrarSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Control Domótico Real'),
        centerTitle: true,
        backgroundColor: Colors.blue,
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
                    onPressed: _mostrarDialogAgregar,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar dispositivo real'),
                  ),
                ],
              ),
            )
          : ListView.builder(
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
                    subtitle: Text('${d.tipo.toUpperCase()} | ${d.ip}'),
                    trailing: Switch(
                      value: d.encendido,
                      onChanged: (_) async {
                        final ok = await widget.notifier.toggle(d.id);
                        if (!ok && mounted) {
                          _mostrarSnack('Error al controlar ${d.nombre}', error: true);
                        }
                      },
                    ),
                    onLongPress: () => _confirmarEliminar(d.id, d.nombre),
                  ),
                );
              },
            ),
      floatingActionButton: widget.notifier.items.isNotEmpty
          ? FloatingActionButton(
              onPressed: _mostrarDialogAgregar,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _confirmarEliminar(int id, String nombre) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar dispositivo'),
        content: Text('¿Eliminar "$nombre"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              widget.notifier.eliminar(id);
              Navigator.pop(context);
              _mostrarSnack('Dispositivo eliminado');
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
    _probando = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Agregar dispositivo REAL'),
            content: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nombreCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej: Lámpara Sala'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _tipoCtrl,
                    decoration: const InputDecoration(labelText: 'Tipo', hintText: 'tasmota, sonoff, shelly'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _ipCtrl,
                    decoration: InputDecoration(
                      labelText: 'IP',
                      hintText: '192.168.1.100',
                      suffixIcon: _probando
                          ? const SizedBox(width: 20, child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))))
                          : null,
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
                    onPressed: _probando ? null : () async {
                      final ip = _ipCtrl.text.trim();
                      if (ip.isEmpty) {
                        _mostrarSnack('Ingresa una IP primero', error: true);
                        return;
                      }
                      setState(() => _probando = true);
                      final ok = await ControladorReal.probarConexion(ip);
                      setState(() => _probando = false);
                      if (ok) {
                        _mostrarSnack('✓ Dispositivo responde en $ip');
                      } else {
                        _mostrarSnack('✗ No se pudo conectar a $ip', error: true);
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
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final nombre = _nombreCtrl.text.trim();
                    final tipo = _tipoCtrl.text.trim();
                    final ip = _ipCtrl.text.trim();
                    final success = await widget.notifier.agregar(nombre, tipo, ip);
                    if (success) {
                      Navigator.pop(context);
                      _mostrarSnack('Dispositivo agregado');
                    } else {
                      _mostrarSnack('No se pudo conectar al dispositivo', error: true);
                    }
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

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _tipoCtrl.dispose();
    _ipCtrl.dispose();
    super.dispose();
  }
}
