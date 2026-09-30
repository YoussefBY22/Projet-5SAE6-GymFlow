import '../../models/enums.dart';
import '../../models/workout.dart';

/// Workouts et programmes de démonstration.
///
/// Paramètres calibrés selon les recommandations reconnues (sources dans
/// DECISIONS.md) :
/// - Hypertrophie : 3-4 séries de 8-12 reps, repos 60-90 s (120 s sur les
///   gros polyarticulaires) — ACSM 2009, Schoenfeld 2016.
/// - Force : 3-5 séries de 3-6 reps, repos 2-3 min — NSCA.
/// - Circuit / cardio : 30-45 s d'effort, repos 30-45 s.
/// - Étirements : maintiens de 30-45 s, 2 répétitions — ACSM 2011.

const _img = 'https://images.unsplash.com/';
String unsplash(String id) => '$_img$id?w=900&q=75&auto=format&fit=crop';

WorkoutItem _r(
  String ex,
  int sets,
  int reps,
  int rest, {
  String tempo = '',
  String load = '',
  String notes = '',
}) => WorkoutItem(
  exerciseId: 'ex_$ex',
  sets: sets,
  reps: reps,
  restSec: rest,
  tempo: tempo,
  suggestedLoad: load,
  notes: notes,
);

WorkoutItem _t(
  String ex,
  int sets,
  int seconds,
  int rest, {
  String notes = '',
}) => WorkoutItem(
  exerciseId: 'ex_$ex',
  sets: sets,
  durationSec: seconds,
  restSec: rest,
  notes: notes,
);

class SeedWorkout {
  const SeedWorkout(this.workout, this.author);
  final Workout workout;
  final String author;
}

