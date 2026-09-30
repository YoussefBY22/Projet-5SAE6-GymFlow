import 'backend.dart';

/// Garde la promesse d'initialisation pour que le splash puisse l'attendre.
class BackendBootstrap {
  BackendBootstrap._();
  static Future<Backend>? _future;

  static void start(Future<Backend> Function() init) => _future = init();

  static Future<Backend> get ready {
    final f = _future;
    if (f != null) return f;
    if (Backend.isReady) return Future.value(Backend.I);
    throw StateError('Backend non démarré');
  }
}
