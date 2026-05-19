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
  static Future<bool> encender(String ip, String tipo) async {
    try {
      String path;
      if (tipo == 'tasmota') {
        path = '/cm?cmnd=Power%20On';
      } else if (tipo == 'sonoff') {
        path = '/control?cmd=on';
      } else if (tipo == 'shelly') {
        path = '/relay/0?turn=on';
      } else {
        path = '/on';
      }
      
      final socket = await Socket.connect(ip, 80, timeout: const Duration(seconds: 2));
      final request = 'GET $path HTTP/1.1\r\nHost: $ip\r\nConnection: close\r\n\r\n';
      socket.add(utf8.encode(request));
      await socket.flush();
      await socket.close();
      return true;
    } catch (e) {
      print('Error encendiendo: $e');
      return false;
    }
  }

  static Future<bool> apagar(String ip, String tipo) async {
    try {
      String path;
      if (tipo == 'tasmota') {
        path = '/cm?cmnd=Power%20Off';
      } else if (tipo == 'sonoff') {
        path = '/control?cmd=off';
      } else if (tipo == 'shelly') {
        path = '/relay/0?turn=off';
      } else {
        path = '/off';
      }
      
      final socket = await Socket.connect(ip, 80, timeout: const Duration(seconds: 2));
      final request = 'GET $path HTTP/1.1\r\nHost: $ip\r\nConnection: close\r\n\r\n';
      socket.add(utf8.encode(request));
      await socket.flush();
      await socket.close();
      return true;
    } catch (e) {
      print('Error apagando: $e');
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

  Future<void> toggle(int id) async {
    final index = _items.indexWhere((d) => d.id == id);
    if (index == -1) return;
    
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
      title: 'Domótica',
      theme: ThemeData.dark(),
      home: HomePage(notifier: notifier),
    );
  }
}

class HomePage extends StatelessWidget {
  final DispositivosNotifier notifier;
  const HomePage({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Control Domótico'),
        centerTitle: true,
        backgroundColor: Colors.blue,
      ),
      body: notifier.items.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.devices_other, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No hay dispositivos', style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('Presiona + para agregar', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            )
          : ListView.builder(
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
                    title: Text(dispositivo.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
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
            TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej: Lampara Sala')),
            const SizedBox(height: 10),
            TextField(controller: tipoCtrl, decoration: const InputDecoration(labelText: 'Tipo', hintText: 'tasmota, sonoff, shelly')),
            const SizedBox(height: 10),
            TextField(controller: ipCtrl, decoration: const InputDecoration(labelText: 'IP', hintText: '192.168.1.100')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
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
