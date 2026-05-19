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
  final inicial = _cargarDesdePrefs(prefs);
  final notifier = DispositivosNotifier(inicial);

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

// Modelo de dispositivo (ahora con puerto opcional para celular)
class Dispositivo {
  final int id;
  final String nombre;
  final String tipo;    // 'tasmota', 'sonoff', 'shelly', 'celular'
  final String ip;
  final int puerto;     // solo usado si tipo == 'celular'
  bool encendido;

  Dispositivo({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.ip,
    this.puerto = 8080,   // puerto por defecto para celular
    this.encendido = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'tipo': tipo,
    'ip': ip,
    'puerto': puerto,
    'encendido': encendido,
  };

  factory Dispositivo.fromJson(Map<String, dynamic> json) => Dispositivo(
    id: json['id'],
    nombre: json['nombre'],
    tipo: json['tipo'],
    ip: json['ip'],
    puerto: json['puerto'] ?? 8080,
    encendido: json['encendido'] ?? false,
  );

  Dispositivo copyWith({bool? encendido}) {
    return Dispositivo(
      id: id,
      nombre: nombre,
      tipo: tipo,
      ip: ip,
      puerto: puerto,
      encendido: encendido ?? this.encendido,
    );
  }
}

// Controlador universal para dispositivos reales (sin paquete http)
class ControladorReal {
  // Envía un comando GET genérico
  static Future<bool> enviarGet(String ip, int puerto, String path) async {
    try {
      final socket = await Socket.connect(ip, puerto, timeout: const Duration(seconds: 2));
      final request = 'GET $path HTTP/1.1\r\nHost: $ip\r\nConnection: close\r\n\r\n';
      socket.add(utf8.encode(request));
      await socket.flush();
      await socket.close();
      return true;
    } catch (e) {
      debugPrint('Error enviando comando a $ip:$puerto$path - $e');
      return false;
    }
  }

  // Control para Tasmota, Sonoff, Shelly (puerto 80)
  static Future<bool> encenderIoT(String tipo, String ip) async {
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
    return enviarGet(ip, 80, path);
  }

  static Future<bool> apagarIoT(String tipo, String ip) async {
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
    return enviarGet(ip, 80, path);
  }

  // Control para linterna de otro celular (puerto configurable, paths /on y /off)
  static Future<bool> encenderCelular(String ip, int puerto) async {
    return enviarGet(ip, puerto, '/on');
  }

  static Future<bool> apagarCelular(String ip, int puerto) async {
    return enviarGet(ip, puerto, '/off');
  }

