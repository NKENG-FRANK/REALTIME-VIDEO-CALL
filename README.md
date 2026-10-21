# CallWave - Real-Time Cross-Platform Audio & Video Calling System

CallWave is a self-hosted, enterprise-grade WebRTC audio and video calling platform. It features low-latency peer-to-peer (P2P) mesh and SFU fallback streaming, background incoming call notifications, resilient ICE reconnection, single-instance desktop lifecycle, and end-to-end microservices architecture.

---

## Table of Contents

1. [System Architecture & Repository Structure](#1-system-architecture--repository-structure)
2. [Folder-by-Folder Guide](#2-folder-by-folder-guide)
3. [Server IP & Domain Configuration Guide](#3-server-ip--domain-configuration-guide)
4. [Backend Deployment Guide (Docker & VPS)](#4-backend-deployment-guide-docker--vps)
5. [Client Build Guide (Android APK & Windows Desktop)](#5-client-build-guide-android-apk--windows-desktop)
6. [Website Management & Download Link Updates](#6-website-management--download-link-updates)
7. [Firewall & Port Reference](#7-firewall--port-reference)
8. [Troubleshooting & Verification](#8-troubleshooting--verification)

---

## 1. System Architecture & Repository Structure

```
REALTIME-VIDEO-CALL/
├── callwave-backend/            # Microservices backend & infrastructure
├── videocall/                   # Cross-platform Flutter client (Android, Windows)
├── website/                     # React + Vite public marketing & download website
├── Dev Docs and Architecture/   # IEEE specs, SRS, and architecture diagrams
├── UI-Designs/                  # Figma mockups and screen references
└── README.md                    # Project documentation
```

### Technology Stack Overview:
- **Backend**: Node.js, TypeScript, Express, Socket.io, Mediasoup (SFU), PostgreSQL, Redis, RabbitMQ, Docker Compose, CoTURN.
- **Client (Frontend)**: Flutter, Dart, `flutter_webrtc`, `flutter_callkit_incoming`, `permission_handler`, `socket_io_client`.
- **Website**: React 19, Vite, Vanilla CSS.

---

## 2. Folder-by-Folder Guide

### `callwave-backend/`
The server-side microservices stack managed via Docker Compose.
- **`docker-compose.yml`**: Defines and orchestrates all 6 containers:
  - `postgres`: Relational database for users, contacts, call history, and auth.
  - `redis`: High-speed session store, presence tracking, and Socket.io horizontal adapter.
  - `rabbitmq`: Asynchronous message broker between microservices.
  - `callwave-user-management` (Port 3000): Authentication (JWT), user registration, contact search, profile.
  - `callwave-video-calls` (Port 3002): WebRTC signaling server, Socket.io room management, and Mediasoup SFU worker pool.
  - `callwave-background-processes` (Port 3003): Offline notification dispatch and background housekeeping.
  - `callwave-coturn` (Port 3478 UDP/TCP, 49152–49252 UDP): Built-in STUN/TURN NAT traversal relay.
- **`services/`**:
  - `user-management/`: Express REST API for login, signup, JWT verification, and contacts.
  - `video-calls/`: WebRTC signaling logic (`videoHandler.ts`), room state, and audio/video pipelines.
  - `background-processes/`: Asynchronous consumer workers for RabbitMQ queues.
- **`packages/`**: Monorepo shared libraries (`@callwave/config`, `@callwave/database`, `@callwave/redis`, `@callwave/rabbitmq`, `@callwave/shared`).
- **`infrastructure/`**: Database migrations, seed data, and service configurations.
- **`.env` / `.env.example`**: Environment variables for database credentials, JWT secrets, and IP addresses.

### `videocall/`
The Flutter client application compiling natively for Android and Windows.
- **`lib/config/api_config.dart`**: Centralized endpoint definitions for backend REST and Socket.io servers.
- **`lib/core/services/`**:
  - `webrtc_call_service.dart`: Core WebRTC peer-connection engine, Perfect Negotiation glare resolution, ICE server list, track binding, camera/mic capture, and speakerphone routing.
  - `signaling_service.dart`: Handles incoming call invites (`call:invite`, `call:incoming`, `call:decline`).
  - `auth_service.dart`: JWT token storage, persistence via `SharedPreferences`.
  - `desktop_tray_service.dart`: Windows system tray minimization and incoming call window foreground focus.
  - `ringtone_service.dart`: Audio ringing for incoming and outgoing calls.
- **`lib/features/`**:
  - `auth/`: Login and registration UI pages.
  - `call/`: `CallPage` (video grid & spotlight), `AudioCallPage`, `IncomingCallPage`, `ConnectingPage`, `CallEndedPage`.
  - `contacts/`: User directory, search, and direct call triggers.
  - `settings/`: Device preferences, camera/mic toggle, audio diagnostics.
- **`android/`**: Native Android wrapper (Manifest permissions, ProGuard, Kotlin build scripts).
- **`windows/`**: Native C++ Windows runner (Single-instance mutex, window size, system tray integration).

### `website/`
The marketing portal for product showcase and app distribution.
- **`src/App.jsx`**: Main landing page with live feature previews, interactive mockups, and direct download buttons.
- **`src/App.css`**: Design tokens, glassmorphism styling, responsive layouts.
- **`dist/`**: Production bundle output from `npm run build`.

### `Dev Docs and Architecture/`
- Technical design specifications, IEEE 830 SRS documentation, product requirements, and visual architecture diagrams.

### `UI-Designs/`
- High-fidelity UI mockups (`auth-page.png`, `connecting-screen.png`, `call-screen.png`, `call-end.png`, `settings-page.png`).

---

## 3. Server IP & Domain Configuration Guide

When deploying to a new server (VPS or Cloud Instance), you must update the IP address (or domain name) in both the backend and frontend.

### Step 3.1: Backend Configuration

#### 1. In `callwave-backend/.env`:
Update the `ANNOUNCED_IP` to your server's public IPv4:
```env
ANNOUNCED_IP=YOUR_SERVER_PUBLIC_IP
```

#### 2. In `callwave-backend/docker-compose.yml`:
Locate the `video-calls` and `coturn` services:

```yaml
  video-calls:
    environment:
      ANNOUNCED_IP: ${ANNOUNCED_IP:-YOUR_SERVER_PUBLIC_IP}
```

```yaml
  coturn:
    command:
      - -n
      - --log-file=stdout
      - --listening-port=3478
      - --fingerprint
      - --lt-cred-mech
      - --realm=YOUR_SERVER_PUBLIC_IP        # <-- Update this
      - --user=callwave:callwave_secret
      - --external-ip=YOUR_SERVER_PUBLIC_IP  # <-- Update this
      - --min-port=49152
      - --max-port=49252
      - --no-cli
```

---

### Step 3.2: Frontend (Flutter Client) Configuration

#### 1. In `videocall/lib/config/api_config.dart`:
Update `_configuredHost` and `defaultLanIp`:
```dart
class ApiConfig {
  // Set to your VPS public IP address or your custom domain (e.g., 'callwave.example.com')
  static const String _configuredHost = String.fromEnvironment('SERVER_IP', defaultValue: 'YOUR_SERVER_PUBLIC_IP');
  static const bool isSecure = bool.fromEnvironment('IS_SECURE', defaultValue: false);

  static const String defaultLanIp = 'YOUR_SERVER_PUBLIC_IP';
  // ...
}
```
> **Tip**: If you are using HTTPS with an SSL domain (e.g. `api.yourdomain.com`), set `isSecure = true` or pass `--dart-define=IS_SECURE=true` at build time.

#### 2. In `videocall/lib/core/services/webrtc_call_service.dart`:
Update the STUN/TURN server URLs in the `_iceServers` map (lines 155–175):
```dart
  static const Map<String, dynamic> _iceServers = {
    'iceServers': [
      // Primary STUN servers
      {'urls': 'stun:YOUR_SERVER_PUBLIC_IP:3478'},
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      // Primary CoTURN Server (UDP and TCP)
      {
        'urls': [
          'turn:YOUR_SERVER_PUBLIC_IP:3478?transport=udp',
          'turn:YOUR_SERVER_PUBLIC_IP:3478?transport=tcp',
        ],
        'username': 'callwave',
        'credential': 'callwave_secret',
      },
    ],
  };
```

---

### Step 3.3: Website Status Pill Configuration

In `website/src/App.jsx`, update the VPS health indicator text near the bottom footer:
```jsx
<div className="system-health-pill">
  <span className="health-dot" /> VPS Services Online (YOUR_SERVER_PUBLIC_IP)
</div>
```

---

## 4. Backend Deployment Guide (Docker & VPS)

### Prerequisites on the VPS:
- Ubuntu 22.04 / 24.04 LTS (or Debian 12)
- Docker & Docker Compose v2 installed (`docker compose version`)
- Git installed

### Step-by-Step Deployment:

1. **Clone the repository on the server**:
   ```bash
   cd ~/Desktop
   git clone https://github.com/NKENG-FRANK/REALTIME-VIDEO-CALL.git
   cd REALTIME-VIDEO-CALL/callwave-backend
   ```

2. **Configure Environment**:
   ```bash
   cp .env.example .env
   nano .env
   ```
   Set `ANNOUNCED_IP` to the VPS's public IP.

3. **Build and start all services**:
   ```bash
   docker compose up -d --build
   ```

4. **Verify container health**:
   ```bash
   docker compose ps
   ```
   Expected running containers:
   - `callwave-postgres` (healthy)
   - `callwave-redis` (healthy)
   - `callwave-rabbitmq` (healthy)
   - `callwave-user-management` (healthy)
   - `callwave-video-calls` (healthy)
   - `callwave-background-processes` (running)
   - `callwave-coturn` (running)

5. **Viewing real-time logs**:
   ```bash
   docker compose logs -f video-calls
   ```

6. **Updating the backend after git changes**:
   ```bash
   git pull
   docker compose build video-calls
   docker compose up -d video-calls
   ```

---

## 5. Client Build Guide (Android APK & Windows Desktop)

All builds are generated from the `videocall/` directory.

### Prerequisites:
- **Flutter SDK** (v3.29.0 or higher): Run `flutter doctor` to ensure all checks pass.
- **Android SDK & NDK**: For building Android APK.
- **Visual Studio 2022**: With **"Desktop development with C++"** workload installed (for Windows builds).

---

### 5.1 Building the Android Release APK

1. Navigate to the client folder:
   ```bash
   cd videocall
   ```

2. Fetch dependencies:
   ```bash
   flutter pub get
   ```

3. Build the release APK:
   ```bash
   flutter build apk --release
   ```
   *(Optional: override server IP without editing files)*:
   ```bash
   flutter build apk --release --dart-define=SERVER_IP=144.91.89.100
   ```

4. **Output Location**:
   The generated APK will be at:
   ```
   videocall/build/app/outputs/flutter-apk/app-release.apk
   ```

---

### 5.2 Building the Windows Desktop Release

1. Ensure the Windows app is not currently running (check Task Manager for `videocall.exe`).

2. Run the build command:
   ```bash
   flutter build windows --release
   ```
   *(Optional: override server IP without editing files)*:
   ```bash
   flutter build windows --release --dart-define=SERVER_IP=144.91.89.100
   ```

3. **Output Location**:
   The portable executable and required runtime DLLs are placed in:
   ```
   videocall/build/windows/x64/runner/Release/
   ```

4. **Packaging for Distribution**:
   Compress all files inside the `Release` folder into a zip file:
   - On Windows PowerShell:
     ```powershell
     Compress-Archive -Path "videocall\build\windows\x64\runner\Release\*" -DestinationPath "CallWave-Windows-x64.zip" -Force
     ```

---

## 6. Website Management & Download Link Updates

The public website allows users to download the latest builds of CallWave.

### 6.1 Uploading Builds to Cloud Storage
Because mobile APKs (~95 MB) and Windows ZIPs (~250 MB) are large, host them on Google Drive, AWS S3, or a cloud bucket.
1. Upload your new `app-release.apk` and `CallWave-Windows-x64.zip` to Google Drive.
2. Set share settings to: **"Anyone with the link can view"**.
3. Copy the sharing links:
   - Format: `https://drive.google.com/file/d/<FILE_ID>/view?usp=sharing`

### 6.2 Updating Download Links in the Website

Open `website/src/App.jsx` and replace the URLs:

1. **Hero section buttons** (around lines 132 & 144):
   ```jsx
   <a href="NEW_APK_LINK" target="_blank" rel="noreferrer" className="platform-store-badge android-badge">
   <a href="NEW_WINDOWS_LINK" target="_blank" rel="noreferrer" className="platform-store-badge windows-badge">
   ```

2. **Downloads cards** (around lines 373 & 433):
   ```jsx
   <a href="NEW_APK_LINK" target="_blank" rel="noreferrer" className="btn-download-main btn-green">
   <a href="NEW_WINDOWS_LINK" target="_blank" rel="noreferrer" className="btn-download-main btn-amber">
   ```

3. **Footer links** (around lines 660 & 661):
   ```jsx
   <a href="NEW_APK_LINK" target="_blank" rel="noreferrer">Android APK (v1.0)</a>
   <a href="NEW_WINDOWS_LINK" target="_blank" rel="noreferrer">Windows Desktop (x64)</a>
   ```

4. **Installation guide modal** (around lines 744 & 793):
   ```jsx
   <a href="NEW_APK_LINK" target="_blank" rel="noreferrer" className="btn-download-main btn-green">
   <a href="NEW_WINDOWS_LINK" target="_blank" rel="noreferrer" className="btn-download-main btn-amber">
   ```

### 6.3 Building and Deploying the Website

1. Navigate to the website directory:
   ```bash
   cd website
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Compile production bundle:
   ```bash
   npm run build
   ```
   Output is generated in `website/dist/`.

4. **Hosting Options**:
   - **Nginx on VPS**: Point your Nginx `root` directive to `/path/to/REALTIME-VIDEO-CALL/website/dist`.
   - **Vercel / Netlify**: Connect the GitHub repository and set the root directory to `website`.

---

## 7. Firewall & Port Reference

Ensure the following inbound ports are open on your VPS firewall (e.g. `ufw` or cloud security group):

| Port / Protocol | Service | Description |
|---|---|---|
| **3000 / TCP** | User Management API | REST endpoints (Login, Register, Contacts) |
| **3001 / TCP** | Audio Calls Service | WebSocket signaling for audio |
| **3002 / TCP** | Video Calls Service | Socket.io signaling & Mediasoup control |
| **3478 / UDP & TCP** | CoTURN Server | STUN and TURN listening port |
| **40000–40099 / UDP** | Mediasoup Media | RTC media traffic for SFU video/audio streams |
| **49152–49252 / UDP** | CoTURN Relay | TURN media relay ports for symmetric NAT traversal |

To open these on Ubuntu UFW:
```bash
sudo ufw allow 3000:3002/tcp
sudo ufw allow 3478/tcp
sudo ufw allow 3478/udp
sudo ufw allow 40000:40099/udp
sudo ufw allow 49152:49252/udp
sudo ufw reload
```

---

## 8. Troubleshooting & Verification

### Common Issues & Solutions

1. **Call rings on both devices, but media (video/audio) does not stream**:
   - Verify `callwave-coturn` is running (`docker compose ps`).
   - Check that UDP ports `3478` and `49152–49252` are open in your VPS firewall.
   - Confirm `ANNOUNCED_IP` in `docker-compose.yml` matches your public server IP, not `127.0.0.1`.

2. **App shows "Connection Failed" or cannot reach server**:
   - Verify `api_config.dart` has the correct `_configuredHost` IP.
   - Test backend health in your browser: `http://YOUR_SERVER_PUBLIC_IP:3000/health` and `http://YOUR_SERVER_PUBLIC_IP:3002/health`.

3. **Android app does not receive calls when locked**:
   - Ensure the user granted **Microphone**, **Camera**, and **Notifications** permissions on first launch.
   - Disable battery optimization for CallWave in Android Settings.

4. **Windows build fails with "Visual Studio toolchain not found"**:
   - Open Visual Studio Installer, click *Modify*, and ensure *Desktop development with C++* is checked.
