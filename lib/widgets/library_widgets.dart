import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../core/routes.dart';
import '../core/theme.dart';
import '../core/validators.dart';
import '../models/content.dart';
import '../services/backend.dart';
import '../services/library_service.dart';
import 'common.dart';
import 'pickers.dart';

Color statusColor(ContentStatus s) => switch (s) {
  ContentStatus.private => AppColors.navy,
  ContentStatus.pending => AppColors.gold,
  ContentStatus.published => AppColors.success,
  ContentStatus.rejected => AppColors.red,
};

/// Étiquettes d'un contenu dans une liste : statut de ses propres
/// créations, ou « Communauté » pour le contenu publié par un membre.
List<Pill> libraryPills(LibraryItem x) {
  final b = Backend.I;
  final me = b.auth.currentUser;
  final origin = b.library.originOf(x, me);
  final s = x.publication.status;
  return [
    if (origin == LibraryFilters.mine && !me!.canManageContent)
      Pill(
        s == ContentStatus.private ? 'Personnel' : s.label,
        color: statusColor(s),
        icon: s.icon,
      )
    else if (s == ContentStatus.pending)
      Pill('À valider', color: statusColor(s), icon: s.icon)
    else if (origin == LibraryFilters.community)
      const Pill('Communauté', color: AppColors.navy, icon: Icons.groups),
  ];
}

