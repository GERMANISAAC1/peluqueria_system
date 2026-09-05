// =============================================================================
// main.dart — "Enfoque" App de Productividad / Bloqueador de Apps
// =============================================================================
// Flutter + Material 3 · TODO el código Dart vive en este único archivo.
//
// ⚠️ LEE ESTO PRIMERO:
// El bloqueo REAL de otras apps (detectar que el usuario abrió Instagram y
// sacarlo de ahí de forma confiable, incluso con pantalla apagada) requiere
// piezas NATIVAS de Android que NO pueden escribirse en Dart:
//   1) Un AccessibilityService en Kotlin (detecta cambios de ventana y actúa
//      al instante, sin las restricciones de "background activity launch"
//      que Android 10+ impone a los servicios normales).
//   2) Un BroadcastReceiver para BOOT_COMPLETED (reiniciar el bloqueo tras
//      reiniciar el teléfono).
//   3) Declaraciones en AndroidManifest.xml (permisos, servicio, receiver).
//   4) Ajustes en build.gradle (compileSdk/targetSdk, minSdk 29).
//
// Estas piezas se entregan en archivos aparte (ver README.md del proyecto).
// En este archivo, cada sección que depende de esas piezas está marcada con
// el comentario "// NATIVE:" explicando qué hace falta y por qué.
//
// Sin esas piezas nativas, esta app SIGUE FUNCIONANDO como:
//   - Selector de apps a bloquear + temporizador + UI completa.
//   - Detección de la app en primer plano vía UsageStatsManager (paquete
//     `usage_stats`, sondeo cada pocos segundos) mientras el Foreground
//     Service esté vivo.
//   - Registro de intentos, notificación persistente y pantalla de bloqueo
//     propia cuando el usuario vuelve a "Enfoque" o cuando el sondeo logra
//     redirigir a tiempo.
//   - Sin el AccessibilityService, la redirección puede no ser 100% instantánea
//     (limitación del propio sistema operativo, no del código).
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// -----------------------------------------------------------------------------
// Navigator global: nos permite mostrar la pantalla de bloqueo desde
// cualquier punto (incluido el listener del Foreground Service) sin pasar
// context manualmente por todos lados.
// -----------------------------------------------------------------------------
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Instancia global de notificaciones locales (para el aviso de felicitación
// al terminar el temporizador). La notificación PERSISTENTE de "Modo
// Productividad activado" la gestiona flutter_foreground_task directamente.
final FlutterLocalNotificationsPlugin localNotifications =
    FlutterLocalNotificationsPlugin();

// -----------------------------------------------------------------------------
// Canal nativo propio para listar apps instaladas (requisito #1).
// -----------------------------------------------------------------------------
// NOTA: originalmente esta app usaba el paquete de terceros `device_apps`,
// pero ese plugin quedó sin mantenimiento y su propio build.gradle no es
// compatible con versiones modernas de Android Gradle Plugin (namespace
// faltante, compileSdk desactualizado, recursos rotos). En vez de depender
// de un paquete externo frágil para algo tan simple como "listar apps con
// PackageManager", implementamos un MethodChannel propio hacia
// MainActivity.kt (ver método "getInstalledApps" en ese archivo). Esto
// elimina por completo el riesgo de romper el build por culpa de un
// mantenedor externo.
const MethodChannel _appsChannel = MethodChannel('focus_app/apps');

// Canal para consultar el permiso de "Acceso a datos de uso" y para recibir
// avisos de MainActivity cuando el AccessibilityService detecta un intento
// de abrir una app bloqueada (reemplaza al paquete `usage_stats`, que tenía
// el mismo problema de compileSdk desactualizado que `device_apps`).
const MethodChannel _nativeEventsChannel =
    MethodChannel('focus_app/native_events');

// =============================================================================
// PUNTO DE ENTRADA
// =============================================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Necesario para que flutter_foreground_task pueda comunicarse con el
  // isolate de la UI mediante un puerto de mensajes.
  FlutterForegroundTask.initCommunicationPort();

  await _initLocalNotifications();

  // Envolvemos todo en un try/catch amplio: requisito #19 (evitar cierres
  // inesperados). Cualquier error de inicialización no debe tumbar la app.
  runZonedGuarded(() {
    runApp(const FocusApp());
  }, (error, stack) {
    debugPrint('Error no controlado: $error');
  });
}

Future<void> _initLocalNotifications() async {
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);
  await localNotifications.initialize(initSettings);
}

// =============================================================================
// MODELOS
// =============================================================================

/// Representa una app instalada en el dispositivo.
class AppInfo {
  final String packageName;
  final String appName;
  final bool isSystemApp;
  final Uint8List? icon;

  AppInfo({
    required this.packageName,
    required this.appName,
    required this.isSystemApp,
    this.icon,
  });

  /// Construye una instancia a partir del mapa que devuelve el canal nativo
  /// `focus_app/apps` (ver MainActivity.kt, método getInstalledApps).
  factory AppInfo.fromChannelMap(Map<dynamic, dynamic> map) {
    final iconBytes = map['icon'];
    return AppInfo(
      packageName: map['packageName'] as String,
      appName: map['appName'] as String,
      isSystemApp: map['isSystemApp'] as bool? ?? false,
      icon: iconBytes is Uint8List
          ? iconBytes
          : (iconBytes is List ? Uint8List.fromList(iconBytes.cast<int>()) : null),
    );
  }
}

/// Pide al lado nativo (Kotlin) la lista de apps instaladas con intent de
/// lanzamiento. Lanza una excepción si el canal falla; quien llame debe
/// envolver esto en try/catch (requisito #19).
Future<List<AppInfo>> fetchInstalledApps() async {
  final result = await _appsChannel.invokeMethod<List<dynamic>>('getInstalledApps');
  if (result == null) return [];
  return result
      .cast<Map<dynamic, dynamic>>()
      .map((m) => AppInfo.fromChannelMap(m))
      .toList();
}

