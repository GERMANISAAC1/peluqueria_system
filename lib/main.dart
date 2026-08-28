// =============================================================================
// GUARDIAN LOCK — main.dart (versión 100% LOCAL, sin API keys)
// =============================================================================
//
// Esta versión NO usa Firebase, NO usa Google Maps, NO usa Google Sign-In ni
// notificaciones push. Todo el login y los datos (dispositivo, historial de
// ubicaciones, contactos, eventos) se guardan cifrados en el propio teléfono:
//
//   - Credenciales de cuenta y sesión → flutter_secure_storage
//   - Historial de ubicaciones, contactos, eventos → sqflite (SQLite local)
//   - Ubicación actual → geolocator (no requiere API key en Android)
//
// LIMITACIÓN IMPORTANTE: al no haber servidor/nube, la cuenta y los datos
// existen SOLO en este dispositivo. No hay sincronización entre teléfonos,
// ni comandos remotos (bloqueo/alarma a distancia), ni alertas push. La
// pantalla de "Mapa" muestra el historial como lista de coordenadas en vez
// de un mapa visual, porque el mapa visual (Google Maps SDK) sí requiere una
// API key — si más adelante quieres agregarlo, dímelo.
//
// REQUISITO: agrega el bloque de dependencias del pubspec.yaml que te di
// junto con este archivo, y corre `flutter pub get`.
// =============================================================================

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

// =============================================================================
// SECCIÓN 1: MODELOS DE DOMINIO
// =============================================================================

class LocationPoint {
  final double latitude;
  final double longitude;
  final int timestamp;

  const LocationPoint({this.latitude = 0.0, this.longitude = 0.0, int? timestamp})
      : timestamp = timestamp ?? 0;

  factory LocationPoint.fromMap(Map<String, dynamic> map) => LocationPoint(
        latitude: (map['latitude'] ?? 0.0).toDouble(),
        longitude: (map['longitude'] ?? 0.0).toDouble(),
        timestamp: map['timestamp'] ?? 0,
      );

  Map<String, dynamic> toMap() =>
      {'latitude': latitude, 'longitude': longitude, 'timestamp': timestamp};
}

class Device {
  final String deviceId;
  final String deviceName;
  final bool isLost;
  final bool hiddenModeEnabled;
  final LocationPoint? lastKnownLocation;

  const Device({
    this.deviceId = '',
    this.deviceName = 'Mi dispositivo',
    this.isLost = false,
    this.hiddenModeEnabled = false,
    this.lastKnownLocation,
  });

  factory Device.fromMap(Map<String, dynamic> map) => Device(
        deviceId: map['deviceId'] ?? '',
        deviceName: map['deviceName'] ?? 'Mi dispositivo',
        isLost: map['isLost'] ?? false,
        hiddenModeEnabled: map['hiddenModeEnabled'] ?? false,
        lastKnownLocation:
            map['lastKnownLocation'] != null ? LocationPoint.fromMap(map['lastKnownLocation']) : null,
      );

  Map<String, dynamic> toMap() => {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'isLost': isLost,
        'hiddenModeEnabled': hiddenModeEnabled,
        'lastKnownLocation': lastKnownLocation?.toMap(),
      };

  Device copyWith({bool? isLost, bool? hiddenModeEnabled, LocationPoint? lastKnownLocation}) => Device(
        deviceId: deviceId,
        deviceName: deviceName,
        isLost: isLost ?? this.isLost,
        hiddenModeEnabled: hiddenModeEnabled ?? this.hiddenModeEnabled,
        lastKnownLocation: lastKnownLocation ?? this.lastKnownLocation,
      );
}

class EmergencyContact {
  final String id;
  final String name;
  final String phoneNumber;

  const EmergencyContact({this.id = '', this.name = '', this.phoneNumber = ''});

  factory EmergencyContact.fromMap(Map<String, dynamic> map) =>
      EmergencyContact(id: map['id'] ?? '', name: map['name'] ?? '', phoneNumber: map['phoneNumber'] ?? '');

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'phoneNumber': phoneNumber};
}

enum SecurityEventType { markedAsLost, markedAsFound, locationUpdated, deviceRegistered, hiddenModeToggled }

class SecurityEvent {
  final String id;
  final SecurityEventType type;
  final String description;
  final int timestamp;

