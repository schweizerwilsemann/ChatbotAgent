import 'package:flutter/foundation.dart';

/// Application build flavors.
enum Flavor {
  appDev,
  appDevRelease,
  appProd,
}

/// Holds environment-specific configuration resolved from the build flavor.
class FlavorConfig {
  FlavorConfig._();

  static Flavor _flavor = Flavor.appDev;

  /// The active flavor.
  static Flavor get flavor => _flavor;

  /// Initialize the config with the given flavor. Must be called once
  /// in each entry-point before `runApp()`.
  static void init(Flavor f) {
    _flavor = f;
    debugPrint('=== Flavor: ${f.name} ===');
    debugPrint('=== API URL: $apiBaseUrl ===');
  }

  /// Resolve Flutter's `--flavor` value to the application flavor config.
  static Flavor resolveFlavor(String? flavorName) {
    switch (flavorName) {
      case 'appDev':
      case null:
        return Flavor.appDev;
      case 'appDevRelease':
        return Flavor.appDevRelease;
      case 'appProd':
        return Flavor.appProd;
      default:
        throw UnsupportedError('Unsupported flavor: $flavorName');
    }
  }

  /// Base URL for the backend API.
  static String get apiBaseUrl {
    switch (_flavor) {
      case Flavor.appDev:
      case Flavor.appDevRelease:
        // 10.0.2.2 = Android emulator -> host localhost
        // For physical device, replace with your PC's local IP.
        return 'http://10.0.2.2:8000';
      case Flavor.appProd:
        return 'https://api.sportsvenue.example.com';
    }
  }

  /// Display name shown in the app bar / launcher.
  static String get appName {
    switch (_flavor) {
      case Flavor.appDev:
        return 'Sports Venue [DEV]';
      case Flavor.appDevRelease:
        return 'Sports Venue [DEV RELEASE]';
      case Flavor.appProd:
        return 'Sports Venue';
    }
  }

  /// Whether to show Flutter's debug banner.
  static bool get showDebugBanner {
    switch (_flavor) {
      case Flavor.appDev:
      case Flavor.appDevRelease:
      case Flavor.appProd:
        return false;
    }
  }

  /// Whether verbose network / agent logging is enabled.
  static bool get enableVerboseLogging {
    switch (_flavor) {
      case Flavor.appDev:
        return true;
      case Flavor.appDevRelease:
      case Flavor.appProd:
        return false;
    }
  }
}