  // Probar conexión a un IP:puerto (para cualquier tipo)
  static Future<bool> probarConexion(String ip, int puerto) async {
    try {
      final socket = await Socket.connect(ip, puerto, timeout: const Duration(seconds: 1));
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
  bool _modoDemo = false;   // si está en true, simula toggles sin red

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
  bool get modoDemo => _modoDemo;
  void toggleModoDemo() {
    _modoDemo = !_modoDemo;
    notifyListeners();
  }

  Future<bool> toggle(int id) async {
    final index = _items.indexWhere((d) => d.id == id);
    if (index == -1) return false;
    final d = _items[index];

    bool exito;
    if (_modoDemo) {
      // simular siempre éxito
      exito = true;
      await Future.delayed(const Duration(milliseconds: 300));
    } else {
      // control real según tipo
      if (d.tipo == 'celular') {
        if (!d.encendido) {
          exito = await ControladorReal.encenderCelular(d.ip, d.puerto);
        } else {
          exito = await ControladorReal.apagarCelular(d.ip, d.puerto);
        }
      } else {
        // IoT: tasmota, sonoff, shelly, etc.
        if (!d.encendido) {
          exito = await ControladorReal.encenderIoT(d.tipo, d.ip);
        } else {
          exito = await ControladorReal.apagarIoT(d.tipo, d.ip);
        }
      }
    }

    if (exito) {
      _items[index] = d.copyWith(encendido: !d.encendido);
      notifyListeners();
      _guardar();
    }
    return exito;
  }

  // Agregar dispositivo IoT (sin puerto, usa 80)
  Future<bool> agregarIoT(String nombre, String tipo, String ip) async {
    final ok = await ControladorReal.probarConexion(ip, 80);
    if (!ok) return false;
    _items.add(Dispositivo(
      id: _nextId++,
      nombre: nombre.trim(),
      tipo: tipo.toLowerCase(),
      ip: ip.trim(),
      puerto: 80,
    ));
    notifyListeners();
    _guardar();
    return true;
  }

  // Agregar dispositivo celular (con puerto)
  Future<bool> agregarCelular(String nombre, String ip, int puerto) async {
    final ok = await ControladorReal.probarConexion(ip, puerto);
    if (!ok) return false;
    _items.add(Dispositivo(
      id: _nextId++,
      nombre: nombre.trim(),
      tipo: 'celular',
      ip: ip.trim(),
      puerto: puerto,
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
      title: 'Domótica Pro',
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
  void _mostrarSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Control Domótico'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        actions: [
          Row(
            children: [
              const Text('Demo'),
              Switch(
                value: widget.notifier.modoDemo,
                onChanged: (_) => widget.notifier.toggleModoDemo(),
                activeColor: Colors.orange,
              ),
            ],
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
                    onPressed: _mostrarDialogOpciones,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar dispositivo'),
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
                    subtitle: Text(
                      d.tipo == 'celular'
                          ? '📱 Celular | ${d.ip}:${d.puerto}'
                          : '🔌 ${d.tipo.toUpperCase()} | ${d.ip}',
                    ),
                    trailing: Switch(
                      value: d.encendido,
                      onChanged: (_) async {
                        final ok = await widget.notifier.toggle(d.id);
                        if (!ok && mounted) {
                          _mostrarSnack('Error al controlar ${d.nombre}', error: true);
                        } else if (ok && !widget.notifier.modoDemo) {
                          _mostrarSnack('${d.nombre} ${d.encendido ? "apagado" : "encendido"}');
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
              onPressed: _mostrarDialogOpciones,
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

  void _mostrarDialogOpciones() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tipo de dispositivo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.device_hub),
              title: const Text('IoT (Tasmota/Sonoff/Shelly)'),
              onTap: () {
                Navigator.pop(context);
                _mostrarDialogAgregarIoT();
              },
            ),
            ListTile(
              leading: const Icon(Icons.phone_android),
              title: const Text('Otro celular (linterna)'),
              onTap: () {
                Navigator.pop(context);
                _mostrarDialogAgregarCelular();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogAgregarIoT() {
    final nombreCtrl = TextEditingController();
    final tipoCtrl = TextEditingController();
    final ipCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Agregar dispositivo IoT'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej: Lámpara Sala'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: tipoCtrl,
                decoration: const InputDecoration(labelText: 'Tipo', hintText: 'tasmota, sonoff, shelly'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: ipCtrl,
                decoration: const InputDecoration(labelText: 'IP', hintText: '192.168.1.100'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'IP requerida';
                  final pattern = r'^(\d{1,3}\.){3}\d{1,3}$';
                  if (!RegExp(pattern).hasMatch(v.trim())) return 'IP inválida';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final nombre = nombreCtrl.text.trim();
                final tipo = tipoCtrl.text.trim();
                final ip = ipCtrl.text.trim();
                final success = await widget.notifier.agregarIoT(nombre, tipo, ip);
                if (success) {
                  Navigator.pop(context);
                  _mostrarSnack('Dispositivo IoT agregado');
                } else {
                  _mostrarSnack('No se pudo conectar al dispositivo', error: true);
                }
              }
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogAgregarCelular() {
    final nombreCtrl = TextEditingController();
    final ipCtrl = TextEditingController();
    final puertoCtrl = TextEditingController(text: '8080');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Agregar otro celular (linterna)'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej: Linterna Juan'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: ipCtrl,
                decoration: const InputDecoration(labelText: 'IP del celular', hintText: '192.168.1.50'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'IP requerida';
                  final pattern = r'^(\d{1,3}\.){3}\d{1,3}$';
                  if (!RegExp(pattern).hasMatch(v.trim())) return 'IP inválida';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: puertoCtrl,
                decoration: const InputDecoration(labelText: 'Puerto', hintText: '8080 (default)'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Puerto requerido';
                  if (int.tryParse(v.trim()) == null) return 'Número válido';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () async {
                  final ip = ipCtrl.text.trim();
                  final puerto = int.tryParse(puertoCtrl.text.trim()) ?? 8080;
                  if (ip.isEmpty) {
                    _mostrarSnack('Ingresa IP primero', error: true);
                    return;
                  }
                  final ok = await ControladorReal.probarConexion(ip, puerto);
                  if (ok) {
                    _mostrarSnack('✓ Celular responde en $ip:$puerto');
                  } else {
                    _mostrarSnack('✗ No se pudo conectar', error: true);
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
              if (formKey.currentState!.validate()) {
                final nombre = nombreCtrl.text.trim();
                final ip = ipCtrl.text.trim();
                final puerto = int.parse(puertoCtrl.text.trim());
                final success = await widget.notifier.agregarCelular(nombre, ip, puerto);
                if (success) {
                  Navigator.pop(context);
                  _mostrarSnack('Celular agregado (linterna controlable)');
                } else {
                  _mostrarSnack('No se pudo conectar al celular', error: true);
                }
              }
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }
}
