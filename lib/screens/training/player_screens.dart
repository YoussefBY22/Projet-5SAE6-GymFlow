import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formatters.dart';
import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/exercise.dart';
import '../../models/session_log.dart';
import '../../models/workout.dart';
import '../../models/content.dart';
import '../../services/backend.dart';
import '../../services/platform/platform_services.dart';
import '../../services/training_log_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/bits.dart';
import '../../widgets/cards.dart';
import '../../widgets/common.dart';
import '../../widgets/media.dart';
import '../shell/main_shell.dart';

/// Saisie d'une série pendant la séance.
class _SetEntry {
  _SetEntry({required this.reps, required this.load});
  final TextEditingController reps;
  final TextEditingController load;
  bool done = false;

  void dispose() {
    reps.dispose();
    load.dispose();
  }
}

/// Lecteur de séance pas à pas (façon Strava / Nike Training) :
/// exercice en cours avec vidéo, séries à cocher, saisie charge/reps,
/// minuteur de repos animé avec vibration, progression globale.
class SessionPlayerScreen extends StatefulWidget {
  const SessionPlayerScreen({super.key, required this.workoutId});
  final String workoutId;

  @override
  State<SessionPlayerScreen> createState() => _SessionPlayerScreenState();
}

class _SessionPlayerScreenState extends State<SessionPlayerScreen> {
  late final Workout _workout;
  late final List<(WorkoutItem, Exercise)> _items;
  late final List<List<_SetEntry>> _entries;
  late final DateTime _startedAt;
  int _index = 0;
  bool _paused = false;
  bool _finishing = false;

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;

  // Minuteur de repos.
  int _restTotal = 0;
  int _restLeft = 0;