List<SeedWorkout> seedWorkouts(DateTime at) {
  Workout w(
    String key,
    String name,
    String focus,
    String description,
    Level level,
    Goal goal,
    String cover,
    List<WorkoutItem> items,
  ) => Workout(
    id: 'w_$key',
    name: name,
    focus: focus,
    description: description,
    level: level,
    goal: goal,
    coverImage: unsplash(cover),
    items: items,
    authorId: '',
    createdAt: at,
  );

  return [
    SeedWorkout(
      w(
        'push',
        'Push Day',
        'Pectoraux · Épaules · Triceps',
        'Séance de poussée orientée hypertrophie : on commence lourd sur les '
            'polyarticulaires puis on isole.',
        Level.intermediate,
        Goal.muscleGain,
        'photo-1652363722833-509b3aac287b',
        [
          _r('bench', 4, 8, 120, tempo: '2-1-1', load: '70-75 % 1RM'),
          _r('incline_db', 3, 10, 90, tempo: '2-0-1', load: 'RPE 8'),
          _r('db_fly', 3, 12, 60, tempo: '3-1-1', load: 'Léger, amplitude max'),
          _r('ohp', 3, 8, 120, load: '65-70 % 1RM'),
          _r('lateral', 3, 15, 60, load: 'Léger, sans élan'),
          _r('pushdown', 3, 12, 60, tempo: '2-0-1'),
          _r(
            'dips',
            3,
            10,
            90,
            notes: 'Ajoutez du lest si 10 reps sont faciles.',
          ),
        ],
      ),
      'mehdi',
    ),
    SeedWorkout(
      w(
        'pull',
        'Pull Day',
        'Dos · Biceps · Arrière d\'épaules',
        'Séance de tirage : largeur (tractions, tirage) puis épaisseur (rowings).',
        Level.intermediate,
        Goal.muscleGain,
        'photo-1517963879433-6ad2b056d712',
        [
          _r('pullup', 4, 8, 120, notes: 'Avec élastique si besoin.'),
          _r('bb_row', 4, 8, 120, load: '65-70 % 1RM'),
          _r('latpull', 3, 10, 90),
          _r('cable_row', 3, 12, 75, tempo: '2-1-1'),
          _r('facepull', 3, 15, 60, load: 'Léger'),
          _r('bb_curl', 3, 10, 60),
          _r('hammer', 3, 12, 60),
        ],
      ),
      'mehdi',
    ),
    SeedWorkout(
      w(
        'legs',
        'Leg Day',
        'Quadriceps · Ischios · Fessiers · Mollets',
        'Jambes complètes : squat lourd en force, puis volume et isolation.',
        Level.intermediate,
        Goal.muscleGain,
        'photo-1618168220187-ef594ca55286',
        [
          _r(
            'squat',
            4,
            6,
            180,
            load: '75-80 % 1RM',
            notes: 'Échauffement progressif.',
          ),
          _r('rdl', 3, 10, 120, tempo: '3-0-1'),
          _r('legpress', 3, 12, 90),
          _r('lunge', 3, 10, 90, notes: '10 pas par jambe.'),
          _r('legcurl', 3, 12, 60),
          _r('calf', 4, 15, 45),
          _t('plank', 3, 45, 45),
        ],
      ),
      'mehdi',
    ),
    SeedWorkout(
      w(
        'fb_a',
        'Full Body A — Débutant',
        'Corps entier',
        'Premiers pas en salle : un exercice par grand mouvement, charges '
            'modérées, technique avant tout.',
        Level.beginner,
        Goal.fitness,
        'photo-1758875568800-29fb434c7b17',
        [
          _r('goblet', 3, 12, 90, load: 'Haltère 8-16 kg'),
          _r('db_bench', 3, 10, 90, load: 'RPE 7'),
          _r('cable_row', 3, 12, 90),
          _r('db_shoulder', 2, 12, 75),
          _r('glutebridge', 3, 15, 60),
          _t('plank', 3, 30, 45),
        ],
      ),
      'amira',
    ),
    SeedWorkout(
      w(
        'fb_b',
        'Full Body B — Débutant',
        'Corps entier',
        'Seconde séance du cycle débutant, pour varier les mouvements.',
        Level.beginner,
        Goal.fitness,
        'photo-1641337221253-fdc7237f6b61',
        [
          _r('legpress', 3, 12, 90),
          _r('pushup', 3, 10, 75, notes: 'Sur les genoux si nécessaire.'),
          _r('latpull', 3, 12, 90),
          _r('rdl', 3, 10, 90, load: 'Barre légère ou haltères'),
          _r('db_curl', 2, 12, 60),
          _r('crunch', 3, 15, 45),
        ],
      ),
      'amira',
    ),
    SeedWorkout(
      w(
        'upper',
        'Upper Body',
        'Haut du corps',
        'Haut du corps complet pour le split Upper/Lower.',
        Level.intermediate,
        Goal.muscleGain,
        'photo-1526506118085-60ce8714f8c5',
        [
          _r('db_bench', 4, 8, 120),
          _r('bb_row', 4, 8, 120),
          _r('db_shoulder', 3, 10, 90),
          _r('latpull', 3, 10, 90),
          _r('skull', 3, 12, 60),
          _r('db_curl', 3, 12, 60),
        ],
      ),
      'admin',
    ),
    SeedWorkout(
      w(
        'lower',
        'Lower Body',
        'Bas du corps · Fessiers',
        'Bas du corps complet avec un accent sur les fessiers.',
        Level.intermediate,
        Goal.muscleGain,
        'photo-1649888317149-05d953c9fef8',
        [
          _r('squat', 4, 8, 150),
          _r('hipthrust', 4, 10, 90),
          _r('bulgarian', 3, 10, 90, notes: 'Par jambe.'),
          _r('legext', 3, 12, 60),
          _r('legcurl', 3, 12, 60),
          _r('calf', 3, 15, 45),
        ],
      ),
      'admin',
    ),
    SeedWorkout(
      w(
        'hiit_home',
        'HIIT Maison brûle-graisse',
        'Cardio · Corps entier · Sans matériel',
        'Circuit sans matériel : enchaînez chaque exercice, récupérez, '
            'puis refaites 3 tours.',
        Level.beginner,
        Goal.weightLoss,
        'photo-1714646442330-9068099f5521',
        [
          _t('jacks', 3, 40, 30),
          _r('burpee', 3, 10, 45),
          _t('mountain', 3, 30, 30),
          _t('highknees', 3, 30, 30),
          _r('pushup', 3, 10, 45),
          _r('glutebridge', 3, 15, 30),
          _t('plank', 3, 30, 30),
        ],
      ),
      'sarra',
    ),
    SeedWorkout(
      w(
        'core',
        'Core & Abdos',
        'Sangle abdominale',
        'Gainage et abdominaux pour un tronc solide et un dos protégé.',
        Level.beginner,
        Goal.fitness,
        'photo-1591258370814-01609b341790',
        [
          _t('plank', 3, 40, 30),
          _r('crunch', 3, 15, 30),
          _r('legraise', 3, 12, 45),
          _r('russian', 3, 20, 30, notes: '10 rotations par côté.'),
          _r('birddog', 3, 10, 30, notes: 'Par côté.'),
          _t('mountain', 3, 30, 30),
        ],
      ),
      'sarra',
    ),
    SeedWorkout(
      w(
        'cardio_kb',
        'Cardio Kettlebell',
        'Endurance · Puissance',
        'Séance d\'endurance mêlant kettlebell, vélo et corde à sauter.',
        Level.intermediate,
        Goal.endurance,
        'photo-1706029831387-fd8bc3d27d01',
        [
          _t(
            'bike',
            1,
            600,
            60,
            notes: 'Échauffement 10 min à allure modérée.',
          ),
          _r('kbswing', 5, 15, 45, load: 'Kettlebell 12-20 kg'),
          _t('jumprope', 4, 60, 45),
          _r('burpee', 3, 12, 45),
          _t('highknees', 3, 30, 30),
        ],
      ),
      'sarra',
    ),
    SeedWorkout(
      w(
        'mobility',
        'Mobilité & étirements',
        'Hanches · Dos · Ischios',
        'Routine douce de mobilité et d\'étirements, idéale les jours de repos.',
        Level.beginner,
        Goal.fitness,
        'photo-1593204075264-0b7994458bf3',
        [
          _r('catcow', 2, 10, 15),
          _r('worldsgreatest', 2, 5, 20, notes: '5 par côté.'),
          _t('childpose', 2, 45, 15),
          _t('pigeon', 2, 45, 15, notes: 'Par côté.'),
          _t('hipflexor', 2, 40, 15, notes: 'Par côté.'),
          _t('quadstretch', 2, 30, 15),
          _t('hamstringband', 2, 40, 15),
          _r('birddog', 2, 10, 30),
        ],
      ),
      'amira',
    ),
  ];
}

