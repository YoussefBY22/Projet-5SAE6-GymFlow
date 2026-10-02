import '../core/errors.dart';
import '../core/search.dart';
import '../models/content.dart';
import '../models/enums.dart';
import '../models/exercise.dart';
import '../models/prefs.dart';
import '../models/user.dart';
import '../models/workout.dart';
import '../repositories/repository.dart';
import 'backend.dart';

/// Groupes et options de filtres des listes d'entraînement (clés stables,
/// mémorisées dans les préférences de l'utilisateur).
class LibraryFilters {
  LibraryFilters._();

  static const level = 'level';
  static const goal = 'goal';
  static const muscle = 'muscle';
  static const equipment = 'equipment';
  static const type = 'type';
  static const origin = 'origin';
  static const favorites = 'fav';
  static const duration = 'duration';
  static const days = 'days';
  static const weeks = 'weeks';
  static const lang = 'lang';
  static const media = 'media';
  static const status = 'status';

  // Origine
  static const club = 'club';
  static const community = 'community';
  static const mine = 'mine';

  // Durée d'un workout (minutes)
  static const durations = {
    'lt30': (0, 29),
    '30_45': (30, 45),
    '45_60': (46, 60),
    'gt60': (61, 999),
  };

  // Jours par semaine d'un programme
  static const dayBuckets = {'1_3': (1, 3), '4': (4, 4), '5_7': (5, 7)};

  // Durée d'un programme (semaines)
  static const weekBuckets = {'le4': (1, 4), '5_8': (5, 8), '9p': (9, 52)};

  /// Listes dont les filtres sont mémorisés.
  static const exercisesList = 'exercises';
  static const workoutsList = 'workouts';
  static const programsList = 'programs';
}

/// Bibliothèque d'entraînement partagée par les trois types de contenus :
/// visibilité, publication modérée, recherche bilingue et filtres.
///
/// Règles :
/// - un abonné crée des contenus **privés** (visibles par lui seul) ;
/// - il peut les **proposer** : un coach ou l'admin les accepte (publiés,
///   visibles de tous) ou les refuse avec un motif ;
/// - les contenus du staff sont publiés directement ;
/// - un contenu publié par un abonné n'est plus modifiable par lui (il
///   peut le dupliquer) ; le staff peut le modérer.
class LibraryService {
  LibraryService(this._b);
  final Backend _b;

  static const maxPersonalItems = 100;

  // ------------------------------------------------------------------
  // Accès aux contenus
  // ------------------------------------------------------------------

  LibraryItem? find(ContentKind kind, String id) => switch (kind) {
    ContentKind.exercise => _b.exercises.byId(id),
    ContentKind.workout => _b.workouts.byId(id),
    ContentKind.program => _b.programs.byId(id),
  };

  Future<void> _save(LibraryItem x) async {
    switch (x) {
      case Exercise e:
        await _b.exercises.save(e);
      case Workout w:
        await _b.workouts.save(w);
      case Program p:
        await _b.programs.save(p);
    }
  }

  LibraryItem _withPublication(LibraryItem x, Publication p) => switch (x) {
    Exercise e => e.copyWith(publication: p),
    Workout w => w.copyWith(publication: p),
    Program pr => pr.copyWith(publication: p),
    _ => throw StateError('Type inconnu'),
  };

  /// Auteur membre du staff (ou contenu d'origine du club) ?
  bool isStaffAuthor(String authorId) {
    if (authorId.isEmpty) return true;
    return _b.users.byId(authorId)?.canManageContent ?? false;
  }

  /// Nom d'auteur affiché : « Club GymFlow », le coach, ou « Prénom N. »
  /// pour un abonné (jamais le nom complet).
  String authorLabel(LibraryItem x) {
    if (x.authorId.isEmpty) return 'Club GymFlow';
    final u = _b.users.byId(x.authorId);
    if (u == null) return 'Ancien membre';
    if (u.isAdmin) return 'Club GymFlow';
    if (u.isCoach) return 'Coach ${u.firstName}';
    final parts = u.fullName.trim().split(RegExp(r'\s+'));
    final initial = parts.length > 1 ? ' ${parts.last[0].toUpperCase()}.' : '';
    return '${parts.first}$initial';
  }

