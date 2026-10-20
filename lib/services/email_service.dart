import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../core/config.dart';
import '../core/email_config.dart';
import '../core/errors.dart';
import '../models/course.dart';
import '../models/enums.dart';
import 'backend.dart';

/// Fournisseur d'envoi de l'email de confirmation.
enum EmailProvider {
  formSubmit('FormSubmit'),
  emailJs('EmailJS');

  const EmailProvider(this.label);
  final String label;
}

/// Résultat d'une tentative d'envoi : `error == null` = email parti.
typedef EmailAttempt = ({String? error, bool retry});

/// Email de confirmation de réservation.
///
/// Fournisseur par défaut : **FormSubmit** (configuration commitée dans
/// `EmailConfig`, aucune clé : fonctionne sans `secrets.json`). EmailJS est
/// utilisé à la place si ses trois clés sont présentes dans `secrets.json`.
/// L'envoi se fait en arrière-plan ; il ne lève jamais d'erreur et ne
/// bloque jamais la réservation. Le résultat (envoyé, échec, non
/// configuré) est enregistré dans la réservation, sans aucune clé.
class EmailService {
  EmailService(
    this._b, {
    String? serviceId,
    String? templateId,
    String? publicKey,
    String? demoRecipient,
  }) : serviceId = serviceId ?? AppConfig.emailJsServiceId,
       templateId = templateId ?? AppConfig.emailJsTemplateId,
       publicKey = publicKey ?? AppConfig.emailJsPublicKey,
       demoRecipient = demoRecipient ?? AppConfig.emailJsDemoRecipient;

  final Backend _b;

  /// Clés EmailJS facultatives, lues dans `secrets.json` (remplaçables
  /// dans les tests).
  String serviceId;
  String templateId;
  String publicKey;
  String demoRecipient;

  /// FormSubmit : destinataire fixe (configuration commitée).
  String formSubmitRecipient = EmailConfig.formSubmitRecipient;
  List<String> activatedOrigins = EmailConfig.activatedOrigins;

  /// Origine de la page web (`null` hors web : Android, tests).
  String? webOrigin = kIsWeb ? Uri.base.origin : null;

  /// Pause avant l'unique nouvel essai (nulle dans les tests).
  Duration retryDelay = const Duration(seconds: 1);

  bool get emailJsConfigured =>
      serviceId.trim().isNotEmpty &&
      templateId.trim().isNotEmpty &&
      publicKey.trim().isNotEmpty;

  /// EmailJS si ses clés sont présentes, sinon FormSubmit.
  EmailProvider get provider =>
      emailJsConfigured ? EmailProvider.emailJs : EmailProvider.formSubmit;

  bool get configured =>
      emailJsConfigured || formSubmitRecipient.trim().isNotEmpty;

  final Map<String, Future<EmailDelivery?>> _pending = {};

  /// Un envoi est-il en cours pour cette réservation ?
  bool isSending(String reservationId) => _pending.containsKey(reservationId);

  /// Envoi en cours (l'interface l'attend pour afficher le résultat).
  Future<EmailDelivery?>? pendingFor(String reservationId) =>
      _pending[reservationId];

  /// Dernier envoi lancé en arrière-plan (attendu dans les tests).
  Future<EmailDelivery?>? lastSend;

  /// Lance l'envoi sans l'attendre (appelé après une confirmation).
  void sendInBackground(String reservationId) {
    lastSend = _sendOnce(reservationId);
  }

  /// « Renvoyer l'email » : auteur de la réservation, coach du cours ou
  /// admin ; au plus une fois par minute (contrôle fait ici).
  Future<EmailDelivery?> resend(String reservationId) async {
    final me = _b.requireUser();
    final r =
        _b.reservations.byId(reservationId) ??
        (throw const NotFoundException());
    final c = _b.courses.byId(r.courseId) ?? (throw const NotFoundException());
    if (r.userId != me.id && !_b.courseService.canManage(me, c)) {
      throw const PermissionDeniedException();
    }
    if (r.status != ReservationStatus.confirmed) {
      throw const BusinessRuleException(
        'Seule une place confirmée reçoit un email de confirmation.',
      );
    }
    if (isSending(reservationId)) {
      throw const BusinessRuleException('Envoi déjà en cours.');
    }
    final last = r.email?.attemptedAt;
    if (last != null) {
      final wait = AppConfig.emailResendDelay - _b.now().difference(last);
      if (wait > Duration.zero) {
        throw BusinessRuleException(
          'Patientez encore ${wait.inSeconds + 1} s avant de renvoyer '
          'l\'email.',
        );
      }
    }
    return _sendOnce(reservationId);
  }

  Future<EmailDelivery?> _sendOnce(String reservationId) {
    final running = _pending[reservationId];
    if (running != null) return running;
    final f = _send(reservationId).whenComplete(() {
      _pending.remove(reservationId);
      _b.bus.emit();
    });
    _pending[reservationId] = f;
    _b.bus.emit();
    return f;
  }

