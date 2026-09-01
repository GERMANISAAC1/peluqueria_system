package com.example.focus_app
// ⚠️ Cambia "com.example.focus_app" por tu applicationId real, aquí y en la
// ruta de carpetas donde vive este archivo.

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/**
 * MainActivity
 * =============================================================================
 * Expone dos canales nativos que reemplazan a paquetes de terceros que
 * resultaron incompatibles con AGP moderno (`device_apps` y `usage_stats`,
 * ambos con "compileSdk" desactualizado en su propio build.gradle):
 *
 *  - "focus_app/apps": listar apps instaladas (requisito #1).
 *  - "focus_app/native_events": estado del permiso de Acceso a datos de uso
 *    (requisito #14), y el "pendingBlockedPackage" que deja
 *    AppBlockAccessibilityService.kt cuando saca al usuario de una app
 *    bloqueada y trae esta Activity al frente (requisito #4).
 */
class MainActivity : FlutterActivity() {

    private val APPS_CHANNEL = "focus_app/apps"
    private val NATIVE_EVENTS_CHANNEL = "focus_app/native_events"

    companion object {
        /**
         * Paquete bloqueado que el AccessibilityService detectó más
         * recientemente. Flutter lo "consume" (lee y limpia) vía el método
         * "consumePendingBlockedPackage" cuando la app vuelve a primer
         * plano (ver didChangeAppLifecycleState en main.dart).
         */
        var pendingBlockedPackage: String? = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntentExtras(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntentExtras(intent)
    }

    private fun handleIntentExtras(intent: Intent?) {
        val blocked = intent?.getStringExtra("blocked_package")
        if (blocked != null) {
            pendingBlockedPackage = blocked
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APPS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledApps" -> {
                        try {
                            result.success(getInstalledApps())
                        } catch (e: Exception) {
                            result.error("APPS_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NATIVE_EVENTS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasUsageAccess" -> {
                        try {
                            result.success(hasUsageAccess())
                        } catch (e: Exception) {
                            result.error("USAGE_ERROR", e.message, null)
                        }
                    }
                    "consumePendingBlockedPackage" -> {
                        val pkg = pendingBlockedPackage
                        pendingBlockedPackage = null
                        result.success(pkg)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ------------------------- Apps instaladas -------------------------

    private fun getInstalledApps(): List<Map<String, Any?>> {
        val pm = packageManager

        val mainIntent = Intent(Intent.ACTION_MAIN, null)
        mainIntent.addCategory(Intent.CATEGORY_LAUNCHER)
        val resolveInfos = pm.queryIntentActivities(mainIntent, 0)

        val apps = mutableListOf<Map<String, Any?>>()
        val seenPackages = mutableSetOf<String>()

        for (resolveInfo in resolveInfos) {
            val packageName = resolveInfo.activityInfo?.packageName ?: continue
            if (packageName == applicationContext.packageName) continue
            if (!seenPackages.add(packageName)) continue

            try {
                val appInfo: ApplicationInfo = pm.getApplicationInfo(packageName, 0)
                val appName = pm.getApplicationLabel(appInfo).toString()
                val isSystemApp = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
                val iconDrawable: Drawable = pm.getApplicationIcon(appInfo)
                val iconBytes = drawableToPngBytes(iconDrawable)

                apps.add(
                    mapOf(
                        "packageName" to packageName,
                        "appName" to appName,
                        "isSystemApp" to isSystemApp,
                        "icon" to iconBytes,
                    )
                )
            } catch (e: Exception) {
                continue
            }
        }
        return apps
    }

    private fun drawableToPngBytes(drawable: Drawable): ByteArray {
        val bitmap: Bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
            drawable.bitmap
        } else {
            val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 96
            val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 96
            val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            bmp
        }
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        return stream.toByteArray()
    }

    // ------------------------- Acceso a datos de uso -------------------------

    /**
     * Reemplazo nativo de `UsageStats.checkUsagePermission()` del paquete
     * `usage_stats` (eliminado). Verifica el permiso especial
     * PACKAGE_USAGE_STATS vía AppOpsManager, tal como lo hace Android
     * internamente.
     */
    private fun hasUsageAccess(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            android.os.Process.myUid(),
            packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }
}

