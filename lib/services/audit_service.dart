import '../models/misc.dart';
import '../repositories/repository.dart';
import 'backend.dart';

/// Journal d'audit des actions sensibles (activation, suppression, rôles…).
class AuditService {
  AuditService(this._b);
  final Backend _b;

  Future<void> log(String action, String details, {String? targetId}) async {
    final actor = _b.auth.currentUser;
    await _b.auditRepo.save(
      AuditEntry(
        id: IdGen.next('a_'),
        actorId: actor?.id ?? 'system',
        actorName: actor?.fullName ?? 'Système',
        action: action,
        details: details,
        targetId: targetId,
        createdAt: _b.now(),
      ),
    );
  }

  /// Réservé au super admin.
  List<AuditEntry> entries() {
    _b.requireRole(Backend.adminOnly);
    return _b.auditRepo.all.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}
