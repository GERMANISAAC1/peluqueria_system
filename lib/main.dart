// =============================================================================
// GUARDIAN LOCK — main.dart (versión autocontenida, un solo archivo)
// =============================================================================
//
// Este archivo reemplaza ÚNICAMENTE lib/main.dart. No requiere ni toca las
// carpetas existentes del proyecto (core/theme, data, db, domain/usecases,
// features, presentation, routes, screens, services) usadas por las otras
// apps de este repositorio.
//
// REQUISITO OBLIGATORIO: agrega el bloque de dependencias del final de este
// comentario a tu pubspec.yaml (sección `dependencies:`), y luego corre
// `flutter pub get`. Sin esto, el build seguirá fallando con "Couldn't
// resolve the package X" — eso ocurre siempre que un archivo Dart importa un
// paquete no declarado en pubspec.yaml, sin importar en cuántos archivos
// esté repartido el código.
//
//   firebase_core: ^3.6.0
//   firebase_auth: ^5.3.1
//   cloud_firestore: ^5.4.4
//   firebase_messaging: ^15.1.3
//   google_sign_in: ^6.2.1
//   provider: ^6.1.2
//   geolocator: ^13.0.1
//   google_maps_flutter: ^2.9.0
//   flutter_secure_storage: ^9.2.2
//   sqflite: ^2.3.3
//   path: ^1.9.0
//   flutter_local_notifications: ^18.0.1
//   permission_handler: ^11.3.1
//   uuid: ^4.5.1
//   intl: ^0.19.0
//
// También necesitarás, una sola vez:
//   flutterfire configure
// para generar tus credenciales reales de Firebase (ver docs/INSTALL.md del
// paquete original de Guardian Lock). Mientras tanto, este archivo incluye
// una configuración de Firebase de MARCADOR DE POSICIÓN al final: la app
// compilará, pero las llamadas a Firebase fallarán hasta que la reemplaces.
//
// Protección contra desinstalación / bloqueo remoto / alarma remota:
// requieren un pequeño puente nativo en Kotlin (MainActivity.kt +
// GuardianDeviceAdminReceiver.kt) que SÍ vive fuera de lib/, en
// android/app/src/main/kotlin/... — Dart no tiene forma de acceder a
// DeviceAdminReceiver sin ese puente. Este archivo ya incluye el lado Dart
// (DeviceAdminService) apuntando a ese canal; si no agregas el código
// Kotlin, esas funciones lanzarán un error controlado y quedan sin efecto,
// pero el resto de la app compila y funciona con normalidad.
// =============================================================================

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
  final double accuracy;
  final int timestamp;

  const LocationPoint({
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.accuracy = 0.0,
    int? timestamp,
  }) : timestamp = timestamp ?? 0;

  factory LocationPoint.fromMap(Map<String, dynamic> map) => LocationPoint(
        latitude: (map['latitude'] ?? 0.0).toDouble(),
        longitude: (map['longitude'] ?? 0.0).toDouble(),
        accuracy: (map['accuracy'] ?? 0.0).toDouble(),
        timestamp: map['timestamp'] ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'timestamp': timestamp,
      };
}

class Device {
  final String deviceId;
  final String ownerUid;
  final String deviceName;
  final bool isLost;
  final bool hiddenModeEnabled;
  final LocationPoint? lastKnownLocation;
  final int batteryLevel;
  final bool isOnline;

  const Device({
    this.deviceId = '',
    this.ownerUid = '',
    this.deviceName = '',
    this.isLost = false,
    this.hiddenModeEnabled = false,
    this.lastKnownLocation,
    this.batteryLevel = 100,
    this.isOnline = false,
  });

  factory Device.fromMap(Map<String, dynamic> map) => Device(
        deviceId: map['deviceId'] ?? '',
        ownerUid: map['ownerUid'] ?? '',
        deviceName: map['deviceName'] ?? '',
        isLost: map['isLost'] ?? false,
        hiddenModeEnabled: map['hiddenModeEnabled'] ?? false,
        lastKnownLocation: map['lastKnownLocation'] != null
            ? LocationPoint.fromMap(Map<String, dynamic>.from(map['lastKnownLocation']))
            : null,
        batteryLevel: map['batteryLevel'] ?? 100,
        isOnline: map['isOnline'] ?? false,
      );

