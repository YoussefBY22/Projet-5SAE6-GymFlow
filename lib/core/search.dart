import '../models/enums.dart';

/// Recherche tolérante et bilingue (français / anglais).
///
/// 1. Normalisation : minuscules, sans accents ni ponctuation
///    (« Développé-couché » → « developpe couche »).
/// 2. Glossaire du sport : chaque groupe réunit les appellations
///    équivalentes d'un même mouvement ou d'une même notion dans les deux
///    langues. « bench press » cherche aussi « developpe couche »,
///    « pull up » cherche aussi « traction ». Ainsi un contenu saisi en
///    français est trouvé par un anglophone, même sans traduction.
/// 3. Chaque mot de la requête doit apparaître (le pluriel est toléré).
class Search {
  Search._();

  static String normalize(String s) {
    const from = 'àâäáãåéèêëíìîïóòôöõúùûüçñœæ';
    const to = 'aaaaaaeeeeiiiiooooouuuucnoa';
    final buf = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final i = from.indexOf(ch);
      if (i >= 0) {
        buf.write(to[i]);
      } else if (RegExp(r'[a-z0-9]').hasMatch(ch)) {
        buf.write(ch);
      } else {
        buf.write(' ');
      }
    }
    return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Groupes d'équivalences (déjà normalisés). Les expressions longues
  /// passent avant les mots seuls.
  static const List<List<String>> glossary = [
    // Mouvements
    ['developpe couche', 'bench press', 'dc'],
    ['developpe incline', 'incline press', 'incline bench'],
    [
      'developpe militaire',
      'overhead press',
      'military press',
      'shoulder press',
      'ohp',
    ],
    ['developpe', 'press'],
    ['traction', 'pull up', 'pullup', 'chin up', 'chinup'],
    ['pompe', 'push up', 'pushup', 'press up'],
    ['tirage vertical', 'lat pulldown', 'pulldown', 'pull down'],
    ['tirage horizontal', 'seated row', 'cable row', 'low row'],
    ['rowing', 'row'],
    ['souleve de terre roumain', 'romanian deadlift', 'rdl'],
    ['souleve de terre', 'deadlift'],
    ['squat bulgare', 'bulgarian split squat', 'split squat'],
    ['fente', 'lunge'],
    ['presse a cuisses', 'leg press'],
    ['gainage', 'planche', 'plank'],
    ['ecarte', 'fly', 'flye', 'flyes'],
    ['elevation laterale', 'lateral raise', 'side raise'],
    ['oiseau', 'rear delt fly', 'reverse fly'],
    ['curl marteau', 'hammer curl'],
    ['barre au front', 'skull crusher', 'skullcrusher'],
    ['extension triceps', 'triceps extension', 'pushdown'],
    ['pont fessier', 'glute bridge'],
    ['releve de jambes', 'leg raise'],
    ['montee de genoux', 'high knees'],
    ['corde a sauter', 'jump rope', 'skipping'],
    ['velo', 'bike', 'cycling', 'spinning'],
    ['tapis de course', 'treadmill'],
    ['course', 'running', 'run', 'jogging'],
    ['etirement', 'stretch', 'stretching'],
    ['echauffement', 'warm up', 'warmup'],
    ['mobilite', 'mobility'],
    ['posture de l enfant', 'child s pose', 'childs pose'],
    // Muscles et zones
    ['pectoraux', 'pecs', 'chest', 'poitrine'],
    ['dos', 'back'],
    ['epaules', 'shoulders', 'delts', 'deltoides'],
    ['quadriceps', 'quads', 'cuisses'],
    ['ischio jambiers', 'ischios', 'hamstrings'],
    ['fessiers', 'glutes', 'glute', 'fesses'],
    ['mollets', 'calves', 'calf'],
    ['abdominaux', 'abdos', 'abs', 'core', 'sangle abdominale'],
    ['jambes', 'legs', 'leg'],
    ['bras', 'arms'],
    ['haut du corps', 'upper body', 'upper'],
    ['bas du corps', 'lower body', 'lower'],
    ['corps entier', 'full body', 'fullbody'],
    // Matériel
    ['halteres', 'haltere', 'dumbbells', 'dumbbell', 'db'],
    ['barre', 'barbell'],
    ['poulie', 'cable'],
    ['elastique', 'band', 'resistance band'],
    ['poids du corps', 'bodyweight', 'body weight', 'sans materiel'],
    ['tapis', 'mat'],
    // Objectifs, niveaux, divers
    ['perte de poids', 'weight loss', 'fat loss', 'bruler des graisses'],
    ['prise de masse', 'muscle gain', 'hypertrophie', 'hypertrophy', 'bulk'],
    ['force', 'strength'],
    ['endurance', 'stamina'],
    ['forme', 'fitness'],
    ['debutant', 'beginner', 'novice'],
    ['intermediaire', 'intermediate'],
    ['avance', 'advanced', 'expert'],
    ['maison', 'home', 'at home'],
    ['seance', 'workout', 'session', 'entrainement', 'training'],
    ['programme', 'program'],
    ['jour', 'day', 'jours', 'days'],
    ['semaine', 'week', 'semaines', 'weeks'],
  ];