  Future<EmailDelivery?> _send(String reservationId) async {
    try {
      final r = _b.reservations.byId(reservationId);
      final c = r == null ? null : _b.courses.byId(r.courseId);
      final user = r == null ? null : _b.users.byId(r.userId);
      if (r == null ||
          c == null ||
          user == null ||
          r.status != ReservationStatus.confirmed ||
          r.bookingCode == null) {
        return null;
      }
      final now = _b.now();
      final via = provider;
      final coachName = _b.users.byId(c.coachId)?.fullName ?? 'Votre coach';
      final qrText = _b.reservationService.ticketQrText(r)!;
      final String to;
      if (via == EmailProvider.emailJs) {
        final demo = demoRecipient.trim();
        to = demo.isNotEmpty ? demo : user.email;
      } else {
        to = formSubmitRecipient.trim();
      }
      EmailDelivery delivery;
      if (!configured) {
        delivery = EmailDelivery(
          status: EmailStatus.notConfigured,
          attemptedAt: now,
          error: 'aucun destinataire FormSubmit ni clés EmailJS',
        );
      } else if (via == EmailProvider.formSubmit &&
          webOrigin != null &&
          !activatedOrigins.contains(webOrigin)) {
        // Origine web non activée : FormSubmit refuserait l'envoi (et
        // enverrait un nouvel email d'activation). On n'appelle pas.
        delivery = EmailDelivery(
          status: EmailStatus.failed,
          attemptedAt: now,
          to: to,
          error: originNotActivated(webOrigin!),
        );
      } else {
        final error = await _withRetry(
          via == EmailProvider.emailJs
              ? () => _emailJs(
                  templateParams(
                    toEmail: to,
                    toName: user.fullName,
                    course: c,
                    coachName: coachName,
                    bookingCode: r.bookingCode!,
                    qrText: qrText,
                  ),
                )
              : () => _formSubmit(
                  formSubmitFields(
                    memberName: user.fullName,
                    course: c,
                    coachName: coachName,
                    bookingCode: r.bookingCode!,
                    qrText: qrText,
                  ),
                ),
        );
        delivery = EmailDelivery(
          status: error == null ? EmailStatus.sent : EmailStatus.failed,
          attemptedAt: now,
          sentAt: error == null ? _b.now() : null,
          to: to,
          error: error,
        );
      }
      _log(
        delivery.status == EmailStatus.sent
            ? 'email envoyé à $to (${via.label})'
            : '${delivery.status.label} : ${delivery.error}',
      );
      final fresh = _b.reservations.byId(reservationId);
      if (fresh == null) return delivery;
      await _b.reservations.save(fresh.copyWith(email: delivery));
      return delivery;
    } catch (_) {
      return null;
    }
  }

  /// Raison affichée quand l'application web tourne sur une origine que
  /// FormSubmit n'a pas activée (autre port, GitHub Pages…).
  static String originNotActivated(String origin) =>
      'FormSubmit : origine non activée ($origin). Lancez l\'application web '
      'avec --web-port ${EmailConfig.webPort}, ou activez cette origine '
      '(voir DECISIONS.md).';

  /// Un nouvel essai sur erreur réseau, délai dépassé ou 5xx. Retourne
  /// `null` si l'email est parti, sinon une raison lisible (jamais de clé).
  Future<String?> _withRetry(Future<EmailAttempt> Function() call) async {
    String? error;
    for (var attempt = 1; attempt <= 2; attempt++) {
      bool retry;
      try {
        final a = await call().timeout(AppConfig.emailTimeout);
        if (a.error == null) return null;
        error = a.error;
        retry = a.retry;
      } on TimeoutException {
        error = 'délai de 10 s dépassé';
        retry = true;
      } catch (_) {
        error = 'réseau indisponible';
        retry = true;
      }
      if (!retry || attempt == 2) break;
      _log('$error : nouvel essai');
      await Future<void>.delayed(retryDelay);
    }
    return error;
  }

  // ------------------------------------------------------------ FormSubmit