  Map<String, dynamic> toMap() => {
        'deviceId': deviceId,
        'ownerUid': ownerUid,
        'deviceName': deviceName,
        'isLost': isLost,
        'hiddenModeEnabled': hiddenModeEnabled,
        'lastKnownLocation': lastKnownLocation?.toMap(),
        'batteryLevel': batteryLevel,
        'isOnline': isOnline,
      };
}

class EmergencyContact {
  final String id;
  final String name;
  final String phoneNumber;
  final String email;

  const EmergencyContact({
    this.id = '',
    this.name = '',
    this.phoneNumber = '',
    this.email = '',
  });

  factory EmergencyContact.fromMap(Map<String, dynamic> map) => EmergencyContact(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        phoneNumber: map['phoneNumber'] ?? '',
        email: map['email'] ?? '',
      );

  Map<String, dynamic> toMap() =>
      {'id': id, 'name': name, 'phoneNumber': phoneNumber, 'email': email};

  EmergencyContact copyWithId(String newId) =>
      EmergencyContact(id: newId, name: name, phoneNumber: phoneNumber, email: email);
}

enum SecurityEventType {
  markedAsLost,
  markedAsFound,
  remoteLockTriggered,
  alarmTriggered,
  locationUpdated,
  deviceRegistered,
}

enum RemoteCommand { lockDevice, triggerAlarm, locateNow, wipeDevice }

RemoteCommand? remoteCommandFromString(String raw) {
  for (final c in RemoteCommand.values) {
    if (_toSnake(c.name).toUpperCase() == raw.toUpperCase()) return c;
  }
  return null;
}

String _toSnake(String camel) =>
    camel.replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m.group(0)}').toUpperCase();

class SecurityEvent {
  final String id;
  final SecurityEventType type;
  final String description;
  final int timestamp;

  SecurityEvent({this.id = '', required this.type, required this.description, int? timestamp})
      : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  factory SecurityEvent.fromMap(Map<String, dynamic> map) => SecurityEvent(
        id: map['id'] ?? '',
        type: SecurityEventType.values.firstWhere((e) => e.name == map['type'],
            orElse: () => SecurityEventType.locationUpdated),
        description: map['description'] ?? '',
        timestamp: map['timestamp'] ?? 0,
      );

  Map<String, dynamic> toMap() =>
      {'id': id, 'type': type.name, 'description': description, 'timestamp': timestamp};

  SecurityEvent copyWithId(String newId) =>
      SecurityEvent(id: newId, type: type, description: description, timestamp: timestamp);
}

// =============================================================================
// SECCIÓN 2: SERVICIOS (equivalentes a los Repository de la versión Kotlin)
// =============================================================================

class SecureStorageService {
  SecureStorageService._internal();
  static final SecureStorageService instance = SecureStorageService._internal();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyDeviceId = 'guardian_lock_device_id';

  Future<void> saveDeviceId(String deviceId) => _storage.write(key: _keyDeviceId, value: deviceId);
  Future<String?> getDeviceId() => _storage.read(key: _keyDeviceId);
}

sealed class AuthResult {}

class AuthSuccess extends AuthResult {
  final User user;
  AuthSuccess(this.user);
}

class AuthError extends AuthResult {
  final String message;
  AuthError(this.message);
}

class AuthService {
  AuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
      : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  User? get currentUser => _auth.currentUser;

