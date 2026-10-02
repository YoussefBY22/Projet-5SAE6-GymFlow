import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formatters.dart';
import '../../core/legal.dart';
import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../models/privacy.dart';
import '../../services/backend.dart';
import '../../services/privacy_service.dart';
import '../../widgets/common.dart';
import '../../widgets/pickers.dart';

/// Paramètres de confidentialité : visibilité, réseaux sociaux, partage,
/// consentements, export des données et suppression du compte.
class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    return Scaffold(
      appBar: AppBar(title: const Text('Confidentialité')),
      body: ListenableBuilder(
        listenable: b.auth,
        builder: (context, _) {
          final u = b.auth.currentUser;
          if (u == null) return const SizedBox.shrink();
          final p = u.privacy;
          Future<void> set(PrivacySettings next, String done) => runAction(
            context,
            () => b.privacy.updateSettings(next),
            success: done,
          );
          return ListView(
            padding: pagePadding(context, maxWidth: 760),
            children: [
              if (p.hiddenByAdmin)
                const Padding(
                  padding: EdgeInsets.only(bottom: Gap.m),
                  child: GfCard(
                    color: AppColors.redSoft,
                    child: InfoRow(
                      Icons.visibility_off,
                      'Votre profil a été masqué par la salle (modération). '
                      'Contactez l\'accueil pour en savoir plus.',
                    ),
                  ),
                ),
              const _Section('Visibilité'),
              GfCard(
                padding: const EdgeInsets.symmetric(horizontal: Gap.m),
                child: Column(
                  children: [
                    if (u.isMember)
                      SwitchListTile(
                        key: const Key('privacy_visible'),
                        contentPadding: EdgeInsets.zero,
                        value: p.profileVisible,
                        onChanged: u.isAdult
                            ? (v) => set(
                                p.copyWith(
                                  profileVisible: v,
                                  showSocialLinks: v && p.showSocialLinks,
                                ),
                                v
                                    ? 'Profil visible dans la communauté.'
                                    : 'Profil masqué.',
                              )
                            : null,
                        title: const Text('Profil visible des autres membres'),
                        subtitle: Text(
                          u.isAdult
                              ? 'Photo, nom, objectif et séances partagées. Désactivé par défaut.'
                              : 'Indisponible pour les comptes de mineurs.',
                        ),
                      ),
                    if (u.isMember)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: p.showSocialLinks,
                        onChanged: p.profileVisible
                            ? (v) => set(
                                p.copyWith(showSocialLinks: v),
                                v ? 'Réseaux affichés.' : 'Réseaux masqués.',
                              )
                            : null,
                        title: const Text('Afficher mes réseaux sociaux'),
                        subtitle: const Text(
                          'Seulement si votre profil est visible.',
                        ),
                      ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: p.askToShareSessions,
                      onChanged: (v) => set(
                        p.copyWith(askToShareSessions: v),
                        'Préférence enregistrée.',
                      ),
                      title: const Text('Me proposer de partager mes séances'),
                      subtitle: const Text(
                        'Sinon, toutes vos séances restent privées.',
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: p.showClubFeed,
                      onChanged: (v) => set(
                        p.copyWith(showClubFeed: v),
                        'Préférence enregistrée.',
                      ),
                      title: const Text(
                        'Voir l\'activité du club sur mon accueil',
                      ),
                      subtitle: const Text(
                        'Affichage seulement, ne publie rien.',
                      ),
                    ),
                  ],
                ),
              ),
              if (u.isMember) ...[
                const _Section('Mes réseaux sociaux'),
                const _SocialForm(),
                if (p.isPubliclyVisible)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        Routes.member,
                        arguments: u.id,
                      ),
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text(
                        'Voir mon profil tel que les autres le voient',
                      ),
                    ),
                  ),
              ],
              const _Section('Mes données'),
              GfCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.download_outlined),
                      title: const Text('Télécharger mes données'),
                      subtitle: const Text(
                        'Copie complète au format JSON (droit d\'accès et de portabilité)',
                      ),
                      onTap: () => _export(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.history),
                      title: const Text('Historique de mes consentements'),
                      subtitle: Text('${u.consents.length} enregistrement(s)'),
                      onTap: () => _consents(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: const Text('Politique de confidentialité et CGU'),
                      subtitle: Text('Version ${Legal.version}'),
                      onTap: () => Navigator.pushNamed(context, Routes.legal),
                    ),
                    if (u.isMember) ...[
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.delete_forever_outlined,
                          color: AppColors.red,
                        ),
                        title: Text(
                          'Supprimer mon compte',
                          style: AppText.body(color: AppColors.red),
                        ),
                        subtitle: const Text(
                          'Effacement définitif de vos données',
                        ),
                        onTap: () => _delete(context),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: Gap.xl),
            ],
          );
        },
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    final json = Backend.I.privacy.exportMyData();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mes données'),
        content: SizedBox(
          width: 600,
          height: 420,
          child: SingleChildScrollView(
            child: SelectableText(
              json,
              style: AppText.label(size: 11, color: AppColors.ink),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(minimumSize: const Size(120, 44)),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: json));
              if (ctx.mounted) {
                Navigator.pop(ctx);
                showSnack(context, 'Données copiées dans le presse-papiers.');
              }
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copier'),
          ),
        ],
      ),
    );
  }

  Future<void> _consents(BuildContext context) async {
    final list = Backend.I.auth.currentUser!.consents.reversed.toList();
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: list.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(Gap.l),
                child: Text('Aucun consentement enregistré.'),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final c in list)
                    ListTile(
                      leading: Icon(
                        c.granted ? Icons.check_circle : Icons.cancel,
                        color: c.granted ? AppColors.success : AppColors.red,
                      ),
                      title: Text(ConsentType.label(c.type)),
                      subtitle: Text(
                        '${c.granted ? 'Accordé' : 'Retiré'} le ${Fmt.dateTime(c.at)} · version ${c.version}',
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await confirm(
      context,
      title: 'Supprimer définitivement votre compte ?',
      message:
          'Vos séances, pesées, réservations, workouts personnels et notifications '
          'seront effacés. Vos factures sont conservées 10 ans pour la comptabilité, '
          'sans lien avec votre identité. Cette action est irréversible.',
      confirmLabel: 'Continuer',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final password = await askText(
      context,
      title: 'Confirmez avec votre mot de passe',
      label: 'Mot de passe',
      obscure: true,
      validator: (v) => (v ?? '').isEmpty ? 'Obligatoire.' : null,
    );
    if (password == null || !context.mounted) return;
    final done = await runAction(
      context,
      () => Backend.I.privacy.deleteMyAccount(password),
    );
    if (done && context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, Routes.login, (_) => false);
    }
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, Gap.l, 4, Gap.s),
    child: Text(title, style: AppText.title(size: 18)),
  );
}

