# Implementation Plan - ChillStick (Android TV Shell & Native iOS Controller)

This plan outlines the architecture and implementation files for **ChillStick**, a custom controller clone system:
1. **TV Side**: A native Android TV app in Kotlin that embeds a WebSocket server, displays a local pairing screen, redirects to Roger Boesch's **Shockwave** game, and translates incoming WebSocket events into native WebView keypresses.
2. **Mobile Side**: A native iOS app in Swift/SwiftUI that scans the pairing QR code, connects directly to the TV over the local Wi-Fi router, prevents screen sleeping, and shows a game controller layout.

## The Architecture: Native Local Pairing

```mermaid
graph TD
    subgraph Chromecast HD (Android TV)
        App[Kotlin Leanback Android App]
        WebView[Fullscreen WebView]
        WS[Embedded WebSocket Server :8081]
    end
    subgraph iPhone (iOS Native Swift App)
        ControllerApp[SwiftUI App]
        QRScanner[AVFoundation QR Scanner]
        WSClient[URLSessionWebSocketTask]
        ControllerUI[SwiftUI Gamepad UI]
    end

    App -- 1. Launches & Starts --> WS
    App -- 2. Loads Local Pairing UI --> WebView
    WebView -- 3. Displays ws:// IP QR Code --> User
    User -- 4. Scans QR with iOS App --> QRScanner
    QRScanner -- 5. Establishes Connection --> WSClient
    WSClient -- 6. Connects WebSocket --> WS
    WS -- 7. Triggers Connection Status --> WebView
    WebView -- 8. Redirects to Shockwave Game --> WebView
    ControllerUI -- 9. Sends Touch Events (JSON) --> WSClient
    WSClient -- 10. Relays Buttons --> WS
    WS -- 11. Injects KeyEvents into Game --> WebView
```

---

## Proposed Project Structure

We will create two modules under `/Users/bhsiao/dev/gdrive/plan-impl-verify/`:
1. `tv/` - Android TV Gradle project (Kotlin).
2. `ios/` - Native iOS SwiftUI codebase.

---

## 1. Android TV App Code (`tv/`)

### [NEW] [tv/build.gradle.kts](file:///Users/bhsiao/dev/gdrive/plan-impl-verify/tv/build.gradle.kts)
Project-level Gradle script.

### [NEW] [tv/settings.gradle.kts](file:///Users/bhsiao/dev/gdrive/plan-impl-verify/tv/settings.gradle.kts)
Declares the `:app` module.

### [NEW] [tv/app/build.gradle.kts](file:///Users/bhsiao/dev/gdrive/plan-impl-verify/tv/app/build.gradle.kts)
Module-level configuration. Includes standard Android UI libraries and `org.java-websocket:Java-WebSocket:1.5.3` for WebSocket serving.

### [NEW] [tv/app/src/main/AndroidManifest.xml](file:///Users/bhsiao/dev/gdrive/plan-impl-verify/tv/app/src/main/AndroidManifest.xml)
- Declares Internet and Wi-Fi state permissions.
- Configures for Leanback TV launcher.

### [NEW] [tv/app/src/main/java/com/chillstick/tv/MainActivity.kt](file:///Users/bhsiao/dev/gdrive/plan-impl-verify/tv/app/src/main/java/com/chillstick/tv/MainActivity.kt)
- Starts `GamepadServer` (port `8081`).
- Instantiates a fullscreen `WebView`.
- Directs WebView to load a local `pairing.html`.
- On mobile connection: redirects WebView to `https://rogerboesch.games/shockwave/?mode=desktop`.
- Receives button press events (`"accelerate_down"`, `"steer_left_up"`, etc.) and injects corresponding `KeyEvent`s into the WebView.

### [NEW] [tv/app/src/main/java/com/chillstick/tv/GamepadServer.kt](file:///Users/bhsiao/dev/gdrive/plan-impl-verify/tv/app/src/main/java/com/chillstick/tv/GamepadServer.kt)
WebSocket server implementation that relays lifecycle callbacks and controller events to `MainActivity`.

