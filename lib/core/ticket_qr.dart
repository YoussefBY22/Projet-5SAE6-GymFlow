import 'package:intl/intl.dart';

import 'booking_code.dart';

/// Contenu du QR d'un ticket : un texte lisible par n'importe quel appareil
/// photo (et non un code seul, qu'un téléphone prend pour une recherche
/// web), qui contient le code de réservation.
///
/// Volontairement **sans** nom ni email de l'abonné : le service qui
/// dessine le QR (api.qrserver.com) voit passer ce texte.
class TicketQr {
  TicketQr._();

  static String text({
    required String code,
    required String courseTitle,
    required DateTime? start,
    required DateTime? end,
    required String coachName,
    required String room,
  }) {
    final when = start == null
        ? 'à planifier'
        : '${DateFormat('EEE d MMM y', 'fr_FR').format(start)}, '
              '${DateFormat('HH:mm', 'fr_FR').format(start)}'
              '${end == null ? '' : '–${DateFormat('HH:mm', 'fr_FR').format(end)}'}';
    return [
      'GymFlow – Réservation $code',
      'Cours : $courseTitle',
      'Date : $when',
      'Coach : $coachName – $room',
      'Présentez ce code au coach.',
    ].join('\n');
  }

  // Pas de \b final : coller le texte dans un champ d'une seule ligne
  // supprime les retours à la ligne (« …QWD6Cours : … »).
  static final RegExp _code = RegExp(
    r'\bGF[\s\-–]?([A-Z0-9]{4})[\s\-–]?([A-Z0-9]{4})',
    caseSensitive: false,
  );

  /// Code `GF-XXXX-XXXX` trouvé dans une saisie : code seul (tolérant aux
  /// minuscules, espaces et tirets) ou texte complet du QR collé.
  /// `null` si aucun code valide n'y figure.
  static String? extractCode(String input) {
    final direct = BookingCode.normalize(input);
    if (direct != null) return direct;
    for (final m in _code.allMatches(input)) {
      final code =
          'GF-${m.group(1)!.toUpperCase()}-${m.group(2)!.toUpperCase()}';
      if (BookingCode.isValidFormat(code)) return code;
    }
    return null;
  }
}
