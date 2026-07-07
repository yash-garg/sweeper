/// Base class for all errors sweeper reports to the user.
///
/// `bin/sweeper.dart` catches this type, prints [message] to stderr, and
/// exits with code 2. Library code must never print or exit itself.
abstract class SweeperException implements Exception {
  SweeperException(this.message);

  final String message;

  @override
  String toString() => message;
}
