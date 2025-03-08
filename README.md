<<<<<<< HEAD
# tsbd_Admin
=======
# TSBD App Store

A Flutter application for browsing, downloading, and managing Android applications. The app features a modern UI with dark mode support, download management, and integration with Firebase for data storage.

## Features

- Browse and search through a collection of Android applications
- Download applications with progress tracking
- Manage downloads efficiently
- Install applications directly from the app
- Dark and light theme support
- Multi-language support (English and Bangla)
- Download notifications
- Auto-reload functionality
- Customizable download location
- Telegram support channel

## Prerequisites

- Flutter SDK (latest version)
- Android Studio / VS Code
- Firebase project with Realtime Database
- Android device or emulator

## Setup

1. Clone the repository:
```bash
git clone https://github.com/yourusername/tsbd_app.git
cd tsbd_app
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure Firebase:
   - Create a new Firebase project
   - Enable Realtime Database
   - Add your Android app to the project
   - Download and place the `google-services.json` file in the `android/app` directory
   - Update the Firebase configuration in `lib/main.dart` with your project details

4. Run the app:
```bash
flutter run
```

## Firebase Configuration

Update the following in `lib/main.dart`:
```dart
FirebaseOptions(
  apiKey: 'your-api-key',
  appId: 'your-app-id',
  messagingSenderId: 'your-sender-id',
  projectId: 'your-project-id',
  databaseURL: 'your-database-url',
)
```

## Project Structure

```
lib/
  ├── main.dart              # App entry point
  ├── screens/
  │   ├── splash.dart        # Splash screen
  │   ├── home.dart          # Main home screen
  │   ├── downloader.dart    # Download screen
  │   ├── downloads.dart     # Downloads management screen
  │   ├── info.dart          # Information screen
  │   └── settings.dart      # Settings screen
  └── models/
      └── game_file.dart     # Game file model
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support, join our Telegram channel: [RS Support Team](https://t.me/RSsupportteam)
>>>>>>> e47170f (Initial commit)
