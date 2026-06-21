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
                    val timeout = (call.argument<Int>("timeout") ?: 8) * 1000

                    executor.execute {
                        val ok = httpGet(url, timeout)
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

            val code = conn.responseCode
            android.util.Log.d("NetCtrl", "HTTP $code for $urlStr")

            // Consumir el body para liberar la conexión
            try { conn.inputStream.use { it.readBytes() } } catch (_: Exception) {}
            conn.disconnect()

            // Cualquier respuesta = comando recibido
            true
        } catch (e: Exception) {
            android.util.Log.e("NetCtrl", "Error GET $urlStr: ${e.message}")
            false
        }
    }
}
