import 'package:flutter/foundation.dart';

/// Immutable snapshot of startup initialization results.
class BootstrapStatus {
  final bool firebaseInitialized;
  final bool crashlyticsConfigured;
  final bool notificationServiceInitialized;
  final bool settingsServiceInitialized;
  final bool streakServiceInitialized;
  final bool adServiceInitialized;
  final String? firebaseError;

  const BootstrapStatus({
    required this.firebaseInitialized,
    required this.crashlyticsConfigured,
    required this.notificationServiceInitialized,
    required this.settingsServiceInitialized,
    required this.streakServiceInitialized,
    required this.adServiceInitialized,
    this.firebaseError,
  });

  const BootstrapStatus.initial()
    : firebaseInitialized = false,
      crashlyticsConfigured = false,
      notificationServiceInitialized = false,
      settingsServiceInitialized = false,
      streakServiceInitialized = false,
      adServiceInitialized = false,
      firebaseError = null;

  BootstrapStatus copyWith({
    bool? firebaseInitialized,
    bool? crashlyticsConfigured,
    bool? notificationServiceInitialized,
    bool? settingsServiceInitialized,
    bool? streakServiceInitialized,
    bool? adServiceInitialized,
    String? firebaseError,
  }) {
    return BootstrapStatus(
      firebaseInitialized: firebaseInitialized ?? this.firebaseInitialized,
      crashlyticsConfigured:
          crashlyticsConfigured ?? this.crashlyticsConfigured,
      notificationServiceInitialized:
          notificationServiceInitialized ?? this.notificationServiceInitialized,
      settingsServiceInitialized:
          settingsServiceInitialized ?? this.settingsServiceInitialized,
      streakServiceInitialized:
          streakServiceInitialized ?? this.streakServiceInitialized,
      adServiceInitialized: adServiceInitialized ?? this.adServiceInitialized,
      firebaseError: firebaseError ?? this.firebaseError,
    );
  }

  bool get cloudAvailable => firebaseInitialized;
}

/// In-memory runtime flags used by services to gracefully degrade in local mode.
class AppRuntimeState extends ChangeNotifier {
  static final AppRuntimeState instance = AppRuntimeState._internal();
  AppRuntimeState._internal();

  BootstrapStatus _bootstrapStatus = const BootstrapStatus.initial();

  BootstrapStatus get bootstrapStatus => _bootstrapStatus;
  bool get cloudAvailable => _bootstrapStatus.cloudAvailable;

  void updateBootstrapStatus(BootstrapStatus status) {
    _bootstrapStatus = status;
    debugPrint(
      '📌 BootstrapStatus: firebase=${status.firebaseInitialized}, '
      'notifications=${status.notificationServiceInitialized}, '
      'settings=${status.settingsServiceInitialized}, '
      'streak=${status.streakServiceInitialized}, ads=${status.adServiceInitialized}',
    );
    notifyListeners();
  }
}
