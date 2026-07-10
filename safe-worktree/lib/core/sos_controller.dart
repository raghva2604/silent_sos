// DELETED: file removed per user request on 2026-01-06
// Minimal stub remains so imports do not fail.

class SosController {
  static final SosController instance = SosController._();
  SosController._();

  int? getRemaining() => null;
  bool get isActive => false;
  void start({required int seconds, required void Function() onSend}) {}
  void stop() {}
  void dispose() {}
}
