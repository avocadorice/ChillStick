package com.chillstick.tv

import org.java_websocket.WebSocket
import org.java_websocket.handshake.ClientHandshake
import org.java_websocket.server.WebSocketServer
import java.net.InetSocketAddress

class GamepadServer(port: Int, private val listener: ServerListener) : WebSocketServer(InetSocketAddress(port)) {

    interface ServerListener {
        fun onClientConnected(conn: WebSocket)
        fun onClientDisconnected(conn: WebSocket)
        fun onMessageReceived(conn: WebSocket, message: String)
    }

    override fun onOpen(conn: WebSocket, handshake: ClientHandshake) {
        println("WebSocket connection opened: ${conn.remoteSocketAddress}")
        listener.onClientConnected(conn)
    }

    override fun onClose(conn: WebSocket, code: Int, reason: String, remote: Boolean) {
        println("WebSocket connection closed: ${conn.remoteSocketAddress}")
        listener.onClientDisconnected(conn)
    }

    override fun onMessage(conn: WebSocket, message: String) {
        listener.onMessageReceived(conn, message)
    }

    override fun onError(conn: WebSocket?, ex: Exception) {
        println("WebSocket server error: ${ex.message}")
        ex.printStackTrace()
    }

    override fun onStart() {
        println("WebSocket server started on port $port")
    }
}
