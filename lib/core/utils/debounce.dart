import 'dart:async';

/// Debounces rapid value changes (e.g. search-as-you-type) so expensive
/// filtering work only runs after the user pauses typing.
class Debouncer {
  Debouncer({this.delay = const Duration(milliseconds: 150)});

  final Duration delay;
  Timer? _timer;

  /// Schedules [action]; a prior pending action is cancelled.
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Runs [action] immediately, cancelling any pending one.
  void flush(VoidCallback action) {
    _timer?.cancel();
    action();
  }

  void cancel() => _timer?.cancel();

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
