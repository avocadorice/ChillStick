package com.chillstick.tv

import android.app.Activity
import android.net.http.SslError
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import android.webkit.SslErrorHandler
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import org.json.JSONObject
import org.java_websocket.WebSocket
import java.net.Inet4Address
import java.net.NetworkInterface
import java.util.Collections

class MainActivity : Activity(), GamepadServer.ServerListener {

    private lateinit var webView: WebView
    private var server: GamepadServer? = null
    private var isPaired = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Set landscape, keep screen on, hide system bars
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.decorView.systemUiVisibility = (View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_FULLSCREEN
                or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY)

        webView = WebView(this)
        setContentView(webView)

        setupWebView()

        // Start WebSocket Gamepad Server on port 8081
        try {
            server = GamepadServer(8081, this)
            server?.start()
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // Auto-detect local Wi-Fi IP and load pairing page
        val ip = getLocalIpAddress() ?: "127.0.0.1"
        webView.loadUrl("file:///android_asset/pairing.html?ip=$ip")
    }

    private fun setupWebView() {
        val settings = webView.settings
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.allowFileAccess = true
        settings.mediaPlaybackRequiresUserGesture = false
        settings.useWideViewPort = true
        settings.loadWithOverviewMode = true

        webView.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                return false
            }

            override fun onReceivedSslError(view: WebView?, handler: SslErrorHandler?, error: SslError?) {
                // Ignore SSL certificate errors for localhost/development WebGL games
                handler?.proceed()
            }
        }
    }

    private fun getLocalIpAddress(): String? {
        try {
            val interfaces = Collections.list(NetworkInterface.getNetworkInterfaces())
            for (networkInterface in interfaces) {
                val addresses = Collections.list(networkInterface.inetAddresses)
                for (address in addresses) {
                    if (!address.isLoopbackAddress && address is Inet4Address) {
                        val ip = address.hostAddress
                        // Ensure we return a local network address
                        if (ip.startsWith("192.168.") || ip.startsWith("10.") || ip.startsWith("172.")) {
                            return ip
                        }
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return null
    }

    override fun onClientConnected(conn: WebSocket) {
        runOnUiThread {
            if (!isPaired) {
                isPaired = true
                // Connect and load Roger's Shockwave WebGL game
                webView.loadUrl("https://rogerboesch.games/shockwave/?mode=desktop")
            }
        }
    }

    override fun onClientDisconnected(conn: WebSocket) {
        runOnUiThread {
            if (isPaired) {
                isPaired = false
                val ip = getLocalIpAddress() ?: "127.0.0.1"
                webView.loadUrl("file:///android_asset/pairing.html?ip=$ip")
            }
        }
    }

    override fun onMessageReceived(conn: WebSocket, message: String) {
        try {
            val obj = JSONObject(message)
            val action = obj.getString("action") // "keydown" or "keyup"
            val key = obj.getString("key") // "left", "right", "thrust", "brake"

            val keyCode = when (key) {
                "left" -> 37     // ArrowLeft
                "right" -> 39    // ArrowRight
                "thrust" -> 16   // Shift (WipEout style throttle in Shockwave)
                "brake" -> 32    // Space
                else -> 0
            }

            val keyName = when (key) {
                "left" -> "ArrowLeft"
                "right" -> "ArrowRight"
                "thrust" -> "Shift"
                "brake" -> " "
                else -> ""
            }

            if (keyCode != 0) {
                // Directly dispatch KeyboardEvent into DOM to simulate keyboard presses safely
                val jsEvent = "window.dispatchEvent(new KeyboardEvent('$action', { keyCode: $keyCode, which: $keyCode, key: '$keyName', bubbles: true }));"
                runOnUiThread {
                    webView.evaluateJavascript(jsEvent, null)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            server?.stop()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
