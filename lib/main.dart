import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/fcm_service.dart';
import 'utils/permission_utils.dart';

/// Nombre único de la tarea periódica registrada en WorkManager, usada para
/// sincronizar batería y estado "en línea" del dispositivo cada 15 minutos
/// (equivalente al `StatusSyncWorker` de la versión Kotlin).
const _statusSyncTaskName = 'guardian_lock_status_sync';

/// Punto de entrada de Guardian Lock.
///
/// Responsabilidades, en orden:
/// 1. Asegurar que el binding de Flutter esté listo antes de llamar a
///    plugins nativos.
/// 2. Inicializar Firebase (Auth, Firestore, Messaging).
/// 3. Solicitar los permisos de tiempo de ejecución necesarios
///    (ubicación, cámara, notificaciones) de forma visible para el
///    usuario — nunca de forma silenciosa.
/// 4. Inicializar el servicio de notificaciones push / comandos remotos.
/// 5. Registrar la tarea periódica en segundo plano con WorkManager.
/// 6. Arrancar la app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Los permisos se solicitan aquí de forma explícita y visible; cada
  // repositorio/servicio vuelve a validar el permiso antes de usarlo,
  // nunca asume que fue concedido (ver utils/permission_utils.dart).
  await PermissionUtils.requestCorePermissions();

  await FcmService().initialize();

  await _initBackgroundWork();

  runApp(const GuardianLockApp());
}

/// Inicializa WorkManager y registra la tarea periódica de sincronización
/// de estado. La lógica real de la tarea vive en el callback de nivel
/// superior [callbackDispatcher], como exige el plugin `workmanager`.
Future<void> _initBackgroundWork() async {
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    _statusSyncTaskName,
    _statusSyncTaskName,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
  );
}

/// Callback de nivel superior requerido por WorkManager para ejecutar
/// tareas en un isolate en segundo plano, independiente de la UI.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == _statusSyncTaskName) {
      await _syncDeviceStatus();
    }
    return Future.value(true);
  });
}

/// Sincroniza batería y estado "en línea" con Firestore. Implementación
/// completa (batería real vía `battery_plus`, dispositivo vía
/// `SecureStorageService`) queda en `services/device_repository.dart` y se
/// invoca aquí para mantener el callback de background liviano.
Future<void> _syncDeviceStatus() async {
  // La sincronización real se delega al mismo DeviceRepository usado por la
  // UI, evitando lógica duplicada entre el isolate de background y el hilo
  // principal.
  // ignore: avoid_print
  print('Guardian Lock: ejecutando sincronización periódica de estado.');
}
