import 'dart:math';

/// Code de réservation (ticket QR) : `GF-XXXX-XXXX`.
///
/// Tiré avec [Random.secure] dans un alphabet de 31 signes sans caractère
/// ambigu (ni 0/O, ni 1/I/L) : 31⁸ ≈ 8,5 × 10¹¹ combinaisons, donc non
/// devinable, et lisible à voix haute ou à recopier à la main.
class BookingCode {
  BookingCode._();

  static const alphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  static final Random _random = Random.secure();
  static final RegExp _format = RegExp('^GF-[$alphabet]{4}-[$alphabet]{4}\$');

  /// Nouveau code, différent de tous ceux de [taken].
  static String generate([Set<String> taken = const {}]) {
    while (true) {
      String part() => List.generate(
        4,
        (_) => alphabet[_random.nextInt(alphabet.length)],
      ).join();
      final code = 'GF-${part()}-${part()}';
      if (!taken.contains(code)) return code;
    }
  }

  static bool isValidFormat(String code) => _format.hasMatch(code);

  /// Saisie manuelle tolérante : espaces, minuscules et tirets manquants
  /// (« gf abcd efgh », « GFABCDEFGH ») ; `null` si ce n'est pas un code.
  static String? normalize(String input) {
    final raw = input.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
    final body = raw.startsWith('GF') ? raw.substring(2) : raw;
    if (body.length != 8) return null;
    final code = 'GF-${body.substring(0, 4)}-${body.substring(4)}';
    return isValidFormat(code) ? code : null;
  }
}