  Future<EmailAttempt> _formSubmit(Map<String, String> fields) async {
    final res = await _b.httpClient.post(
      Uri.parse(
        '${EmailConfig.formSubmitBaseUrl}'
        '${formSubmitRecipient.trim()}',
      ),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        // Hors web, un client Dart n'envoie ni Origin ni Referer : on
        // annonce l'origine activée. Sur le web, le navigateur les fixe.
        if (webOrigin == null) ...{
          'Origin': EmailConfig.nativeOrigin,
          'Referer': '${EmailConfig.nativeOrigin}/',
        },
      },
      body: jsonEncode(fields),
    );
    return parseFormSubmit(
      res.statusCode,
      utf8.decode(res.bodyBytes, allowMalformed: true),
    );
  }

  /// Réponse FormSubmit : toujours HTTP 200, le succès est dans le JSON
  /// (`"success": "true"`).
  static EmailAttempt parseFormSubmit(int status, String body) {
    if (status >= 500) {
      return (error: 'FormSubmit indisponible ($status)', retry: true);
    }
    if (status != 200) {
      return (error: 'FormSubmit : erreur HTTP $status', retry: false);
    }
    Object? json;
    try {
      json = jsonDecode(body);
    } catch (_) {
      return (error: 'FormSubmit : réponse illisible', retry: false);
    }
    if (json is! Map) {
      return (error: 'FormSubmit : réponse illisible', retry: false);
    }
    final ok = json['success'];
    if (ok == true || ok == 'true') return (error: null, retry: false);
    final message = '${json['message'] ?? ''}'.trim();
    final lower = message.toLowerCase();
    if (lower.contains('activat')) {
      return (
        error:
            'FormSubmit : origine non activée (cliquez sur le lien '
            '« Activate Form » reçu par email)',
        retry: false,
      );
    }
    if (lower.contains('web server')) {
      return (
        error: 'FormSubmit : origine absente (en-tête Referer manquant)',
        retry: false,
      );
    }
    final short = message.length > 140
        ? '${message.substring(0, 140)}…'
        : message;
    return (
      error: short.isEmpty
          ? 'FormSubmit : envoi refusé'
          : 'FormSubmit : $short',
      retry: false,
    );
  }

  /// Champs du message FormSubmit (modèle « table » : une ligne par champ).
  static Map<String, String> formSubmitFields({
    required String memberName,
    required Course course,
    required String coachName,
    required String bookingCode,
    required String qrText,
  }) => {
    '_subject': '✅ Réservation confirmée – ${course.title}',
    '_template': 'table',
    '_captcha': 'false',
    'Abonné': memberName,
    'Cours': course.title,
    'Date': course.startAt == null
        ? 'à planifier'
        : formatDate(course.startAt!),
    'Coach': coachName,
    'Salle': course.room,
    'Code de réservation': bookingCode,
    'QR code (image)': AppConfig.qrImageUrl(qrText),
  };

  // --------------------------------------------------------------- EmailJS

  Future<EmailAttempt> _emailJs(Map<String, String> params) async {
    final http.Response res = await _b.httpClient.post(
      Uri.parse(AppConfig.emailJsUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'service_id': serviceId,
        'template_id': templateId,
        'user_id': publicKey,
        'template_params': params,
      }),
    );
    final body = utf8.decode(res.bodyBytes, allowMalformed: true).trim();
    if (res.statusCode == 200 && body == 'OK') {
      return (error: null, retry: false);
    }
    return (
      error: _describeHttp(res.statusCode, body),
      retry: res.statusCode >= 500,
    );
  }

  String _describeHttp(int status, String body) {
    final what = switch (status) {
      200 => 'réponse inattendue d\'EmailJS',
      400 => 'requête refusée par EmailJS (400)',
      401 || 403 => 'accès refusé par EmailJS ($status)',
      412 || 429 => 'quota EmailJS atteint ($status)',
      >= 500 => 'service EmailJS indisponible ($status)',
      _ => 'erreur EmailJS ($status)',
    };
    final detail = _redact(body);
    return detail.isEmpty ? what : '$what : $detail';
  }

  /// Retire toute clé du texte renvoyé par EmailJS et le raccourcit.
  String _redact(String text) {
    var t = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    for (final secret in [serviceId, templateId, publicKey]) {
      if (secret.trim().length >= 3) t = t.replaceAll(secret.trim(), '•••');
    }
    return t.length > 140 ? '${t.substring(0, 140)}…' : t;
  }

  /// Paramètres du modèle EmailJS (noms imposés par le modèle existant).
  ///
  /// Le modèle actuel (non modifiable pour l'instant) n'utilise
  /// `{{booking_code}}` que dans l'URL de l'image du QR
  /// (`…create-qr-code/?size=200x200&data={{booking_code}}`). On y place donc
  /// le **texte du ticket déjà encodé pour une URL** (`Uri.encodeComponent`) :
  /// le QR de l'email contient le même texte lisible que celui de
  /// l'application. `qr_data` (même valeur) et `booking_code_text` (code en
  /// clair) sont envoyés en plus, ignorés par le modèle actuel, pour un
  /// futur modèle (voir DECISIONS.md).
  static Map<String, String> templateParams({
    required String toEmail,
    required String toName,
    required Course course,
    required String coachName,
    required String bookingCode,
    required String qrText,
  }) {
    final qrData = Uri.encodeComponent(qrText);
    return {
      'to_email': toEmail,
      'to_name': toName,
      'course_title': course.title,
      'course_date': course.startAt == null ? '' : formatDate(course.startAt!),
      'coach_name': coachName,
      'booking_code': qrData,
      'qr_data': qrData,
      'booking_code_text': bookingCode,
    };
  }

  /// « mardi 21 octobre à 18h00 ».
  static String formatDate(DateTime d) =>
      DateFormat("EEEE d MMMM 'à' HH'h'mm", 'fr_FR').format(d);

  static void _log(String message) {
    if (kDebugMode) debugPrint('[Email] $message');
  }
}
