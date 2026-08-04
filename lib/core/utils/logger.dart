import 'package:flutter/foundation.dart';

/// Minimal structured logger for VYRA.
///
/// Every message is prefixed with `[VYRA]` and a severity tag so logs are
/// greppable. Debug / info / perf messages are only printed in debug builds;
/// warnings and errors are always surfaced so issues never go silent in
/// release. A future remote sink (e.g. crash reporting) can be plugged in
/// here without touching any call site.
class AppLogger {
  AppLogger._();

  static void debug(String message) {
    if (kDebugMode) debugPrint('[VYRA][debug] $message');
  }

  static void info(String message) {
    if (kDebugMode) debugPrint('[VYRA][info] $message');
  }

  static void warn(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('[VYRA][warn] $message${error == null ? '' : ' → $error'}');
    if (stackTrace != null && kDebugMode) {
      debugPrint('[VYRA][warn] ${stackTrace.toString().trimRight()}');
    }
  }

  static void error(
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    debugPrint('[VYRA][error] $message${error == null ? '' : ' → $error'}');
    if (stackTrace != null) {
      debugPrint('[VYRA][error] ${stackTrace.toString().trimRight()}');
    }
  }

  static void perf(String message, Stopwatch watch) {
    if (kDebugMode) {
      debugPrint('[VYRA][perf] $message took ${watch.elapsedMilliseconds}ms');
    }
  }
}