  Future<AuthResult> signInWithEmail(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return cred.user != null ? AuthSuccess(cred.user!) : AuthError('No se pudo iniciar sesión.');
    } on FirebaseAuthException catch (e) {
      return AuthError(_mapError(e));
    } catch (_) {
      return AuthError('Ocurrió un error inesperado.');
    }
  }

  Future<AuthResult> registerWithEmail(String email, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      return cred.user != null ? AuthSuccess(cred.user!) : AuthError('No se pudo crear la cuenta.');
    } on FirebaseAuthException catch (e) {
      return AuthError(_mapError(e));
    } catch (_) {
      return AuthError('Ocurrió un error inesperado.');
    }
  }

  Future<AuthResult> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return AuthError('Inicio de sesión con Google cancelado.');
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      return result.user != null
          ? AuthSuccess(result.user!)
          : AuthError('No se pudo iniciar sesión con Google.');
    } catch (_) {
      return AuthError('No se pudo completar el inicio de sesión con Google.');
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  String _mapError(FirebaseAuthException e) {
    switch (e.code) {
      case 'network-request-failed':
        return 'Sin conexión a internet.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con este correo.';
      case 'weak-password':
        return 'La contraseña es demasiado débil.';
      default:
        return e.message ?? 'Ocurrió un error inesperado.';
    }
  }
}

class DeviceRepository {
  DeviceRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _devices => _firestore.collection('devices');

  Future<void> registerDevice(Device device) => _devices.doc(device.deviceId).set(device.toMap());

  Stream<Device?> observeDevice(String deviceId) => _devices
      .doc(deviceId)
      .snapshots()
      .map((s) => s.exists ? Device.fromMap(s.data()!) : null);

  Future<void> updateLostStatus(String deviceId, bool isLost) =>
      _devices.doc(deviceId).update({'isLost': isLost});

  Future<void> updateLastLocation(String deviceId, LocationPoint point) =>
      _devices.doc(deviceId).update({'lastKnownLocation': point.toMap()});

  Future<void> updateBatteryAndOnline(String deviceId, int battery, bool online) =>
      _devices.doc(deviceId).update({'batteryLevel': battery, 'isOnline': online});
}

class LocationRepository {
  LocationRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

  Future<LocationPoint> getCurrentLocation() async {
    final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    return LocationPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> saveToHistory(String deviceId, LocationPoint point) => _firestore
      .collection('devices')
      .doc(deviceId)
      .collection('location_history')
      .add(point.toMap());

  Future<List<LocationPoint>> getHistory(String deviceId, {int limit = 100}) async {
    final snap = await _firestore
        .collection('devices')
        .doc(deviceId)
        .collection('location_history')
        .orderBy('timestamp')
        .limitToLast(limit)
        .get();
    return snap.docs.map((d) => LocationPoint.fromMap(d.data())).toList();
  }
}

class ContactRepository {
  ContactRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> _contacts(String deviceId) =>
      _firestore.collection('devices').doc(deviceId).collection('emergency_contacts');

  Future<void> addContact(String deviceId, EmergencyContact contact) async {
    final id = contact.id.isNotEmpty ? contact.id : _uuid.v4();
    await _contacts(deviceId).doc(id).set(contact.copyWithId(id).toMap());
  }

  Future<void> removeContact(String deviceId, String contactId) =>
      _contacts(deviceId).doc(contactId).delete();

  Future<List<EmergencyContact>> getContacts(String deviceId) async {
    final snap = await _contacts(deviceId).get();
    return snap.docs.map((d) => EmergencyContact.fromMap(d.data())).toList();
  }
}

class LocalEventDatabase {
  LocalEventDatabase._internal();
  static final LocalEventDatabase instance = LocalEventDatabase._internal();
  Database? _db;