/// Pide al lado nativo el tiempo de uso reciente por app (vía
/// UsageStatsManager, requiere el permiso "Acceso a datos de uso"). Devuelve
/// un mapa packageName -> milisegundos en primer plano dentro de la
/// ventana de tiempo solicitada. Si el permiso no está concedido, Android
/// simplemente devuelve un mapa vacío o incompleto (no lanza error), así
/// que el llamador debe manejar ese caso con un aviso, no como falla.
Future<Map<String, int>> fetchUsageStats({int hoursBack = 24}) async {
  final result = await _nativeEventsChannel.invokeMethod<List<dynamic>>(
    'getUsageStats',
    {'hoursBack': hoursBack},
  );
  if (result == null) return {};
  final map = <String, int>{};
  for (final entry in result.cast<Map<dynamic, dynamic>>()) {
    final pkg = entry['packageName'] as String?;
    final millis = entry['totalTimeInForegroundMs'] as int?;
    if (pkg != null && millis != null) {
      map[pkg] = millis;
    }
  }
  return map;
}

/// Formatea milisegundos como "2h 15m" o "45m" para mostrar el tiempo de
/// uso reciente en la lista de apps.
String formatUsageDuration(int millis) {
  final duration = Duration(milliseconds: millis);
  final h = duration.inHours;
  final m = duration.inMinutes % 60;
  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return '${m}m';
  return '<1m';
}

/// Una sesión de bloqueo registrada en el historial (requisito #20).
class BlockSession {
  final DateTime start;
  final DateTime end;
  final int durationMinutes;
  final int attempts;
  final bool completed; // true si terminó por tiempo, false si se canceló

  BlockSession({
    required this.start,
    required this.end,
    required this.durationMinutes,
    required this.attempts,
    required this.completed,
  });

  Map<String, dynamic> toJson() => {
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'durationMinutes': durationMinutes,
        'attempts': attempts,
        'completed': completed,
      };

  factory BlockSession.fromJson(Map<String, dynamic> json) => BlockSession(
        start: DateTime.parse(json['start']),
        end: DateTime.parse(json['end']),
        durationMinutes: json['durationMinutes'],
        attempts: json['attempts'],
        completed: json['completed'] ?? true,
      );
}

// =============================================================================
// FRASES MOTIVACIONALES Y SUGERENCIAS (requisitos #8 y #9)
// =============================================================================

const List<String> kMotivationalPhrases = [
  'Sigue concentrado, vas muy bien.',
  'Tu futuro agradecerá este esfuerzo.',
  'Evita las distracciones, tú puedes.',
  'Cada minuto sin distraerte es una victoria.',
  'La disciplina de hoy es tu libertad de mañana.',
  'Respira, enfócate, avanza.',
  'Las distracciones pueden esperar, tus metas no.',
  'Estás construyendo un mejor hábito ahora mismo.',
];

const List<String> kProductiveSuggestions = [
  'Leer un libro 📖',
  'Estudiar 📚',
  'Aprender programación 💻',
  'Hacer ejercicio 🏃',
  'Meditar 🧘',
  'Organizar tareas ✅',
  'Practicar inglés 🗣️',
];

String randomPhrase() =>
    kMotivationalPhrases[Random().nextInt(kMotivationalPhrases.length)];

String randomSuggestion() =>
    kProductiveSuggestions[Random().nextInt(kProductiveSuggestions.length)];

// =============================================================================
// PERSISTENCIA — Claves de SharedPreferences (requisito #11)
// =============================================================================
class PrefsKeys {
  static const themeMode = 'theme_mode';
  static const blockedPackages = 'blocked_packages';
  static const isBlockingActive = 'is_blocking_active';
  static const blockEndTimeMs = 'block_end_time_ms';
  static const blockStartTimeMs = 'block_start_time_ms';
  static const selectedDurationMinutes = 'selected_duration_minutes';
  static const blockedAttempts = 'blocked_attempts';
  static const totalSecondsSaved = 'total_seconds_saved';
  static const streakDays = 'streak_days';
  static const lastActiveDate = 'last_active_date';
  static const history = 'history';
  static const strictModeEnabled = 'strict_mode_enabled';
  static const isStrictSession = 'is_strict_session';
}

