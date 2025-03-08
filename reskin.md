# TSBD App Reskin Guide

This document provides a complete guide on how to customize and rebrand the TSBD app. Follow these steps to create your own version of the app.

## Table of Contents
- [Changing App Name](#changing-app-name)
- [Changing App Icons](#changing-app-icons)
- [Updating App Version](#updating-app-version)
- [Customizing App Colors and Theme](#customizing-app-colors-and-theme)
- [Updating Splash Screen](#updating-splash-screen)
- [Configuring Firebase](#configuring-firebase)
- [Modifying App Content](#modifying-app-content)
- [Updating Package Name](#updating-package-name)
- [Configuring Ad Units](#configuring-ad-units)

## Changing App Name

1. **Android App Name**:
   - Open `android/app/src/main/AndroidManifest.xml`
   - Find the `android:label` attribute in the `application` tag
   - Change it to your desired app name

2. **iOS App Name**:
   - Open `ios/Runner/Info.plist`
   - Find the `CFBundleName` key
   - Change its value to your desired app name

3. **App Title in Flutter**:
   - Open `lib/main.dart`
   - Find the `MaterialApp` widget
   - Update the `title` property to your desired app name

## Changing App Icons

1. **Prepare Your Icon**:
   - Create a square PNG image (preferably 1024x1024 pixels)
   - Place it in `assets/images/app_icon.png` (replacing the existing one)

2. **Generate Icons using flutter_launcher_icons**:
   - The project already has the `flutter_launcher_icons` package configured in `pubspec.yaml`
   - Run the following command to generate all required icon sizes:
   ```bash
   flutter pub get && flutter pub run flutter_launcher_icons
   ```

3. **Manual Icon Customization (if needed)**:
   - **Android**: Replace icons in `android/app/src/main/res/mipmap-*/`
   - **iOS**: Replace icons in `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

4. **Adaptive Icon Background (Android)**:
   - To change the background color of the adaptive icon, update the `adaptive_icon_background` value in the `flutter_launcher_icons` section of `pubspec.yaml`

## Updating App Version

1. **Update Version in pubspec.yaml**:
   - Open `pubspec.yaml`
   - Find the `version` field (currently `1.0.0+1`)
   - Change it to your desired version using the format `x.y.z+n`, where:
     - `x.y.z` is the version name (displayed to users)
     - `n` is the version code (used internally for updates)
   - Example: `2.0.0+10`

2. **Update Version in About Screen**:
   - Open `lib/screens/settings.dart`
   - Find the version display in the About section
   - Update the hardcoded version or modify it to read from the package info

## Customizing App Colors and Theme

1. **Update Theme Colors**:
   - Open `lib/main.dart`
   - Find the `ThemeData` creation
   - Update the color scheme to match your branding:
     - `primary`: Main brand color
     - `secondary`: Accent color
     - `surface`: Background color for cards
     - `background`: Background color for screens

2. **Dark Theme Customization**:
   - Find the dark theme configuration and update it similarly

## Updating Splash Screen

1. **Android Splash Screen**:
   - Open `android/app/src/main/res/drawable/launch_background.xml`
   - Modify to add your custom splash image or background

2. **iOS Splash Screen**:
   - Update `ios/Runner/Assets.xcassets/LaunchImage.imageset/`
   - Replace the images with your own launch images

## Configuring Firebase

1. **Create Your Firebase Project**:
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Create a new project or use an existing one

2. **Add Applications**:
   - Add Android and iOS applications with the correct package names

3. **Download Configuration Files**:
   - For Android: Download `google-services.json` and place it in `android/app/`
   - For iOS: Download `GoogleService-Info.plist` and place it in `ios/Runner/`

4. **Update Firebase Dependencies**:
   - Ensure the Firebase dependencies in `pubspec.yaml` are up to date

## Modifying App Content

1. **Update Default Content**:
   - Modify `assets/games_data.json` if you're using static data
   - Update Firestore collections if you're using Firebase

2. **Change App Messaging**:
   - Update strings throughout the app in various screens

## Updating Package Name

1. **Android Package Name**:
   - Open `android/app/build.gradle`
   - Find the `applicationId` and change it to your desired package name (e.g., `com.yourcompany.appname`)
   - Update the package references in:
     - `android/app/src/main/AndroidManifest.xml`
     - `android/app/src/debug/AndroidManifest.xml`
     - `android/app/src/profile/AndroidManifest.xml`
     - All files in the `android/app/src/main/kotlin/` directory

2. **iOS Bundle ID**:
   - Open Xcode
   - Update the Bundle Identifier in project settings

## Configuring Ad Units

1. **AdMob Configuration**:
   - Open `android/app/src/main/AndroidManifest.xml`
   - Find the meta-data tag for AdMob app ID and update it
   - Update AdMob unit IDs in the code where they are used

2. **Code Updates**:
   - Update ad unit IDs in `lib/widgets/banner_ad_widget.dart`
   - Make sure ad initialization is updated in the main app startup

## Final Steps

1. **Clean Build**:
   ```bash
   flutter clean
   flutter pub get
   ```

2. **Test Your App**:
   - Test the app thoroughly on both Android and iOS devices
   - Verify all customizations appear correctly

3. **Build Release Versions**:
   ```bash
   flutter build apk --release  # For Android
   flutter build ios --release  # For iOS
   ```

With these steps, you can completely customize the TSBD app to match your branding and requirements. 