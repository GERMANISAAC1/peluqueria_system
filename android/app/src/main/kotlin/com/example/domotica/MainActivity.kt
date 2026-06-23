package com.example.domotica

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.HttpURLConnection
import java.net.Socket
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
                        val ok = enviarComando(url, timeoutMs)
                        handler.post { result.success(ok) }
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    // ─────────────────────────────────────────────────────────────
    // Estrategia: TCP raw HTTP/1.0
    //
    // Por qué TCP raw en vez de HttpURLConnection:
    // HttpURLConnection de Java usa HTTP/1.1 con keep-alive.
    // Algunos servidores embebidos (Web Remote Droid) cierran la
    // conexión TCP después de ejecutar el comando SIN enviar una
    // respuesta HTTP completa. Esto hace que responseCode() lance
    // IOException y el comando se considere fallido aunque funcionó.
    //
    // Con TCP raw mandamos HTTP/1.0 (sin keep-alive) y consideramos
    // exitoso si el servidor recibe la request (pudo conectarse y
    // mandar datos). La respuesta es opcional — si el servidor la
    // manda bien, si no la manda también bien.
    // ─────────────────────────────────────────────────────────────
    private fun enviarComando(urlStr: String, timeoutMs: Int): Boolean {
        return try {
            val url = URL(urlStr)
            val host = url.host
            val port = if (url.port == -1) 80 else url.port
            val path = if (url.file.isEmpty()) "/" else url.file

            android.util.Log.d("NetCtrl", "TCP $host:$port$path")

            val socket = Socket()
            socket.soTimeout = timeoutMs
            socket.connect(java.net.InetSocketAddress(host, port), timeoutMs)

            // Mandamos la request HTTP/1.0
            val request = "GET $path HTTP/1.0\r\nHost: $host\r\nConnection: close\r\n\r\n"
            socket.getOutputStream().write(request.toByteArray())
            socket.getOutputStream().flush()

            // Intentar leer la respuesta (opcional - puede no llegar)
            try {
                val buf = ByteArray(256)
                socket.getInputStream().read(buf)
                val resp = String(buf).trim()
                android.util.Log.d("NetCtrl", "Respuesta: ${resp.take(50)}")
            } catch (_: Exception) {
                // El servidor cerró sin responder — normal en algunos firmwares
                android.util.Log.d("NetCtrl", "Sin respuesta HTTP — comando enviado igual")
            }

            socket.close()

            // Si llegamos aquí = conectamos y mandamos la request = ÉXITO
            true

        } catch (e: Exception) {
            android.util.Log.e("NetCtrl", "ERROR: ${e.message}")
            // Reintento con HttpURLConnection como fallback
            fallbackHttp(urlStr, timeoutMs)
        }
    }

    // Fallback con HttpURLConnection por si el socket falla
    private fun fallbackHttp(urlStr: String, timeoutMs: Int): Boolean {
        return try {
            android.util.Log.d("NetCtrl", "Fallback HTTP: $urlStr")
            System.setProperty("http.keepAlive", "false")
            val conn = URL(urlStr).openConnection() as HttpURLConnection
            conn.requestMethod = "GET"
            conn.connectTimeout = timeoutMs
            conn.readTimeout = timeoutMs
            conn.useCaches = false
            conn.setRequestProperty("Connection", "close")
            conn.connect()
            try { conn.responseCode } catch (_: Exception) { }
            try { conn.inputStream?.use { it.readBytes() } } catch (_: Exception) { }
            conn.disconnect()
            // Si conectó = éxito
            true
        } catch (e: Exception) {
            android.util.Log.e("NetCtrl", "Fallback ERROR: ${e.message}")
            false
        }
    }
}
