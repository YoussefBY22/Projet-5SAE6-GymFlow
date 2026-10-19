import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../core/legal.dart';
import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/enums.dart';
import '../../services/backend.dart';
import '../../services/seed/seed_service.dart';
import '../../widgets/bits.dart';
import '../../widgets/common.dart';

/// En-tête marine commun aux écrans d'authentification.
class _AuthHeader extends StatelessWidget {
  const _AuthHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    // Ordinateur : carte arrondie centrée au lieu d'un bandeau collé en haut.
    final wide = isWide(context);
    return Container(
      width: double.infinity,
      margin: wide ? const EdgeInsets.only(top: Gap.xl) : EdgeInsets.zero,
      padding: EdgeInsets.fromLTRB(
        Gap.l,
        MediaQuery.paddingOf(context).top + Gap.l,
        Gap.l,
        Gap.xl,
      ),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: wide
            ? BorderRadius.circular(28)
            : const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset('assets/images/logo_mark.png', width: 44),
              const SizedBox(width: Gap.s),
              Text('GymFlow', style: AppText.title(color: AppColors.white)),
            ],
          ),
          const SizedBox(height: Gap.l),
          Text(title, style: AppText.display(color: AppColors.white, size: 28)),
          const SizedBox(height: Gap.xs),
          Text(subtitle, style: AppText.body(color: AppColors.cream)),
        ],
      ),
    );
  }
}

