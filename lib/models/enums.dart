import 'package:flutter/material.dart';

/// Énumérations métier et leurs libellés en français.

T enumFrom<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

enum UserRole {
  superAdmin('Super Admin', Icons.admin_panel_settings),
  coach('Coach', Icons.sports),
  member('Abonné', Icons.person);

  const UserRole(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum Goal {
  weightLoss('Perte de poids', Icons.local_fire_department),
  muscleGain('Prise de masse', Icons.fitness_center),
  fitness('Forme', Icons.favorite),
  endurance('Endurance', Icons.directions_run);

  const Goal(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum Gender {
  female('Femme'),
  male('Homme');

  const Gender(this.label);
  final String label;
}

enum SubscriptionType {
  none('Aucun', 0, 0),
  trial('Essai 7 jours', 0, 0),
  monthly('Mensuel', 1, 89),
  quarterly('Trimestriel', 3, 240),
  yearly('Annuel', 12, 850);

  const SubscriptionType(this.label, this.months, this.price);
  final String label;
  final int months;
  final double price;
}

enum Muscle {
  chest('Pectoraux'),
  back('Dos'),
  shoulders('Épaules'),
  biceps('Biceps'),
  triceps('Triceps'),
  quads('Quadriceps'),
  hamstrings('Ischio-jambiers'),
  glutes('Fessiers'),
  calves('Mollets'),
  abs('Abdominaux'),
  fullBody('Corps entier'),
  cardio('Cardio');

  const Muscle(this.label);
  final String label;
}

enum Equipment {
  bodyweight('Poids du corps'),
  dumbbell('Haltères'),
  barbell('Barre'),
  machine('Machine'),
  cable('Poulie'),
  kettlebell('Kettlebell'),
  band('Élastique'),
  cardioMachine('Machine cardio'),
  mat('Tapis');

  const Equipment(this.label);
  final String label;
}

enum Level {
  beginner('Débutant'),
  intermediate('Intermédiaire'),
  advanced('Avancé');

  const Level(this.label);
  final String label;
}

enum ExerciseType {
  strength('Force'),
  cardio('Cardio'),
  mobility('Mobilité'),
  stretching('Étirement');

  const ExerciseType(this.label);
  final String label;
}

enum MediaKind {
  image('Image'),
  video('Vidéo'),
  youtube('YouTube');

  const MediaKind(this.label);
  final String label;
}

enum CourseCategory {
  yoga('Yoga', Icons.self_improvement),
  hiit('HIIT', Icons.bolt),
  spinning('Spinning', Icons.pedal_bike),
  boxing('Boxe', Icons.sports_mma),
  pilates('Pilates', Icons.accessibility_new),
  zumba('Zumba', Icons.music_note),
  strength('Musculation', Icons.fitness_center),
  stretching('Stretching', Icons.airline_seat_flat);

  const CourseCategory(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum CourseStatus {
  toPlan('À planifier'),
  scheduled('Programmé'),
  done('Terminé'),
  cancelled('Annulé');

  const CourseStatus(this.label);
  final String label;
}

enum ReservationStatus {
  confirmed('Confirmée'),
  waitlisted("Liste d'attente"),
  cancelled('Annulée');

  const ReservationStatus(this.label);
  final String label;
}

enum ProductCategory {
  supplements('Compléments', Icons.science),
  accessories('Accessoires', Icons.sports_gymnastics),
  clothing('Vêtements', Icons.checkroom),
  drinks('Boissons', Icons.local_drink);

  const ProductCategory(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum OrderStatus {
  paid('Payée'),
  prepared('Préparée'),
  delivered('Remise');

  const OrderStatus(this.label);
  final String label;
}

enum NotificationType {
  course(Icons.event),
  reservation(Icons.event_available),
  waitlist(Icons.hourglass_top),
  order(Icons.shopping_bag),
  kudos(Icons.thumb_up),
  announcement(Icons.campaign),
  system(Icons.info);

  const NotificationType(this.icon);
  final IconData icon;
}