// =============================================================================
// ESTADO GLOBAL DE LA APP (ChangeNotifier — sin paquetes externos de estado,
// requisito #20 "usar únicamente paquetes necesarios")
// =============================================================================
class AppState extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.system;

  Set<String> blockedPackages = {};
  bool isBlockingActive = false;
  DateTime? blockStartTime;
  DateTime? blockEndTime;
  int selectedDurationMinutes = 30;

  int blockedAttempts = 0;
  int totalSecondsSaved = 0;
  int streakDays = 0;
  DateTime? lastActiveDate;
  List<BlockSession> history = [];

  // Modo estricto (requisito de monetización: función premium). Cuando
  // está activo, "Detener bloqueo" exige un reto de confirmación en vez de
  // cancelar directo. "isStrictSession" se congela al iniciar la sesión,
  // para que cambiar el ajuste a mitad de un bloqueo no sea una forma de
  // hacer trampa.
  bool strictModeEnabled = false;
  bool isStrictSession = false;

  Timer? _countdownTicker;
  Duration remaining = Duration.zero;

  // ----------------------------- Carga / guardado -----------------------------

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final themeStr = prefs.getString(PrefsKeys.themeMode);
      themeMode = switch (themeStr) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

      blockedPackages = (prefs.getStringList(PrefsKeys.blockedPackages) ?? [])
          .toSet();
      isBlockingActive = prefs.getBool(PrefsKeys.isBlockingActive) ?? false;

      final endMs = prefs.getInt(PrefsKeys.blockEndTimeMs);
      blockEndTime =
          endMs != null ? DateTime.fromMillisecondsSinceEpoch(endMs) : null;

      final startMs = prefs.getInt(PrefsKeys.blockStartTimeMs);
      blockStartTime = startMs != null
          ? DateTime.fromMillisecondsSinceEpoch(startMs)
          : null;

      selectedDurationMinutes =
          prefs.getInt(PrefsKeys.selectedDurationMinutes) ?? 30;
      blockedAttempts = prefs.getInt(PrefsKeys.blockedAttempts) ?? 0;
      totalSecondsSaved = prefs.getInt(PrefsKeys.totalSecondsSaved) ?? 0;
      streakDays = prefs.getInt(PrefsKeys.streakDays) ?? 0;

      final lastActiveStr = prefs.getString(PrefsKeys.lastActiveDate);
      lastActiveDate =
          lastActiveStr != null ? DateTime.tryParse(lastActiveStr) : null;

      strictModeEnabled = prefs.getBool(PrefsKeys.strictModeEnabled) ?? false;
      isStrictSession = prefs.getBool(PrefsKeys.isStrictSession) ?? false;

      final historyStr = prefs.getString(PrefsKeys.history);
      if (historyStr != null) {
        final list = jsonDecode(historyStr) as List;
        history = list
            .map((e) => BlockSession.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      // Si el bloqueo estaba activo y ya venció (p. ej. la app estuvo
      // cerrada), lo cerramos correctamente al reabrir.
      if (isBlockingActive &&
          blockEndTime != null &&
          DateTime.now().isAfter(blockEndTime!)) {
        await _finishBlocking(completed: true);
      } else if (isBlockingActive) {
        _startCountdown();
      }
    } catch (e) {
      debugPrint('Error cargando preferencias: $e');
    }
    notifyListeners();
  }

  Future<void> _savePrimitive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        PrefsKeys.themeMode,
        switch (themeMode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'system',
        },
      );
      await prefs.setStringList(
          PrefsKeys.blockedPackages, blockedPackages.toList());
      await prefs.setBool(PrefsKeys.isBlockingActive, isBlockingActive);
      await prefs.setInt(
          PrefsKeys.selectedDurationMinutes, selectedDurationMinutes);
      await prefs.setInt(PrefsKeys.blockedAttempts, blockedAttempts);
      await prefs.setInt(PrefsKeys.totalSecondsSaved, totalSecondsSaved);
      await prefs.setInt(PrefsKeys.streakDays, streakDays);
      await prefs.setBool(PrefsKeys.strictModeEnabled, strictModeEnabled);
      await prefs.setBool(PrefsKeys.isStrictSession, isStrictSession);
      if (lastActiveDate != null) {
        await prefs.setString(
            PrefsKeys.lastActiveDate, lastActiveDate!.toIso8601String());
      }
      if (blockEndTime != null) {
        await prefs.setInt(
            PrefsKeys.blockEndTimeMs, blockEndTime!.millisecondsSinceEpoch);
      } else {
        await prefs.remove(PrefsKeys.blockEndTimeMs);
      }
      if (blockStartTime != null) {
        await prefs.setInt(PrefsKeys.blockStartTimeMs,
            blockStartTime!.millisecondsSinceEpoch);
      } else {
        await prefs.remove(PrefsKeys.blockStartTimeMs);
      }
      await prefs.setString(
        PrefsKeys.history,
        jsonEncode(history.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('Error guardando preferencias: $e');
    }
  }

  // ----------------------------- Tema -----------------------------

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    _savePrimitive();
    notifyListeners();
  }

  // ----------------------------- Modo estricto -----------------------------

  void setStrictModeEnabled(bool enabled) {
    strictModeEnabled = enabled;
    _savePrimitive();
    notifyListeners();
  }

  // ----------------------------- Selección de apps -----------------------------

  void toggleBlockedPackage(String packageName) {
    if (blockedPackages.contains(packageName)) {
      blockedPackages.remove(packageName);
    } else {
      blockedPackages.add(packageName);
    }
    _savePrimitive();
    notifyListeners();
  }

  void setSelectedDuration(int minutes) {
    selectedDurationMinutes = minutes;
    _savePrimitive();
    notifyListeners();
  }

  // ----------------------------- Bloqueo -----------------------------

  Future<void> startBlocking() async {
    if (blockedPackages.isEmpty) return;

    isBlockingActive = true;
    blockStartTime = DateTime.now();
    blockEndTime =
        blockStartTime!.add(Duration(minutes: selectedDurationMinutes));
    blockedAttempts = 0;
    // Congelamos el modo estricto de ESTA sesión al momento de arrancar.
    // Así, si el usuario cambia el ajuste general a mitad de un bloqueo
    // (por ejemplo, apagándolo para poder cancelar más fácil), la sesión
    // ya en curso sigue siendo estricta — el cambio solo aplica a la
    // PRÓXIMA sesión. Esto es lo que hace que el modo tenga sentido como
    // "anti-trampa" real.
    isStrictSession = strictModeEnabled;

    _updateStreak();
    await _savePrimitive();

    // NATIVE-ASSISTED: arrancamos el Foreground Service (paquete
    // flutter_foreground_task). Esto SÍ es 100% Dart/plugin, pero para que
    // sobreviva a pantalla apagada y arranque tras reiniciar el equipo,
    // AndroidManifest.xml debe declarar el servicio y el receiver de
    // BOOT_COMPLETED (ver README.md / archivos nativos adjuntos).
    await _startForegroundService();

    notifyListeners();
    _startCountdown();
  }

  Future<void> stopBlocking({bool completed = false}) async {
    await _finishBlocking(completed: completed);
  }

  Future<void> _finishBlocking({required bool completed}) async {
    _countdownTicker?.cancel();

    if (blockStartTime != null) {
      final now = DateTime.now();
      final actualMinutes = now.difference(blockStartTime!).inMinutes;
      history.insert(
        0,
        BlockSession(
          start: blockStartTime!,
          end: now,
          durationMinutes: actualMinutes,
          attempts: blockedAttempts,
          completed: completed,
        ),
      );
      if (history.length > 100) {
        history = history.sublist(0, 100);
      }
      // El "tiempo ahorrado" acumula el tiempo real que la app estuvo
      // bloqueando distracciones.
      totalSecondsSaved += now.difference(blockStartTime!).inSeconds;
    }

    isBlockingActive = false;
    blockStartTime = null;
    blockEndTime = null;
    remaining = Duration.zero;
    isStrictSession = false;

    await _savePrimitive();
    await FlutterForegroundTask.stopService();

    if (completed) {
      await _showCompletionNotification();
    }

    notifyListeners();
  }

  void _updateStreak() {
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    if (lastActiveDate == null) {
      streakDays = 1;
    } else {
      final lastDateOnly = DateTime(
          lastActiveDate!.year, lastActiveDate!.month, lastActiveDate!.day);
      final diff = todayDateOnly.difference(lastDateOnly).inDays;
      if (diff == 1) {
        streakDays += 1;
      } else if (diff > 1) {
        streakDays = 1;
      }
      // Si diff == 0 (mismo día) no cambiamos la racha.
    }
    lastActiveDate = today;
  }

  void _startCountdown() {
    _countdownTicker?.cancel();
    _tick();
    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      _tick();
    });
  }

  void _tick() {
    if (blockEndTime == null) return;
    final now = DateTime.now();
    if (now.isAfter(blockEndTime!)) {
      remaining = Duration.zero;
      _finishBlocking(completed: true);
      return;
    }
    remaining = blockEndTime!.difference(now);
    notifyListeners();
  }

  /// Se llama cuando el Foreground Service detecta que el usuario intentó
  /// abrir una app bloqueada (requisito #6/#4).
  void registerBlockedAttempt() {
    blockedAttempts += 1;
    _savePrimitive();
    notifyListeners();
  }

  // ----------------------------- Foreground Service -----------------------------

  Future<void> _startForegroundService() async {
    // Guardamos también la config en prefs "planas" para que el isolate del
    // servicio (que corre por separado) pueda leerlas sin depender de este
    // objeto en memoria.
    await FlutterForegroundTask.startService(
      notificationTitle: 'Modo Productividad activado',
      notificationText: 'Bloqueando distracciones. Toca para volver a Enfoque.',
      callback: startCallback,
    );
  }

  Future<void> _showCompletionNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'focus_completion_channel',
      'Sesiones completadas',
      channelDescription: 'Notificaciones al finalizar una sesión de enfoque',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await localNotifications.show(
      1001,
      '¡Sesión completada! 🎉',
      'Terminaste tu tiempo de enfoque. ¡Buen trabajo!',
      details,
    );
  }

  @override
  void dispose() {
    _countdownTicker?.cancel();
    super.dispose();
  }
}