### [NEW] [tv/app/src/main/assets/pairing.html](file:///Users/bhsiao/dev/gdrive/plan-impl-verify/tv/app/src/main/assets/pairing.html)
Displays the pairing screen in WebView. Auto-detects the Chromecast's IP and renders a QR code representing `ws://<ip>:8081` (using a local inline SVG/JS QR renderer so it runs offline).

---

## 2. Native iOS App Code (`ios/`)

We will place the Swift source files under `/Users/bhsiao/dev/gdrive/plan-impl-verify/ios/ChillStick/`.

### [NEW] [ios/ChillStick/ChillStickApp.swift](file:///Users/bhsiao/dev/gdrive/plan-impl-verify/ios/ChillStick/ChillStickApp.swift)
App entry point. Disables the phone's idle screen sleep timer:
```swift
import SwiftUI

@main
struct ChillStickApp: App {
    init() {
        // Prevent screen sleep during controller gameplay
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### [NEW] [ios/ChillStick/WebSocketManager.swift](file:///Users/bhsiao/dev/gdrive/plan-impl-verify/ios/ChillStick/WebSocketManager.swift)
A state-observing Swift class handling WebSocket lifecycle via `URLSessionWebSocketTask`:
- Connects to `ws://<tv-ip>:8081`.
- Sends JSON events like `{"action": "keydown", "key": "thrust"}`.
- Reconnects automatically on failure.

### [NEW] [ios/ChillStick/QRScannerView.swift](file:///Users/bhsiao/dev/gdrive/plan-impl-verify/ios/ChillStick/QRScannerView.swift)
SwiftUI wrapper around `AVCaptureSession` and `AVCaptureMetadataOutput` that handles camera access, scans the QR code, parses the `ws://...` endpoint, and forwards it to the connection manager.

### [NEW] [ios/ChillStick/ContentView.swift](file:///Users/bhsiao/dev/gdrive/plan-impl-verify/ios/ChillStick/ContentView.swift)
App view controller:
- Stage 1: Prompts for camera permissions and displays the QR scanner.
- Stage 2: Displays a "Connecting..." indicator.
- Stage 3: Opens the landscape gamepad layout interface.

### [NEW] [ios/ChillStick/GamepadView.swift](file:///Users/bhsiao/dev/gdrive/plan-impl-verify/ios/ChillStick/GamepadView.swift)
SwiftUI view rendering the virtual gamepad layout:
- Left side: Large D-pad buttons (Left / Right).
- Right side: Accent action buttons (Thrust / Brake).
- Uses customized SwiftUI `DragGesture(minimumDistance: 0)` to support continuous press detection and multi-touch inputs.

---

## 3. Build & Setup Scripts

### [NEW] [setup_and_build.sh](file:///Users/bhsiao/dev/gdrive/plan-impl-verify/setup_and_build.sh)
Helper shell script that:
- Installs standard command dependencies (Java, Android build tools).
- Compiles the Android TV APK.
- Instructs the user on how to open `/Users/bhsiao/dev/gdrive/plan-impl-verify/ios` in Xcode to run the native controller on their iPhone.

---

## Verification Plan

### Manual Verification
1. **Build Android App**: Run `bash setup_and_build.sh` on your Mac to compile the Android debug APK.
2. **Install on TV**: Use `adb connect <chromecast-ip>:5555` and `adb install tv-app.apk` to push to your Chromecast.
3. **Build iOS App**: Open `ios/` in Xcode on your Mac, connect your iPhone via USB, and compile/run the project.
4. **Pair**: Launch the TV app, launch the iPhone app, point the phone camera at the TV QR code, and verify pairing.
5. **Play**: Verify that turning the D-pad and holding thrust drives Roger Boesch's Shockwave ship.