/// Connexion (`Form` + `GlobalKey<FormState>` + `TextFormField` avec validator).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _banner;

  @override
  void initState() {
    super.initState();
    if (Backend.isReady) _banner = Backend.I.auth.pendingMessage;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _banner = null;
    });
    try {
      final user = await Backend.I.auth.login(_email.text, _password.text);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        Routes.afterLogin(user),
        (_) => false,
      );
    } catch (e) {
      if (mounted) setState(() => _banner = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: MaxWidth(
          maxWidth: 560,
          child: Column(
            children: [
              const _AuthHeader(
                title: 'Content de vous revoir',
                subtitle:
                    'Connectez-vous pour retrouver vos séances et vos cours.',
              ),
              Padding(
                padding: const EdgeInsets.all(Gap.l),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        child: _banner == null
                            ? const SizedBox.shrink()
                            : Container(
                                margin: const EdgeInsets.only(bottom: Gap.m),
                                padding: const EdgeInsets.all(Gap.m),
                                decoration: BoxDecoration(
                                  color: AppColors.redSoft,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: AppColors.red,
                                    ),
                                    const SizedBox(width: Gap.s),
                                    Expanded(
                                      child: Text(
                                        _banner!,
                                        style: AppText.body(
                                          color: AppColors.red,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      TextFormField(
                        key: const Key('login_email'),
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Adresse e-mail',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        validator: Validators.email,
                      ),
                      const SizedBox(height: Gap.m),
                      TextFormField(
                        key: const Key('login_password'),
                        controller: _password,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _obscure ? 'Afficher' : 'Masquer',
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Le mot de passe est obligatoire.'
                            : null,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, Routes.forgot),
                          child: const Text('Mot de passe oublié ?'),
                        ),
                      ),
                      const SizedBox(height: Gap.s),
                      LoadingButton(
                        key: const Key('login_submit'),
                        label: 'Se connecter',
                        loading: _loading,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: Gap.m),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Pas encore membre ?',
                            style: AppText.body(color: AppColors.inkSoft),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, Routes.register),
                            child: const Text('Créer un compte'),
                          ),
                        ],
                      ),
                      const SizedBox(height: Gap.m),
                      DemoAccountsPanel(
                        onPick: (a) => setState(() {
                          _email.text = a.email;
                          _password.text = a.password;
                          _banner = null;
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Panneau discret des comptes de démonstration.
/// Pour le retirer : supprimer ce widget de [LoginScreen].
class DemoAccountsPanel extends StatelessWidget {
  const DemoAccountsPanel({super.key, required this.onPick});
  final ValueChanged<DemoAccount> onPick;

  @override
  Widget build(BuildContext context) {
    return GfCard(
      color: AppColors.cream,
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.science_outlined, color: AppColors.navy),
          iconColor: AppColors.navy,
          collapsedIconColor: AppColors.navy,
          title: Text('Comptes de démo', style: AppText.subtitle(size: 15)),
          subtitle: Text(
            'Touchez un compte pour remplir le formulaire',
            style: AppText.label(size: 12),
          ),
          children: [
            for (final a in demoAccounts)
              ListTile(
                dense: true,
                leading: Icon(a.role.icon, color: AppColors.navy),
                title: Text(a.label, style: AppText.body(size: 14)),
                subtitle: Text(a.email, style: AppText.label(size: 12)),
                onTap: () => onPick(a),
              ),
          ],
        ),
      ),
    );
  }
}

/// Inscription d'un nouvel abonné (essai gratuit de 7 jours).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _age = TextEditingController();
  Gender _gender = Gender.female;
  Goal _goal = Goal.fitness;
  bool _accept = false;
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm, _age]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_accept) {
      showSnack(
        context,
        'Acceptez les conditions d\'utilisation et la politique de confidentialité.',
        error: true,
      );
      return;
    }
    setState(() => _loading = true);
    final ok = await runAction(
      context,
      () => Backend.I.auth.register(
        fullName: _name.text,
        email: _email.text,
        password: _password.text,
        gender: _gender,
        goal: _goal,
        age: int.parse(_age.text.trim()),
        acceptTerms: _accept,
      ),
    );
    if (!mounted) return;
    setState(() => _loading = false);
    // Nouveau compte : présentation de l'application et choix de visibilité.
    if (ok) {
      Navigator.pushNamedAndRemoveUntil(context, Routes.intro, (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
      body: SingleChildScrollView(
        padding: pagePadding(context, maxWidth: 600, top: Gap.l, bottom: Gap.l),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Rejoignez le club', style: AppText.title(size: 24)),
              const SizedBox(height: Gap.xs),
              Text(
                '7 jours d\'essai gratuit pour découvrir les cours et la salle.',
                style: AppText.body(color: AppColors.inkSoft),
              ),
              const SizedBox(height: Gap.l),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nom complet',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: Validators.name,
              ),
              const SizedBox(height: Gap.m),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Adresse e-mail',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: Validators.email,
              ),
              const SizedBox(height: Gap.m),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  helperText: '8 caractères min., une lettre et un chiffre',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Afficher' : 'Masquer',
                    icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: Validators.password,
              ),
              const SizedBox(height: Gap.m),
              TextFormField(
                controller: _confirm,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirmer le mot de passe',
                  prefixIcon: Icon(Icons.lock_reset),
                ),
                validator: (v) => v != _password.text
                    ? 'Les mots de passe ne correspondent pas.'
                    : null,
              ),
              const SizedBox(height: Gap.m),
              TextFormField(
                controller: _age,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Âge',
                  helperText:
                      'Inscription en ligne réservée aux personnes majeures',
                  prefixIcon: Icon(Icons.cake_outlined),
                ),
                validator: (v) {
                  final base = Validators.intRange(
                    field: 'L\'âge',
                    min: 1,
                    max: 100,
                  )(v);
                  if (base != null) return base;
                  return int.parse(v!.trim()) < Legal.minimumAge
                      ? 'Moins de 18 ans : inscription à l\'accueil avec un parent.'
                      : null;
                },
              ),
              const SizedBox(height: Gap.l),
              Text('Je suis', style: AppText.subtitle(size: 15)),
              const SizedBox(height: Gap.s),
              Wrap(
                spacing: Gap.s,
                children: [
                  for (final g in Gender.values)
                    GfFilterChip(
                      label: g.label,
                      selected: _gender == g,
                      onTap: () => setState(() => _gender = g),
                    ),
                ],
              ),
              const SizedBox(height: Gap.m),
              Text('Mon objectif', style: AppText.subtitle(size: 15)),
              const SizedBox(height: Gap.s),
              Wrap(
                spacing: Gap.s,
                runSpacing: Gap.s,
                children: [
                  for (final g in Goal.values)
                    GfFilterChip(
                      label: g.label,
                      icon: g.icon,
                      selected: _goal == g,
                      onTap: () => setState(() => _goal = g),
                    ),
                ],
              ),
              const SizedBox(height: Gap.m),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _accept,
                onChanged: (v) => setState(() => _accept = v ?? false),
                title: Text(
                  'J\'accepte les conditions d\'utilisation, la politique de '
                  'confidentialité et le règlement de la salle',
                  style: AppText.body(size: 14),
                ),
                secondary: TextButton(
                  onPressed: () => Navigator.pushNamed(context, Routes.legal),
                  child: const Text('Lire'),
                ),
              ),
              const SizedBox(height: Gap.m),
              LoadingButton(
                label: 'Créer mon compte',
                loading: _loading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mot de passe oublié : envoi d'un code (e-mail simulé) puis nouveau mot
/// de passe.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailKey = GlobalKey<FormState>();
  final _resetKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_emailKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final code = await Backend.I.auth.requestPasswordReset(_email.text);
      // Envoi réel par e-mail (API EmailJS) ; en cas d'échec, le code
      // s'affiche à l'écran comme avant (démonstration).
      final emailed =
          code == null ||
          await Backend.I.mailer.sendResetCode(_email.text, code);
      if (!mounted) return;
      setState(() => _codeSent = true);
      if (emailed) {
        // Même message qu'un compte existe ou non : on ne révèle rien.
        showSnack(
          context,
          'Si un compte existe pour cette adresse, un code vient d\'y être '
          'envoyé par e-mail (pensez aux courriers indésirables).',
        );
        return;
      }
      // Envoi d'e-mail simulé : la « boîte de réception » s'affiche ici.
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(
            Icons.mark_email_read_outlined,
            color: AppColors.navy,
            size: 40,
          ),
          title: const Text('E-mail simulé'),
          content: Text(
            'Objet : votre code GymFlow\n\nVotre code de réinitialisation est :\n\n$code\n\nIl est valable 15 minutes.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('J\'ai compris'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reset() async {
    if (!_resetKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final ok = await runAction(
      context,
      () =>
          Backend.I.auth.resetPassword(_email.text, _code.text, _password.text),
      success: 'Mot de passe modifié. Connectez-vous.',
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mot de passe oublié')),
      body: SingleChildScrollView(
        padding: pagePadding(context, maxWidth: 600, top: Gap.l, bottom: Gap.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Recevez un code à 6 chiffres par e-mail pour choisir un nouveau mot de passe.',
              style: AppText.body(color: AppColors.inkSoft),
            ),
            const SizedBox(height: Gap.l),
            Form(
              key: _emailKey,
              child: TextFormField(
                controller: _email,
                enabled: !_codeSent,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Adresse e-mail',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: Validators.email,
              ),
            ),
            const SizedBox(height: Gap.m),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: _codeSent
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: LoadingButton(
                label: 'Envoyer le code',
                loading: _loading,
                onPressed: _sendCode,
              ),
              secondChild: Form(
                key: _resetKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: 'Code reçu',
                        prefixIcon: Icon(Icons.pin_outlined),
                      ),
                      validator: (v) =>
                          RegExp(r'^\d{6}$').hasMatch(v?.trim() ?? '')
                          ? null
                          : 'Code à 6 chiffres.',
                    ),
                    const SizedBox(height: Gap.s),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Nouveau mot de passe',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: Validators.password,
                    ),
                    const SizedBox(height: Gap.m),
                    LoadingButton(
                      label: 'Changer mon mot de passe',
                      loading: _loading,
                      onPressed: _reset,
                    ),
                    TextButton(
                      onPressed: _loading ? null : _sendCode,
                      child: const Text('Renvoyer un code'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