/// Acceso simple al AppState desde cualquier widget, vía InheritedNotifier.
class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState appState,
    required super.child,
  }) : super(notifier: appState);

  static AppState of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope no encontrado en el árbol');
    return scope!.notifier!;
  }
}

// =============================================================================
// FOREGROUND SERVICE — TaskHandler (requisitos #5, #7)
// =============================================================================
// NATIVE: Este TaskHandler corre dentro de un servicio en primer plano real
// de Android (implementado por el plugin flutter_foreground_task), lo cual
// requiere declarar el <service> correspondiente en AndroidManifest.xml.
//
// IMPORTANTE: la detección de apps bloqueadas y la redirección instantánea
// (requisito #6) YA NO se hacen aquí sondeando UsageStatsManager desde
// Dart. Ese enfoque dependía del paquete `usage_stats`, que resultó
// incompatible con versiones modernas de Android Gradle Plugin (mismo
// problema de compileSdk que tuvimos con `device_apps`). En su lugar, esa
// responsabilidad quedó 100% en AppBlockAccessibilityService.kt (nativo),
// que además es más confiable porque reacciona al instante al cambio de
// ventana, sin depender de un sondeo cada pocos segundos.
//
// Este TaskHandler ahora solo mantiene viva la notificación persistente y
// avisa a la UI cuando el tiempo de bloqueo termina.
// -----------------------------------------------------------------------------

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(FocusTaskHandler());
}

class FocusTaskHandler extends TaskHandler {
  DateTime? _blockEndTime;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _refreshConfig();
  }

  @override
  void onRepeatEvent(DateTime timestamp) async {
    await _refreshConfig();

    if (_blockEndTime == null || DateTime.now().isAfter(_blockEndTime!)) {
      FlutterForegroundTask.sendDataToMain({'type': 'session_finished'});
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {}

  Future<void> _refreshConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final endMs = prefs.getInt(PrefsKeys.blockEndTimeMs);
    _blockEndTime =
        endMs != null ? DateTime.fromMillisecondsSinceEpoch(endMs) : null;
  }
}

// =============================================================================
// PERMISOS (requisitos #14, #15)
// =============================================================================
class PermissionStatusInfo {
  final String title;
  final String description;
  final bool granted;
  final VoidCallback onFix;

  PermissionStatusInfo({
    required this.title,
    required this.description,
    required this.granted,
    required this.onFix,
  });
}

class PermissionsHelper {
  /// Usage Access no tiene un flag estándar en permission_handler; se
  /// verifica vía AppOpsManager desde el lado nativo (MainActivity.kt,
  /// método "hasUsageAccess" del canal focus_app/native_events).
  static Future<bool> hasUsageAccess() async {
    try {
      final granted =
          await _nativeEventsChannel.invokeMethod<bool>('hasUsageAccess');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  static void openUsageAccessSettings() {
    // NATIVE: abre la pantalla de sistema "Acceso a datos de uso". Esto
    // funciona directamente vía Intent, sin necesidad de código Kotlin
    // adicional, gracias a android_intent_plus.
    const intent = AndroidIntent(
      action: 'android.settings.USAGE_ACCESS_SETTINGS',
    );
    intent.launch();
  }

  /// No existe API pública para verificar si NUESTRO AccessibilityService
  /// está habilitado sin código nativo. Aquí solo abrimos la pantalla de
  /// ajustes; la verificación real de "¿está mi servicio activo?" debe
  /// hacerse en Kotlin (AppBlockAccessibilityService) y exponerse a Dart
  /// mediante un MethodChannel. Ver README.md.
  static void openAccessibilitySettings() {
    const intent = AndroidIntent(
      action: 'android.settings.ACCESSIBILITY_SETTINGS',
    );
    intent.launch();
  }

  static Future<bool> hasIgnoreBatteryOptimization() async {
    final status = await Permission.ignoreBatteryOptimizations.status;
    return status.isGranted;
  }

  static Future<void> requestIgnoreBatteryOptimization() async {
    await Permission.ignoreBatteryOptimizations.request();
  }

  static Future<bool> hasNotificationPermission() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  static Future<void> requestNotificationPermission() async {
    await Permission.notification.request();
  }
}

// =============================================================================
// APP RAÍZ
// =============================================================================
class FocusApp extends StatefulWidget {
  const FocusApp({super.key});

  @override
  State<FocusApp> createState() => _FocusAppState();
}

class _FocusAppState extends State<FocusApp> with WidgetsBindingObserver {
  final AppState _appState = AppState();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Cuando AppBlockAccessibilityService detecta una app bloqueada, saca al
    // usuario a la pantalla de inicio y trae a Enfoque al frente. Ese
    // "volver a primer plano" dispara este callback: aprovechamos para
    // preguntarle al lado nativo si venimos de un bloqueo pendiente
    // (patrón "pull", sin necesidad de que Kotlin llame directamente a
    // Dart, lo cual simplifica bastante la integración).
    if (state == AppLifecycleState.resumed) {
      _checkPendingBlockedApp();
    }
  }

  Future<void> _checkPendingBlockedApp() async {
    try {
      final package = await _nativeEventsChannel
          .invokeMethod<String>('consumePendingBlockedPackage');
      if (package == null) return;
      // El contador de intentos ya lo incrementó el propio
      // AccessibilityService directamente en SharedPreferences; solo
      // necesitamos recargar el estado para reflejarlo en la UI.
      await _appState.load();
      _showBlockScreenIfNeeded(package);
    } catch (e) {
      debugPrint('Error consultando bloqueo pendiente: $e');
    }
  }

  Future<void> _bootstrap() async {
    await _appState.load();

    // Configuración del Foreground Service. NATIVE: los canales/permisos
    // que esto usa deben existir en AndroidManifest.xml.
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'focus_foreground_channel',
        channelName: 'Modo Productividad',
        channelDescription:
            'Notificación persistente mientras el bloqueo está activo.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(3000),
        autoRunOnBoot: true,
        allowWifiLock: false,
      ),
    );