/// Bouton de la barre d'application : langue d'affichage des contenus.
class ContentLangButton extends StatelessWidget {
  const ContentLangButton({super.key});

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    return ListenableBuilder(
      listenable: b.auth,
      builder: (context, _) {
        final lang = b.library.contentLang;
        return PopupMenuButton<String>(
          key: const Key('content_lang'),
          tooltip: 'Langue des noms d\'exercices et de séances',
          initialValue: lang,
          onSelected: (l) => runAction(
            context,
            () => b.library.setContentLang(l),
            success: l == ContentLang.en
                ? 'Names shown in English when available.'
                : 'Noms affichés en français.',
          ),
          itemBuilder: (_) => [
            const PopupMenuItem(
              enabled: false,
              child: Text('Afficher les noms en'),
            ),
            for (final l in ContentLang.all)
              CheckedPopupMenuItem(
                value: l,
                checked: l == lang,
                child: Text(ContentLang.label(l)),
              ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.s),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.translate, size: 20),
                const SizedBox(width: 4),
                Text(
                  lang.toUpperCase(),
                  style: AppText.subtitle(size: 13, color: AppColors.white),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Bouton « À valider » (staff) avec le nombre de propositions.
class ReviewQueueButton extends StatelessWidget {
  const ReviewQueueButton({super.key});

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    return ListenableBuilder(
      listenable: Listenable.merge([b.bus, b.auth]),
      builder: (context, _) {
        final me = b.auth.currentUser;
        if (me == null || !me.canManageContent) return const SizedBox.shrink();
        final n = b.library.pendingCount;
        return IconButton(
          key: const Key('review_queue'),
          tooltip: 'Propositions à valider',
          onPressed: () => Navigator.pushNamed(context, Routes.review),
          icon: Badge(
            isLabelVisible: n > 0,
            label: Text('$n'),
            backgroundColor: AppColors.gold,
            textColor: AppColors.navy,
            child: const Icon(Icons.fact_check_outlined),
          ),
        );
      },
    );
  }
}

/// Panneau de publication d'un contenu (écran de détail) :
/// - l'auteur abonné voit le statut et peut proposer / retirer ;
/// - le staff valide ou refuse une proposition ;
/// - tout le monde peut dupliquer pour personnaliser.
class PublicationPanel extends StatelessWidget {
  const PublicationPanel({super.key, required this.item});
  final LibraryItem item;

  Future<void> _submit(BuildContext context) async {
    final b = Backend.I;
    final deps = b.library
        .dependenciesOf(item)
        .where((d) => d.authorId == item.authorId && !d.isPublished)
        .toList();
    final ok = await confirm(
      context,
      title: 'Proposer à la publication ?',
      message:
          'Un coach va vérifier votre ${item.kind.lower}. S\'il est accepté, '
          'tous les membres de la salle pourront le voir et l\'utiliser, avec '
          'votre prénom et l\'initiale de votre nom comme auteur.'
          '${deps.isEmpty ? '' : '\n\nÉléments personnels proposés avec lui : ${deps.map((d) => d.name).join(', ')}.'}'
          '\n\nUne fois publié, il appartient à la bibliothèque de la salle : '
          'il reste disponible (anonymisé) même si vous supprimez votre compte.'
          '${item.altName == null ? '\n\nAstuce : ajoutez un nom en ${ContentLang.other(item.lang) == ContentLang.en ? 'anglais' : 'français'} pour que plus de membres le trouvent.' : ''}',
      confirmLabel: 'Proposer',
    );
    if (!ok || !context.mounted) return;
    await runAction(
      context,
      () => b.library.submit(item.kind, item.id),
      success: 'Proposition envoyée. Vous serez notifié de la décision.',
    );
  }

  Future<void> _reject(BuildContext context) async {
    final reason = await askText(
      context,
      title: 'Refuser « ${item.name} »',
      label: 'Motif communiqué à l\'auteur',
      hint: 'Ex. ajoutez une étape, précisez le repos…',
      validator: Validators.text(field: 'Le motif', min: 5, max: 300),
    );
    if (reason == null || !context.mounted) return;
    await runAction(
      context,
      () => Backend.I.library.reject(item.kind, item.id, reason),
      success: 'Refus envoyé à l\'auteur.',
    );
  }

  Future<void> _duplicate(BuildContext context) async {
    final b = Backend.I;
    LibraryItem? copy;
    final ok = await runAction(
      context,
      () async => copy = await b.library.duplicate(item.kind, item.id),
      success: 'Copie créée : vous pouvez la modifier librement.',
    );
    final c = copy;
    if (!ok || c == null || !context.mounted) return;
    Navigator.pushReplacementNamed(context, switch (c.kind) {
      ContentKind.exercise => Routes.exercise,
      ContentKind.workout => Routes.workout,
      ContentKind.program => Routes.program,
    }, arguments: c.id);
  }

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    final me = b.auth.currentUser!;
    final pub = item.publication;
    final mine = item.authorId == me.id;
    final reviewer = pub.reviewerId == null
        ? null
        : b.users.byId(pub.reviewerId!);

    Widget statusCard() {
      final (Color color, String text) = switch (pub.status) {
        ContentStatus.private => (
          AppColors.cream,
          'Visible par vous seul. Proposez-le pour en faire profiter les '
              'autres membres.',
        ),
        ContentStatus.pending => (
          AppColors.cream,
          'En attente de validation par un coach'
              '${pub.submittedAt == null ? '' : ' (proposé ${Fmt.relative(pub.submittedAt!, now: b.now())})'}.',
        ),
        ContentStatus.rejected => (
          AppColors.redSoft,
          'Non publié${reviewer == null ? '' : ' par ${reviewer.firstName}'} : '
              '${pub.note ?? 'sans motif'}\nCorrigez-le puis proposez-le à nouveau.',
        ),
        ContentStatus.published => (
          AppColors.successSoft,
          'Publié : visible par tous les membres. Merci pour votre partage !',
        ),
      };
      return GfCard(
        key: const Key('publication_status'),
        color: color,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(pub.status.icon, color: AppColors.navy),
            const SizedBox(width: Gap.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pub.status.label, style: AppText.subtitle()),
                  const SizedBox(height: 2),
                  Text(text, style: AppText.body(size: 14)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final actions = <Widget>[
      if (mine && !me.canManageContent && !pub.isPublished && !pub.isPending)
        ElevatedButton.icon(
          key: const Key('submit_content'),
          onPressed: () => _submit(context),
          icon: const Icon(Icons.send, size: 18),
          label: const Text('Proposer à la publication'),
        ),
      if (mine && pub.isPending)
        OutlinedButton.icon(
          key: const Key('withdraw_content'),
          onPressed: () => runAction(
            context,
            () => b.library.withdraw(item.kind, item.id),
            success: 'Proposition retirée : le contenu est de nouveau privé.',
          ),
          icon: const Icon(Icons.undo, size: 18),
          label: const Text('Retirer la proposition'),
        ),
      if (!mine && pub.isPending && me.canManageContent) ...[
        ElevatedButton.icon(
          key: const Key('approve_content'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: AppColors.white,
          ),
          onPressed: () => runAction(
            context,
            () => b.library.approve(item.kind, item.id),
            success: 'Publié pour tous les membres.',
          ),
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Accepter et publier'),
        ),
        OutlinedButton.icon(
          key: const Key('reject_content'),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.red),
          onPressed: () => _reject(context),
          icon: const Icon(Icons.close, size: 18),
          label: const Text('Refuser'),
        ),
      ],
      if (pub.isPublished || mine)
        TextButton.icon(
          key: const Key('duplicate_content'),
          onPressed: () => _duplicate(context),
          icon: const Icon(Icons.copy_all_outlined, size: 18),
          label: Text(mine ? 'Dupliquer' : 'Copier pour personnaliser'),
        ),
    ];

    final showStatus =
        (mine && !me.canManageContent) ||
        (pub.isPending && me.canManageContent);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showStatus) ...[statusCard(), const SizedBox(height: Gap.s)],
        if (actions.isNotEmpty)
          Wrap(spacing: Gap.s, runSpacing: Gap.s, children: actions),
      ],
    );
  }
}

/// Ligne « Par … » sous le titre d'un contenu.
class AuthorLine extends StatelessWidget {
  const AuthorLine({super.key, required this.item, this.extra});
  final LibraryItem item;
  final String? extra;

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    final lang = b.library.contentLang;
    final other = item.nameIn(ContentLang.other(lang));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (other != item.nameIn(lang))
          Text(
            other,
            style: AppText.label(
              size: 13,
            ).copyWith(fontStyle: FontStyle.italic),
          ),
        Text(
          'Par ${b.library.authorLabel(item)}${extra == null ? '' : ' · $extra'}',
          style: AppText.label(size: 12),
        ),
      ],
    );
  }
}

