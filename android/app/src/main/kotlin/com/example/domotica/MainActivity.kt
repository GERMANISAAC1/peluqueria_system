package com.example.domotica

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader
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
                        // Intento 1
                        var ok = httpGet(url, timeoutMs)
                        // Intento 2 si falló
                        if (!ok) {
                            Thread.sleep(600)
                            ok = httpGet(url, timeoutMs)
                        }
                        // Intento 3 si falló
                        if (!ok) {
                            Thread.sleep(800)
                            ok = httpGet(url, timeoutMs)
                        }
                        handler.post { result.success(ok) }
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun httpGet(urlStr: String, timeoutMs: Int): Boolean {
        var conn: HttpURLConnection? = null
        return try {
            android.util.Log.d("NetCtrl", "GET $urlStr")

            // Deshabilitar cache HTTP del sistema
            System.setProperty("http.keepAlive", "false")

            val url = URL(urlStr)
            conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "GET"
            conn.connectTimeout = timeoutMs
            conn.readTimeout = timeoutMs
            conn.useCaches = false
            conn.defaultUseCaches = false
            conn.instanceFollowRedirects = true
            conn.setRequestProperty("Connection", "close")
            conn.setRequestProperty("Cache-Control", "no-cache, no-store")
            conn.setRequestProperty("Pragma", "no-cache")

            // Conectar explícitamente
            conn.connect()

            // Leer código HTTP
            val code = conn.responseCode
            android.util.Log.d("NetCtrl", "HTTP $code ← $urlStr")

            // Leer y descartar body completo
            try {
                val stream = if (code < 400) conn.inputStream else conn.errorStream
                stream?.use { s ->
                    BufferedReader(InputStreamReader(s)).use { br ->
                        while (br.readLine() != null) { /* descartar */ }
                    }
                }
            } catch (_: Exception) {}

            // Cualquier código HTTP válido = servidor recibió el comando
            code > 0

        } catch (e: Exception) {
            android.util.Log.e("NetCtrl", "ERROR $urlStr: ${e.javaClass.simpleName} - ${e.message}")
            false
        } finally {
            try { conn?.disconnect() } catch (_: Exception) {}
        }
    }
}
