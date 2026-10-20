import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../core/formatters.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../services/backend.dart';
import '../../services/checkin_service.dart';
import '../../widgets/common.dart';

/// Lecteur de code branchable (caméra) : reçoit `onCode` à appeler avec la
/// valeur lue. Aucun n'est fourni aujourd'hui (pas de package caméra) ;
/// un scanner pourra être branché sans toucher aux règles, qui sont toutes
/// dans [CheckInService.validate].
typedef CodeReaderBuilder =
    Widget Function(BuildContext context, ValueChanged<String> onCode);

/// « Valider par code » (coach / admin) : saisie du code du ticket,
/// confirmation avec le nom de l'abonné, puis retour à la saisie.
class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key, this.courseId});

  /// Cours d'où l'on vient (affiché en titre) ; la validation accepte tout
  /// cours que l'utilisateur peut gérer.
  final String? courseId;

  /// Point d'extension pour un futur scanner (voir [CodeReaderBuilder]).
  static CodeReaderBuilder? readerBuilder;

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;
  String? _error;
  CheckInResult? _result;

  @override
  void dispose() {
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _validate([String? value]) async {
    final input = (value ?? _code.text).trim();
    if (input.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await Backend.I.checkIn.validate(input);
      if (!mounted) return;
      setState(() => _result = res);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is AppException ? e.message : friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _next() {
    setState(() {
      _result = null;
      _error = null;
      _code.clear();
    });
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.courseId == null
        ? null
        : Backend.I.courses.byId(widget.courseId!);
    final reader = CheckInScreen.readerBuilder;
    return Scaffold(
      appBar: AppBar(
        title: Text(c == null ? 'Valider par code' : 'Valider · ${c.title}'),
      ),
      body: ListView(
        padding: pagePadding(context, maxWidth: 600, bottom: Gap.xl),
        children: [
          if (_result != null)
            _Confirmation(result: _result!, onNext: _next)
          else ...[
            if (reader != null) ...[
              reader(context, _validate),
              const SizedBox(height: Gap.m),
            ],
            GfCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Code du ticket', style: AppText.subtitle(size: 15)),
                  const SizedBox(height: Gap.xs),
                  Text(
                    'Saisissez le code affiché sous le QR de l\'abonné '
                    '(ex. GF-7K4M-2QXP), ou collez le texte lu dans le QR. '
                    'Majuscules et tirets facultatifs.',
                    style: AppText.label(size: 12),
                  ),
                  const SizedBox(height: Gap.s),
                  TextField(
                    key: const ValueKey('checkin_code'),
                    controller: _code,
                    focusNode: _focus,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _validate(),
                    decoration: const InputDecoration(
                      labelText: 'GF-XXXX-XXXX',
                      prefixIcon: Icon(Icons.confirmation_number_outlined),
                    ),
                  ),
                  const SizedBox(height: Gap.m),
                  LoadingButton(
                    key: const ValueKey('checkin_submit'),
                    label: 'Valider la présence',
                    icon: Icons.how_to_reg,
                    loading: _busy,
                    onPressed: _validate,
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: Gap.m),
              GfCard(
                key: const ValueKey('checkin_error'),
                color: AppColors.redSoft,
                child: Row(
                  children: [
                    const Icon(Icons.block, color: AppColors.red),
                    const SizedBox(width: Gap.s),
                    Expanded(
                      child: Text(
                        _error!,
                        style: AppText.subtitle(color: AppColors.red, size: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Confirmation extends StatelessWidget {
  const _Confirmation({required this.result, required this.onNext});
  final CheckInResult result;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final bg = r.alreadyDone ? AppColors.gold : AppColors.success;
    final fg = onColor(bg);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GfCard(
          key: const ValueKey('checkin_confirmation'),
          color: bg,
          child: Column(
            children: [
              Icon(
                r.alreadyDone ? Icons.info_outline : Icons.check_circle,
                color: fg,
                size: 56,
              ),
              const SizedBox(height: Gap.s),
              GfAvatar(r.member, radius: 32),
              const SizedBox(height: Gap.s),
              Text(
                r.member?.fullName ?? 'Abonné',
                textAlign: TextAlign.center,
                style: AppText.title(color: fg, size: 22),
              ),
              const SizedBox(height: Gap.xs),
              Text(
                r.message,
                textAlign: TextAlign.center,
                style: AppText.subtitle(color: fg, size: 15),
              ),
              const SizedBox(height: Gap.xs),
              Text(
                '${r.course.title}'
                '${r.course.startAt == null ? '' : ' · ${Fmt.time(r.course.startAt!)}'}',
                textAlign: TextAlign.center,
                style: AppText.label(color: fg),
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.m),
        ElevatedButton.icon(
          key: const ValueKey('checkin_next'),
          onPressed: onNext,
          icon: const Icon(Icons.navigate_next),
          label: const Text('Abonné suivant'),
        ),
      ],
    );
  }
}