/// Section « Langue » des formulaires de création : langue de saisie
/// choisie au début, puis traduction facultative (encouragée).
class LanguageSection extends StatelessWidget {
  const LanguageSection({
    super.key,
    required this.lang,
    required this.onLang,
    required this.kind,
  });
  final String lang;
  final ValueChanged<String> onLang;
  final ContentKind kind;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Langue de saisie', style: AppText.subtitle()),
        const SizedBox(height: Gap.xs),
        SegmentedButton<String>(
          key: const Key('input_lang'),
          segments: const [
            ButtonSegment(
              value: ContentLang.fr,
              label: Text('Français'),
              icon: Icon(Icons.language),
            ),
            ButtonSegment(
              value: ContentLang.en,
              label: Text('English'),
              icon: Icon(Icons.language),
            ),
          ],
          selected: {lang},
          onSelectionChanged: (s) => onLang(s.first),
        ),
        const SizedBox(height: Gap.xs),
        Text(
          'Écrivez votre ${kind.lower} dans la langue de votre choix. '
          'La recherche comprend les deux langues.',
          style: AppText.label(size: 12),
        ),
      ],
    );
  }
}

/// Bloc « Traduction (facultatif) » des formulaires.
class TranslationFields extends StatelessWidget {
  const TranslationFields({
    super.key,
    required this.lang,
    required this.name,
    required this.description,
    required this.kind,
    this.extra,
  });
  final String lang;
  final TextEditingController name;
  final TextEditingController description;
  final ContentKind kind;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final other = ContentLang.other(lang);
    final otherLabel = other == ContentLang.en ? 'anglais' : 'français';
    return GfCard(
      color: AppColors.cream,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.translate, color: AppColors.navy),
              const SizedBox(width: Gap.s),
              Expanded(
                child: Text(
                  'Nom en $otherLabel (facultatif)',
                  style: AppText.subtitle(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Ajouter le nom en $otherLabel aidera d\'autres membres à trouver '
            'votre ${kind.lower} si vous décidez de le publier.',
            style: AppText.body(size: 13),
          ),
          const SizedBox(height: Gap.s),
          TextFormField(
            key: const Key('alt_name'),
            controller: name,
            decoration: InputDecoration(
              labelText: other == ContentLang.en
                  ? 'Name in English (ex. Bench press)'
                  : 'Nom en français (ex. Développé couché)',
            ),
            validator: Validators.text(
              field: 'Le nom traduit',
              min: 3,
              max: 80,
              optional: true,
            ),
          ),
          const SizedBox(height: Gap.s),
          TextFormField(
            controller: description,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: other == ContentLang.en
                  ? 'Short description in English'
                  : 'Courte description en français',
            ),
            validator: Validators.text(
              field: 'La description traduite',
              max: 600,
              optional: true,
            ),
          ),
          ?extra,
        ],
      ),
    );
  }
}
