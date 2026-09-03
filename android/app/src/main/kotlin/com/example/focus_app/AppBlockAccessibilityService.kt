package com.example.focus_app
// ⚠️ Cambia "com.example.focus_app" por tu applicationId real, aquí y en el
// AndroidManifest.xml, y mueve este archivo a la carpeta correspondiente.

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.content.SharedPreferences
import android.view.accessibility.AccessibilityEvent
import org.json.JSONArray

/**
 * AppBlockAccessibilityService
 * =============================================================================
 * Esta es la pieza NATIVA que hace posible el bloqueo instantáneo y confiable
 * de apps (requisito #4 y #6), algo que NO se puede lograr solo con Dart /
 * Foreground Service, porque Android 10+ restringe que servicios en segundo
 * plano lancen actividades sin un "trigger" del sistema con privilegios
 * (background activity launch restrictions). Un AccessibilityService SÍ tiene
 * esos privilegios cuando reacciona a TYPE_WINDOW_STATE_CHANGED.
 *
 * Flujo:
 *  1. Android nos notifica cada vez que cambia la ventana en primer plano
 *     (onAccessibilityEvent).
 *  2. Leemos el paquete de esa ventana (event.packageName).
 *  3. Comparamos contra la lista de apps bloqueadas, que leemos de
 *     SharedPreferences (la MISMA que usa Flutter/shared_preferences, ya que
 *     este plugin en Android usa un archivo de preferencias compartido con
 *     prefijo "FlutterSharedPreferences").
 *  4. Si coincide y el bloqueo sigue vigente (comparamos con el timestamp
 *     guardado), disparamos GLOBAL_ACTION_HOME para sacar al usuario
 *     inmediatamente, y además abrimos nuestra MainActivity con un extra que
 *     le indica a Flutter que muestre la pantalla de bloqueo (BlockScreen).
 *
 * IMPORTANTE: El usuario debe habilitar este servicio manualmente en
 * Ajustes > Accesibilidad > Enfoque. Ningún método programático puede
 * activarlo automáticamente (restricción de seguridad de Android, aplica en
 * todas las versiones, incluida Android 16).
 */
class AppBlockAccessibilityService : AccessibilityService() {

    private lateinit var prefs: SharedPreferences
    private var lastBlockedPackage: String? = null

    companion object {
        // Debe coincidir EXACTAMENTE con las claves usadas en Dart
        // (ver PrefsKeys en main.dart). flutter_shared_preferences antepone
        // "flutter." a cada clave al guardarlas en el SharedPreferences nativo.
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_BLOCKED_PACKAGES = "flutter.blocked_packages"
        private const val KEY_IS_ACTIVE = "flutter.is_blocking_active"
        private const val KEY_END_TIME = "flutter.block_end_time_ms"

        // El plugin oficial `shared_preferences` de Flutter NO guarda
        // List<String> como un StringSet nativo de Android. Lo codifica
        // como un String normal: este prefijo mágico (constante fija en el
        // propio código fuente del plugin) + un JSON array. Sin decodificar
        // esto correctamente, prefs.getStringSet() lanza ClassCastException
        // (silenciada por nuestro try/catch) y SIEMPRE devuelve una lista
        // vacía — este era el bug real por el que ninguna app se bloqueaba
        // pese a tener todos los permisos bien configurados.
        private const val LIST_PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBMaXN0Lg=="
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        prefs = applicationContext.getSharedPreferences(PREFS_NAME, MODE_PRIVATE)

        // Configuración fina del servicio: solo nos interesan los cambios
        // de ventana, para minimizar el consumo de batería/CPU (requisito #18).
        val info = AccessibilityServiceInfo()
        info.eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        info.flags = AccessibilityServiceInfo.DEFAULT
        serviceInfo = info
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val packageName = event.packageName?.toString() ?: return
        if (packageName == applicationContext.packageName) return // ignorar nuestra propia app

        try {
            val isActive = prefs.getBoolean(KEY_IS_ACTIVE, false)
            if (!isActive) return

            val endTime = prefs.getLong(KEY_END_TIME, 0L)
            if (endTime != 0L && System.currentTimeMillis() > endTime) return // bloqueo vencido

            // Decodificamos correctamente la lista guardada por
            // shared_preferences (ver comentario de LIST_PREFIX arriba).
            val blockedSet: Set<String> = readStringList(KEY_BLOCKED_PACKAGES).toSet()

            if (blockedSet.contains(packageName)) {
                if (packageName != lastBlockedPackage) {
                    lastBlockedPackage = packageName
                    blockNow(packageName)
                }
            } else {
                lastBlockedPackage = null
            }
        } catch (e: Exception) {
            // Nunca dejamos que una excepción tumbe el servicio de accesibilidad
            // (requisito #19).
            e.printStackTrace()
        }
    }

    /**
     * Lee y decodifica una List<String> guardada por el plugin Flutter
     * `shared_preferences`. Ese plugin la almacena como un String plano con
     * el prefijo mágico LIST_PREFIX seguido de un JSON array — NO como un
     * StringSet nativo de Android, a diferencia de lo que podría asumirse.
     */
    private fun readStringList(key: String): List<String> {
        val raw = prefs.getString(key, null) ?: return emptyList()
        if (!raw.startsWith(LIST_PREFIX)) return emptyList()
        return try {
            val json = raw.substring(LIST_PREFIX.length)
            val arr = JSONArray(json)
            (0 until arr.length()).map { arr.getString(it) }
        } catch (e: Exception) {
            e.printStackTrace()
            emptyList()
        }
    }

    private fun blockNow(blockedPackage: String) {
        // 1) Sacamos al usuario de la app bloqueada inmediatamente.
        performGlobalAction(GLOBAL_ACTION_HOME)

        // 2) Registramos el intento directamente en SharedPreferences, en
        //    la misma clave que usa Dart (requisito #10 - estadísticas).
        //    Flutter recarga este valor con AppState.load() cuando la app
        //    vuelve a primer plano (ver "consumePendingBlockedPackage" en
        //    MainActivity.kt y didChangeAppLifecycleState en main.dart).
        try {
            val current = prefs.getInt("flutter.blocked_attempts", 0)
            prefs.edit().putInt("flutter.blocked_attempts", current + 1).apply()
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // 3) Abrimos nuestra app para que Flutter muestre la pantalla de
        //    bloqueo (BlockScreen) con el mensaje motivacional.
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("blocked_package", blockedPackage)
        }
        startActivity(intent)
    }

    override fun onInterrupt() {
        // Requerido por la clase base; no necesitamos limpiar nada especial.
    }
}