  Future<Database> get database async => _db ??= await _init();

  Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'guardian_lock.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) => db.execute('''
        CREATE TABLE security_events (
          id TEXT PRIMARY KEY, type TEXT NOT NULL, description TEXT NOT NULL, timestamp INTEGER NOT NULL
        )
      '''),
    );
  }

  Future<void> insert(SecurityEvent event) async {
    final db = await database;
    await db.insert('security_events', event.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<SecurityEvent>> getAll() async {
    final db = await database;
    final rows = await db.query('security_events', orderBy: 'timestamp DESC');
    return rows.map((r) => SecurityEvent.fromMap(r)).toList();
  }
}

class SecurityEventRepository {
  SecurityEventRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;
  final _uuid = const Uuid();

  Future<List<SecurityEvent>> getLocalHistory() => LocalEventDatabase.instance.getAll();

  Future<void> logEvent(String deviceId, SecurityEvent event) async {
    final id = event.id.isNotEmpty ? event.id : _uuid.v4();
    final finalEvent = event.copyWithId(id);
    await LocalEventDatabase.instance.insert(finalEvent);
    try {
      await _firestore.collection('devices').doc(deviceId).collection('events').doc(id).set(finalEvent.toMap());
    } catch (_) {
      // Se queda persistido localmente; se puede reintentar más tarde.
    }
  }
}

/// Puente hacia el canal nativo Android para DeviceAdminReceiver /
/// DevicePolicyManager. Requiere código Kotlin adicional (ver comentario al
/// inicio del archivo). Si ese código no está presente, cada llamada lanza
/// un PlatformException que se captura y se ignora silenciosamente aquí,
/// para que el resto de la app no se vea afectado.
class DeviceAdminService {
  static const _channel = MethodChannel('com.guardianlock.app/device_admin');

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

  Future<void> lockDeviceNow() async {
    try {
      await _channel.invokeMethod('lockDeviceNow');
    } catch (_) {}
  }

  Future<void> triggerAlarm() async {
    try {
      await _channel.invokeMethod('triggerAlarm');
    } catch (_) {}
  }
}

class PermissionUtils {
  static Future<Map<Permission, PermissionStatus>> requestCorePermissions() async {
    return {
      Permission.locationWhenInUse: await Permission.locationWhenInUse.request(),
      Permission.camera: await Permission.camera.request(),
      Permission.notification: await Permission.notification.request(),
    };
  }
}

class FcmService {
  final _deviceAdmin = DeviceAdminService();
  final _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotifications.initialize(const InitializationSettings(android: androidInit));
    FirebaseMessaging.onMessage.listen(_handleMessage);
  }

  Future<void> _handleMessage(RemoteMessage message) async {
    final commandRaw = message.data['command'];
    if (commandRaw == null) return;
    final command = remoteCommandFromString(commandRaw);
    if (command == null) return;

    switch (command) {
      case RemoteCommand.lockDevice:
        await _deviceAdmin.lockDeviceNow();
        break;
      case RemoteCommand.triggerAlarm:
        await _deviceAdmin.triggerAlarm();
        await _showAlert('Alarma activada de forma remota', 'El propietario activó la alarma.');
        break;
      case RemoteCommand.locateNow:
      case RemoteCommand.wipeDevice:
        break;
    }
  }

  Future<void> _showAlert(String title, String body) async {
    const details = AndroidNotificationDetails(
      'security_alerts_channel',
      'Alertas de seguridad',
      importance: Importance.high,
      priority: Priority.high,
    );
    await _localNotifications.show(2001, title, body, const NotificationDetails(android: details));
  }
}

// =============================================================================
// SECCIÓN 3: PROVIDERS (estado, equivalentes a los ViewModel de Kotlin)
// =============================================================================

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService}) : _authService = authService ?? AuthService() {
    isAuthenticated = _authService.currentUser != null;
  }
  final AuthService _authService;

  bool isLoading = false;
  String? errorMessage;
  bool isAuthenticated = false;

  Future<void> signIn(String email, String password) async {
    if (!_validate(email, password)) return;
    _setLoading();
    _handleResult(await _authService.signInWithEmail(email, password));
  }

  Future<void> register(String email, String password, String confirm) async {
    if (password != confirm) return _setError('Las contraseñas no coinciden.');
    if (!_validate(email, password)) return;
    _setLoading();
    _handleResult(await _authService.registerWithEmail(email, password));
  }

  Future<void> signInWithGoogle() async {
    _setLoading();
    _handleResult(await _authService.signInWithGoogle());
  }

  Future<void> signOut() async {
    await _authService.signOut();
    isAuthenticated = false;
    notifyListeners();
  }

  void _handleResult(AuthResult result) {
    isLoading = false;
    if (result is AuthSuccess) {
      isAuthenticated = true;
      errorMessage = null;
    } else if (result is AuthError) {
      errorMessage = result.message;
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
  DashboardProvider({DeviceRepository? deviceRepository}) : _deviceRepository = deviceRepository ?? DeviceRepository() {
    _init();
  }
  final DeviceRepository _deviceRepository;
  StreamSubscription<Device?>? _sub;

  Device? device;
  bool isLoading = true;
  String? errorMessage;

  Future<void> _init() async {
    final deviceId = await SecureStorageService.instance.getDeviceId();
    if (deviceId == null) {
      isLoading = false;
      errorMessage = 'No hay dispositivo registrado.';
      notifyListeners();
      return;
    }
    _sub = _deviceRepository.observeDevice(deviceId).listen((d) {
      device = d;
      isLoading = false;
      notifyListeners();
    });
  }

  Future<void> toggleLostMode(bool isLost) async {
    final deviceId = await SecureStorageService.instance.getDeviceId();
    if (deviceId == null) return;
    await _deviceRepository.updateLostStatus(deviceId, isLost);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

class MapProvider extends ChangeNotifier {
  MapProvider({LocationRepository? locationRepository}) : _locationRepository = locationRepository ?? LocationRepository() {
    loadHistory();
  }
  final LocationRepository _locationRepository;

  List<LocationPoint> history = [];
  bool isLoading = true;

  Future<void> loadHistory() async {
    final deviceId = await SecureStorageService.instance.getDeviceId();
    if (deviceId == null) return;
    isLoading = true;
    notifyListeners();
    history = await _locationRepository.getHistory(deviceId);
    isLoading = false;
    notifyListeners();
  }
}

class ContactsProvider extends ChangeNotifier {
  ContactsProvider({ContactRepository? contactRepository}) : _contactRepository = contactRepository ?? ContactRepository() {
    loadContacts();
  }
  final ContactRepository _contactRepository;

  List<EmergencyContact> contacts = [];
  bool isLoading = true;

  Future<void> loadContacts() async {
    final deviceId = await SecureStorageService.instance.getDeviceId();
    if (deviceId == null) return;
    contacts = await _contactRepository.getContacts(deviceId);
    isLoading = false;
    notifyListeners();
  }

  Future<void> addContact(String name, String phone, String email) async {
    final deviceId = await SecureStorageService.instance.getDeviceId();
    if (deviceId == null || name.trim().isEmpty || phone.trim().isEmpty) return;
    await _contactRepository.addContact(deviceId, EmergencyContact(name: name, phoneNumber: phone, email: email));
    await loadContacts();
  }

  Future<void> removeContact(String contactId) async {
    final deviceId = await SecureStorageService.instance.getDeviceId();
    if (deviceId == null) return;
    await _contactRepository.removeContact(deviceId, contactId);
    await loadContacts();
  }
}

class HistoryProvider extends ChangeNotifier {
  HistoryProvider({SecurityEventRepository? eventRepository}) : _eventRepository = eventRepository ?? SecurityEventRepository() {
    _load();
  }
  final SecurityEventRepository _eventRepository;

  List<SecurityEvent> events = [];
  bool isLoading = true;

  Future<void> _load() async {
    events = await _eventRepository.getLocalHistory();
    isLoading = false;
    notifyListeners();
  }
}

// =============================================================================
// SECCIÓN 4: PANTALLAS
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
              Text('Guardian Lock',
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Protege tu dispositivo contra pérdida y robo. Localízalo, bloquéalo y '
                'recibe alertas en tiempo real.',
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
              onPressed: auth.isLoading ? null : () => context.read<AuthProvider>().signIn(_email.text.trim(), _password.text),
              child: auth.isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Entrar'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.read<AuthProvider>().signInWithGoogle(),
              icon: const Icon(Icons.g_mobiledata),
              label: const Text('Continuar con Google'),
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
            : state.errorMessage != null
                ? Center(child: Text(state.errorMessage!))
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
                                Text(state.device?.deviceName ?? 'Dispositivo sin nombre',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                const SizedBox(height: 12),
                                Text('Batería: ${state.device?.batteryLevel ?? 0}%'),
                                Text('Conexión: ${state.device?.isOnline == true ? "En línea" : "Sin conexión"}'),
                                Text(state.device?.lastKnownLocation != null
                                    ? 'Ubicación: ${state.device!.lastKnownLocation!.latitude.toStringAsFixed(4)}, ${state.device!.lastKnownLocation!.longitude.toStringAsFixed(4)}'
                                    : 'Ubicación: desconocida'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(child: FilledButton.tonalIcon(onPressed: onOpenMap, icon: const Icon(Icons.map), label: const Text('Mapa'))),
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

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MapProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Ubicación del dispositivo')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.history.isEmpty
              ? const Center(child: Text('Aún no hay ubicaciones registradas.'))
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(state.history.last.latitude, state.history.last.longitude),
                    zoom: 15,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('last'),
                      position: LatLng(state.history.last.latitude, state.history.last.longitude),
                    ),
                  },
                  polylines: {
                    Polyline(
                      polylineId: const PolylineId('history'),
                      points: state.history.map((p) => LatLng(p.latitude, p.longitude)).toList(),
                    ),
                  },
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
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: const Text('Protección contra desinstalación'),
              subtitle: Text(_isAdminActive ? 'Activada' : 'Desactivada'),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
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
    final email = TextEditingController();
    final provider = context.read<ContactsProvider>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nuevo contacto'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre')),
          TextField(controller: phone, decoration: const InputDecoration(labelText: 'Teléfono')),
          TextField(controller: email, decoration: const InputDecoration(labelText: 'Correo (opcional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              provider.addContact(name.text, phone.text, email.text);
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
// SECCIÓN 5: APP RAÍZ Y NAVEGACIÓN
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
  const GuardianLockApp({super.key});

  @override
  Widget build(BuildContext context) {
    final start = FirebaseAuth.instance.currentUser != null ? Routes.dashboard : Routes.welcome;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => MapProvider()),
        ChangeNotifierProvider(create: (_) => ContactsProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
      ],
      child: MaterialApp(
        title: 'Guardian Lock',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF1B3A6B)),
        initialRoute: start,
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
// SECCIÓN 6: CONFIGURACIÓN DE FIREBASE (MARCADOR DE POSICIÓN)
// =============================================================================
//
// Reemplaza estos valores con los reales ejecutando `flutterfire configure`,
// o copia aquí los valores de tu archivo firebase_options.dart si ya lo
// tienes generado en otro lado. Mientras tengan estos valores de ejemplo,
// la app COMPILA pero las llamadas a Firebase (login, Firestore, FCM)
// fallarán en tiempo de ejecución.

FirebaseOptions get _firebaseOptionsAndroid => const FirebaseOptions(
      apiKey: 'REEMPLAZAR_CON_flutterfire_configure',
      appId: 'REEMPLAZAR_CON_flutterfire_configure',
      messagingSenderId: 'REEMPLAZAR_CON_flutterfire_configure',
      projectId: 'REEMPLAZAR_CON_flutterfire_configure',
      storageBucket: 'REEMPLAZAR_CON_flutterfire_configure',
    );

// =============================================================================
// SECCIÓN 7: SINCRONIZACIÓN PERIÓDICA (pendiente)
// =============================================================================
//
// La sincronización periódica en segundo plano (batería/estado cada 15 min)
// se implementaba con el paquete `workmanager`, pero ese paquete no compila
// con versiones recientes de Flutter/Kotlin (APIs internas obsoletas del
// plugin). Se quitó temporalmente para desbloquear el build. Alternativas a
// futuro: WorkManager nativo vía MethodChannel propio, o el paquete
// `android_alarm_manager_plus`.
//
// =============================================================================
// SECCIÓN 8: PUNTO DE ENTRADA
// =============================================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: _firebaseOptionsAndroid);

  await PermissionUtils.requestCorePermissions();

  await FcmService().initialize();

  runApp(const GuardianLockApp());
}