  /// `mine`, `club` ou `community`.
  String originOf(LibraryItem x, AppUser? me) {
    if (me != null && x.authorId == me.id) return LibraryFilters.mine;
    return isStaffAuthor(x.authorId)
        ? LibraryFilters.club
        : LibraryFilters.community;
  }

  /// Visible : publié, à soi, ou proposé (pour le staff qui valide).
  bool canSee(AppUser? me, LibraryItem x) {
    if (x.publication.isPublished) return true;
    if (me == null) return false;
    if (x.authorId == me.id) return true;
    return x.publication.isPending && me.canManageContent;
  }

  bool canEdit(AppUser me, LibraryItem x) {
    if (x.authorId == me.id) {
      return me.canManageContent || !x.publication.isPublished;
    }
    // Les créations non publiées d'un abonné restent les siennes.
    if (!x.publication.isPublished) return false;
    if (me.isAdmin) return true;
    // Un coach modère aussi le contenu publié par les abonnés.
    return me.isCoach && !isStaffAuthor(x.authorId);
  }

  /// Contenus utilisés par [x] (exercices d'un workout ; workouts et
  /// exercices d'un programme).
  List<LibraryItem> dependenciesOf(LibraryItem x) {
    final out = <String, LibraryItem>{};
    void addWorkout(Workout w) {
      for (final i in w.items) {
        final e = _b.exercises.byId(i.exerciseId);
        if (e != null) out[e.id] = e;
      }
    }

    switch (x) {
      case Workout w:
        addWorkout(w);
      case Program p:
        for (final d in p.days) {
          final w = _b.workouts.byId(d.workoutId);
          if (w == null) continue;
          out[w.id] = w;
          addWorkout(w);
        }
      default:
        break;
    }
    return out.values.toList();
  }

  int personalCount(String userId, ContentKind kind) {
    bool mineNotPublished(LibraryItem x) =>
        x.authorId == userId && !x.publication.isPublished;
    return switch (kind) {
      ContentKind.exercise => _b.exercises.all.where(mineNotPublished).length,
      ContentKind.workout => _b.workouts.all.where(mineNotPublished).length,
      ContentKind.program => _b.programs.all.where(mineNotPublished).length,
    };
  }

  void checkPersonalLimit(AppUser me, ContentKind kind) {
    if (me.canManageContent) return;
    if (personalCount(me.id, kind) >= maxPersonalItems) {
      throw BusinessRuleException(
        'Limite de $maxPersonalItems ${kind.lower}s personnels atteinte.',
      );
    }
  }

  // ------------------------------------------------------------------
  // Publication modérée
  // ------------------------------------------------------------------

  void _checkPublishable(LibraryItem x) {
    if (x.name.trim().length < 3) {
      throw const ValidationException(
        'Le nom doit faire au moins 3 caractères.',
      );
    }
    final description = switch (x) {
      Exercise e => e.description,
      Workout w => w.description,
      Program p => p.description,
      _ => '',
    };
    if (description.trim().length < 20) {
      throw const ValidationException(
        'Avant de publier, ajoutez une description d\'au moins 20 caractères '
        'pour aider les autres membres.',
      );
    }
    if (x is Exercise && x.steps.isEmpty) {
      throw const ValidationException(
        'Avant de publier, décrivez au moins une étape d\'exécution.',
      );
    }
  }

