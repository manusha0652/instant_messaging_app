# ChatLink - Secure Instant Messaging App

A Flutter-based secure instant messaging application that uses QR codes for peer discovery and connection.

## Features

### 🔐 Security
- **Biometric Authentication**: Use fingerprint to unlock the app
- **PIN Protection**: 4-6 digit PIN for secure access
- **Local Storage**: All data stored securely on device using SQLite
- **No Cloud Dependency**: Complete privacy with local-only data

### 📱 Core Functionality
- **QR Code Connection**: Connect instantly by scanning QR codes
- **Tab-Based Navigation**: Home, Scan, Chats, and Profile tabs
- **Real-time Messaging**: Send and receive messages in temporary sessions
- **Chat History**: Save and manage chat sessions
- **User Profiles**: Customizable user profiles with avatars

### 🎨 User Interface
- **Material Design 3**: Modern and intuitive interface
- **Dark/Light Theme**: Automatic theme switching based on system
- **Smooth Animations**: Polished user experience with fluid transitions
- **Responsive Design**: Optimized for various screen sizes

## Technical Stack

| Component | Technology |
|-----------|------------|
| Framework | Flutter (Dart) |
| Database | SQLite |
| QR Codes | `qr_flutter`, `qr_code_scanner` |
| Authentication | `local_auth` (Biometric), SHA256 PIN hashing |
| Storage | `flutter_secure_storage`, `shared_preferences` |
| Target OS | Android 9+ (API 28+) |

## Getting Started

### Prerequisites
- Flutter SDK (3.10.0 or higher)
- Dart SDK (3.0.0 or higher)
- Android Studio / VS Code
- Android device or emulator (API 28+)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd instant_messaging_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

**ChatLink** - *Secure, private, and instant messaging!*
