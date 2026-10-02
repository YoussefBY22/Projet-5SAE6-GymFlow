import 'package:flutter/material.dart';

import 'enums.dart';
import 'json.dart';

/// Cycle de vie d'un contenu de la bibliothèque (exercice, workout,
/// programme) créé par un abonné :
/// privé → en attente (proposé) → publié, ou refusé (avec un motif).
/// Le contenu créé par un coach ou l'admin est publié directement.
enum ContentStatus {
  private('Privé', Icons.lock_outline),
  pending('En attente de validation', Icons.hourglass_top),
  published('Publié', Icons.public),
  rejected('Refusé', Icons.block);

  const ContentStatus(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum ContentKind {
  exercise('Exercice', 'exercice', Icons.sports_gymnastics),
  workout('Workout', 'workout', Icons.fitness_center),
  program('Programme', 'programme', Icons.calendar_view_week);

  const ContentKind(this.label, this.lower, this.icon);
  final String label;
  final String lower;
  final IconData icon;
}

/// Langues de saisie des contenus.
class ContentLang {
  ContentLang._();
  static const fr = 'fr';
  static const en = 'en';
  static const all = [fr, en];

  static String label(String l) => l == en ? 'English' : 'Français';
  static String other(String l) => l == en ? fr : en;
  static String normalize(String? l) => l == en ? en : fr;
}

/// État de publication d'un contenu.
class Publication {
  const Publication({
    this.status = ContentStatus.published,
    this.submittedAt,
    this.reviewedAt,
    this.reviewerId,
    this.note,
  });

  /// Contenu personnel d'un abonné, jamais proposé.
  static const personal = Publication(status: ContentStatus.private);

  final ContentStatus status;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? reviewerId;

  /// Motif de refus communiqué à l'auteur.
  final String? note;

  bool get isPublished => status == ContentStatus.published;
  bool get isPending => status == ContentStatus.pending;

  Json toJson() => {
    'status': status.name,
    'submittedAt': dateToJson(submittedAt),
    'reviewedAt': dateToJson(reviewedAt),
    'reviewerId': reviewerId,
    'note': note,
  };

  factory Publication.fromJson(Json? j, {bool legacyPrivate = false}) {
    if (j == null) {
      return legacyPrivate ? personal : const Publication();
    }
    return Publication(
      status: enumFrom(
        ContentStatus.values,
        j['status'],
        ContentStatus.published,
      ),
      submittedAt: dateFromJson(j['submittedAt']),
      reviewedAt: dateFromJson(j['reviewedAt']),
      reviewerId: j['reviewerId'] as String?,
      note: j['note'] as String?,
    );
  }
}

/// Élément de la bibliothèque d'entraînement (exercice, workout,
/// programme) : bilingue et publiable.
abstract interface class LibraryItem {
  String get id;
  ContentKind get kind;

  /// Nom dans la langue de saisie [lang].
  String get name;

  /// Nom dans l'autre langue (facultatif).
  String? get altName;
  String get lang;
  String get authorId;
  DateTime get createdAt;
  Publication get publication;
}

extension LibraryItemX on LibraryItem {
  /// Nom affiché dans la langue choisie, avec repli sur la langue de saisie.
  String nameIn(String language) {
    if (language == lang) return name;
    final alt = altName;
    return alt == null || alt.isEmpty ? name : alt;
  }

  /// Le contenu a-t-il un nom dans cette langue ?
  bool availableIn(String language) =>
      language == lang || (altName?.isNotEmpty ?? false);

  bool get isPublished => publication.isPublished;
}
