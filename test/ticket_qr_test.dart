import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/config.dart';
import 'package:gymflow/core/ticket_qr.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  String sample() => TicketQr.text(
    code: 'GF-ZD4R-QWD6',
    courseTitle: 'Pilates express (démo)',
    start: DateTime(2026, 10, 20, 0, 30),
    end: DateTime(2026, 10, 20, 1, 30),
    coachName: 'Amira Trabelsi',
    room: 'Studio Zen',
  );

  group('Contenu du QR', () {
    test('texte lisible et utile, au format demandé', () {
      expect(
        sample(),
        'GymFlow – Réservation GF-ZD4R-QWD6\n'
        'Cours : Pilates express (démo)\n'
        'Date : mar. 20 oct. 2026, 00:30–01:30\n'
        'Coach : Amira Trabelsi – Studio Zen\n'
        'Présentez ce code au coach.',
      );
    });

    test('URL du QR : 300x300, encodée, accents conservés', () {
      final url = Uri.parse(AppConfig.qrImageUrl(sample()));
      expect(url.host, 'api.qrserver.com');
      expect(url.queryParameters['size'], '300x300');
      expect(url.queryParameters['data'], sample());
      expect(AppConfig.qrImageUrl(sample()), contains('R%C3%A9servation'));
      expect(AppConfig.qrImageUrl(sample()), isNot(contains(' ')));
      expect(AppConfig.qrImageUrl(sample()), isNot(contains('\n')));
    });
  });

  group('Extraction du code', () {
    test('code seul, minuscules, espaces, sans tirets', () {
      expect(TicketQr.extractCode('GF-ZD4R-QWD6'), 'GF-ZD4R-QWD6');
      expect(TicketQr.extractCode('  gf-zd4r-qwd6 '), 'GF-ZD4R-QWD6');
      expect(TicketQr.extractCode('gfzd4rqwd6'), 'GF-ZD4R-QWD6');
    });

    test('texte complet du QR collé (avec ou sans retours à la ligne)', () {
      expect(TicketQr.extractCode(sample()), 'GF-ZD4R-QWD6');
      expect(TicketQr.extractCode(sample().toLowerCase()), 'GF-ZD4R-QWD6');
      // Champ d'une ligne : les retours à la ligne disparaissent au collage.
      expect(
        TicketQr.extractCode(sample().replaceAll('\n', '')),
        'GF-ZD4R-QWD6',
      );
    });

    test('aucun code valide : null', () {
      expect(TicketQr.extractCode('Bonjour coach'), isNull);
      expect(TicketQr.extractCode('GymFlow – Réservation'), isNull);
      // Caractères exclus de l'alphabet (0, O, 1, I, L).
      expect(TicketQr.extractCode('GF-0OIL-1234'), isNull);
    });
  });
}