  /// L'auteur propose son contenu à la publication. Les contenus
  /// personnels qu'il utilise (exercices d'un workout…) sont proposés avec.
  Future<void> submit(ContentKind kind, String id) async {
    final me = _b.requireUser();
    final x = find(kind, id) ?? (throw const NotFoundException());
    if (x.authorId != me.id) throw const PermissionDeniedException();
    if (me.canManageContent || x.publication.isPublished) {
      throw const BusinessRuleException('Ce contenu est déjà publié.');
    }
    if (x.publication.isPending) {
      throw const BusinessRuleException('Ce contenu est déjà en attente.');
    }
    _checkPublishable(x);
    final deps = dependenciesOf(x);
    for (final d in deps) {
      if (!d.publication.isPublished && d.authorId != me.id) {
        throw const BusinessRuleException(
          'Ce contenu utilise un élément privé qui ne vous appartient pas.',
        );
      }
    }
    final pending = Publication(
      status: ContentStatus.pending,
      submittedAt: _b.now(),
    );
    await _save(_withPublication(x, pending));
    for (final d in deps) {
      if (d.authorId == me.id && !d.publication.isPublished) {
        await _save(_withPublication(d, pending));
      }
    }
    await _b.audit.log(
      'Contenu proposé',
      '${kind.label} « ${x.name} »',
      targetId: id,
    );
    for (final staff in _b.users.where((u) => u.canManageContent && u.active)) {
      await _b.notifications.notify(
        staff.id,
        NotificationType.system,
        'À valider : ${kind.lower} « ${x.name} »',
        'Proposé par ${authorLabel(x)}${deps.any((d) => d.authorId == me.id && !d.publication.isPublished) ? ' avec ses éléments personnels' : ''}.',
        route: '/review',
      );
    }
    _b.bus.emit();
  }

  /// L'auteur retire sa proposition (le contenu redevient privé).
  Future<void> withdraw(ContentKind kind, String id) async {
    final me = _b.requireUser();
    final x = find(kind, id) ?? (throw const NotFoundException());
    if (x.authorId != me.id) throw const PermissionDeniedException();
    if (!x.publication.isPending) {
      throw const BusinessRuleException('Aucune proposition en cours.');
    }
    await _save(_withPublication(x, Publication.personal));
    _b.bus.emit();
  }

  /// Validation par un coach ou l'admin : le contenu (et ses éléments
  /// proposés avec lui) devient visible de tous.
  Future<void> approve(ContentKind kind, String id) async {
    final me = _b.requireRole(Backend.staff);
    final x = find(kind, id) ?? (throw const NotFoundException());
    if (!x.publication.isPending) {
      throw const BusinessRuleException('Ce contenu n\'est pas en attente.');
    }
    final published = Publication(
      status: ContentStatus.published,
      submittedAt: x.publication.submittedAt,
      reviewedAt: _b.now(),
      reviewerId: me.id,
    );
    final deps = dependenciesOf(x);
    for (final d in deps) {
      if (d.publication.isPublished) continue;
      if (d.authorId != x.authorId || !d.publication.isPending) {
        throw const BusinessRuleException(
          'Un élément utilisé n\'est pas publiable (privé ou refusé).',
        );
      }
    }
    for (final d in deps) {
      if (!d.publication.isPublished) {
        await _save(_withPublication(d, published));
      }
    }
    await _save(_withPublication(x, published));
    await _b.audit.log(
      'Contenu publié',
      '${kind.label} « ${x.name} »',
      targetId: id,
    );
    await _b.notifications.notify(
      x.authorId,
      NotificationType.system,
      'Publié : « ${x.name} »',
      'Votre ${kind.lower} est maintenant visible par tous les membres. Merci !',
      route: _routeOf(kind),
      refId: id,
    );
    _b.bus.emit();
  }

  /// Refus motivé : l'auteur est prévenu et peut corriger puis reproposer.
  Future<void> reject(ContentKind kind, String id, String reason) async {
    final me = _b.requireRole(Backend.staff);
    final x = find(kind, id) ?? (throw const NotFoundException());
    if (!x.publication.isPending) {
      throw const BusinessRuleException('Ce contenu n\'est pas en attente.');
    }
    final note = reason.trim();
    if (note.length < 5 || note.length > 300) {
      throw const ValidationException('Motif : 5 à 300 caractères.');
    }
    await _save(
      _withPublication(
        x,
        Publication(
          status: ContentStatus.rejected,
          submittedAt: x.publication.submittedAt,
          reviewedAt: _b.now(),
          reviewerId: me.id,
          note: note,
        ),
      ),
    );
    // Les éléments proposés avec lui redeviennent privés.
    for (final d in dependenciesOf(x)) {
      if (d.authorId == x.authorId && d.publication.isPending) {
        await _save(_withPublication(d, Publication.personal));
      }
    }
    await _b.audit.log(
      'Contenu refusé',
      '${kind.label} « ${x.name} » : $note',
      targetId: id,
    );
    await _b.notifications.notify(
      x.authorId,
      NotificationType.system,
      'Non publié : « ${x.name} »',
      'Motif : $note. Vous pouvez le modifier puis le proposer à nouveau.',
      route: _routeOf(kind),
      refId: id,
    );
    _b.bus.emit();
  }

