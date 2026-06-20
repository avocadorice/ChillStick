import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var wsManager = WebSocketManager()
    @State private var hasPermission = false
    @State private var checkingPermission = true

    var body: some View {
        Group {
            if wsManager.isConnected {
                GamepadView(wsManager: wsManager)
                    .transition(.opacity)
            } else if wsManager.isConnecting {
                ConnectingView(wsManager: wsManager)
            } else if let error = wsManager.connectionError {
                ErrorView(error: error) {
                    wsManager.connectionError = nil
                }
            } else {
                ScannerFlowView(hasPermission: $hasPermission, checkingPermission: $checkingPermission) { scannedCode in
                    // Scan validation: expect ws://<ip>:8081
                    if scannedCode.hasPrefix("ws://") {
                        wsManager.connect(to: scannedCode)
                    } else {
                        wsManager.connectionError = "Scanned code is not a valid ChillStick TV address: \(scannedCode)"
                    }
                }
            }
        }
        .animation(.easeInOut, value: wsManager.isConnected)
    }
}

struct ConnectingView: View {
    @ObservedObject var wsManager: WebSocketManager
    
    var body: some View {
        ZStack {
            Color(red: 20/255, green: 20/255, blue: 20/255)
                .ignoresSafeArea()
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 229/255, green: 9/255, blue: 20/255)))
                    .scaleEffect(1.5)
                Text("Connecting to ChillStick TV...")
                    .foregroundColor(.white)
                    .font(.headline)
                Button("Cancel") {
                    wsManager.disconnect()
                }
                .foregroundColor(.red)
                .padding(.top, 10)
            }
        }
    }
}

struct ErrorView: View {
    let error: String
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color(red: 20/255, green: 20/255, blue: 20/255)
                .ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 50))
                Text("Connection Failed")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text(error)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Button("Scan Again") {
                    onDismiss()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color(red: 229/255, green: 9/255, blue: 20/255))
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
    }
}

struct ScannerFlowView: View {
    @Binding var hasPermission: Bool
    @Binding var checkingPermission: Bool
    var onScan: (String) -> Void
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if checkingPermission {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 229/255, green: 9/255, blue: 20/255)))
            } else if hasPermission {
                QRScannerView(onScan: onScan)
                    .ignoresSafeArea()
                
                // Netflix scanner HUD layout overlay
                VStack {
                    Text("CHILLSTICK")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(Color(red: 229/255, green: 9/255, blue: 20/255))
                        .padding(.top, 30)
                        .tracking(3)
                    Text("Point your camera at the TV pairing code")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.top, 2)
                    Spacer()
                    // Scanning square layout
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(red: 229/255, green: 9/255, blue: 20/255), lineWidth: 3)
                        .frame(width: 250, height: 250)
                        .shadow(color: Color(red: 229/255, green: 9/255, blue: 20/255).opacity(0.4), radius: 10)
                    Spacer()
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("Camera Access Needed")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Text("ChillStick needs camera access to scan the pairing QR code on your TV screen.")
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Button("Grant Access") {
                        requestCameraAccess()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(red: 229/255, green: 9/255, blue: 20/255))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .onAppear {
            checkCameraPermission()
        }
    }
    
    private func checkCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        DispatchQueue.main.async {
            hasPermission = status == .authorized
            checkingPermission = false
        }
    }
    
    private func requestCameraAccess() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                hasPermission = granted
                checkingPermission = false
            }
        }
    }
}