/// Formulaire des réseaux sociaux (tous facultatifs).
class _SocialForm extends StatefulWidget {
  const _SocialForm();

  @override
  State<_SocialForm> createState() => _SocialFormState();
}

class _SocialFormState extends State<_SocialForm> {
  final _formKey = GlobalKey<FormState>();
  late final SocialLinks _initial = Backend.I.auth.currentUser!.social;
  late final _instagram = TextEditingController(text: _initial.instagram ?? '');
  late final _facebook = TextEditingController(text: _initial.facebook ?? '');
  late final _linkedin = TextEditingController(text: _initial.linkedin ?? '');
  late final _snapchat = TextEditingController(text: _initial.snapchat ?? '');
  late final _email = TextEditingController(text: _initial.publicEmail ?? '');
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_instagram, _facebook, _linkedin, _snapchat, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _check(String? Function() f) {
    try {
      f();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await runAction(
      context,
      () => Backend.I.privacy.updateSocial(
        SocialLinks(
          instagram: _instagram.text,
          facebook: _facebook.text,
          linkedin: _linkedin.text,
          snapchat: _snapchat.text,
          publicEmail: _email.text,
        ),
      ),
      success: 'Réseaux enregistrés.',
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    Widget field(
      TextEditingController c,
      String label,
      String hint,
      IconData icon,
      String? Function(String?) validator,
    ) => Padding(
      padding: const EdgeInsets.only(bottom: Gap.s),
      child: TextFormField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
        ),
        validator: validator,
      ),
    );
    return GfCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Facultatif. Affichés seulement si votre profil est visible et que '
              '« Afficher mes réseaux sociaux » est activé.',
              style: AppText.label(),
            ),
            const SizedBox(height: Gap.m),
            field(
              _instagram,
              'Instagram',
              'votre.identifiant',
              Icons.camera_alt_outlined,
              (v) =>
                  _check(() => PrivacyService.normalizeHandle(v, 'Instagram')),
            ),
            field(
              _facebook,
              'Facebook',
              'https://facebook.com/votre-profil',
              Icons.facebook,
              (v) => _check(
                () => PrivacyService.normalizeProfileUrl(v, 'Facebook', const [
                  'facebook.com',
                  'fb.com',
                ]),
              ),
            ),
            field(
              _linkedin,
              'LinkedIn',
              'https://linkedin.com/in/votre-profil',
              Icons.work_outline,
              (v) => _check(
                () => PrivacyService.normalizeProfileUrl(v, 'LinkedIn', const [
                  'linkedin.com',
                ]),
              ),
            ),
            field(
              _snapchat,
              'Snapchat',
              'votre.identifiant',
              Icons.chat_bubble_outline,
              (v) =>
                  _check(() => PrivacyService.normalizeHandle(v, 'Snapchat')),
            ),
            field(
              _email,
              'E-mail de contact public',
              'contact@exemple.com',
              Icons.alternate_email,
              (v) => v == null || v.trim().isEmpty
                  ? null
                  : _check(() {
                      final r = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');
                      if (!r.hasMatch(v.trim())) {
                        throw 'Adresse e-mail invalide.';
                      }
                      return null;
                    }),
            ),
            const SizedBox(height: Gap.s),
            LoadingButton(
              label: 'Enregistrer mes réseaux',
              loading: _saving,
              onPressed: _save,
              color: AppColors.navy,
            ),
          ],
        ),
      ),
    );
  }
}

/// Politique de confidentialité et conditions d'utilisation.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget doc(List<(String, String)> sections) => ListView(
      padding: pagePadding(context, maxWidth: 760),
      children: [
        Text('Version ${Legal.version}', style: AppText.label()),
        const SizedBox(height: Gap.s),
        for (final (title, body) in sections)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.m),
            child: GfCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.subtitle()),
                  const SizedBox(height: 4),
                  Text(body, style: AppText.body(size: 14)),
                ],
              ),
            ),
          ),
      ],
    );
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Documents légaux'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Confidentialité'),
              Tab(text: 'Conditions'),
            ],
          ),
        ),
        body: TabBarView(
          children: [doc(Legal.privacyPolicy), doc(Legal.terms)],
        ),
      ),
    );
  }
}
