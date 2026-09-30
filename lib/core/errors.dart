/// Exceptions métier de GymFlow. Tous les messages sont en français et
/// peuvent être affichés tels quels à l'utilisateur.
class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Action refusée pour le rôle de l'utilisateur courant.
class PermissionDeniedException extends AppException {
  const PermissionDeniedException([
    super.message = "Vous n'avez pas les droits pour cette action.",
  ]);
}

/// Aucun utilisateur connecté.
class NotAuthenticatedException extends AppException {
  const NotAuthenticatedException([
    super.message = 'Votre session a expiré. Reconnectez-vous.',
  ]);
}

/// Donnée saisie invalide.
class ValidationException extends AppException {
  const ValidationException(super.message);
}

/// Règle métier non respectée (cours complet, stock insuffisant…).
class BusinessRuleException extends AppException {
  const BusinessRuleException(super.message);
}

/// Élément introuvable.
class NotFoundException extends AppException {
  const NotFoundException([super.message = 'Élément introuvable.']);
}

/// Erreur réseau ou hors-ligne.
class NetworkException extends AppException {
  const NetworkException([
    super.message =
        'Connexion impossible. Vérifiez votre accès à Internet puis réessayez.',
  ]);
}

/// Transforme n'importe quelle erreur en message lisible.
String friendlyError(Object error) {
  if (error is AppException) return error.message;
  return 'Une erreur inattendue est survenue. Réessayez.';
}
