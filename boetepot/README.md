# boetepot

A new Flutter project.

## App icon (iOS + Android)

De app-icoon die je op je telefoon ziet (en die meegaat in je iOS Archive / Android AAB) komt uit:
- iOS: `boetepot/ios/Runner/Assets.xcassets/AppIcon.appiconset`
- Android: `boetepot/android/app/src/main/res/mipmap-*` (en eventueel adaptive icon in `mipmap-anydpi-v26`)

In dit project is `flutter_launcher_icons` toegevoegd zodat je met 1 commando beide platformen kunt genereren.

1) Zet je 1024×1024 PNG op: `boetepot/assets/images/app_icon.png`
2) Run:
   - `cd boetepot`
   - `flutter pub get`
   - `dart run flutter_launcher_icons`

Daarna opnieuw build/archiven voor App Store Connect / Play Console.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
