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
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Dispositivo.fromJson(e)).toList();
  } catch (_) {
    return [];
  }
}

class Dispositivo {
  final int id;
  final String nombre;
  final String tipo;
  final String ip;
  bool encendido;
  bool esSimulado; // para modo demostración

  Dispositivo({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.ip,
    this.encendido = false,
    this.esSimulado = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'tipo': tipo,
        'ip': ip,
        'encendido': encendido,
        'esSimulado': esSimulado,
      };

  factory Dispositivo.fromJson(Map<String, dynamic> j) => Dispositivo(
        id: j['id'],
        nombre: j['nombre'],
        tipo: j['tipo'],
        ip: j['ip'],
        encendido: j['encendido'] ?? false,
        esSimulado: j['esSimulado'] ?? false,
      );
}

class DeviceController {
  static Future<bool> enviarComandoReal(String ip, String comando) async {
    try {
      final socket = await Socket.connect(ip, 80, timeout: const Duration(seconds: 2));
      final request = 'GET $comando HTTP/1.1\r\nHost: $ip\r\nConnection: close\r\n\r\n';
      socket.add(utf8.encode(request));
      await socket.flush();
      await socket.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> encenderReal(String ip, String tipo) async {
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
    return enviarComandoReal(ip, comando);
  }

  static Future<bool> apagarReal(String ip, String tipo) async {
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
    return enviarComandoReal(ip, comando);
  }

  static Future<bool> probarConexionReal(String ip) async {
    try {
      final socket = await Socket.connect(ip, 80, timeout: const Duration(seconds: 1));
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  // Escaneo de red básico (puerto 80 abierto)
  static Future<List<String>> escanearRed(String subnet) async {
    List<String> encontrados = [];
    for (int i = 1; i <= 254; i++) {
      final ip = '$subnet.$i';
      try {
        final socket = await Socket.connect(ip, 80, timeout: const Duration(milliseconds: 300));
        await socket.close();
        encontrados.add(ip);
      } catch (_) {}
    }
    return encontrados;
  }
}

class DispositivosNotifier extends ChangeNotifier {
  List<Dispositivo> _items = [];
  SharedPreferences? _prefs;
  int _nextId = 1;
  bool _modoSimulacion = true; // Por defecto simulación

  DispositivosNotifier(List<Dispositivo> initial) {
    _items = List.of(initial);
    if (_items.isEmpty) {
      // Agregar dispositivos de demostración
      _items.addAll([
        Dispositivo(id: _nextId++, nombre: 'Demo Luz Sala', tipo: 'demo', ip: 'simulado', encendido: false, esSimulado: true),
        Dispositivo(id: _nextId++, nombre: 'Demo TV', tipo: 'demo', ip: 'simulado', encendido: false, esSimulado: true),
        Dispositivo(id: _nextId++, nombre: 'Demo Aire', tipo: 'demo', ip: 'simulado', encendido: false, esSimulado: true),
      ]);
    } else {
      _nextId = _items.map((d) => d.id).reduce((a, b) => a > b ? a : b) + 1;
    }
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
  }

  List<Dispositivo> get items => List.unmodifiable(_items);
  bool get modoSimulacion => _modoSimulacion;

  void toggleModoSimulacion() {
    _modoSimulacion = !_modoSimulacion;
    notifyListeners();
  }

  Future<bool> toggle(int id) async {
    final index = _items.indexWhere((d) => d.id == id);
    if (index == -1) return false;

    final d = _items[index];
    bool success;

    if (_modoSimulacion || d.esSimulado) {
      // Modo demostración: simular siempre éxito
      success = true;
      await Future.delayed(const Duration(milliseconds: 300)); // simular latencia
    } else {
      // Modo real
      if (!d.encendido) {
        success = await DeviceController.encenderReal(d.ip, d.tipo);
      } else {
        success = await DeviceController.apagarReal(d.ip, d.tipo);
      }
    }

    if (success) {
      _items[index] = Dispositivo(
        id: d.id,
        nombre: d.nombre,
        tipo: d.tipo,
        ip: d.ip,
        encendido: !d.encendido,
        esSimulado: d.esSimulado,
      );
      notifyListeners();
      _guardar();
    }
    return success;
  }

  Future<void> agregarDispositivoReal(String nombre, String tipo, String ip) async {
    // Verificar si realmente responde antes de agregar
    final ok = await DeviceController.probarConexionReal(ip);
    if (!ok) throw Exception('No se pudo conectar a $ip');
    _items.add(Dispositivo(
      id: _nextId++,
      nombre: nombre,
      tipo: tipo.toLowerCase(),
      ip: ip,
      esSimulado: false,
    ));
    notifyListeners();
    _guardar();
  }

  void agregarDispositivoDemo(String nombre, String tipo) {
    _items.add(Dispositivo(
      id: _nextId++,
      nombre: nombre,
      tipo: tipo,
      ip: 'simulado',
      esSimulado: true,
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
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
      ),
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
  final _nombreCtrl = TextEditingController();
  final _tipoCtrl = TextEditingController();
  final _ipCtrl = TextEditingController();

  void _mostrarSnackBar(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Domótica Pro'),
        centerTitle: true,
        actions: [
          Switch(
            value: widget.notifier.modoSimulacion,
            onChanged: (_) => widget.notifier.toggleModoSimulacion(),
            activeColor: Colors.blue,
          ),
          const SizedBox(width: 8),
          Text(widget.notifier.modoSimulacion ? 'DEMO' : 'REAL', style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _mostrarAyuda(),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: widget.notifier.modoSimulacion ? Colors.orange.shade900 : Colors.green.shade900,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.notifier.modoSimulacion ? Icons.smart_toy : Icons.wifi, size: 16),
                const SizedBox(width: 8),
                Text(
                  widget.notifier.modoSimulacion
                      ? 'MODO DEMOSTRACIÓN - Los toggles son simulados'
                      : 'MODO REAL - Controla dispositivos físicos',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: widget.notifier.items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.devices_other, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('No hay dispositivos'),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () => _mostrarDialogAgregar(),
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
                          subtitle: Text(d.esSimulado ? '${d.tipo} | Simulado' : '${d.tipo} | ${d.ip}'),
                          trailing: Switch(
                            value: d.encendido,
                            onChanged: (_) async {
                              final ok = await widget.notifier.toggle(d.id);
                              if (!ok && mounted) {
                                _mostrarSnackBar('Error al controlar ${d.nombre}', error: true);
                              } else if (ok && mounted && !widget.notifier.modoSimulacion && !d.esSimulado) {
                                _mostrarSnackBar('${d.nombre} ${d.encendido ? "apagado" : "encendido"} correctamente');
                              }
                            },
                          ),
                          onLongPress: () => _confirmarEliminar(d.id, d.nombre),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarDialogAgregar,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _mostrarAyuda() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Modos de uso'),
        content: const Text(
          '🔵 MODO DEMO (switch azul):\n'
          '• Simula encendido/apagado sin red\n'
          '• Ideal para probar la app\n\n'
          '🟢 MODO REAL (switch verde):\n'
          '• Controla dispositivos reales\n'
          '• Deben estar en la misma WiFi\n'
          '• Soporta Tasmota, Sonoff, Shelly\n\n'
          '➕ Agregar dispositivo:\n'
          '• Demo: solo nombre y tipo\n'
          '• Real: IP válida y tipo correcto',
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
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
    final isDemo = widget.notifier.modoSimulacion;
    _nombreCtrl.clear();
    _tipoCtrl.clear();
    _ipCtrl.clear();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isDemo ? 'Agregar dispositivo DEMO' : 'Agregar dispositivo REAL'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej: Lampara Sala'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _tipoCtrl,
                decoration: const InputDecoration(labelText: 'Tipo', hintText: 'tasmota, sonoff, shelly, demo'),
              ),
              if (!isDemo) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _ipCtrl,
                  decoration: const InputDecoration(labelText: 'IP', hintText: '192.168.1.100'),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () async {
                    final ip = _ipCtrl.text.trim();
                    if (ip.isEmpty) return;
                    final ok = await DeviceController.probarConexionReal(ip);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ok ? '✓ Dispositivo responde' : '✗ No responde'), backgroundColor: ok ? Colors.green : Colors.red),
                    );
                  },
                  icon: const Icon(Icons.network_check),
                  label: const Text('Probar conexión'),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final nombre = _nombreCtrl.text.trim();
              if (nombre.isEmpty) return;
              final tipo = _tipoCtrl.text.trim();
              if (isDemo) {
                widget.notifier.agregarDispositivoDemo(nombre, tipo.isEmpty ? 'demo' : tipo);
                Navigator.pop(context);
                _mostrarSnackBar('Dispositivo demo agregado');
              } else {
                final ip = _ipCtrl.text.trim();
                if (ip.isEmpty) {
                  _mostrarSnackBar('Ingresa una IP', error: true);
                  return;
                }
                try {
                  await widget.notifier.agregarDispositivoReal(nombre, tipo, ip);
                  Navigator.pop(context);
                  _mostrarSnackBar('Dispositivo real agregado');
                } catch (e) {
                  _mostrarSnackBar(e.toString(), error: true);
                }
              }
            },
            child: const Text('Agregar'),
          ),
        ],
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
