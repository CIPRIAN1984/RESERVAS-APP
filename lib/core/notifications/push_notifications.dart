import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../observability/observability.dart';
import '../supabase/supabase_client.dart';

/// Registers the device's FCM token with the backend so it can receive push
/// notifications, and keeps it fresh on rotation. Entirely gated behind
/// [AppConfig.pushEnabled]: when push isn't configured for the build (no
/// Firebase config files), every method is a safe no-op and Firebase is never
/// touched — the app runs identically without it.
class PushNotifications {
  PushNotifications._();

  static bool _initialized = false;

  /// Initializes Firebase once. Safe to call before there's a signed-in user;
  /// the token is only persisted later, in [registerForUser].
  static Future<void> ensureInitialized() async {
    if (!AppConfig.pushEnabled || _initialized) return;
    try {
      await Firebase.initializeApp();
      await FirebaseMessaging.instance.requestPermission();
      _initialized = true;
    } catch (error, stack) {
      // Never let a misconfigured Firebase break app startup.
      await Observability.captureError(error, stack, hint: 'Firebase.initializeApp');
    }
  }

  /// Persists the current device token for the signed-in user and subscribes
  /// to refreshes. Call after sign-in (the RPC uses auth.uid()).
  static Future<void> registerForUser() async {
    if (!AppConfig.pushEnabled) return;
    await ensureInitialized();
    if (!_initialized) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _save(token);
      FirebaseMessaging.instance.onTokenRefresh.listen(_save);
    } catch (error, stack) {
      await Observability.captureError(error, stack, hint: 'registerForUser');
    }
  }

  static Future<void> _save(String token) async {
    try {
      await AppSupabase.client.rpc('registrar_device_token', params: {
        'p_token': token,
        'p_platform': _platform(),
      });
    } catch (error, stack) {
      await Observability.captureError(error, stack, hint: 'registrar_device_token');
    }
  }

  static String _platform() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    return 'android';
  }
}