    // Escuchamos los mensajes que llegan del TaskHandler en segundo plano
    // (solo "session_finished" ahora; la detección de apps bloqueadas la
    // hace AppBlockAccessibilityService.kt de forma nativa).
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);

    if (mounted) setState(() => _loaded = true);

    // Cubre el caso de arranque en frío: MainActivity pudo haber sido
    // lanzada directamente por AppBlockAccessibilityService.
    _checkPendingBlockedApp();
  }

  void _onTaskData(Object data) {
    if (data is! Map) return;
    final type = data['type'];
    if (type == 'session_finished') {
      _appState.stopBlocking(completed: true);
    }
  }

  void _showBlockScreenIfNeeded(String? package) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    // Evitamos apilar varias pantallas de bloqueo.
    if (ModalRoute.of(navigator.context)?.settings.name == '/block') return;
    navigator.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/block'),
        builder: (_) => BlockScreen(packageName: package),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return AppStateScope(
      appState: _appState,
      child: AnimatedBuilder(
        animation: _appState,
        builder: (context, _) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'Enfoque',
            debugShowCheckedModeBanner: false,
            themeMode: _appState.themeMode,
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: Colors.indigo,
              brightness: Brightness.light,
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: Colors.indigo,
              brightness: Brightness.dark,
            ),
            home: const HomeShell(),
          );
        },
      ),
    );
  }
}

// =============================================================================
// HOME SHELL — Navegación inferior con animación (requisito #16)
// =============================================================================
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _pages = const [
    DashboardScreen(),
    AppsScreen(),
    StatsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _pages[_index],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.shield_outlined),
              selectedIcon: Icon(Icons.shield),
              label: 'Inicio'),
          NavigationDestination(
              icon: Icon(Icons.apps_outlined),
              selectedIcon: Icon(Icons.apps),
              label: 'Apps'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Estadísticas'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Ajustes'),
        ],
      ),
    );
  }
}

// =============================================================================
// DASHBOARD — Pantalla principal (toggle de bloqueo, cuenta atrás, frases)
// =============================================================================
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _phrase = randomPhrase();
  String _suggestion = randomSuggestion();
  Timer? _phraseTimer;

  @override
  void initState() {
    super.initState();
    _phraseTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      setState(() {
        _phrase = randomPhrase();
        _suggestion = randomSuggestion();
      });
    });
  }

  @override
  void dispose() {
    _phraseTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Enfoque', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            appState.isBlockingActive
                ? 'Modo productividad activo'
                : 'Listo para concentrarte',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 24),

          // ------------------- Tarjeta principal de estado -------------------
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: appState.isBlockingActive
                          ? Column(
                              key: const ValueKey('active'),
                              children: [
                                Icon(Icons.lock_clock,
                                    size: 56,
                                    color: theme.colorScheme.primary),
                                const SizedBox(height: 12),
                                Text(
                                  _formatDuration(appState.remaining),
                                  style: theme.textTheme.displaySmall,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${appState.blockedPackages.length} apps bloqueadas',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                if (appState.isStrictSession) ...[
                                  const SizedBox(height: 8),
                                  Chip(
                                    avatar: Icon(Icons.shield,
                                        size: 16,
                                        color: theme.colorScheme.onErrorContainer),
                                    label: const Text('Modo estricto'),
                                    backgroundColor:
                                        theme.colorScheme.errorContainer,
                                    labelStyle: TextStyle(
                                        color:
                                            theme.colorScheme.onErrorContainer),
                                  ),
                                ],
                              ],
                            )
                          : Column(
                              key: const ValueKey('inactive'),
                              children: [
                                Icon(Icons.lock_open,
                                    size: 56,
                                    color: theme.colorScheme.outline),
                                const SizedBox(height: 12),
                                Text('${appState.selectedDurationMinutes} min',
                                    style: theme.textTheme.headlineMedium),
                                const SizedBox(height: 8),
                                Text(
                                  appState.blockedPackages.isEmpty
                                      ? 'Selecciona apps en la pestaña "Apps"'
                                      : '${appState.blockedPackages.length} apps seleccionadas',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 20),
                    if (!appState.isBlockingActive)
                      _DurationPicker(appState: appState),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: appState.isBlockingActive
                              ? theme.colorScheme.error
                              : null,
                        ),
                        onPressed: () async {
                          if (appState.isBlockingActive) {
                            if (appState.isStrictSession) {
                              // Modo estricto: no se cancela directo, hay
                              // que pasar el reto de confirmación primero.
                              final confirmed = await showDialog<bool>(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => const StrictModeChallengeDialog(),
                              );
                              if (confirmed == true) {
                                await appState.stopBlocking(completed: false);
                              }
                            } else {
                              await appState.stopBlocking(completed: false);
                            }
                          } else {
                            if (appState.blockedPackages.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Selecciona al menos una app para bloquear')),
                              );
                              return;
                            }
                            await appState.startBlocking();
                          }
                        },
                        icon: Icon(appState.isBlockingActive
                            ? Icons.stop_circle_outlined
                            : Icons.play_circle_outline),
                        label: Text(appState.isBlockingActive
                            ? 'Detener bloqueo'
                            : 'Activar modo productividad'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ------------------- Frase motivacional -------------------
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Row(
                  key: ValueKey(_phrase),
                  children: [
                    Icon(Icons.format_quote,
                        color: theme.colorScheme.onPrimaryContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _phrase,
                        style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ------------------- Sugerencia productiva -------------------
          Card(
            child: ListTile(
              leading: const Icon(Icons.lightbulb_outline),
              title: const Text('En vez de eso, prueba:'),
              subtitle: Text(_suggestion),
            ),
          ),

          const SizedBox(height: 12),
          const _PermissionsBanner(),
        ],
      ),
    );
  }
}