  static String _routeOf(ContentKind k) => switch (k) {
    ContentKind.exercise => '/exercise',
    ContentKind.workout => '/workout',
    ContentKind.program => '/program',
  };

  /// File de validation (staff) : les plus anciennes propositions d'abord.
  List<LibraryItem> reviewQueue() {
    _b.requireRole(Backend.staff);
    final all = <LibraryItem>[
      ..._b.programs.where((x) => x.publication.isPending),
      ..._b.workouts.where((x) => x.publication.isPending),
      ..._b.exercises.where((x) => x.publication.isPending),
    ];
    DateTime at(LibraryItem x) => x.publication.submittedAt ?? x.createdAt;
    all.sort((a, b) => at(a).compareTo(at(b)));
    return all;
  }

  int get pendingCount {
    final me = _b.auth.currentUser;
    if (me == null || !me.canManageContent) return 0;
    return _b.programs.all.where((x) => x.publication.isPending).length +
        _b.workouts.all.where((x) => x.publication.isPending).length +
        _b.exercises.all.where((x) => x.publication.isPending).length;
  }

  /// Copie personnelle d'un contenu visible (pour le personnaliser).
  Future<LibraryItem> duplicate(ContentKind kind, String id) async {
    final me = _b.requireUser();
    final x = find(kind, id);
    if (x == null || !canSee(me, x)) throw const NotFoundException();
    checkPersonalLimit(me, kind);
    final pub = me.canManageContent
        ? const Publication()
        : Publication.personal;
    final name = _copyName(x.name);
    final alt = x.altName == null ? null : _copyName(x.altName!, en: true);
    final now = _b.now();
    final LibraryItem copy = switch (x) {
      Exercise e => e.copyWith(
        id: IdGen.next('ex_'),
        name: name,
        altName: alt,
        authorId: me.id,
        createdAt: now,
        publication: pub,
      ),
      Workout w => w.copyWith(
        id: IdGen.next('w_'),
        name: name,
        altName: alt,
        authorId: me.id,
        createdAt: now,
        publication: pub,
      ),
      Program p => p.copyWith(
        id: IdGen.next('p_'),
        name: name,
        altName: alt,
        authorId: me.id,
        createdAt: now,
        publication: pub,
      ),
      _ => throw StateError('Type inconnu'),
    };
    await _save(copy);
    _b.bus.emit();
    return copy;
  }

  static String _copyName(String n, {bool en = false}) {
    final suffix = en ? ' (copy)' : ' (copie)';
    final base = n.length + suffix.length > 80
        ? n.substring(0, 80 - suffix.length)
        : n;
    return '$base$suffix';
  }

  // ------------------------------------------------------------------
  // Recherche et filtres
  // ------------------------------------------------------------------

  String get contentLang =>
      _b.auth.currentUser?.prefs.contentLang ?? ContentLang.fr;

  String _exerciseText(Exercise e) => [
    e.name,
    e.altName ?? '',
    ...e.aliases,
    e.primaryMuscle.label,
    Search.muscleEn[e.primaryMuscle] ?? '',
    for (final m in e.secondaryMuscles) '${m.label} ${Search.muscleEn[m]}',
    e.equipment.label,
    Search.equipmentEn[e.equipment] ?? '',
    e.type.label,
  ].join(' ');

