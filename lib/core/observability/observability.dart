import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../config/app_config.dart';

/// Centralizes crash/error reporting so the rest of the app never imports
/// Sentry directly. When no DSN is configured (`SENTRY_DSN` empty), reporting
/// is a no-op and the app runs exactly as before — Sentry is opt-in per build.
class Observability {
  Observability._();

  /// Runs [appRunner] inside a Sentry zone when enabled, or directly otherwise.
  /// Uncaught Flutter/Dart errors are captured automatically by the SDK.
  static Future<void> run(FutureOr<void> Function() appRunner) async {
    if (!AppConfig.isSentryEnabled) {
      await appRunner();
      return;
    }

    await SentryFlutter.init(
      (options) {
        options.dsn = AppConfig.sentryDsn;
        options.environment = AppConfig.environmentName;
        // Sample a fraction of transactions in production; everything in dev.
        options.tracesSampleRate = kReleaseMode ? 0.2 : 1.0;
        // Never ship user PII to the error backend.
        options.sendDefaultPii = false;
      },
      appRunner: () => appRunner(),
    );
  }

  /// Reports a handled error with optional context, without crashing the app.
  static Future<void> captureError(
    Object error,
    StackTrace stackTrace, {
    String? hint,
  }) async {
    if (!AppConfig.isSentryEnabled) {
      debugPrint('Observability (disabled) — $hint: $error');
      return;
    }
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      hint: hint == null ? null : Hint.withMap({'context': hint}),
    );
  }

  /// Associates the current signed-in user with subsequent events (id only,
  /// no email/PII). Pass null on sign-out to clear it.
  static Future<void> setUser(String? userId) async {
    if (!AppConfig.isSentryEnabled) return;
    await Sentry.configureScope(
      (scope) => scope.setUser(userId == null ? null : SentryUser(id: userId)),
    );
  }
}