class _DurationPicker extends StatelessWidget {
  final AppState appState;
  const _DurationPicker({required this.appState});

  static const _options = [15, 30, 60, 120, 240];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final minutes in _options)
          ChoiceChip(
            label: Text(minutes < 60 ? '$minutes min' : '${minutes ~/ 60} h'),
            selected: appState.selectedDurationMinutes == minutes,
            onSelected: (_) => appState.setSelectedDuration(minutes),
          ),
        ChoiceChip(
          label: const Text('Personalizado'),
          selected: !_options.contains(appState.selectedDurationMinutes),
          onSelected: (_) async {
            final result = await _pickCustomDuration(context, appState);
            if (result != null) appState.setSelectedDuration(result);
          },
        ),
      ],
    );
  }

  Future<int?> _pickCustomDuration(BuildContext context, AppState appState) {
    int minutes = appState.selectedDurationMinutes;
    return showModalBottomSheet<int>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Duración personalizada',
                    style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 12),
                Text('$minutes minutos',
                    style: Theme.of(ctx).textTheme.headlineSmall),
                Slider(
                  min: 5,
                  max: 480,
                  divisions: 95,
                  value: minutes.toDouble(),
                  label: '$minutes min',
                  onChanged: (v) =>
                      setSheetState(() => minutes = v.round()),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, minutes),
                  child: const Text('Confirmar'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Aviso breve si falta algún permiso, con acceso rápido a Ajustes.
class _PermissionsBanner extends StatefulWidget {
  const _PermissionsBanner();

  @override
  State<_PermissionsBanner> createState() => _PermissionsBannerState();
}

class _PermissionsBannerState extends State<_PermissionsBanner> {
  bool? _usageOk;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final ok = await PermissionsHelper.hasUsageAccess();
    if (mounted) setState(() => _usageOk = ok);
  }

  @override
  Widget build(BuildContext context) {
    if (_usageOk == null || _usageOk == true) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: ListTile(
        leading: Icon(Icons.warning_amber,
            color: theme.colorScheme.onErrorContainer),
        title: const Text('Falta un permiso importante'),
        subtitle: const Text(
            'Concede "Acceso a datos de uso" para que el bloqueo funcione.'),
        trailing: FilledButton(
          onPressed: () {
            PermissionsHelper.openUsageAccessSettings();
          },
          child: const Text('Abrir'),
        ),
      ),
    );
  }
}

// =============================================================================
// PANTALLA DE APPS — lista, búsqueda y selección (requisitos #1, #2)
// =============================================================================
class AppsScreen extends StatefulWidget {
  const AppsScreen({super.key});

  @override
  State<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends State<AppsScreen> {
  List<AppInfo> _allApps = [];
  List<AppInfo> _filtered = [];
  bool _loading = true;
  bool _loadError = false;
  String _query = '';

  // Modo "ordenar por uso reciente" (requisito #10 / mejora sobre la lista
  // fija de "sugeridas"): en vez de adivinar nombres de apps distractoras,
  // mostramos las que más tiempo se usaron en las últimas 24h, para que el
  // usuario decida con datos reales de SU teléfono.
  bool _sortByUsage = false;
  bool _loadingUsage = false;
  Map<String, int> _usageMillis = {}; // packageName -> ms en primer plano

  // Paquetes conocidos de apps que suelen distraer, para preseleccionar
  // sugerencias rápidas (requisito: Facebook, TikTok, Instagram, YouTube,
  // X/Twitter, Discord, etc.). Se mantiene como atajo rápido, complementario
  // al ordenamiento por uso real.
  static const _knownDistractors = <String>{
    'com.facebook.katana',
    'com.facebook.lite',
    'com.zhiliaoapp.musically', // TikTok
    'com.ss.android.ugc.trill', // TikTok (variante)
    'com.instagram.android',
    'com.instagram.lite',
    'com.google.android.youtube',
    'com.google.android.apps.youtube.music',
    'com.twitter.android', // X / Twitter
    'com.discord',
    'com.snapchat.android',
    'com.reddit.frontpage',
    'com.whatsapp',
    'com.facebook.orca', // Messenger
    'com.pinterest',
    'com.spotify.music',
    'com.netflix.mediaclient',
  };

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    try {
      final apps = await fetchInstalledApps();
      apps.sort((a, b) =>
          a.appName.toLowerCase().compareTo(b.appName.toLowerCase()));
      setState(() {
        _allApps = apps;
        _filtered = apps;
        _loading = false;
        _loadError = false;
      });
    } catch (e) {
      debugPrint('Error listando apps: $e');
      setState(() {
        _loading = false;
        _loadError = true;
      });
    }
  }

