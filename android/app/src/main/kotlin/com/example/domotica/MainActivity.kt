package com.example.domotica

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
                    val timeoutMs = (call.argument<Int>("timeout") ?: 8) * 1000

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

            val code = try { conn.responseCode } catch (_: Exception) { -1 }
            android.util.Log.d("NetCtrl", "HTTP $code ← $urlStr")

            try { conn.inputStream.use { it.readBytes() } } catch (_: Exception) {
                try { conn.errorStream?.use { it.readBytes() } } catch (_: Exception) {}
            }
            conn.disconnect()

            // Cualquier respuesta = comando recibido = true
            // Solo false si excepción de red (timeout, sin conexión)
            code != -1

        } catch (e: Exception) {
            android.util.Log.e("NetCtrl", "ERROR: ${e.message}")
            false
        }
    }
}