class SeedProgram {
  const SeedProgram(this.program, this.author);
  final Program program;
  final String author;
}

List<SeedProgram> seedPrograms(DateTime at) {
  Program p(
    String key,
    String name,
    String description,
    Level level,
    Goal goal,
    int weeks,
    String equipment,
    String cover,
    Map<int, String> days,
  ) => Program(
    id: 'p_$key',
    name: name,
    description: description,
    level: level,
    goal: goal,
    weeks: weeks,
    equipment: equipment,
    coverImage: unsplash(cover),
    days: [
      for (final e in days.entries)
        ProgramDay(weekday: e.key, workoutId: 'w_${e.value}'),
    ],
    authorId: '',
    createdAt: at,
  );

  return [
    SeedProgram(
      p(
        'ppl',
        'Push / Pull / Legs — 6 jours',
        'Le split le plus populaire pour la prise de masse : chaque groupe '
            'musculaire est travaillé deux fois par semaine.',
        Level.advanced,
        Goal.muscleGain,
        8,
        'Salle complète',
        'photo-1534368959876-26bf04f2c947',
        {1: 'push', 2: 'pull', 3: 'legs', 4: 'push', 5: 'pull', 6: 'legs'},
      ),
      'mehdi',
    ),
    SeedProgram(
      p(
        'fullbody',
        'Full Body 3 jours — Débutant',
        'Trois séances corps entier par semaine avec un jour de repos entre '
            'chaque : le meilleur départ recommandé par l\'ACSM.',
        Level.beginner,
        Goal.fitness,
        6,
        'Haltères, poulies, machines',
        'photo-1758875568800-29fb434c7b17',
        {1: 'fb_a', 3: 'fb_b', 5: 'fb_a'},
      ),
      'amira',
    ),
    SeedProgram(
      p(
        'upperlower',
        'Upper / Lower — 4 jours',
        'Haut et bas du corps en alternance, deux fois par semaine : '
            'équilibre idéal entre volume et récupération.',
        Level.intermediate,
        Goal.muscleGain,
        8,
        'Salle complète',
        'photo-1581009146145-b5ef050c2e1e',
        {1: 'upper', 2: 'lower', 4: 'upper', 5: 'lower'},
      ),
      'admin',
    ),
    SeedProgram(
      p(
        'weightloss_home',
        'Perte de poids à la maison',
        'Circuits sans matériel, gainage et mobilité : 4 séances courtes par '
            'semaine pour brûler des calories sans aller à la salle.',
        Level.beginner,
        Goal.weightLoss,
        6,
        'Aucun (tapis conseillé)',
        'photo-1571019613454-1cb2f99b2d8b',
        {1: 'hiit_home', 3: 'core', 5: 'hiit_home', 7: 'mobility'},
      ),
      'sarra',
    ),
    SeedProgram(
      p(
        'mobility',
        'Mobilité & étirements',
        'Trois routines hebdomadaires pour gagner en souplesse, soulager le '
            'dos et mieux récupérer.',
        Level.beginner,
        Goal.fitness,
        4,
        'Tapis, élastique',
        'photo-1593431763017-c689a61b729a',
        {2: 'mobility', 4: 'mobility', 6: 'mobility'},
      ),
      'amira',
    ),
    SeedProgram(
      p(
        'endurance',
        'Endurance & cardio',
        'Kettlebell, HIIT et gainage pour améliorer votre condition physique.',
        Level.intermediate,
        Goal.endurance,
        6,
        'Kettlebell, vélo, corde',
        'photo-1633394782240-f81aba3f850d',
        {1: 'cardio_kb', 3: 'hiit_home', 5: 'core'},
      ),
      'sarra',
    ),
  ];
}