  Future<void> _toggleSortByUsage() async {
    if (_sortByUsage) {
      // Apagar: volvemos al orden alfabético.
      setState(() {
        _sortByUsage = false;
        _applyFilterAndSort();
      });
      return;
    }

    final hasAccess = await PermissionsHelper.hasUsageAccess();
    if (!hasAccess) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Activa "Acceso a datos de uso" en Ajustes para ordenar por uso reciente'),
          action: SnackBarAction(
            label: 'Abrir',
            onPressed: PermissionsHelper.openUsageAccessSettings,
          ),
        ),
      );
      return;
    }

    setState(() => _loadingUsage = true);
    try {
      final usage = await fetchUsageStats(hoursBack: 24);
      setState(() {
        _usageMillis = usage;
        _sortByUsage = true;
        _loadingUsage = false;
        _applyFilterAndSort();
      });
    } catch (e) {
      debugPrint('Error obteniendo estadísticas de uso: $e');
      setState(() => _loadingUsage = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No se pudo leer el tiempo de uso reciente')),
      );
    }
  }

  void _onSearch(String query) {
    _query = query;
    setState(() => _applyFilterAndSort());
  }

  void _applyFilterAndSort() {
    var list = _allApps
        .where((a) =>
            a.appName.toLowerCase().contains(_query.toLowerCase()) ||
            a.packageName.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    if (_sortByUsage) {
      list.sort((a, b) {
        final usageA = _usageMillis[a.packageName] ?? 0;
        final usageB = _usageMillis[b.packageName] ?? 0;
        if (usageA != usageB) return usageB.compareTo(usageA); // desc
        return a.appName.toLowerCase().compareTo(b.appName.toLowerCase());
      });
    } else {
      list.sort((a, b) =>
          a.appName.toLowerCase().compareTo(b.appName.toLowerCase()));
    }
    _filtered = list;
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('Apps a bloquear',
                      style: Theme.of(context).textTheme.headlineSmall),
                ),
                TextButton.icon(
                  onPressed: () {
                    final appState = AppStateScope.of(context);
                    for (final pkg in _knownDistractors) {
                      final exists =
                          _allApps.any((a) => a.packageName == pkg);
                      if (exists && !appState.blockedPackages.contains(pkg)) {
                        appState.toggleBlockedPackage(pkg);
                      }
                    }
                  },
                  icon: const Icon(Icons.bolt),
                  label: const Text('Sugeridas'),
                ),
              ],
            ),
          ),
          // Toggle "ordenar por uso reciente" — más útil que la lista fija
          // de sugerencias, porque usa datos reales del teléfono del
          // usuario en vez de adivinar nombres de apps.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                FilterChip(
                  avatar: _loadingUsage
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.timelapse, size: 18),
                  label: const Text('Ordenar por uso (24h)'),
                  selected: _sortByUsage,
                  onSelected: (_) => _toggleSortByUsage(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar app...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: _onSearch,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _loadError
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, size: 48),
                              const SizedBox(height: 12),
                              const Text(
                                'No se pudo obtener la lista de apps instaladas.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: () {
                                  setState(() => _loading = true);
                                  _loadApps();
                                },
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _filtered.isEmpty
                        ? const Center(child: Text('No se encontraron apps'))
                        : ListView.builder(
                            itemCount: _filtered.length,
                            itemBuilder: (context, i) {
                              final app = _filtered[i];
                              final selected = appState.blockedPackages
                                  .contains(app.packageName);
                              final usageMs = _usageMillis[app.packageName];
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                color: selected
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                        .withOpacity(0.3)
                                    : Colors.transparent,
                                child: CheckboxListTile(
                                  value: selected,
                                  onChanged: (_) => appState
                                      .toggleBlockedPackage(app.packageName),
                                  secondary: app.icon != null
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.memory(app.icon!,
                                              width: 40, height: 40),
                                        )
                                      : const Icon(Icons.apps),
                                  title: Text(app.appName),
                                  subtitle: _sortByUsage
                                      ? Text(
                                          usageMs != null && usageMs > 0
                                              ? '${formatUsageDuration(usageMs)} en las últimas 24h'
                                              : 'Sin uso reciente',
                                          style: const TextStyle(fontSize: 12),
                                        )
                                      : Text(app.packageName,
                                          style: const TextStyle(fontSize: 11)),
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

// =============================================================================
// ESTADÍSTICAS (requisito #10)
// =============================================================================
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  String _formatHours(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Estadísticas', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.savings_outlined,
                  label: 'Tiempo ahorrado',
                  value: _formatHours(appState.totalSecondsSaved),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.block,
                  label: 'Intentos bloqueados',
                  value: '${appState.blockedAttempts}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StatCard(
            icon: Icons.local_fire_department,
            label: 'Días consecutivos de productividad',
            value: '${appState.streakDays}',
            wide: true,
          ),
          const SizedBox(height: 20),
          Text('Historial de sesiones', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (appState.history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Aún no hay sesiones registradas')),
            )
          else
            ...appState.history.take(30).map(
                  (s) => Card(
                    child: ListTile(
                      leading: Icon(
                        s.completed ? Icons.check_circle : Icons.cancel,
                        color: s.completed ? Colors.green : Colors.orange,
                      ),
                      title: Text('${s.durationMinutes} min · '
                          '${s.completed ? "Completada" : "Cancelada"}'),
                      subtitle: Text(
                          '${s.start.day}/${s.start.month}/${s.start.year} · '
                          '${s.attempts} intentos bloqueados'),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool wide;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(value, style: theme.textTheme.headlineSmall),
            Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// AJUSTES — tema, permisos (requisitos #13, #14, #15)
// =============================================================================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _usageAccess = false;
  bool _batteryIgnored = false;
  bool _notifications = false;

  @override
  void initState() {
    super.initState();
    _refreshPermissions();
  }

  Future<void> _refreshPermissions() async {
    final usage = await PermissionsHelper.hasUsageAccess();
    final battery = await PermissionsHelper.hasIgnoreBatteryOptimization();
    final notif = await PermissionsHelper.hasNotificationPermission();
    if (!mounted) return;
    setState(() {
      _usageAccess = usage;
      _batteryIgnored = battery;
      _notifications = notif;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Ajustes', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 16),

          // ---------------- Tema ----------------
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Apariencia', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode),
                          label: Text('Claro')),
                      ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto),
                          label: Text('Auto')),
                      ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode),
                          label: Text('Oscuro')),
                    ],
                    selected: {appState.themeMode},
                    onSelectionChanged: (s) =>
                        appState.setThemeMode(s.first),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          // ---------------- Modo estricto (premium) ----------------
          Card(
            child: SwitchListTile(
              secondary: Icon(Icons.shield_outlined,
                  color: theme.colorScheme.primary),
              title: Row(
                children: [
                  const Text('Modo estricto'),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'PRO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: const Text(
                  'No podrás cancelar el bloqueo antes de tiempo sin completar un reto de confirmación. Aplica desde la próxima sesión que inicies.'),
              value: appState.strictModeEnabled,
              onChanged: (v) => appState.setStrictModeEnabled(v),
            ),
          ),

          const SizedBox(height: 16),
          Text('Permisos necesarios', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),

          _PermissionTile(
            title: 'Acceso a datos de uso',
            subtitle:
                'Necesario para detectar qué app está en primer plano.',
            granted: _usageAccess,
            onTap: () {
              PermissionsHelper.openUsageAccessSettings();
              Future.delayed(
                  const Duration(seconds: 1), _refreshPermissions);
            },
          ),
          _PermissionTile(
            title: 'Servicio de accesibilidad',
            subtitle:
                'Permite bloquear apps al instante (requiere configuración nativa, ver README).',
            granted: null, // No verificable sin MethodChannel nativo.
            onTap: () {
              PermissionsHelper.openAccessibilitySettings();
            },
          ),
          _PermissionTile(
            title: 'Ignorar optimización de batería',
            subtitle: 'Evita que Android cierre el servicio en segundo plano.',
            granted: _batteryIgnored,
            onTap: () async {
              await PermissionsHelper.requestIgnoreBatteryOptimization();
              _refreshPermissions();
            },
          ),
          _PermissionTile(
            title: 'Notificaciones',
            subtitle: 'Para mostrar el estado del modo productividad.',
            granted: _notifications,
            onTap: () async {
              await PermissionsHelper.requestNotificationPermission();
              _refreshPermissions();
            },
          ),

          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Diagnóstico (temporal)'),
              subtitle: const Text(
                  'Muestra el valor crudo guardado para las apps bloqueadas'),
              trailing: FilledButton.tonal(
                onPressed: () async {
                  try {
                    final result = await _nativeEventsChannel
                        .invokeMethod<String>('getRawPrefsDump');
                    if (!context.mounted) return;
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Valor crudo guardado'),
                        content: SelectableText(result ?? 'null'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cerrar'),
                          ),
                        ],
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Error'),
                        content: SelectableText('$e'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cerrar'),
                          ),
                        ],
                      ),
                    );
                  }
                },
                child: const Text('Ver'),
              ),
            ),
          ),

          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Acerca de Enfoque'),
              subtitle: const Text(
                  'App de productividad para bloquear distracciones. v1.0.0'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool? granted; // null = desconocido/no verificable desde Dart puro
  final VoidCallback onTap;

  const _PermissionTile({
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = granted == true
        ? Icons.check_circle
        : granted == false
            ? Icons.error_outline
            : Icons.help_outline;
    final color = granted == true
        ? Colors.green
        : granted == false
            ? Colors.red
            : Colors.orange;

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: FilledButton.tonal(
          onPressed: onTap,
          child: const Text('Configurar'),
        ),
      ),
    );
  }
}

