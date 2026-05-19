import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

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
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Dispositivo.fromJson(e)).toList();
  } catch (_) {
    return [];
  }
}

// Modelo simple
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

// Controlador HTTP
class DeviceController {
  static Future<bool> encender(String ip, String tipo) async {
    try {
      Uri url;
      if (tipo == 'tasmota') {
        url = Uri.parse('http://$ip/cm?cmnd=Power%20On');
      } else if (tipo == 'sonoff') {
        url = Uri.parse('http://$ip/control?cmd=on');
      } else if (tipo == 'shelly') {
        url = Uri.parse('http://$ip/relay/0?turn=on');
      } else {
        url = Uri.parse('http://$ip/on');
      }
      
      final response = await http.get(url).timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (e) {
      print('Error encendiendo: $e');
      return false;
    }
  }

  static Future<bool> apagar(String ip, String tipo) async {
    try {
      Uri url;
      if (tipo == 'tasmota') {
        url = Uri.parse('http://$ip/cm?cmnd=Power%20Off');
      } else if (tipo == 'sonoff') {
        url = Uri.parse('http://$ip/control?cmd=off');
      } else if (tipo == 'shelly') {
        url = Uri.parse('http://$ip/relay/0?turn=off');
      } else {
        url = Uri.parse('http://$ip/off');
      }
      
      final response = await http.get(url).timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (e) {
      print('Error apagando: $e');
      return false;
    }
  }
}

// Estado global
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

  Future<void> toggle(int id) async {
    final index = _items.indexWhere((d) => d.id == id);
    if (index == -1) return;
    
    final dispositivo = _items[index];
    bool success;
    
    if (!dispositivo.encendido) {
      success = await DeviceController.encender(dispositivo.ip, dispositivo.tipo);
      if (success) {
        _items[index] = dispositivo.copyWith(encendido: true);
      }
    } else {
      success = await DeviceController.apagar(dispositivo.ip, dispositivo.tipo);
      if (success) {
        _items[index] = dispositivo.copyWith(encendido: false);
      }
    }
    
    if (success) {
      notifyListeners();
      _guardar();
    }
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

// App principal
class MyApp extends StatelessWidget {
  final DispositivosNotifier notifier;
  const MyApp({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Domótica',
      theme: ThemeData.dark(),
      home: HomePage(notifier: notifier),
    );
  }
}

// Pantalla principal simple y funcional
class HomePage extends StatelessWidget {
  final DispositivosNotifier notifier;
  const HomePage({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Control Domótico'),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: notifier.items.length,
        itemBuilder: (context, index) {
          final dispositivo = notifier.items[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(
                dispositivo.encendido ? Icons.power : Icons.power_off,
                color: dispositivo.encendido ? Colors.green : Colors.red,
              ),
              title: Text(dispositivo.nombre),
              subtitle: Text('${dispositivo.tipo} | ${dispositivo.ip}'),
              trailing: Switch(
                value: dispositivo.encendido,
                onChanged: (_) => notifier.toggle(dispositivo.id),
              ),
              onLongPress: () => _confirmarEliminar(context, notifier, dispositivo.id),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarDialogAgregar(context, notifier),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _confirmarEliminar(BuildContext context, DispositivosNotifier notifier, int id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar'),
        content: const Text('¿Eliminar este dispositivo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              notifier.eliminar(id);
              Navigator.pop(context);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogAgregar(BuildContext context, DispositivosNotifier notifier) {
    final nombreCtrl = TextEditingController();
    final tipoCtrl = TextEditingController();
    final ipCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Agregar Dispositivo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: 'Ej: Lampara Sala',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: tipoCtrl,
              decoration: const InputDecoration(
                labelText: 'Tipo',
                hintText: 'tasmota, sonoff, shelly',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ipCtrl,
              decoration: const InputDecoration(
                labelText: 'IP',
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
              if (nombreCtrl.text.isNotEmpty && ipCtrl.text.isNotEmpty) {
                notifier.agregar(
                  nombreCtrl.text,
                  tipoCtrl.text.isNotEmpty ? tipoCtrl.text : 'tasmota',
                  ipCtrl.text,
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

// Extensión para copyWith
extension DispositivoCopy on Dispositivo {
  Dispositivo copyWith({bool? encendido}) {
    return Dispositivo(
      id: id,
      nombre: nombre,
      tipo: tipo,
      ip: ip,
      encendido: encendido ?? this.encendido,
    );
  }
}
