package com.example.focus_app
// ⚠️ Cambia el nombre de paquete por tu applicationId real.

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.preference.PreferenceManager

/**
 * BootReceiver
 * =============================================================================
 * Cumple el requisito #17: "la aplicación debe seguir funcionando tras
 * reiniciar el dispositivo". Sin este receiver nativo, cualquier Foreground
 * Service se detiene al apagar el teléfono y NO vuelve a arrancar solo,
 * sin importar qué se haga en Dart.
 *
 * Nota: flutter_foreground_task ya incluye su propia lógica interna de
 * "autoRunOnBoot" (activada en main.dart vía ForegroundTaskOptions), pero
 * ese mecanismo depende de que ESTE receiver (o el que el plugin registra
 * automáticamente) esté correctamente declarado en el Manifest. Si usas una
 * versión del plugin que ya registra su propio BroadcastReceiver de boot,
 * puedes omitir este archivo; se incluye aquí como respaldo explícito y para
 * dejar constancia de qué hace falta si decides implementarlo manualmente.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != "android.intent.action.QUICKBOOT_POWERON"
        ) {
            return
        }

        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val wasActive = prefs.getBoolean("flutter.is_blocking_active", false)
            val endTime = prefs.getLong("flutter.block_end_time_ms", 0L)

            // Solo reactivamos si el bloqueo seguía vigente al momento del
            // reinicio (evita reactivar sesiones ya vencidas).
            if (wasActive && endTime > System.currentTimeMillis()) {
                // Lanzamos la MainActivity en modo "silencioso" para que
                // Flutter, al inicializar AppState.load(), detecte
                // isBlockingActive = true y vuelva a arrancar el
                // Foreground Service + el conteo regresivo automáticamente.
                val launchIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    putExtra("resumed_from_boot", true)
                }
                context.startActivity(launchIntent)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
