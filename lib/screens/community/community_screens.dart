import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/formatters.dart';
import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../services/backend.dart';
import '../../services/community_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/bits.dart';
import '../../widgets/cards.dart';
import '../../widgets/common.dart';
import '../../widgets/pickers.dart';

/// Annuaire des membres qui ont choisi d'être visibles.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  String _query = '';
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    return Scaffold(
      appBar: AppBar(title: const Text('Membres de la salle')),
      body: ListenableBuilder(
        listenable: Listenable.merge([b.bus, b.auth]),
        builder: (context, _) {
          final me = b.auth.currentUser!;
          final members = b.community.members(
            query: _query,
            activeOnly: _active,
          );
          return ListView(
            padding: pagePadding(context),
            children: [
              if (me.isMember && !me.privacy.isPubliclyVisible)
                Padding(
                  padding: const EdgeInsets.only(bottom: Gap.m),
                  child: GfCard(
                    color: AppColors.cream,
                    onTap: () => Navigator.pushNamed(context, Routes.privacy),
                    child: const InfoRow(
                      Icons.visibility_off_outlined,
                      'Votre profil est privé : vous voyez les autres, eux ne vous voient pas. '
                      'Touchez pour le rendre visible.',
                    ),
                  ),
                ),
              TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Rechercher un membre',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: Gap.s),
              Wrap(
                spacing: Gap.s,
                children: [
                  GfFilterChip(
                    label: 'Tous',
                    selected: !_active,
                    onTap: () => setState(() => _active = false),
                  ),
                  GfFilterChip(
                    label: 'Actifs cette semaine',
                    icon: Icons.local_fire_department_outlined,
                    selected: _active,
                    onTap: () => setState(() => _active = true),
                  ),
                ],
              ),
              const SizedBox(height: Gap.m),
              if (members.isEmpty)
                const SizedBox(
                  height: 320,
                  child: EmptyState(
                    icon: Icons.groups_outlined,
                    title: 'Personne pour le moment',
                    message:
                        'Seuls les membres qui ont choisi d\'être visibles apparaissent ici.',
                  ),
                )
              else
                ResponsiveWrapGrid(
                  minTileWidth: 340,
                  children: [
                    for (var i = 0; i < members.length; i++)
                      FadeSlideIn(
                        index: i,
                        child: _MemberCard(profile: members[i]),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.profile});
  final PublicProfile profile;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final last = p.sharedSessions.isEmpty ? null : p.sharedSessions.first;
    return GfCard(
      onTap: () =>
          Navigator.pushNamed(context, Routes.member, arguments: p.userId),
      child: Row(
        children: [
          GfAvatar(p.asAvatarUser(), radius: 28),
          const SizedBox(width: Gap.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.fullName, style: AppText.subtitle(size: 15)),
                const SizedBox(height: 2),
                Text(
                  last == null
                      ? 'Aucune séance partagée'
                      : 'Dernière séance : ${last.title} · ${Fmt.relative(last.startedAt, now: Backend.I.now())}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.label(size: 12),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Pill(
                      p.goal.label,
                      color: AppColors.gold,
                      icon: p.goal.icon,
                    ),
                    Pill('${p.sharedSessions.length} séances'),
                    if (p.activeThisWeek)
                      const Pill(
                        'Actif cette semaine',
                        color: AppColors.success,
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (!p.social.isEmpty)
            const Icon(
              Icons.link,
              color: AppColors.inkSoft,
              semanticLabel: 'Réseaux sociaux',
            ),
        ],
      ),
    );
  }
}

/// Profil public d'un membre.
class MemberProfileScreen extends StatelessWidget {
  const MemberProfileScreen({super.key, required this.userId});
  final String userId;

  Future<void> _open(BuildContext context, String label, Uri uri) async {
    final ok = await confirm(
      context,
      title: 'Ouvrir $label ?',
      message: 'Vous allez quitter GymFlow pour un service externe ($label).',
      confirmLabel: 'Ouvrir',
    );
    if (!ok) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      showSnack(context, 'Impossible d\'ouvrir le lien.', error: true);
    }
  }

  Future<void> _report(BuildContext context, PublicProfile p) async {
    final reason = await askText(
      context,
      title: 'Signaler ${p.firstName}',
      label: 'Motif du signalement',
      hint: 'Ex. photo inappropriée, harcèlement…',
      validator: Validators.text(field: 'Le motif', min: 5, max: 300),
    );
    if (reason == null || !context.mounted) return;
    await runAction(
      context,
      () => Backend.I.community.report(p.userId, reason),
      success: 'Merci. La salle va examiner ce profil.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    return ListenableBuilder(
      listenable: b.bus,
      builder: (context, _) {
        PublicProfile? p;
        try {
          p = b.community.profile(userId);
        } catch (_) {
          p = null;
        }
        if (p == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.lock_outline,
              title: 'Profil privé',
              message:
                  'Ce membre a choisi de ne pas rendre son profil visible.',
            ),
          );
        }
        final profile = p;
        final mine = b.auth.currentUser?.id == profile.userId;
        final s = profile.social;
        final links = <(IconData, String, Uri)>[
          if (s.instagram != null)
            (
              Icons.camera_alt_outlined,
              'Instagram',
              Uri.https('www.instagram.com', '/${s.instagram}/'),
            ),
          if (s.facebook != null)
            (Icons.facebook, 'Facebook', Uri.parse(s.facebook!)),
          if (s.linkedin != null)
            (Icons.work_outline, 'LinkedIn', Uri.parse(s.linkedin!)),
          if (s.snapchat != null)
            (
              Icons.chat_bubble_outline,
              'Snapchat',
              Uri.https('www.snapchat.com', '/add/${s.snapchat}'),
            ),
          if (s.publicEmail != null)
            (
              Icons.alternate_email,
              'E-mail',
              Uri(scheme: 'mailto', path: s.publicEmail),
            ),
        ];
        final volume = profile.sharedSessions.fold<double>(
          0,
          (t, x) => t + x.totalVolume,
        );
        return Scaffold(
          appBar: AppBar(
            title: Text(mine ? 'Mon profil public' : profile.firstName),
            actions: [
              if (!mine)
                PopupMenuButton<String>(
                  tooltip: 'Options',
                  onSelected: (_) => _report(context, profile),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'report',
                      child: Text('Signaler ce profil'),
                    ),
                  ],
                ),
            ],
          ),
          body: ListView(
            padding: pagePadding(context, maxWidth: 860),
            children: [
              GfCard(
                child: Column(
                  children: [
                    GfAvatar(profile.asAvatarUser(), radius: 44),
                    const SizedBox(height: Gap.s),
                    Text(
                      profile.fullName,
                      style: AppText.title(size: 22),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      'Membre depuis ${Fmt.monthYear(profile.memberSince)}',
                      style: AppText.label(),
                    ),
                    const SizedBox(height: Gap.s),
                    Wrap(
                      spacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        Pill(
                          profile.goal.label,
                          color: AppColors.gold,
                          icon: profile.goal.icon,
                        ),
                        if (profile.activeThisWeek)
                          const Pill(
                            'Actif cette semaine',
                            color: AppColors.success,
                          ),
                      ],
                    ),
                    const SizedBox(height: Gap.m),
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            value: '${profile.sharedSessions.length}',
                            label: 'Séances partagées',
                          ),
                        ),
                        Expanded(
                          child: StatTile(
                            value: volume >= 1000
                                ? '${Fmt.dec1(volume / 1000)} t'
                                : '${volume.round()} kg',
                            label: 'Volume partagé',
                          ),
                        ),
                      ],
                    ),
                    if (links.isNotEmpty) ...[
                      const Divider(height: Gap.l),
                      Wrap(
                        spacing: Gap.s,
                        runSpacing: Gap.s,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final (icon, label, uri) in links)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(48, 44),
                              ),
                              onPressed: () => _open(context, label, uri),
                              icon: Icon(icon, size: 18),
                              label: Text(label),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (mine)
                const Padding(
                  padding: EdgeInsets.only(top: Gap.s),
                  child: InfoRow(
                    Icons.info_outline,
                    'Aperçu de ce que voient les autres membres. Âge, poids, abonnement '
                    'et e-mail de connexion ne sont jamais affichés.',
                  ),
                ),
              SectionHeader('Séances partagées', padded: false),
              if (profile.sharedSessions.isEmpty)
                const GfCard(
                  child: InfoRow(
                    Icons.fitness_center,
                    'Aucune séance partagée pour le moment.',
                  ),
                )
              else
                ResponsiveWrapGrid(
                  minTileWidth: 380,
                  children: [
                    for (final session in profile.sharedSessions.take(12))
                      ActivityCard(session: session),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
