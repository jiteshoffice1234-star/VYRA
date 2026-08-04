/// Collection helpers that fill small gaps in the standard library.
extension FirstWhereOrNullX<T> on Iterable<T> {
  /// Returns the first element matching [test], or `null` when none match.
  T? firstWhereOrNull(bool Function(T element) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