// =============================================================================
// PANTALLA DE BLOQUEO — se muestra cuando se detecta un intento de abrir
// una app bloqueada (requisito #4)
// =============================================================================
// =============================================================================
// RETO DE CONFIRMACIÓN — Modo estricto (función premium / anti-trampa)
// =============================================================================
// Se muestra en vez de cancelar directo cuando la sesión activa se inició
// con "Modo estricto" encendido. Combina dos tipos de fricción deliberada:
// 1) Una espera obligatoria (no se puede saltar).
// 2) Escribir una frase exacta, elegida al azar en cada intento (para que
//    no sea algo que el usuario memorice y escriba en automático sin
//    pensarlo).
// Devuelve `true` por Navigator.pop si el usuario completó el reto y de
// verdad quiere cancelar, o `null`/`false` si se arrepintió o cerró el
// diálogo — en ambos casos el bloqueo sigue activo.
class StrictModeChallengeDialog extends StatefulWidget {
  const StrictModeChallengeDialog({super.key});

  @override
  State<StrictModeChallengeDialog> createState() =>
      _StrictModeChallengeDialogState();
}

class _StrictModeChallengeDialogState
    extends State<StrictModeChallengeDialog> {
  static const _phrases = [
    'Quiero interrumpir mi enfoque',
    'Prefiero distraerme ahora mismo',
    'Estoy seguro de cancelar mi sesión',
    'Elijo romper mi racha de hoy',
  ];

  static const _waitSeconds = 8;

  late final String _targetPhrase;
  late int _secondsLeft;
  Timer? _timer;
  final _controller = TextEditingController();
  bool _textMatches = false;

  @override
  void initState() {
    super.initState();
    _targetPhrase = _phrases[Random().nextInt(_phrases.length)];
    _secondsLeft = _waitSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) t.cancel();
      });
    });
    _controller.addListener(() {
      final matches = _controller.text.trim() == _targetPhrase;
      if (matches != _textMatches) {
        setState(() => _textMatches = matches);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final waitDone = _secondsLeft <= 0;
    final canConfirm = waitDone && _textMatches;

    return AlertDialog(
      icon: Icon(Icons.shield, color: theme.colorScheme.error, size: 32),
      title: const Text('¿Seguro que quieres cancelar?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
              'El modo estricto está activo para esta sesión. Escribe exactamente la siguiente frase para confirmar:'),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _targetPhrase,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Escribe la frase aquí',
              border: const OutlineInputBorder(),
              errorText: _controller.text.isNotEmpty && !_textMatches
                  ? 'No coincide exactamente'
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          if (!waitDone)
            Text(
              'Espera $_secondsLeft s antes de poder confirmar...',
              style: TextStyle(color: theme.colorScheme.outline),
            )
          else
            Text(
              'Ya puedes confirmar si de verdad quieres cancelar.',
              style: TextStyle(color: theme.colorScheme.primary),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Mejor sigo enfocado'),
        ),
        FilledButton(
          onPressed:
              canConfirm ? () => Navigator.of(context).pop(true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
          ),
          child: const Text('Confirmar cancelación'),
        ),
      ],
    );
  }
}

class BlockScreen extends StatelessWidget {
  final String? packageName;
  const BlockScreen({super.key, this.packageName});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final theme = Theme.of(context);

    return PopScope(
      canPop: false, // El usuario no puede "volver" a la app bloqueada.
      child: Scaffold(
        backgroundColor: theme.colorScheme.errorContainer,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock,
                    size: 96, color: theme.colorScheme.onErrorContainer),
                const SizedBox(height: 24),
                Text(
                  'Esta app está bloqueada',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(color: theme.colorScheme.onErrorContainer),
                ),
                const SizedBox(height: 12),
                Text(
                  randomPhrase(),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: theme.colorScheme.onErrorContainer),
                ),
                const SizedBox(height: 8),
                if (appState.remaining > Duration.zero)
                  Text(
                    'Quedan ${appState.remaining.inMinutes} minutos',
                    style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer),
                  ),
                const SizedBox(height: 32),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.lightbulb_outline),
                    title: const Text('Prueba esto en su lugar:'),
                    subtitle: Text(randomSuggestion()),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    // NATIVE: idealmente esto lo dispara directamente el
                    // AccessibilityService (GLOBAL_ACTION_HOME) en el mismo
                    // instante en que detecta la app bloqueada. Aquí, como
                    // acción explícita del usuario dentro de nuestra propia
                    // app, es seguro lanzar el intent HOME.
                    const intent = AndroidIntent(
                      action: 'android.intent.action.MAIN',
                      category: 'android.intent.category.HOME',
                      flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
                    );
                    intent.launch();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.home),
                  label: const Text('Volver al inicio'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