  String _workoutText(Workout w) => [
    w.name,
    w.altName ?? '',
    w.focus,
    w.goal.label,
    Search.goalEn[w.goal] ?? '',
    w.level.label,
    Search.levelEn[w.level] ?? '',
    for (final i in w.items)
      if (_b.exercises.byId(i.exerciseId) case final e?)
        '${e.name} ${e.altName ?? ''} ${e.aliases.join(' ')}',
  ].join(' ');

  String _programText(Program p) => [
    p.name,
    p.altName ?? '',
    p.equipment,
    p.goal.label,
    Search.goalEn[p.goal] ?? '',
    p.level.label,
    Search.levelEn[p.level] ?? '',
    for (final d in p.days)
      if (_b.workouts.byId(d.workoutId) case final w?)
        '${w.name} ${w.altName ?? ''} ${w.focus}',
  ].join(' ');

  bool _common(LibraryItem x, AppUser me, FilterValues f, Level level) {
    if (f.isActive(LibraryFilters.level) &&
        !f.has(LibraryFilters.level, level.name)) {
      return false;
    }
    if (f.isActive(LibraryFilters.origin) &&
        !f.has(LibraryFilters.origin, originOf(x, me))) {
      return false;
    }
    if (f.has(LibraryFilters.favorites, 'only') &&
        !me.favoriteIds.contains(x.id)) {
      return false;
    }
    if (f.isActive(LibraryFilters.lang) &&
        !f.of(LibraryFilters.lang).any(x.availableIn)) {
      return false;
    }
    if (f.isActive(LibraryFilters.status) &&
        !(x.authorId == me.id &&
            f.has(LibraryFilters.status, x.publication.status.name))) {
      return false;
    }
    return true;
  }

  static bool _inBucket(
    FilterValues f,
    String group,
    Map<String, (int, int)> buckets,
    int value,
  ) {
    if (!f.isActive(group)) return true;
    return f.of(group).any((k) {
      final b = buckets[k];
      return b != null && value >= b.$1 && value <= b.$2;
    });
  }

  /// Matériel nécessaire : tout doit faire partie du matériel coché
  /// (« j'ai des haltères et un tapis »).
  static bool _equipmentOk(FilterValues f, Iterable<Equipment> needed) {
    if (!f.isActive(LibraryFilters.equipment)) return true;
    final have = f.of(LibraryFilters.equipment);
    return needed.every((e) => have.contains(e.name));
  }

  Iterable<Exercise> _exercisesOf(Workout w) => [
    for (final i in w.items) ?_b.exercises.byId(i.exerciseId),
  ];

  /// Tri : favoris d'abord (le plus récent en tête), puis pertinence de la
  /// recherche, puis ordre alphabétique dans la langue d'affichage.
  List<T> _sort<T extends LibraryItem>(
    List<T> list,
    AppUser me,
    List<String> variants,
  ) {
    final favs = me.favoriteIds.toList();
    final lang = me.prefs.contentLang;
    int favRank(T x) {
      final i = favs.indexOf(x.id);
      return i < 0 ? -1 : i;
    }

    list.sort((a, b) {
      final fa = favRank(a), fb = favRank(b);
      if (fa != fb) return fb.compareTo(fa);
      final sa = Search.score(variants, '${a.name} ${a.altName ?? ''}');
      final sb = Search.score(variants, '${b.name} ${b.altName ?? ''}');
      if (sa != sb) return sb.compareTo(sa);
      return Search.normalize(
        a.nameIn(lang),
      ).compareTo(Search.normalize(b.nameIn(lang)));
    });
    return list;
  }

  List<Exercise> exercises({
    String query = '',
    FilterValues filters = const {},
  }) {
    final me = _b.requireUser();
    final v = Search.expand(query);
    final f = filters;
    return _sort(
      _b.exercises.where((e) {
        if (!canSee(me, e) || !_common(e, me, f, e.level)) return false;
        if (f.isActive(LibraryFilters.muscle) &&
            !f.has(LibraryFilters.muscle, e.primaryMuscle.name) &&
            !e.secondaryMuscles.any(
              (m) => f.has(LibraryFilters.muscle, m.name),
            )) {
          return false;
        }
        if (!_equipmentOk(f, [e.equipment])) return false;
        if (f.isActive(LibraryFilters.type) &&
            !f.has(LibraryFilters.type, e.type.name)) {
          return false;
        }
        if (f.has(LibraryFilters.media, 'video') && !e.hasVideo) return false;
        return Search.matches(v, _exerciseText(e));
      }),
      me,
      v,
    );
  }

