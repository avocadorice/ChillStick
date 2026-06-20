import Foundation
import Combine

class WebSocketManager: ObservableObject {
    @Published var isConnected = false
    @Published var isConnecting = false
    @Published var connectionError: String? = nil
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession
    private var pingTimer: Timer?
    private var connectionUrl: URL?

    init() {
        self.urlSession = URLSession(configuration: .default)
    }
    
    func connect(to urlString: String) {
        guard let url = URL(string: urlString) else {
            self.connectionError = "Invalid URL"
            return
        }
        
        self.connectionUrl = url
        self.isConnecting = true
        self.connectionError = nil
        
        webSocketTask = urlSession.webSocketTask(with: url)
        webSocketTask?.resume()
        
        // Start listening to incoming WebSocket frames (if any) and check connections
        listen()
        checkConnection()
        startPingTimer()
    }
    
    func disconnect() {
        pingTimer?.invalidate()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        self.isConnected = false
        self.isConnecting = false
    }
    
    private func listen() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                print("Received message from TV: \(message)")
                self.listen()
            case .failure(let error):
                DispatchQueue.main.async {
                    self.isConnected = false
                    self.isConnecting = false
                    self.connectionError = error.localizedDescription
                }
            }
        }
    }
    
    private func checkConnection() {
        self.webSocketTask?.sendPing { [weak self] error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let error = error {
                    self.isConnected = false
                    self.isConnecting = false
                    self.connectionError = error.localizedDescription
                } else {
                    self.isConnected = true
                    self.isConnecting = false
                }
            }
        }
    }
    
    private func startPingTimer() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.checkConnection()
        }
    }
    
    func sendKey(action: String, key: String) {
        guard isConnected else { return }
        
        let payload: [String: String] = [
            "action": action,
            "key": key
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: [])
            if let jsonString = String(data: data, encoding: .utf8) {
                let message = URLSessionWebSocketTask.Message.string(jsonString)
                webSocketTask?.send(message) { error in
                    if let error = error {
                        print("Failed to send socket packet: \(error)")
                    }
                }
            }
        } catch {
            print("Failed to serialize json input: \(error)")
        }
    }
}