  static final Map<Muscle, String> muscleEn = {
    Muscle.chest: 'chest pecs',
    Muscle.back: 'back lats',
    Muscle.shoulders: 'shoulders delts',
    Muscle.biceps: 'biceps arms',
    Muscle.triceps: 'triceps arms',
    Muscle.quads: 'quads quadriceps legs',
    Muscle.hamstrings: 'hamstrings legs',
    Muscle.glutes: 'glutes',
    Muscle.calves: 'calves',
    Muscle.abs: 'abs core',
    Muscle.fullBody: 'full body',
    Muscle.cardio: 'cardio',
  };

  static final Map<Equipment, String> equipmentEn = {
    Equipment.bodyweight: 'bodyweight',
    Equipment.dumbbell: 'dumbbell',
    Equipment.barbell: 'barbell',
    Equipment.machine: 'machine',
    Equipment.cable: 'cable',
    Equipment.kettlebell: 'kettlebell',
    Equipment.band: 'band',
    Equipment.cardioMachine: 'cardio machine',
    Equipment.mat: 'mat',
  };

  static final Map<Level, String> levelEn = {
    Level.beginner: 'beginner',
    Level.intermediate: 'intermediate',
    Level.advanced: 'advanced',
  };

  static final Map<Goal, String> goalEn = {
    Goal.weightLoss: 'weight loss',
    Goal.muscleGain: 'muscle gain',
    Goal.fitness: 'fitness',
    Goal.endurance: 'endurance',
  };

  static bool _hasPhrase(String text, String phrase) =>
      ' $text '.contains(' $phrase ');

  /// Variantes de la requête obtenues par le glossaire (requête incluse).
  static List<String> expand(String query) {
    final q = normalize(query);
    if (q.isEmpty) return const [];
    // Variante au singulier (« pull ups » → « pull up », « tractions »).
    final singular = q
        .split(' ')
        .map(
          (w) => w.length >= 3 && w.endsWith('s') && !w.endsWith('ss')
              ? w.substring(0, w.length - 1)
              : w,
        )
        .join(' ');
    final variants = <String>{q, singular};
    for (final group in glossary) {
      for (final v in [...variants]) {
        if (variants.length > 40) break;
        for (final term in group) {
          if (!_hasPhrase(v, term)) continue;
          for (final other in group) {
            if (other == term) continue;
            variants.add(' $v '.replaceFirst(' $term ', ' $other ').trim());
          }
          break;
        }
      }
    }
    return variants.toList();
  }

  /// Mot de la requête présent dans le texte : mot entier pour les mots
  /// courts (« run » ne doit pas trouver « crunch »), début de mot sinon
  /// (« tract » trouve « tractions »). Pluriel simple toléré.
  static bool _wordIn(List<String> words, String word) {
    bool hit(String w) =>
        w.length <= 3 ? words.contains(w) : words.any((t) => t.startsWith(w));
    if (hit(word)) return true;
    if (word.length > 4 && word.endsWith('s')) {
      return hit(word.substring(0, word.length - 1));
    }
    return false;
  }

  /// La requête (ou l'une de ses variantes) correspond-elle au texte ?
  /// [variants] : résultat de [expand] (calculé une fois par recherche).
  static bool matches(List<String> variants, String haystack) {
    if (variants.isEmpty) return true;
    final words = normalize(haystack).split(' ');
    for (final v in variants) {
      if (v.split(' ').every((w) => _wordIn(words, w))) return true;
    }
    return false;
  }

  /// Score de pertinence : correspondance dans le titre d'abord.
  static int score(List<String> variants, String title) {
    if (variants.isEmpty) return 0;
    final t = normalize(title);
    for (final v in variants) {
      if (t.startsWith(v)) return 3;
      if (t.contains(v)) return 2;
    }
    return matches(variants, title) ? 1 : 0;
  }
}
