# livegreen

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Build flags and environment defines

For production builds you should provide the Razorpay public key at build time
instead of relying on a fallback in code. Use `--dart-define` when building:

```powershell
# Android release APK
flutter build apk --release --dart-define=RAZORPAY_PUBLIC_KEY=rzp_live_yourkey --dart-define=API_BASE_URL=https://your-api.example.com

# Android AAB for Play Store
flutter build appbundle --release --dart-define=RAZORPAY_PUBLIC_KEY=rzp_live_yourkey --dart-define=API_BASE_URL=https://your-api.example.com

# iOS release
flutter build ios --release --dart-define=RAZORPAY_PUBLIC_KEY=rzp_live_yourkey --dart-define=API_BASE_URL=https://your-api.example.com
```

This populates `String.fromEnvironment('RAZORPAY_PUBLIC_KEY')` used by the app.
If a define is not provided, the app will fallback to a test key for local
development only. Never check real keys into source control.
