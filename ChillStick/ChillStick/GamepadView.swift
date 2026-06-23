import SwiftUI

struct GamepadView: View {
    @ObservedObject var wsManager: WebSocketManager
    
    var body: some View {
        ZStack {
            Color(red: 20/255, green: 20/255, blue: 20/255)
                .ignoresSafeArea()
            
            VStack {
                // Header status row
                HStack {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Connected to TV")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    // Exit the game on the TV (sends it to the background, like the
                    // remote's Back button) — without disconnecting the controller.
                    Button(action: {
                        wsManager.sendKey(action: "keydown", key: "back")
                    }) {
                        Text("⤺ Exit Game")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.12))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                    Button(action: {
                        wsManager.disconnect()
                    }) {
                        Text("Disconnect")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(6)
                    }
                }
                .padding()
                
                Spacer()
                
                // Controls Row
                HStack {
                    // Left Side: D-pad Left and Right
                    HStack(spacing: 20) {
                        TouchButton(label: "◀", color: Color(red: 229/255, green: 9/255, blue: 20/255)) {
                            wsManager.sendKey(action: "keydown", key: "left")
                        } onUp: {
                            wsManager.sendKey(action: "keyup", key: "left")
                        }
                        
                        TouchButton(label: "▶", color: Color(red: 229/255, green: 9/255, blue: 20/255)) {
                            wsManager.sendKey(action: "keydown", key: "right")
                        } onUp: {
                            wsManager.sendKey(action: "keyup", key: "right")
                        }
                    }
                    .padding(.leading, 40)
                    
                    Spacer()
                    
                    // Right Side: Chop and Jump
                    HStack(spacing: 20) {
                        TouchButton(label: "CHOP", color: Color.orange) {
                            wsManager.sendKey(action: "keydown", key: "chop")
                        } onUp: {
                            wsManager.sendKey(action: "keyup", key: "chop")
                        }

                        TouchButton(label: "JUMP", color: Color.green) {
                            wsManager.sendKey(action: "keydown", key: "jump")
                        } onUp: {
                            wsManager.sendKey(action: "keyup", key: "jump")
                        }
                    }
                    .padding(.trailing, 40)
                }
                .padding(.bottom, 30)
                
                Spacer()
            }
        }
    }
}

struct TouchButton: View {
    let label: String
    let color: Color
    let onDown: () -> Void
    let onUp: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Text(label)
            .font(.title2.bold())
            .foregroundColor(.white)
            .frame(width: 100, height: 100)
            .background(isPressed ? color.opacity(0.7) : color)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
            )
            .shadow(color: isPressed ? color.opacity(0.5) : Color.black.opacity(0.3), radius: isPressed ? 8 : 4, y: isPressed ? 0 : 4)
            .scaleEffect(isPressed ? 0.94 : 1.0)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            onDown()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        onUp()
                    }
            )
    }
}
