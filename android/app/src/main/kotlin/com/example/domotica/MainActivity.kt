package com.example.gym

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    private val CHANNEL = "domotica/http"
    private val executor = Executors.newCachedThreadPool()
    private val handler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "get") {
                    val url = call.argument<String>("url") ?: ""
                    val timeoutSec = call.argument<Int>("timeout") ?: 8
                    val timeoutMs = timeoutSec * 1000

                    executor.execute {
                        val ok = httpGet(url, timeoutMs)
                        handler.post { result.success(ok) }
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun httpGet(urlStr: String, timeoutMs: Int): Boolean {
        return try {
            android.util.Log.d("NetCtrl", "GET $urlStr")
            val url = URL(urlStr)
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "GET"
            conn.connectTimeout = timeoutMs
            conn.readTimeout = timeoutMs
            conn.setRequestProperty("Connection", "close")
            conn.setRequestProperty("Cache-Control", "no-cache")
            conn.instanceFollowRedirects = true
            conn.doInput = true

            // Leer el código de respuesta
            val code = try { conn.responseCode } catch (e: Exception) { -1 }
            android.util.Log.d("NetCtrl", "HTTP $code ← $urlStr")

            // Consumir body para liberar conexión
            try {
                conn.inputStream.use { it.readBytes() }
            } catch (_: Exception) {
                try { conn.errorStream?.use { it.readBytes() } } catch (_: Exception) {}
            }
            conn.disconnect()

            // CLAVE: cualquier respuesta del servidor = comando recibido = true
            // Solo false si hubo excepción de red (timeout, sin conexión)
            // Web Remote Droid puede responder 404/405 pero igual ejecuta el comando
            code != -1

        } catch (e: Exception) {
            android.util.Log.e("NetCtrl", "ERROR $urlStr : ${e.message}")
            false
        }
    }
}
