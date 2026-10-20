import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/formatters.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../models/course.dart';
import '../../models/enums.dart';
import '../../services/backend.dart';
import '../../widgets/common.dart';

/// « Mon ticket » : QR du code de réservation (QR Code Server), code en
/// clair, détails du cours, statut de l'email et présence validée.
class TicketScreen extends StatelessWidget {
  const TicketScreen({super.key, required this.reservationId});
  final String reservationId;

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    return ListenableBuilder(
      listenable: b.bus,
      builder: (context, _) {
        final me = b.auth.currentUser!;
        final r = b.reservations.byId(reservationId);
        final c = r == null ? null : b.courses.byId(r.courseId);
        if (r == null || c == null || r.userId != me.id) {
          return Scaffold(
            appBar: AppBar(title: const Text('Mon ticket')),
            body: const EmptyState(
              icon: Icons.confirmation_number_outlined,
              title: 'Ticket introuvable',
              message: 'Ce ticket n\'existe pas ou n\'est pas le vôtre.',
            ),
          );
        }
        final qr = _QrCard(reservation: r);
        final details = _Details(reservation: r, course: c);
        return Scaffold(
          appBar: AppBar(title: const Text('Mon ticket')),
          body: ListView(
            padding: pagePadding(context, maxWidth: 900, bottom: Gap.xl),
            children: [
              if (isWide(context))
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 340, child: qr),
                    const SizedBox(width: Gap.m),
                    Expanded(child: details),
                  ],
                )
              else ...[
                qr,
                const SizedBox(height: Gap.m),
                details,
              ],
            ],
          ),
        );
      },
    );
  }
}

/// QR (image distante) ou, en secours, le code en grand.
class _QrCard extends StatelessWidget {
  const _QrCard({required this.reservation});
  final Reservation reservation;

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final code = r.bookingCode;
    final valid = r.status == ReservationStatus.confirmed && code != null;
    return GfCard(
      color: AppColors.navy,
      child: Column(
        children: [
          Text(
            valid ? 'Présentez ce QR au coach' : 'Ticket inactif',
            style: AppText.subtitle(color: AppColors.white, size: 15),
          ),
          const SizedBox(height: Gap.m),
          if (r.checkedInAt != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.m),
              child: Pill(
                '✅ Présence validée à ${Fmt.time(r.checkedInAt!)}',
                color: AppColors.gold,
              ),
            ),
          if (valid)
            QrTicketImage(
              code: code,
              data: Backend.I.reservationService.ticketQrText(r) ?? code,
            )
          else
            Container(
              padding: const EdgeInsets.all(Gap.m),
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(Gap.radius),
              ),
              child: Text(
                r.status == ReservationStatus.cancelled
                    ? 'Réservation annulée : ce ticket n\'est plus valable.'
                    : 'Liste d\'attente : le ticket sera actif dès qu\'une '
                          'place se libère.',
                textAlign: TextAlign.center,
                style: AppText.body(color: AppColors.navy),
              ),
            ),
          if (valid) ...[
            const SizedBox(height: Gap.m),
            Text(
              'Code de réservation',
              style: AppText.label(color: AppColors.cream, size: 12),
            ),
            SelectableText(
              code,
              key: const ValueKey('ticket_code'),
              style: AppText.title(
                color: AppColors.gold,
                size: 26,
              ).copyWith(letterSpacing: 2),
            ),
          ],
        ],
      ),
    );
  }
}

/// Image du QR depuis api.qrserver.com. Si elle ne charge pas (hors
/// ligne, service indisponible, image bloquée), le code s'affiche en grand
/// pour une saisie manuelle par le coach.
class QrTicketImage extends StatelessWidget {
  const QrTicketImage({
    super.key,
    required this.code,
    String? data,
    this.size = 240,
  }) : data = data ?? code;

  /// Code affiché en secours si l'image ne charge pas.
  final String code;

