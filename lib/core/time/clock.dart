/// Source of "now". The only place in the code base allowed to call
/// the system clock (enforced by tool/check_domain_purity.sh).
abstract interface class Clock {
  /// The current instant, as a UTC [DateTime].
  DateTime nowUtc();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

/// A clock frozen at [fixedUtc] (tests, previews).
class FixedClock implements Clock {
  FixedClock(this.fixedUtc);

  final DateTime fixedUtc;

  @override
  DateTime nowUtc() => fixedUtc.toUtc();
}