  @override
  void initState() {
    super.initState();
    final b = Backend.I;
    _workout = b.workoutService.workoutById(widget.workoutId)!;
    _items = b.workoutService.resolve(_workout);
    _startedAt = b.now();
    final me = b.auth.currentUser!;
    final lastLoads = _lastLoads(me.id);
    _entries = [
      for (final (item, ex) in _items)
        [
          for (var s = 0; s < item.sets; s++)
            _SetEntry(
              reps: TextEditingController(
                text: item.isTimed ? '1' : '${item.reps ?? 10}',
              ),
              load: TextEditingController(
                text: lastLoads[ex.id] == null
                    ? ''
                    : Fmt.dec1(lastLoads[ex.id]!).replaceAll(',0', ''),
              ),
            ),
        ],
    ];
    _stopwatch.start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  /// Dernière charge utilisée par exercice (pré-remplissage).
  Map<String, double> _lastLoads(String userId) {
    final result = <String, double>{};
    final history = Backend.I.sessions.where((s) => s.userId == userId)
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    for (final s in history) {
      for (final set in s.sets) {
        if (set.loadKg > 0) result[set.exerciseId] = set.loadKg;
      }
    }
    return result;
  }

  void _tick() {
    if (!mounted || _paused) return;
    setState(() {
      if (_restLeft > 0) {
        _restLeft--;
        if (_restLeft == 0) {
          Haptics.restOver();
          SystemSound.play(SystemSoundType.alert);
        }
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final list in _entries) {
      for (final e in list) {
        e.dispose();
      }
    }
    super.dispose();
  }

  int get _totalSets => _entries.fold(0, (s, l) => s + l.length);
  int get _doneSets =>
      _entries.fold(0, (s, l) => s + l.where((e) => e.done).length);

  void _togglePause() {
    setState(() {
      _paused = !_paused;
      _paused ? _stopwatch.stop() : _stopwatch.start();
    });
  }

  void _toggleSet(int setIndex) {
    final entry = _entries[_index][setIndex];
    final (item, _) = _items[_index];
    if (!entry.done) {
      final reps = int.tryParse(entry.reps.text.trim());
      final load = Validators.parseDecimal(entry.load.text) ?? 0;
      if (reps == null || reps < 1 || reps > 200 || load < 0 || load > 500) {
        showSnack(
          context,
          'Vérifiez les répétitions (1-200) et la charge (0-500 kg).',
          error: true,
        );
        return;
      }
    }
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    setState(() {
      entry.done = !entry.done;
      if (entry.done) {
        final isLast =
            _index == _items.length - 1 &&
            _entries[_index].every((e) => e.done);
        if (!isLast && item.restSec > 0) {
          _restTotal = item.restSec;
          _restLeft = item.restSec;
        }
      }
    });
    if (_entries[_index].every((e) => e.done) && _index < _items.length - 1) {
      showSnack(
        context,
        'Exercice terminé ! Passez au suivant quand vous êtes prêt.',
      );
    }
  }

  void _goTo(int i) {
    if (i < 0 || i >= _items.length) return;
    FocusScope.of(context).unfocus();
    setState(() => _index = i);
  }

  Future<bool> _confirmQuit() => confirm(
    context,
    title: 'Abandonner la séance ?',
    message: 'Les séries validées ne seront pas enregistrées.',
    confirmLabel: 'Abandonner',
    destructive: true,
  );

  Future<void> _finish() async {
    if (_doneSets == 0) {
      showSnack(
        context,
        'Validez au moins une série avant de terminer.',
        error: true,
      );
      return;
    }
    if (_doneSets < _totalSets) {
      final ok = await confirm(
        context,
        title: 'Terminer maintenant ?',
        message:
            '$_doneSets séries sur $_totalSets validées. Enregistrer la séance ?',
        confirmLabel: 'Terminer',
      );
      if (!ok) return;
    }
    setState(() => _finishing = true);
    final sets = <SetLog>[];
    for (var i = 0; i < _items.length; i++) {
      final (item, ex) = _items[i];
      for (var s = 0; s < _entries[i].length; s++) {
        final e = _entries[i][s];
        if (!e.done) continue;
        sets.add(
          SetLog(
            exerciseId: ex.id,
            exerciseName: ex.name,
            setIndex: s + 1,
            reps: int.parse(e.reps.text.trim()),
            loadKg: Validators.parseDecimal(e.load.text) ?? 0,
            durationSec: item.isTimed ? item.durationSec : null,
          ),
        );
      }
    }
    try {
      final result = await Backend.I.trainingLog.finishSession(
        workout: _workout,
        startedAt: _startedAt,
        durationSec: _stopwatch.elapsed.inSeconds.clamp(1, 24 * 3600),
        sets: sets,
      );
      _ticker?.cancel();
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          Routes.summary,
          arguments: result,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _finishing = false);
        showSnack(context, e.toString(), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final (item, ex) = _items[_index];
    final entries = _entries[_index];
    final video = ex.mainVideo;
    final progress = _totalSets == 0 ? 0.0 : _doneSets / _totalSets;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmQuit() && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Abandonner',
            icon: const Icon(Icons.close),
            onPressed: () async {
              if (await _confirmQuit() && context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          title: Text(_workout.nameIn(Backend.I.library.contentLang)),
          actions: [
            IconButton(
              key: const Key('pause_button'),
              tooltip: _paused ? 'Reprendre' : 'Pause',
              icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
              onPressed: _togglePause,
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(44),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, Gap.s),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, color: AppColors.gold, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    Fmt.clock(_stopwatch.elapsed),
                    key: const Key('elapsed'),
                    style: AppText.stat(color: AppColors.white, size: 16),
                  ),
                  const SizedBox(width: Gap.m),
                  Expanded(
                    child: AnimatedBar(
                      value: progress,
                      color: AppColors.gold,
                      height: 8,
                    ),
                  ),
                  const SizedBox(width: Gap.s),
                  Text(
                    '$_doneSets/$_totalSets',
                    style: AppText.label(color: AppColors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0.08, 0),
                    end: Offset.zero,
                  ).animate(a),
                  child: child,
                ),
              ),
              child: ListView(
                key: ValueKey(_index),
                padding: const EdgeInsets.fromLTRB(Gap.m, Gap.m, Gap.m, 180),
                children: [
                  Text(
                    'EXERCICE ${_index + 1} / ${_items.length}',
                    style: AppText.label(
                      color: AppColors.red,
                    ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ex.nameIn(Backend.I.library.contentLang),
                    style: AppText.title(size: 24),
                  ),
                  const SizedBox(height: Gap.m),
                  if (video != null)
                    MediaView(video)
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Gap.radius),
                      child: Container(
                        height: 200,
                        color: AppColors.white,
                        child: ExerciseImage(ex, fit: BoxFit.contain),
                      ),
                    ),
                  const SizedBox(height: Gap.s),
                  GfCard(
                    color: AppColors.cream,
                    child: Wrap(
                      spacing: Gap.m,
                      runSpacing: Gap.s,
                      children: [
                        _Target(Icons.repeat, '${item.sets} séries'),
                        _Target(
                          Icons.fitness_center,
                          item.isTimed
                              ? '${item.durationSec} s'
                              : '${item.reps} reps',
                        ),
                        _Target(
                          Icons.hourglass_bottom,
                          'Repos ${item.restSec} s',
                        ),
                        if (item.tempo.isNotEmpty)
                          _Target(Icons.speed, 'Tempo ${item.tempo}'),
                        if (item.suggestedLoad.isNotEmpty)
                          _Target(Icons.scale, item.suggestedLoad),
                      ],
                    ),
                  ),
                  if (item.notes.isNotEmpty) ...[
                    const SizedBox(height: Gap.s),
                    InfoRow(Icons.lightbulb_outline, item.notes),
                  ],
                  if (ex.breathing.isNotEmpty) InfoRow(Icons.air, ex.breathing),
                  const SizedBox(height: Gap.m),
                  for (var s = 0; s < entries.length; s++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Gap.s),
                      child: _SetRow(
                        key: Key('set_${_index}_$s'),
                        index: s,
                        entry: entries[s],
                        timed: item.isTimed,
                        onToggle: () => _toggleSet(s),
                      ),
                    ),
                  TextButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      Routes.exercise,
                      arguments: ex.id,
                    ),
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('Voir la fiche technique'),
                  ),
                ],
              ),
            ),
            // Minuteur de repos animé.
            Positioned(
              left: Gap.m,
              right: Gap.m,
              bottom: 96,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (c, a) => SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.4),
                    end: Offset.zero,
                  ).animate(a),
                  child: FadeTransition(opacity: a, child: c),
                ),
                child: _restLeft > 0
                    ? _RestTimer(
                        key: const Key('rest_timer'),
                        left: _restLeft,
                        total: _restTotal,
                        paused: _paused,
                        onAdd: () => setState(() {
                          _restLeft += 15;
                          _restTotal += 15;
                        }),
                        onSkip: () => setState(() => _restLeft = 0),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            if (_paused)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _togglePause,
                  child: Container(
                    color: AppColors.overlay,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.pause_circle,
                          color: AppColors.gold,
                          size: 72,
                        ),
                        const SizedBox(height: Gap.s),
                        Text(
                          'En pause',
                          style: AppText.title(color: AppColors.white),
                        ),
                        Text(
                          'Touchez pour reprendre',
                          style: AppText.body(color: AppColors.cream),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.all(Gap.m),
            decoration: const BoxDecoration(
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0x14002855),
                  blurRadius: 12,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton.outlined(
                  tooltip: 'Exercice précédent',
                  onPressed: _index == 0 ? null : () => _goTo(_index - 1),
                  icon: const Icon(Icons.chevron_left),
                ),
                const SizedBox(width: Gap.s),
                Expanded(
                  child: _index == _items.length - 1
                      ? LoadingButton(
                          key: const Key('finish_session'),
                          label: 'Terminer la séance',
                          icon: Icons.flag,
                          loading: _finishing,
                          onPressed: _finish,
                        )
                      : LoadingButton(
                          key: const Key('next_exercise'),
                          label: 'Exercice suivant',
                          icon: Icons.skip_next,
                          color: AppColors.navy,
                          loading: false,
                          onPressed: () => _goTo(_index + 1),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Target extends StatelessWidget {
  const _Target(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18, color: AppColors.navy),
      const SizedBox(width: 4),
      Text(text, style: AppText.subtitle(size: 14)),
    ],
  );
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    super.key,
    required this.index,
    required this.entry,
    required this.timed,
    required this.onToggle,
  });

  final int index;
  final _SetEntry entry;
  final bool timed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final done = entry.done;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: kCurve,
      padding: const EdgeInsets.symmetric(horizontal: Gap.s, vertical: Gap.s),
      decoration: BoxDecoration(
        color: done ? AppColors.successSoft : AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: done ? AppColors.success : AppColors.divider,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              'Série ${index + 1}',
              style: AppText.subtitle(
                size: 14,
                color: done ? AppColors.success : AppColors.navy,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: entry.load,
              enabled: !done,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                labelText: 'kg',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: Gap.s),
          Expanded(
            child: timed
                ? Center(child: Text('Tenu', style: AppText.label()))
                : TextField(
                    controller: entry.reps,
                    enabled: !done,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      labelText: 'reps',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: Gap.s),
          TapScale(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: done ? AppColors.success : AppColors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: done ? AppColors.success : AppColors.outline,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.check,
                color: done ? AppColors.white : AppColors.outline,
                semanticLabel: done ? 'Série validée' : 'Valider la série',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestTimer extends StatelessWidget {
  const _RestTimer({
    super.key,
    required this.left,
    required this.total,
    required this.paused,
    required this.onAdd,
    required this.onSkip,
  });

  final int left;
  final int total;
  final bool paused;
  final VoidCallback onAdd;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.navy,
      elevation: 8,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(Gap.m),
        child: Row(
          children: [
            ProgressRing(
              progress: total == 0 ? 0 : left / total,
              size: 76,
              stroke: 8,
              color: AppColors.gold,
              track: const Color(0xFF1A4170),
              child: Text(
                Fmt.clock(Duration(seconds: left)),
                style: AppText.stat(color: AppColors.white, size: 16),
              ),
            ),
            const SizedBox(width: Gap.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    paused ? 'Repos en pause' : 'Récupération',
                    style: AppText.subtitle(color: AppColors.white),
                  ),
                  Text(
                    'Respirez, hydratez-vous.',
                    style: AppText.label(color: AppColors.cream),
                  ),
                  const SizedBox(height: Gap.xs),
                  Row(
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.gold,
                        ),
                        onPressed: onAdd,
                        child: const Text('+15 s'),
                      ),
                      TextButton(
                        key: const Key('skip_rest'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.white,
                        ),
                        onPressed: onSkip,
                        child: const Text('Passer'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Récapitulatif de fin de séance : stats animées, records, confettis.
class SessionSummaryScreen extends StatelessWidget {
  const SessionSummaryScreen({super.key, required this.result});
  final SessionResult result;

  @override
  Widget build(BuildContext context) {
    final s = result.log;
    final records = result.records;
    void goHome() {
      MainShell.tab.value = 0;
      Navigator.pushNamedAndRemoveUntil(context, Routes.home, (_) => false);
    }

    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(Gap.l),
              children: [
                const SizedBox(height: Gap.m),
                const Center(
                  child: Icon(
                    Icons.emoji_events,
                    color: AppColors.gold,
                    size: 72,
                  ),
                ),
                const SizedBox(height: Gap.s),
                Text(
                  'Séance terminée !',
                  key: const Key('summary_title'),
                  textAlign: TextAlign.center,
                  style: AppText.display(color: AppColors.white, size: 30),
                ),
                const SizedBox(height: Gap.xs),
                Text(
                  s.title,
                  textAlign: TextAlign.center,
                  style: AppText.subtitle(color: AppColors.cream),
                ),
                const SizedBox(height: Gap.l),
                GfCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _BigStat(
                              value: s.durationSec / 60,
                              label: 'minutes',
                              format: (v) => v.toStringAsFixed(0),
                            ),
                          ),
                          Expanded(
                            child: _BigStat(
                              value: s.totalVolume,
                              label: 'kg soulevés',
                              format: (v) => Fmt.number(v.round()),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: Gap.l),
                      Row(
                        children: [
                          Expanded(
                            child: _BigStat(
                              value: s.totalSets.toDouble(),
                              label: 'séries',
                            ),
                          ),
                          Expanded(
                            child: _BigStat(
                              value: s.totalReps.toDouble(),
                              label: 'répétitions',
                            ),
                          ),
                          Expanded(
                            child: _BigStat(
                              value: records.length.toDouble(),
                              label: 'records',
                              color: AppColors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (records.isNotEmpty) ...[
                  const SizedBox(height: Gap.l),
                  Text(
                    'Nouveaux records personnels',
                    style: AppText.title(color: AppColors.white, size: 18),
                  ),
                  const SizedBox(height: Gap.s),
                  for (var i = 0; i < records.length; i++)
                    FadeSlideIn(
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: Gap.s),
                        child: GfCard(
                          color: AppColors.gold,
                          padding: const EdgeInsets.symmetric(
                            horizontal: Gap.m,
                            vertical: Gap.s,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.emoji_events,
                                color: AppColors.navy,
                              ),
                              const SizedBox(width: Gap.s),
                              Expanded(
                                child: Text(
                                  records[i].exerciseName,
                                  style: AppText.subtitle(size: 14),
                                ),
                              ),
                              Text(
                                '${Fmt.kg(records[i].bestLoadKg)} × ${records[i].repsAtBest}',
                                style: AppText.stat(size: 15),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: Gap.l),
                Text(
                  'Votre séance est enregistrée dans votre historique et votre progression.',
                  textAlign: TextAlign.center,
                  style: AppText.body(color: AppColors.cream),
                ),
                const SizedBox(height: Gap.m),
                ShareChoiceCard(sessionId: s.id),
                const SizedBox(height: Gap.l),
                ElevatedButton.icon(
                  key: const Key('summary_home'),
                  onPressed: goHome,
                  icon: const Icon(Icons.home),
                  label: const Text('Retour à l\'accueil'),
                ),
                const SizedBox(height: Gap.s),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.white,
                    side: const BorderSide(color: AppColors.white, width: 1.5),
                  ),
                  onPressed: () => Navigator.pushReplacementNamed(
                    context,
                    Routes.sessionDetail,
                    arguments: s.id,
                  ),
                  icon: const Icon(Icons.bar_chart),
                  label: const Text('Voir le détail'),
                ),
              ],
            ),
          ),
          const Positioned.fill(child: Confetti()),
        ],
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({
    required this.value,
    required this.label,
    this.format,
    this.color = AppColors.navy,
  });
  final double value;
  final String label;
  final String Function(double)? format;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedCounter(
          value: value,
          format: format,
          style: AppText.display(color: color, size: 30),
        ),
        Text(label, style: AppText.label()),
      ],
    );
  }
}

/// Détail d'une séance (depuis le fil ou l'historique).
class SessionDetailScreen extends StatelessWidget {
  const SessionDetailScreen({super.key, required this.sessionId});
  final String sessionId;

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    return ListenableBuilder(
      listenable: b.bus,
      builder: (context, _) {
        final s = b.trainingLog.byId(sessionId);
        if (s == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.lock_outline,
              title: 'Séance indisponible',
              message: 'Elle a été supprimée ou son auteur ne la partage pas.',
            ),
          );
        }
        final byExercise = <String, List<SetLog>>{};
        for (final set in s.sets) {
          (byExercise[set.exerciseName] ??= []).add(set);
        }
        final mine = s.userId == b.auth.currentUser?.id;
        // Les prénoms des personnes qui ont dit Bravo ne sont montrés qu'à
        // l'auteur de la séance.
        final kudosNames = mine
            ? s.kudos
                  .map((id) => b.users.byId(id)?.firstName)
                  .whereType<String>()
                  .toList()
            : <String>[];
        return Scaffold(
          appBar: AppBar(title: Text(s.title)),
          body: ListView(
            padding: pagePadding(context, maxWidth: 860),
            children: [
              ActivityCard(session: s),
              if (mine) ...[
                const SizedBox(height: Gap.s),
                GfCard(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.m),
                  child: SwitchListTile(
                    key: const Key('session_share_switch'),
                    contentPadding: EdgeInsets.zero,
                    value: s.shared,
                    onChanged: (v) => runAction(
                      context,
                      () => b.trainingLog.setShared(s.id, v),
                      success: v
                          ? 'Séance publiée sur le fil du club.'
                          : 'Séance retirée du fil du club.',
                    ),
                    title: const Text('Partagée sur le fil du club'),
                    subtitle: Text(
                      s.shared
                          ? 'Visible des autres membres. Désactivez pour la retirer.'
                          : 'Privée : visible par vous seul.',
                    ),
                  ),
                ),
              ],
              if (kudosNames.isNotEmpty) ...[
                const SizedBox(height: Gap.s),
                InfoRow(
                  Icons.thumb_up_outlined,
                  'Bravo de ${kudosNames.join(', ')}',
                ),
              ],
              const SizedBox(height: Gap.m),
              Text('Détail des séries', style: AppText.title(size: 18)),
              const SizedBox(height: Gap.s),
              for (final e in byExercise.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: Gap.s),
                  child: GfCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.key, style: AppText.subtitle(size: 15)),
                        const SizedBox(height: Gap.xs),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final set in e.value)
                              Pill(
                                set.durationSec != null
                                    ? 'S${set.setIndex} · ${set.durationSec} s'
                                    : 'S${set.setIndex} · ${set.loadKg > 0 ? '${Fmt.kg(set.loadKg)} × ' : ''}${set.reps}',
                              ),
                          ],
                        ),
                      ],
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

/// Choix explicite de partager une séance après l'avoir terminée
/// (comme une publication : rien n'est publié sans accord).
class ShareChoiceCard extends StatefulWidget {
  const ShareChoiceCard({super.key, required this.sessionId});
  final String sessionId;

  @override
  State<ShareChoiceCard> createState() => _ShareChoiceCardState();
}

class _ShareChoiceCardState extends State<ShareChoiceCard> {
  bool? _decided;
  bool _busy = false;

  Future<void> _choose(bool share) async {
    setState(() => _busy = true);
    final ok = share
        ? await runAction(
            context,
            () => Backend.I.trainingLog.setShared(widget.sessionId, true),
          )
        : true;
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _decided = share;
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = Backend.I.auth.currentUser!;
    final Widget child;
    if (_decided != null) {
      child = InfoRow(
        _decided! ? Icons.public : Icons.lock_outline,
        _decided!
            ? 'Séance partagée sur le fil du club. Vous pouvez la retirer depuis son détail.'
            : 'Séance gardée privée. Vous pourrez la partager plus tard depuis son détail.',
      );
    } else if (!me.privacy.askToShareSessions) {
      child = const InfoRow(
        Icons.lock_outline,
        'Séance privée (vos réglages ne proposent pas le partage).',
      );
    } else {
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Partager cette séance ?', style: AppText.subtitle()),
          const SizedBox(height: 4),
          Text(
            'Les membres du club verront votre nom, votre photo et les '
            'statistiques de la séance (pas vos mesures).',
            style: AppText.label(),
          ),
          const SizedBox(height: Gap.m),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('keep_private'),
                  onPressed: _busy ? null : () => _choose(false),
                  child: const Text('Garder privée'),
                ),
              ),
              const SizedBox(width: Gap.s),
              Expanded(
                child: ElevatedButton.icon(
                  key: const Key('share_session'),
                  onPressed: _busy ? null : () => _choose(true),
                  icon: const Icon(Icons.public, size: 18),
                  label: const Text('Partager'),
                ),
              ),
            ],
          ),
        ],
      );
    }
    return GfCard(
      child: AnimatedSwitcher(
        duration: kAnim,
        child: KeyedSubtree(key: ValueKey(_decided), child: child),
      ),
    );
  }
}