  List<Workout> workouts({String query = '', FilterValues filters = const {}}) {
    final me = _b.requireUser();
    final v = Search.expand(query);
    final f = filters;
    return _sort(
      _b.workouts.where((w) {
        if (!canSee(me, w) || !_common(w, me, f, w.level)) return false;
        if (f.isActive(LibraryFilters.goal) &&
            !f.has(LibraryFilters.goal, w.goal.name)) {
          return false;
        }
        if (!_inBucket(
          f,
          LibraryFilters.duration,
          LibraryFilters.durations,
          w.estimatedMinutes,
        )) {
          return false;
        }
        final ex = _exercisesOf(w).toList();
        if (f.isActive(LibraryFilters.muscle) &&
            !ex.any(
              (e) => f.has(LibraryFilters.muscle, e.primaryMuscle.name),
            )) {
          return false;
        }
        if (!_equipmentOk(f, ex.map((e) => e.equipment))) return false;
        return Search.matches(v, _workoutText(w));
      }),
      me,
      v,
    );
  }

  List<Program> programs({String query = '', FilterValues filters = const {}}) {
    final me = _b.requireUser();
    final v = Search.expand(query);
    final f = filters;
    final list = _sort(
      _b.programs.where((p) {
        if (!canSee(me, p) || !_common(p, me, f, p.level)) return false;
        if (f.isActive(LibraryFilters.goal) &&
            !f.has(LibraryFilters.goal, p.goal.name)) {
          return false;
        }
        if (!_inBucket(
              f,
              LibraryFilters.days,
              LibraryFilters.dayBuckets,
              p.daysPerWeek,
            ) ||
            !_inBucket(
              f,
              LibraryFilters.weeks,
              LibraryFilters.weekBuckets,
              p.weeks,
            )) {
          return false;
        }
        if (f.isActive(LibraryFilters.equipment)) {
          final needed = <Equipment>{
            for (final d in p.days)
              if (_b.workouts.byId(d.workoutId) case final w?)
                ..._exercisesOf(w).map((e) => e.equipment),
          };
          if (!_equipmentOk(f, needed)) return false;
        }
        return Search.matches(v, _programText(p));
      }),
      me,
      v,
    );
    // Programme suivi : juste après les favoris (hors recherche).
    final active = me.activeProgramId;
    if (v.isEmpty && active != null && !me.favoriteIds.contains(active)) {
      final i = list.indexWhere((p) => p.id == active);
      if (i > 0) {
        final p = list.removeAt(i);
        final firstNonFav = list.indexWhere(
          (x) => !me.favoriteIds.contains(x.id),
        );
        list.insert(firstNonFav < 0 ? list.length : firstNonFav, p);
      }
    }
    return list;
  }

  // ------------------------------------------------------------------
  // Préférences d'affichage (mémorisées avec le compte)
  // ------------------------------------------------------------------

  FilterValues savedFilters(String list) =>
      _b.auth.currentUser?.prefs.filters[list] ?? const {};

  Future<void> saveFilters(String list, FilterValues values) async {
    final me = _b.auth.currentUser;
    if (me == null) return;
    final fresh = _b.users.byId(me.id) ?? me;
    final filters = {...fresh.prefs.filters};
    if (values.activeCount == 0) {
      filters.remove(list);
    } else {
      filters[list] = values;
    }
    await _b.users.save(
      fresh.copyWith(prefs: fresh.prefs.copyWith(filters: filters)),
    );
    _b.auth.refreshCurrent();
  }

  Future<void> setContentLang(String lang) async {
    final me = _b.requireUser();
    await _b.users.save(
      me.copyWith(
        prefs: me.prefs.copyWith(contentLang: ContentLang.normalize(lang)),
      ),
    );
    _b.auth.refreshCurrent();
    _b.bus.emit();
  }
}