  SecurityEvent({this.id = '', required this.type, required this.description, int? timestamp})
      : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  factory SecurityEvent.fromMap(Map<String, dynamic> map) => SecurityEvent(
        id: map['id'] ?? '',
        type: SecurityEventType.values
            .firstWhere((e) => e.name == map['type'], orElse: () => SecurityEventType.locationUpdated),
        description: map['description'] ?? '',
        timestamp: map['timestamp'] ?? 0,
      );

  Map<String, dynamic> toMap() =>
      {'id': id, 'type': type.name, 'description': description, 'timestamp': timestamp};
}

// =============================================================================
// SECCIÓN 2: BASE DE DATOS LOCAL (SQLite) — historial, contactos, ubicaciones
// =============================================================================

class LocalDatabase {
  LocalDatabase._internal();
  static final LocalDatabase instance = LocalDatabase._internal();
  Database? _db;

  Future<Database> get database async => _db ??= await _init();

  Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    final dbFile = join(dbPath, 'guardian_lock_local.db');
    return openDatabase(
      dbFile,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE security_events (
            id TEXT PRIMARY KEY, type TEXT NOT NULL, description TEXT NOT NULL, timestamp INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE location_history (
            id TEXT PRIMARY KEY, latitude REAL NOT NULL, longitude REAL NOT NULL, timestamp INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE contacts (
            id TEXT PRIMARY KEY, name TEXT NOT NULL, phoneNumber TEXT NOT NULL
          )
        ''');
      },
    );
  }
}

// =============================================================================
// SECCIÓN 3: SERVICIOS LOCALES (reemplazan a Firebase Auth / Firestore)
// =============================================================================

/// Autenticación 100% local: guarda una única cuenta (correo + hash de la
/// contraseña) cifrada con flutter_secure_storage. No hay servidor, así que
/// la cuenta solo existe en este dispositivo.
class LocalAuthService {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyEmail = 'guardian_lock_account_email';
  static const _keyPasswordHash = 'guardian_lock_account_password_hash';
  static const _keySessionActive = 'guardian_lock_session_active';

  String _hash(String input) => sha256.convert(utf8.encode(input)).toString();

  Future<bool> hasAccount() async => (await _storage.read(key: _keyEmail)) != null;

  Future<bool> hasActiveSession() async => (await _storage.read(key: _keySessionActive)) == 'true';

  Future<String?> register(String email, String password) async {
    if (await hasAccount()) {
      return 'Ya existe una cuenta local en este dispositivo. Inicia sesión.';
    }
    await _storage.write(key: _keyEmail, value: email);
    await _storage.write(key: _keyPasswordHash, value: _hash(password));
    await _storage.write(key: _keySessionActive, value: 'true');
    return null; // null = éxito
  }

  Future<String?> signIn(String email, String password) async {
    final storedEmail = await _storage.read(key: _keyEmail);
    final storedHash = await _storage.read(key: _keyPasswordHash);
    if (storedEmail == null) {
      return 'No existe una cuenta local todavía. Regístrate primero.';
    }
    if (storedEmail != email || storedHash != _hash(password)) {
      return 'Correo o contraseña incorrectos.';
    }
    await _storage.write(key: _keySessionActive, value: 'true');
    return null;
  }

  Future<void> signOut() async {
    await _storage.write(key: _keySessionActive, value: 'false');
  }
}

/// Guarda el único dispositivo registrado como JSON cifrado local.
class LocalDeviceStore {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _key = 'guardian_lock_device_data';
  final _uuid = const Uuid();

  Future<Device> getOrCreateDevice() async {
    final raw = await _storage.read(key: _key);
    if (raw != null) return Device.fromMap(jsonDecode(raw));
    final device = Device(deviceId: _uuid.v4());
    await save(device);
    return device;
  }

  Future<void> save(Device device) => _storage.write(key: _key, value: jsonEncode(device.toMap()));
}

class LocationHistoryStore {
  final _uuid = const Uuid();

  Future<void> add(LocationPoint point) async {
    final db = await LocalDatabase.instance.database;
    await db.insert('location_history', {'id': _uuid.v4(), ...point.toMap()});
  }

  Future<List<LocationPoint>> getAll() async {
    final db = await LocalDatabase.instance.database;
    final rows = await db.query('location_history', orderBy: 'timestamp DESC', limit: 100);
    return rows.map((r) => LocationPoint.fromMap(r)).toList();
  }
}

class ContactStore {
  final _uuid = const Uuid();

  Future<void> add(EmergencyContact contact) async {
    final db = await LocalDatabase.instance.database;
    final withId = EmergencyContact(id: _uuid.v4(), name: contact.name, phoneNumber: contact.phoneNumber);
    await db.insert('contacts', withId.toMap());
  }

  Future<void> remove(String id) async {
    final db = await LocalDatabase.instance.database;
    await db.delete('contacts', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<EmergencyContact>> getAll() async {
    final db = await LocalDatabase.instance.database;
    final rows = await db.query('contacts');
    return rows.map((r) => EmergencyContact.fromMap(r)).toList();
  }
}

class SecurityEventStore {
  final _uuid = const Uuid();

  Future<void> log(SecurityEventType type, String description) async {
    final db = await LocalDatabase.instance.database;
    final event = SecurityEvent(id: _uuid.v4(), type: type, description: description);
    await db.insert('security_events', event.toMap());
  }

  Future<List<SecurityEvent>> getAll() async {
    final db = await LocalDatabase.instance.database;
    final rows = await db.query('security_events', orderBy: 'timestamp DESC');
    return rows.map((r) => SecurityEvent.fromMap(r)).toList();
  }
}

/// Puente opcional hacia código nativo Android para protección contra
/// desinstalación (DeviceAdminReceiver). No requiere ninguna API key — es
/// 100% local también. Si el código Kotlin del canal aún no existe en tu
/// proyecto, cada llamada falla en silencio y el resto de la app sigue
/// funcionando con normalidad.
class DeviceAdminService {
  static const _channel = MethodChannel('com.example.domotica/device_admin');

  Future<bool> isAdminActive() async {
    try {
      return (await _channel.invokeMethod<bool>('isAdminActive')) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> requestAdminActivation() async {
    try {
      await _channel.invokeMethod('requestAdminActivation');
    } catch (_) {}
  }
}

class PermissionUtils {
  static Future<void> requestCorePermissions() async {
    await Permission.locationWhenInUse.request();
    await Permission.notification.request();
  }
}

// =============================================================================
// SECCIÓN 4: PROVIDERS (estado de la app)
// =============================================================================

class AuthProvider extends ChangeNotifier {
  AuthProvider({LocalAuthService? authService}) : _authService = authService ?? LocalAuthService();
  final LocalAuthService _authService;

  bool isLoading = false;
  String? errorMessage;
  bool isAuthenticated = false;

  Future<void> checkSession() async {
    isAuthenticated = await _authService.hasActiveSession();
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    if (!_validate(email, password)) return;
    _setLoading();
    final error = await _authService.signIn(email, password);
    _finish(error);
  }

  Future<void> register(String email, String password, String confirm) async {
    if (password != confirm) return _setError('Las contraseñas no coinciden.');
    if (!_validate(email, password)) return;
    _setLoading();
    final error = await _authService.register(email, password);
    _finish(error);
  }

  Future<void> signOut() async {
    await _authService.signOut();
    isAuthenticated = false;
    notifyListeners();
  }

  void _finish(String? error) {
    isLoading = false;
    if (error == null) {
      isAuthenticated = true;
      errorMessage = null;
    } else {
      errorMessage = error;
    }
    notifyListeners();
  }

  bool _validate(String email, String password) {
    if (email.isEmpty || !email.contains('@')) {
      _setError('Ingresa un correo válido.');
      return false;
    }
    if (password.length < 8) {
      _setError('La contraseña debe tener al menos 8 caracteres.');
      return false;
    }
    return true;
  }

  void _setLoading() {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    errorMessage = message;
    notifyListeners();
  }
}

class DashboardProvider extends ChangeNotifier {
  DashboardProvider({LocalDeviceStore? store, SecurityEventStore? events})
      : _store = store ?? LocalDeviceStore(),
        _events = events ?? SecurityEventStore() {
    _load();
  }
  final LocalDeviceStore _store;
  final SecurityEventStore _events;

  Device? device;
  bool isLoading = true;

  Future<void> _load() async {
    device = await _store.getOrCreateDevice();
    isLoading = false;
    notifyListeners();
  }

  Future<void> toggleLostMode(bool isLost) async {
    if (device == null) return;
    device = device!.copyWith(isLost: isLost);
    await _store.save(device!);
    await _events.log(
      isLost ? SecurityEventType.markedAsLost : SecurityEventType.markedAsFound,
      isLost ? 'Dispositivo marcado como perdido.' : 'Dispositivo marcado como encontrado.',
    );
    notifyListeners();
  }

  Future<void> toggleHiddenMode(bool enabled) async {
    if (device == null) return;
    device = device!.copyWith(hiddenModeEnabled: enabled);
    await _store.save(device!);
    await _events.log(SecurityEventType.hiddenModeToggled, 'Modo oculto ${enabled ? "activado" : "desactivado"}.');
    notifyListeners();
  }

  Future<void> updateLastLocation(LocationPoint point) async {
    if (device == null) return;
    device = device!.copyWith(lastKnownLocation: point);
    await _store.save(device!);
    notifyListeners();
  }
}

class MapProvider extends ChangeNotifier {
  MapProvider({LocationHistoryStore? store, SecurityEventStore? events})
      : _store = store ?? LocationHistoryStore(),
        _events = events ?? SecurityEventStore() {
    loadHistory();
  }
  final LocationHistoryStore _store;
  final SecurityEventStore _events;

  List<LocationPoint> history = [];
  bool isLoading = true;
  bool isLocating = false;
  String? errorMessage;

  Future<void> loadHistory() async {
    isLoading = true;
    notifyListeners();
    history = await _store.getAll();
    isLoading = false;
    notifyListeners();
  }

  /// Obtiene la ubicación actual real del dispositivo (geolocator no
  /// requiere ninguna API key en Android) y la agrega al historial local.
  Future<LocationPoint?> locateNow() async {
    isLocating = true;
    errorMessage = null;
    notifyListeners();
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied || requested == LocationPermission.deniedForever) {
          errorMessage = 'Permiso de ubicación denegado.';
          isLocating = false;
          notifyListeners();
          return null;
        }
      }
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final point = LocationPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      await _store.add(point);
      await _events.log(SecurityEventType.locationUpdated, 'Ubicación actualizada manualmente.');
      await loadHistory();
      return point;
    } catch (e) {
      errorMessage = 'No se pudo obtener la ubicación. Verifica que el GPS esté activo.';
      notifyListeners();
      return null;
    } finally {
      isLocating = false;
      notifyListeners();
    }
  }
}

class ContactsProvider extends ChangeNotifier {
  ContactsProvider({ContactStore? store}) : _store = store ?? ContactStore() {
    loadContacts();
  }
  final ContactStore _store;

  List<EmergencyContact> contacts = [];
  bool isLoading = true;

  Future<void> loadContacts() async {
    contacts = await _store.getAll();
    isLoading = false;
    notifyListeners();
  }

  Future<void> addContact(String name, String phone) async {
    if (name.trim().isEmpty || phone.trim().isEmpty) return;
    await _store.add(EmergencyContact(name: name, phoneNumber: phone));
    await loadContacts();
  }

  Future<void> removeContact(String id) async {
    await _store.remove(id);
    await loadContacts();
  }
}

class HistoryProvider extends ChangeNotifier {
  HistoryProvider({SecurityEventStore? store}) : _store = store ?? SecurityEventStore() {
    _load();
  }
  final SecurityEventStore _store;

  List<SecurityEvent> events = [];
  bool isLoading = true;

  Future<void> _load() async {
    events = await _store.getAll();
    isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() => _load();
}

// =============================================================================
// SECCIÓN 5: PANTALLAS
// =============================================================================

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onLoginTap, required this.onRegisterTap});
  final VoidCallback onLoginTap;
  final VoidCallback onRegisterTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(Icons.shield, size: 48, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 24),
              Text('Guardian Lock', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Protege tu dispositivo contra pérdida y robo — versión local, sin conexión a servidores.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(onPressed: onLoginTap, child: const Text('Iniciar sesión')),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(onPressed: onRegisterTap, child: const Text('Crear cuenta')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onSuccess, required this.onNavigateToRegister});
  final VoidCallback onSuccess;
  final VoidCallback onNavigateToRegister;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onSuccess());
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Correo electrónico', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
            ),
            if (auth.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(auth.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: auth.isLoading
                  ? null
                  : () => context.read<AuthProvider>().signIn(_email.text.trim(), _password.text),
              child: auth.isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Entrar'),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: widget.onNavigateToRegister, child: const Text('¿No tienes cuenta? Regístrate')),
          ],
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.onSuccess, required this.onNavigateToLogin});
  final VoidCallback onSuccess;
  final VoidCallback onNavigateToLogin;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onSuccess());
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Correo electrónico', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: _confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Confirmar contraseña', border: OutlineInputBorder())),
            if (auth.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(auth.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: auth.isLoading
                  ? null
                  : () => context.read<AuthProvider>().register(_email.text.trim(), _password.text, _confirm.text),
              child: auth.isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Registrarme'),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: widget.onNavigateToLogin, child: const Text('¿Ya tienes cuenta? Inicia sesión')),
          ],
        ),
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.onOpenMap,
    required this.onOpenContacts,
    required this.onOpenHistory,
    required this.onOpenSettings,
  });
  final VoidCallback onOpenMap;
  final VoidCallback onOpenContacts;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guardian Lock'),
        actions: [IconButton(icon: const Icon(Icons.settings), onPressed: onOpenSettings)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(state.device?.deviceName ?? 'Dispositivo',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            const SizedBox(height: 12),
                            Text(state.device?.lastKnownLocation != null
                                ? 'Última ubicación: ${state.device!.lastKnownLocation!.latitude.toStringAsFixed(4)}, '
                                    '${state.device!.lastKnownLocation!.longitude.toStringAsFixed(4)}'
                                : 'Última ubicación: aún no localizado'),
                            const SizedBox(height: 4),
                            const Text('Modo: 100% local (sin servidor)', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: FilledButton.tonalIcon(onPressed: onOpenMap, icon: const Icon(Icons.map), label: const Text('Ubicación'))),
                      const SizedBox(width: 12),
                      Expanded(child: FilledButton.tonalIcon(onPressed: onOpenHistory, icon: const Icon(Icons.history), label: const Text('Historial'))),
                    ]),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(onPressed: onOpenContacts, icon: const Icon(Icons.contact_phone), label: const Text('Contactos de emergencia')),
                    const SizedBox(height: 24),
                    Card(
                      color: state.device?.isLost == true
                          ? Theme.of(context).colorScheme.errorContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(children: [
                          Expanded(
                            child: Text(state.device?.isLost == true ? 'Modo perdido activado' : 'Marcar como perdido',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          Switch(
                            value: state.device?.isLost ?? false,
                            onChanged: (v) => context.read<DashboardProvider>().toggleLostMode(v),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Pantalla de ubicación sin mapa visual (Google Maps requiere API key).
/// Muestra la última ubicación y el historial como lista de coordenadas, y
/// permite pedir la ubicación actual real del dispositivo.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MapProvider>();
    final fmt = DateFormat('dd MMM yyyy, HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Ubicación del dispositivo')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: state.isLocating
            ? null
            : () async {
                final point = await context.read<MapProvider>().locateNow();
                if (point != null && context.mounted) {
                  await context.read<DashboardProvider>().updateLastLocation(point);
                }
              },
        icon: state.isLocating
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.my_location),
        label: const Text('Localizar ahora'),
      ),
      body: Column(
        children: [
          if (state.errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(state.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.history.isEmpty
                    ? const Center(child: Text('Aún no hay ubicaciones registradas.\nToca "Localizar ahora".', textAlign: TextAlign.center))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: state.history.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final point = state.history[index];
                          return ListTile(
                            leading: const Icon(Icons.location_on),
                            title: Text('${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}'),
                            subtitle: Text(fmt.format(DateTime.fromMillisecondsSinceEpoch(point.timestamp))),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.onSignOut});
  final VoidCallback onSignOut;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _deviceAdmin = DeviceAdminService();
  bool _isAdminActive = false;

  @override
  void initState() {
    super.initState();
    _deviceAdmin.isAdminActive().then((v) => setState(() => _isAdminActive = v));
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = context.watch<DashboardProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              title: const Text('Modo oculto'),
              subtitle: const Text('Reduce la visibilidad de notificaciones no críticas.'),
              value: dashboardState.device?.hiddenModeEnabled ?? false,
              onChanged: (v) => context.read<DashboardProvider>().toggleHiddenMode(v),
            ),
            const Divider(),
            ListTile(
              title: const Text('Protección contra desinstalación'),
              subtitle: Text(_isAdminActive ? 'Activada' : 'Desactivada (requiere código nativo Android)'),
              trailing: OutlinedButton(
                onPressed: () async {
                  await _deviceAdmin.requestAdminActivation();
                  final v = await _deviceAdmin.isAdminActive();
                  setState(() => _isAdminActive = v);
                },
                child: Text(_isAdminActive ? 'Gestionar' : 'Activar'),
              ),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: () {
                context.read<AuthProvider>().signOut();
                widget.onSignOut();
              },
              child: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ContactsProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Contactos de emergencia')),
      floatingActionButton: FloatingActionButton(onPressed: () => _showAddDialog(context), child: const Icon(Icons.add)),
      body: state.contacts.isEmpty
          ? const Center(child: Text('No has agregado contactos todavía.'))
          : ListView(
              children: state.contacts
                  .map((c) => ListTile(
                        title: Text(c.name),
                        subtitle: Text(c.phoneNumber),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => context.read<ContactsProvider>().removeContact(c.id),
                        ),
                      ))
                  .toList(),
            ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final name = TextEditingController();
    final phone = TextEditingController();
    final provider = context.read<ContactsProvider>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nuevo contacto'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre')),
          TextField(controller: phone, decoration: const InputDecoration(labelText: 'Teléfono')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              provider.addContact(name.text, phone.text);
              Navigator.pop(dialogContext);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HistoryProvider>();
    final fmt = DateFormat('dd MMM yyyy, HH:mm');
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de eventos')),
      body: state.events.isEmpty
          ? const Center(child: Text('Sin eventos registrados todavía.'))
          : ListView(
              children: state.events
                  .map((e) => ListTile(
                        title: Text(e.description),
                        subtitle: Text(fmt.format(DateTime.fromMillisecondsSinceEpoch(e.timestamp))),
                      ))
                  .toList(),
            ),
    );
  }
}

// =============================================================================
// SECCIÓN 6: APP RAÍZ Y NAVEGACIÓN
// =============================================================================

class Routes {
  static const welcome = '/';
  static const login = '/login';
  static const register = '/register';
  static const dashboard = '/dashboard';
  static const map = '/map';
  static const settings = '/settings';
  static const contacts = '/contacts';
  static const history = '/history';
}

class GuardianLockApp extends StatelessWidget {
  const GuardianLockApp({super.key, required this.startRoute});
  final String startRoute;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..checkSession()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => MapProvider()),
        ChangeNotifierProvider(create: (_) => ContactsProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
      ],
      child: MaterialApp(
        title: 'Guardian Lock',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF1B3A6B)),
        initialRoute: startRoute,
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case Routes.welcome:
              return MaterialPageRoute(
                builder: (c) => WelcomeScreen(
                  onLoginTap: () => Navigator.pushNamed(c, Routes.login),
                  onRegisterTap: () => Navigator.pushNamed(c, Routes.register),
                ),
              );
            case Routes.login:
              return MaterialPageRoute(
                builder: (c) => LoginScreen(
                  onSuccess: () => Navigator.pushNamedAndRemoveUntil(c, Routes.dashboard, (r) => false),
                  onNavigateToRegister: () => Navigator.pushNamed(c, Routes.register),
                ),
              );
            case Routes.register:
              return MaterialPageRoute(
                builder: (c) => RegisterScreen(
                  onSuccess: () => Navigator.pushNamedAndRemoveUntil(c, Routes.dashboard, (r) => false),
                  onNavigateToLogin: () => Navigator.pushNamed(c, Routes.login),
                ),
              );
            case Routes.dashboard:
              return MaterialPageRoute(
                builder: (c) => DashboardScreen(
                  onOpenMap: () => Navigator.pushNamed(c, Routes.map),
                  onOpenContacts: () => Navigator.pushNamed(c, Routes.contacts),
                  onOpenHistory: () => Navigator.pushNamed(c, Routes.history),
                  onOpenSettings: () => Navigator.pushNamed(c, Routes.settings),
                ),
              );
            case Routes.map:
              return MaterialPageRoute(builder: (_) => const MapScreen());
            case Routes.settings:
              return MaterialPageRoute(
                builder: (c) => SettingsScreen(
                  onSignOut: () => Navigator.pushNamedAndRemoveUntil(c, Routes.welcome, (r) => false),
                ),
              );
            case Routes.contacts:
              return MaterialPageRoute(builder: (_) => const ContactsScreen());
            case Routes.history:
              return MaterialPageRoute(builder: (_) => const HistoryScreen());
            default:
              return MaterialPageRoute(
                builder: (c) => WelcomeScreen(
                  onLoginTap: () => Navigator.pushNamed(c, Routes.login),
                  onRegisterTap: () => Navigator.pushNamed(c, Routes.register),
                ),
              );
          }
        },
      ),
    );
  }
}

// =============================================================================
// SECCIÓN 7: PUNTO DE ENTRADA
// =============================================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await PermissionUtils.requestCorePermissions();

  // Decide la pantalla inicial según si ya hay una sesión local activa,
  // sin depender de ningún servidor.
  final hasSession = await LocalAuthService().hasActiveSession();

  runApp(GuardianLockApp(startRoute: hasSession ? Routes.dashboard : Routes.welcome));
}
