import 'package:flutter/material.dart';

import '../../core/responsive.dart';
import '../../core/formatters.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/course.dart';
import '../../models/enums.dart';
import '../../models/misc.dart';
import '../../services/backend.dart';
import '../../services/course_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/bits.dart';
import '../../widgets/cards.dart';
import '../../widgets/common.dart';
import '../../widgets/pickers.dart';
import '../shell/main_shell.dart';
import '../training/workout_screens.dart' show coverAppBar, weekdayNames;

/// Liste des cours : TabBar par statut + filtres (coach, catégorie, jour).
class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen>
    with SingleTickerProviderStateMixin {
  late final List<CourseView> _views;
  late final TabController _tabs;
  String? _coachId;
  CourseCategory? _category;
  int? _weekday;

  @override
  void initState() {
    super.initState();
    final me = Backend.I.auth.currentUser!;
    _views = me.isMember
        ? CourseView.values
        : [CourseView.upcoming, CourseView.toPlan, CourseView.done];
    _tabs = TabController(length: _views.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _pickCoach() async {
    final coaches = Backend.I.userService.coaches();
    final picked = await showModalBottomSheet<String?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('Tous les coachs'),
              onTap: () => Navigator.pop(ctx),
            ),
            for (final c in coaches)
              ListTile(
                leading: GfAvatar(c),
                title: Text(c.fullName),
                subtitle: Text(c.specialty ?? ''),
                onTap: () => Navigator.pop(ctx, c.id),
              ),
          ],
        ),
      ),
    );
    setState(() => _coachId = picked);
  }

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    final me = b.auth.currentUser!;
    final coachName = _coachId == null
        ? null
        : b.users.byId(_coachId!)?.firstName;
    return Scaffold(
      appBar: AppBar(
        leading: const ShellMenuButton(),
        title: const Text('Cours'),
        actions: const [NotificationBell()],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [for (final v in _views) Tab(text: v.label)],
        ),
      ),
      floatingActionButton: me.canManageContent
          ? FloatingActionButton.extended(
              heroTag: 'course_fab',
              onPressed: () => Navigator.pushNamed(context, Routes.courseForm),
              icon: const Icon(Icons.add),
              label: const Text('Cours'),
            )
          : null,
      body: Column(
        children: [
          const SizedBox(height: Gap.s),
          ChipBar(
            children: [
              GfFilterChip(
                label: coachName ?? 'Coach',
                icon: Icons.sports,
                selected: _coachId != null,
                onTap: _pickCoach,
              ),
              for (var d = 1; d <= 7; d++)
                GfFilterChip(
                  label: weekdayNames[d - 1].substring(0, 3),
                  selected: _weekday == d,
                  onTap: () =>
                      setState(() => _weekday = _weekday == d ? null : d),
                ),
            ],
          ),
          ChipBar(
            children: [
              for (final c in CourseCategory.values)
                GfFilterChip(
                  label: c.label,
                  icon: c.icon,
                  selected: _category == c,
                  onTap: () =>
                      setState(() => _category = _category == c ? null : c),
                ),
            ],
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: b.bus,
              builder: (context, _) => TabBarView(
                controller: _tabs,
                children: [
                  for (final v in _views)
                    _CourseList(
                      courses: b.courseService.list(
                        view: v,
                        coachId: _coachId,
                        category: _category,
                        weekday: _weekday,
                      ),
                      view: v,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseList extends StatelessWidget {
  const _CourseList({required this.courses, required this.view});
  final List<Course> courses;
  final CourseView view;

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) {
      final (icon, title, message) = switch (view) {
        CourseView.myBookings => (
          Icons.event_available,
          'Aucune réservation',
          'Réservez un cours dans l\'onglet « À venir ».',
        ),
        CourseView.myPast => (
          Icons.history,
          'Aucun cours suivi',
          'Vos cours terminés apparaîtront ici, avec la possibilité de les noter.',
        ),
        CourseView.toPlan => (
          Icons.schedule,
          'Rien à planifier',
          'Aucun cours en attente de date.',
        ),
        _ => (
          Icons.event_busy,
          'Aucun cours',
          'Aucun cours ne correspond à ces filtres.',
        ),
      };
      return EmptyState(icon: icon, title: title, message: message);
    }
    return ResponsiveList(
      minTileWidth: 400,
      maxWidth: 1200,
      top: Gap.s,
      spacing: Gap.s,
      itemCount: courses.length,
      itemBuilder: (_, i) => FadeSlideIn(
        index: i,
        child: CourseCard(course: courses[i]),
      ),
    );
  }
}

/// Détail d'un cours : réservation, liste d'attente, annulation,
/// agenda, notation, et gestion pour le coach/admin.
class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen({super.key, required this.courseId});
  final String courseId;

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  bool _busy = false;

  Future<void> _act(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    await runAction(context, action, success: success);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _rate(Reservation r) async {
    var stars = r.rating ?? 5;
    final comment = TextEditingController(text: r.comment ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Noter ce cours'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RatingStars(
                value: stars.toDouble(),
                size: 34,
                onChanged: (v) => setLocal(() => stars = v),
              ),
              const SizedBox(height: Gap.m),
              TextField(
                controller: comment,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Commentaire (facultatif)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(96, 44)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Envoyer'),
            ),
          ],
        ),
      ),
    );
    final text = comment.text;
    comment.dispose();
    if (ok != true || !mounted) return;
    await _act(
      () => Backend.I.reservationService.rate(r.id, stars, comment: text),
      'Merci pour votre note !',
    );
  }

  Future<void> _cancelCourse(Course c) async {
    final reason = await askText(
      context,
      title: 'Annuler le cours',
      label: 'Motif (communiqué aux inscrits)',
      validator: Validators.text(field: 'Le motif', min: 3, max: 200),
    );
    if (reason == null || !mounted) return;
    await _act(
      () => Backend.I.courseService.cancel(c.id, reason),
      'Cours annulé, inscrits prévenus.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    return ListenableBuilder(
      listenable: b.bus,
      builder: (context, _) {
        final c = b.courseService.byId(widget.courseId);
        if (c == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.search_off,
              title: 'Cours introuvable',
              message: 'Il a peut-être été supprimé.',
            ),
          );
        }
        final me = b.auth.currentUser!;
        final status = b.courseService.statusOf(c);
        final coach = b.users.byId(c.coachId);
        final active = b.reservationService.activeFor(c.id, me.id);
        final latest = b.reservationService.latestFor(c.id, me.id);
        final confirmed = b.courseService.confirmedCount(c.id);
        final waiting = b.courseService.waitlistCount(c.id);
        final full = confirmed >= c.capacity;
        final rating = b.courseService.averageRating(c.id);
        final canManage = b.courseService.canManage(me, c);
        final subOk =
            c.startAt != null && me.subscription.isActiveAt(c.startAt!);

        Widget? action;
        if (me.isMember) {
          if (status == CourseStatus.scheduled) {
            if (active == null) {
              if (!subOk) {
                action = const GfCard(
                  color: AppColors.redSoft,
                  child: InfoRow(
                    Icons.card_membership,
                    'Votre abonnement a expiré : renouvelez-le à l\'accueil pour réserver.',
                  ),
                );
              } else {
                action = LoadingButton(
                  key: const Key('book_course'),
                  label: full
                      ? 'Rejoindre la liste d\'attente'
                      : 'Réserver ma place',
                  icon: full ? Icons.hourglass_top : Icons.event_available,
                  color: full ? AppColors.navy : AppColors.red,
                  loading: _busy,
                  onPressed: () => _act(
                    () => b.reservationService.book(c.id, joinWaitlist: full),
                    full
                        ? 'Inscrit en liste d\'attente.'
                        : 'Place réservée ! Rappels programmés.',
                  ),
                );
              }
            } else {
              final canCancel =
                  active.status == ReservationStatus.waitlisted ||
                  c.startAt!.difference(b.now()) >= const Duration(hours: 2);
              action = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GfCard(
                    color: active.status == ReservationStatus.confirmed
                        ? AppColors.successSoft
                        : AppColors.cream,
                    child: InfoRow(
                      active.status == ReservationStatus.confirmed
                          ? Icons.check_circle
                          : Icons.hourglass_top,
                      active.status == ReservationStatus.confirmed
                          ? 'Place confirmée. Rappels 24 h et 1 h avant.'
                          : 'Liste d\'attente : vous êtes n°${b.reservationService.waitlistPosition(active)}.',
                    ),
                  ),
                  const SizedBox(height: Gap.s),
                  if (active.status == ReservationStatus.confirmed)
                    OutlinedButton.icon(
                      onPressed: () async {
                        final ok = await b.calendar.addEvent(
                          title: c.title,
                          description:
                              '${c.description}\nCoach : ${coach?.fullName ?? ''}',
                          location: 'GymFlow — ${c.room}',
                          start: c.startAt!,
                          end: c.endAt!,
                        );
                        if (context.mounted && !ok) {
                          showSnack(
                            context,
                            'Aucune application d\'agenda disponible.',
                            error: true,
                          );
                        }
                      },
                      icon: const Icon(Icons.edit_calendar),
                      label: const Text('Ajouter à mon agenda'),
                    ),
                  const SizedBox(height: Gap.s),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppColors.red),
                    onPressed: _busy
                        ? null
                        : () async {
                            if (!canCancel) {
                              showSnack(
                                context,
                                'Annulation impossible moins de 2 h avant le début du cours.',
                                error: true,
                              );
                              return;
                            }
                            final ok = await confirm(
                              context,
                              title: 'Annuler ma réservation ?',
                              message:
                                  'Votre place sera proposée à la liste d\'attente.',
                              confirmLabel: 'Annuler la réservation',
                              destructive: true,
                            );
                            if (ok) {
                              await _act(
                                () => b.reservationService.cancel(active.id),
                                'Réservation annulée.',
                              );
                            }
                          },
                    icon: const Icon(Icons.event_busy),
                    label: Text(
                      canCancel
                          ? 'Annuler ma réservation'
                          : 'Annulation impossible (< 2 h)',
                    ),
                  ),
                ],
              );
            }
          } else if (status == CourseStatus.done &&
              latest != null &&
              latest.status == ReservationStatus.confirmed &&
              latest.attended != false) {
            action = latest.rating == null
                ? LoadingButton(
                    label: 'Noter ce cours',
                    icon: Icons.star,
                    loading: _busy,
                    onPressed: () => _rate(latest),
                  )
                : GfCard(
                    color: AppColors.cream,
                    child: Row(
                      children: [
                        Text('Votre note', style: AppText.subtitle(size: 14)),
                        const Spacer(),
                        RatingStars(value: latest.rating!.toDouble()),
                        IconButton(
                          tooltip: 'Modifier',
                          icon: const Icon(Icons.edit),
                          onPressed: () => _rate(latest),
                        ),
                      ],
                    ),
                  );
          }
        }

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              coverAppBar(
                image: c.imageUrl,
                heroTag: 'c_${c.id}',
                actions: [
                  if (canManage &&
                      status != CourseStatus.done &&
                      status != CourseStatus.cancelled)
                    PopupMenuButton<String>(
                      tooltip: 'Gérer',
                      onSelected: (v) {
                        if (v == 'edit') {
                          Navigator.pushNamed(
                            context,
                            Routes.courseForm,
                            arguments: c.id,
                          );
                        }
                        if (v == 'cancel') _cancelCourse(c);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Modifier')),
                        PopupMenuItem(
                          value: 'cancel',
                          child: Text('Annuler le cours'),
                        ),
                      ],
                    ),
                ],
              ),
              SliverPadding(
                padding: pagePadding(context, maxWidth: 900, bottom: Gap.m),
                sliver: SliverList.list(
                  children: [
                    Row(
                      children: [
                        Icon(c.category.icon, color: AppColors.red, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          c.category.label.toUpperCase(),
                          style: AppText.label(
                            color: AppColors.red,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Pill(
                          status.label,
                          color: switch (status) {
                            CourseStatus.scheduled => AppColors.success,
                            CourseStatus.toPlan => AppColors.gold,
                            CourseStatus.done => AppColors.cream,
                            CourseStatus.cancelled => AppColors.red,
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: Gap.xs),
                    Text(c.title, style: AppText.title(size: 24)),
                    const SizedBox(height: Gap.s),
                    if (rating != null)
                      Row(
                        children: [
                          RatingStars(value: rating),
                          const SizedBox(width: Gap.s),
                          Text(
                            '${Fmt.dec1(rating)} / 5',
                            style: AppText.label(),
                          ),
                        ],
                      ),
                    const SizedBox(height: Gap.s),
                    GfCard(
                      child: Column(
                        children: [
                          InfoRow(
                            Icons.event,
                            c.startAt == null
                                ? 'Date à venir (à planifier)'
                                : Fmt.day(c.startAt!),
                          ),
                          if (c.startAt != null)
                            InfoRow(
                              Icons.schedule,
                              '${Fmt.time(c.startAt!)} – ${Fmt.time(c.endAt!)} (${c.durationMin} min)',
                            ),
                          InfoRow(Icons.place_outlined, c.room),
                          InfoRow(Icons.signal_cellular_alt, c.level.label),
                          InfoRow(
                            Icons.payments_outlined,
                            c.priceIncluded
                                ? 'Inclus dans l\'abonnement'
                                : '${Fmt.money(c.price)} (à régler sur place)',
                          ),
                          if (c.cancelled && c.cancelReason != null)
                            InfoRow(
                              Icons.info_outline,
                              'Annulé : ${c.cancelReason}',
                            ),
                        ],
                      ),
                    ),
                    if (status == CourseStatus.scheduled) ...[
                      const SizedBox(height: Gap.m),
                      Row(
                        children: [
                          Text('Places', style: AppText.subtitle(size: 14)),
                          const Spacer(),
                          Text(
                            '$confirmed / ${c.capacity}${waiting > 0 ? ' · $waiting en attente' : ''}',
                            style: AppText.label(),
                          ),
                        ],
                      ),
                      const SizedBox(height: Gap.xs),
                      AnimatedBar(
                        value: c.capacity == 0 ? 0 : confirmed / c.capacity,
                        color: full ? AppColors.red : AppColors.success,
                      ),
                    ],
                    const SizedBox(height: Gap.m),
                    Text(c.description, style: AppText.body()),
                    const SizedBox(height: Gap.m),
                    if (coach != null)
                      GfCard(
                        child: Row(
                          children: [
                            GfAvatar(coach, radius: 26),
                            const SizedBox(width: Gap.m),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    coach.fullName,
                                    style: AppText.subtitle(),
                                  ),
                                  Text(
                                    coach.specialty ?? 'Coach',
                                    style: AppText.label(),
                                  ),
                                  if (coach.bio != null)
                                    Text(
                                      coach.bio!,
                                      style: AppText.body(size: 13),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: Gap.l),
                    ?action,
                    if (canManage &&
                        c.startAt != null &&
                        status != CourseStatus.cancelled) ...[
                      const SizedBox(height: Gap.m),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          Routes.attendance,
                          arguments: c.id,
                        ),
                        icon: const Icon(Icons.fact_check_outlined),
                        label: Text('Inscrits et présences ($confirmed)'),
                      ),
                    ],
                    const SizedBox(height: Gap.xl),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Création / modification d'un cours (coach : ses cours ; admin : tous).
class CourseFormScreen extends StatefulWidget {
  const CourseFormScreen({super.key, this.courseId});
  final String? courseId;

  @override
  State<CourseFormScreen> createState() => _CourseFormScreenState();
}

class _CourseFormScreenState extends State<CourseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _room = TextEditingController(text: 'Studio Zen');
  final _capacity = TextEditingController(text: '12');
  final _duration = TextEditingController(text: '45');
  final _price = TextEditingController();
  final _image = TextEditingController();
  CourseCategory _category = CourseCategory.yoga;
  Level _level = Level.beginner;
  String? _coachId;
  bool _planned = true;
  DateTime? _date;
  TimeOfDay _time = const TimeOfDay(hour: 18, minute: 0);
  bool _included = true;
  bool _saving = false;
  Course? _existing;

  @override
  void initState() {
    super.initState();
    final b = Backend.I;
    final me = b.auth.currentUser!;
    _coachId = me.isCoach ? me.id : b.userService.coaches().firstOrNull?.id;
    final c = widget.courseId == null
        ? null
        : b.courseService.byId(widget.courseId!);
    if (c != null) {
      _existing = c;
      _title.text = c.title;
      _description.text = c.description;
      _room.text = c.room;
      _capacity.text = '${c.capacity}';
      _duration.text = '${c.durationMin}';
      _price.text = c.priceIncluded ? '' : c.price.toStringAsFixed(0);
      _image.text = c.imageUrl ?? '';
      _category = c.category;
      _level = c.level;
      _coachId = c.coachId;
      _planned = c.startAt != null;
      _date = c.startAt;
      if (c.startAt != null) _time = TimeOfDay.fromDateTime(c.startAt!);
      _included = c.priceIncluded;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _description,
      _room,
      _capacity,
      _duration,
      _price,
      _image,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = Backend.I.now();
    final d = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
      initialDate: _date != null && _date!.isAfter(now)
          ? _date!
          : now.add(const Duration(days: 1)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_planned && _date == null) {
      showSnack(
        context,
        'Choisissez une date ou passez le cours « à planifier ».',
        error: true,
      );
      return;
    }
    if (_coachId == null) {
      showSnack(context, 'Affectez un coach.', error: true);
      return;
    }
    final start = _planned
        ? DateTime(
            _date!.year,
            _date!.month,
            _date!.day,
            _time.hour,
            _time.minute,
          )
        : null;
    setState(() => _saving = true);
    final ok = await runAction(
      context,
      () => Backend.I.courseService.save(
        id: _existing?.id,
        title: _title.text,
        description: _description.text,
        category: _category,
        level: _level,
        coachId: _coachId!,
        room: _room.text,
        capacity: int.parse(_capacity.text.trim()),
        durationMin: int.parse(_duration.text.trim()),
        startAt: start,
        priceIncluded: _included,
        price: _included ? 0 : (Validators.parseDecimal(_price.text) ?? 0),
        imageUrl: _image.text.trim().isEmpty ? null : _image.text.trim(),
      ),
      success: _existing == null
          ? 'Cours créé.'
          : 'Cours mis à jour, inscrits prévenus.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    final me = b.auth.currentUser!;
    return Scaffold(
      appBar: AppBar(
        title: Text(_existing == null ? 'Nouveau cours' : 'Modifier le cours'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: pagePadding(context, maxWidth: 760, bottom: Gap.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Titre du cours'),
                validator: Validators.text(field: 'Le titre', min: 3, max: 60),
              ),
              const SizedBox(height: Gap.m),
              TextFormField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: Validators.text(
                  field: 'La description',
                  min: 10,
                  max: 500,
                ),
              ),
              const SizedBox(height: Gap.m),
              Row(
                children: [
                  Expanded(
                    child: EnumDropdown<CourseCategory>(
                      label: 'Catégorie',
                      value: _category,
                      values: CourseCategory.values,
                      labelOf: (c) => c.label,
                      onChanged: (c) => setState(() => _category = c),
                    ),
                  ),
                  const SizedBox(width: Gap.s),
                  Expanded(
                    child: EnumDropdown<Level>(
                      label: 'Niveau',
                      value: _level,
                      values: Level.values,
                      labelOf: (l) => l.label,
                      onChanged: (l) => setState(() => _level = l),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.m),
              if (me.isAdmin)
                DropdownButtonFormField<String>(
                  initialValue: _coachId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Coach affecté'),
                  items: [
                    for (final c in b.userService.coaches())
                      DropdownMenuItem(
                        value: c.id,
                        child: Text('${c.fullName} — ${c.specialty ?? ''}'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _coachId = v),
                  validator: (v) => v == null ? 'Affectez un coach.' : null,
                )
              else
                InfoRow(Icons.sports, 'Coach : ${me.fullName} (vous)'),
              const SizedBox(height: Gap.m),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _room,
                      decoration: const InputDecoration(labelText: 'Salle'),
                      validator: Validators.text(field: 'La salle', max: 40),
                    ),
                  ),
                  const SizedBox(width: Gap.s),
                  Expanded(
                    child: TextFormField(
                      controller: _capacity,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Capacité'),
                      validator: Validators.intRange(
                        field: 'Capacité',
                        min: 1,
                        max: 100,
                      ),
                    ),
                  ),
                  const SizedBox(width: Gap.s),
                  Expanded(
                    child: TextFormField(
                      controller: _duration,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Durée (min)',
                      ),
                      validator: Validators.intRange(
                        field: 'Durée',
                        min: 15,
                        max: 180,
                      ),
                    ),
                  ),
                ],
              ),
              const FormSection('Planification'),
              Wrap(
                spacing: Gap.s,
                children: [
                  GfFilterChip(
                    label: 'Date fixée',
                    selected: _planned,
                    onTap: () => setState(() => _planned = true),
                  ),
                  GfFilterChip(
                    label: 'À planifier',
                    selected: !_planned,
                    onTap: () => setState(() => _planned = false),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                child: _planned
                    ? Padding(
                        padding: const EdgeInsets.only(top: Gap.m),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickDate,
                                icon: const Icon(Icons.calendar_month),
                                label: Text(
                                  _date == null
                                      ? 'Choisir la date'
                                      : Fmt.dayShort(_date!),
                                ),
                              ),
                            ),
                            const SizedBox(width: Gap.s),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickTime,
                                icon: const Icon(Icons.schedule),
                                label: Text(_time.format(context)),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: Gap.m),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _included,
                onChanged: (v) => setState(() => _included = v),
                title: Text('Inclus dans l\'abonnement', style: AppText.body()),
              ),
              if (!_included)
                TextFormField(
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Prix (TND)'),
                  validator: Validators.decimalRange(
                    field: 'Le prix',
                    min: 0.5,
                    max: 500,
                  ),
                ),
              const SizedBox(height: Gap.m),
              TextFormField(
                controller: _image,
                decoration: const InputDecoration(
                  labelText: 'Image (adresse web, facultatif)',
                ),
                validator: Validators.url,
              ),
              const SizedBox(height: Gap.l),
              LoadingButton(
                label: 'Enregistrer',
                loading: _saving,
                onPressed: _save,
                icon: Icons.check,
              ),
              const SizedBox(height: Gap.l),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inscrits d'un cours et pointage des présences (coach / admin).
class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key, required this.courseId});
  final String courseId;

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    return ListenableBuilder(
      listenable: b.bus,
      builder: (context, _) {
        final c = b.courseService.byId(courseId)!;
        final list = b.reservationService.participants(courseId);
        final canMark =
            c.startAt != null &&
            !b.now().isBefore(c.startAt!.subtract(const Duration(minutes: 15)));
        return Scaffold(
          appBar: AppBar(title: Text('Inscrits · ${c.title}')),
          body: list.isEmpty
              ? const EmptyState(
                  icon: Icons.group_off,
                  title: 'Aucun inscrit',
                  message: 'Les réservations apparaîtront ici.',
                )
              : ListView(
                  padding: pagePadding(context, maxWidth: 900, bottom: Gap.m),
                  children: [
                    if (!canMark)
                      const GfCard(
                        color: AppColors.cream,
                        child: InfoRow(
                          Icons.info_outline,
                          'Le pointage des présences s\'ouvre 15 min avant le début du cours.',
                        ),
                      ),
                    const SizedBox(height: Gap.s),
                    for (final (r, u) in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Gap.s),
                        child: GfCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Gap.s,
                            vertical: Gap.xs,
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: GfAvatar(u),
                            title: Text(
                              u.fullName,
                              style: AppText.subtitle(size: 14),
                            ),
                            subtitle: Text(
                              r.status == ReservationStatus.waitlisted
                                  ? 'Liste d\'attente n°${b.reservationService.waitlistPosition(r)}'
                                  : (r.rating != null
                                        ? 'Note : ${r.rating}/5'
                                        : r.status.label),
                              style: AppText.label(size: 12),
                            ),
                            trailing: r.status != ReservationStatus.confirmed
                                ? const Pill(
                                    'En attente',
                                    color: AppColors.gold,
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Présent',
                                        onPressed: canMark
                                            ? () => runAction(
                                                context,
                                                () => b.reservationService
                                                    .markAttendance(r.id, true),
                                              )
                                            : null,
                                        icon: Icon(
                                          Icons.check_circle,
                                          color: r.attended == true
                                              ? AppColors.success
                                              : AppColors.outline,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Absent',
                                        onPressed: canMark
                                            ? () => runAction(
                                                context,
                                                () => b.reservationService
                                                    .markAttendance(
                                                      r.id,
                                                      false,
                                                    ),
                                              )
                                            : null,
                                        icon: Icon(
                                          Icons.cancel,
                                          color: r.attended == false
                                              ? AppColors.red
                                              : AppColors.outline,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

/// Centre de notifications de l'application.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final n = Backend.I.notifications;
    return ListenableBuilder(
      listenable: n,
      builder: (context, _) {
        final list = n.mine();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Notifications'),
            actions: [
              if (n.unreadCount > 0)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: AppColors.white),
                  onPressed: n.markAllRead,
                  child: const Text('Tout lire'),
                ),
            ],
          ),
          body: list.isEmpty
              ? const EmptyState(
                  icon: Icons.notifications_none,
                  title: 'Tout est calme',
                  message:
                      'Vos rappels, réservations et commandes apparaîtront ici.',
                )
              : ListView.separated(
                  padding: pagePadding(context, maxWidth: 900, bottom: Gap.m),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Gap.s),
                  itemBuilder: (_, i) => FadeSlideIn(
                    index: i,
                    child: _NotificationTile(notification: list[i]),
                  ),
                ),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});
  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final x = notification;
    final b = Backend.I;
    return GfCard(
      color: x.read ? AppColors.white : AppColors.cream,
      padding: const EdgeInsets.all(Gap.s + 4),
      onTap: () {
        b.notifications.markRead(x.id);
        final route = x.route;
        if (route == null) return;
        if (route == Routes.courseDetail &&
            x.refId != null &&
            b.courses.byId(x.refId!) != null) {
          Navigator.pushNamed(context, route, arguments: x.refId);
        } else if (route != Routes.courseDetail) {
          Navigator.pushNamed(context, route);
        }
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: x.read ? AppColors.cream : AppColors.navy,
            child: Icon(
              x.type.icon,
              color: x.read ? AppColors.navy : AppColors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: Gap.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(x.title, style: AppText.subtitle(size: 14)),
                const SizedBox(height: 2),
                Text(x.body, style: AppText.body(size: 13)),
                const SizedBox(height: 4),
                Text(
                  Fmt.relative(x.createdAt, now: b.now()),
                  style: AppText.label(size: 11),
                ),
              ],
            ),
          ),
          if (!x.read)
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 4),
              decoration: const BoxDecoration(
                color: AppColors.red,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