  /// Contenu du QR : texte lisible du ticket (voir `TicketQr`).
  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = _CodeFallback(code: code, size: size);
    if (!NetImage.networkEnabled) return fallback;
    return Container(
      width: size + 24,
      height: size + 24,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Gap.radius),
      ),
      child: Image.network(
        AppConfig.qrImageUrl(data),
        width: size,
        height: size,
        semanticLabel: 'QR du code $code',
        // Web : si l'image ne peut pas être lue par CanvasKit (CORS), on
        // l'affiche en élément <img> HTML plutôt que d'échouer.
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : const Center(child: CircularProgressIndicator()),
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

class _CodeFallback extends StatelessWidget {
  const _CodeFallback({required this.code, required this.size});
  final String code;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('qr_fallback'),
    width: size + 24,
    padding: const EdgeInsets.all(Gap.m),
    decoration: BoxDecoration(
      color: AppColors.cream,
      borderRadius: BorderRadius.circular(Gap.radius),
    ),
    child: Column(
      children: [
        const Icon(Icons.qr_code_2, color: AppColors.navy, size: 40),
        const SizedBox(height: Gap.s),
        Text(
          'QR indisponible',
          style: AppText.subtitle(size: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Gap.xs),
        FittedBox(
          child: Text(
            code,
            style: AppText.title(size: 28).copyWith(letterSpacing: 2),
          ),
        ),
        const SizedBox(height: Gap.xs),
        Text(
          'Le coach peut saisir ce code à la main.',
          textAlign: TextAlign.center,
          style: AppText.label(size: 12),
        ),
      ],
    ),
  );
}

class _Details extends StatelessWidget {
  const _Details({required this.reservation, required this.course});
  final Reservation reservation;
  final Course course;

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    final r = reservation;
    final c = course;
    final coach = b.users.byId(c.coachId);
    final member = b.users.byId(r.userId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.title, style: AppText.title(size: 20)),
              const SizedBox(height: Gap.s),
              if (c.startAt != null) ...[
                InfoRow(Icons.event, Fmt.day(c.startAt!)),
                InfoRow(
                  Icons.schedule,
                  '${Fmt.time(c.startAt!)} – ${Fmt.time(c.endAt!)}',
                ),
              ],
              InfoRow(Icons.place_outlined, c.room),
              InfoRow(Icons.sports, 'Coach : ${coach?.fullName ?? '—'}'),
              InfoRow(
                Icons.person_outline,
                'Abonné : ${member?.fullName ?? '—'}',
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.m),
        if (r.status == ReservationStatus.confirmed) _EmailCard(reservation: r),
      ],
    );
  }
}

/// Statut de l'email de confirmation et bouton « Renvoyer l'email ».
class _EmailCard extends StatelessWidget {
  const _EmailCard({required this.reservation});
  final Reservation reservation;

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    final r = reservation;
    final e = r.email;
    final sending = b.email.isSending(r.id);
    final (icon, text, color) = sending
        ? (Icons.schedule_send, 'Envoi de l\'email en cours…', AppColors.cream)
        : e == null
        ? (Icons.mail_outline, 'Email pas encore envoyé.', AppColors.cream)
        : switch (e.status) {
            EmailStatus.sent => (
              Icons.mark_email_read_outlined,
              '📧 Email envoyé à ${e.to}'
                  '${e.sentAt == null ? '' : ' (${Fmt.dateTime(e.sentAt!)})'}',
              AppColors.successSoft,
            ),
            EmailStatus.failed => (
              Icons.error_outline,
              'Email non envoyé : ${e.error ?? 'raison inconnue'}',
              AppColors.redSoft,
            ),
            EmailStatus.notConfigured => (
              Icons.mail_lock_outlined,
              'Email non envoyé : EmailJS non configuré'
                  '${e.error == null ? '' : ' (${e.error})'}.',
              AppColors.cream,
            ),
          };
    return GfCard(
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.navy),
              const SizedBox(width: Gap.s),
              Expanded(
                child: Text(
                  text,
                  key: const ValueKey('ticket_email_status'),
                  style: AppText.body(size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.s),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              key: const ValueKey('ticket_resend'),
              onPressed: sending ? null : () => _resend(context, r.id),
              icon: const Icon(Icons.forward_to_inbox),
              label: const Text('Renvoyer l\'email'),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _resend(BuildContext context, String id) async {
    EmailDelivery? d;
    final ok = await runAction(
      context,
      () async => d = await Backend.I.email.resend(id),
    );
    if (!ok || !context.mounted || d == null) return;
    final delivery = d!;
    showSnack(
      context,
      emailMessage(delivery),
      error: delivery.status != EmailStatus.sent,
    );
  }
}

/// Message affiché après un envoi (réservation ou renvoi).
String emailMessage(EmailDelivery d) => switch (d.status) {
  EmailStatus.sent => '📧 Email de confirmation envoyé à ${d.to}',
  EmailStatus.failed => 'Email non envoyé : ${d.error ?? 'raison inconnue'}',
  EmailStatus.notConfigured =>
    'Email non envoyé : EmailJS non configuré'
        '${d.error == null ? '' : ' (${d.error})'}.',
};
