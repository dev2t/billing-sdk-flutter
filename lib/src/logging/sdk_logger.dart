import 'dart:developer' as developer;

/// Internal SDK logger. Uses [developer.log] so logs appear in DevTools and console
/// with level filtering. Name is [BillingSdk] for easy filtering.
class BillingSdkLogger {
  BillingSdkLogger._();

  static const String _name = 'BillingSdk';

  /// Informational (e.g. config applied, operation started).
  static void info(String message, [Object? detail]) {
    final text = detail != null ? '$message $detail' : message;
    developer.log(text, name: _name, level: 500);
  }

  /// Success outcome (e.g. token verified, sync succeeded).
  static void success(String message, [Object? detail]) {
    final text = detail != null ? '$message $detail' : message;
    developer.log(text, name: _name, level: 400);
  }

  /// Warning (e.g. fallback used, recoverable issue).
  static void warning(String message, [Object? detail]) {
    final text = detail != null ? '$message $detail' : message;
    developer.log(text, name: _name, level: 900);
  }

  /// Error / failure (e.g. invalid signature, network failure).
  static void error(String message, [Object? detail]) {
    final text = detail != null ? '$message $detail' : message;
    developer.log(text, name: _name, level: 1000);
  }
}
