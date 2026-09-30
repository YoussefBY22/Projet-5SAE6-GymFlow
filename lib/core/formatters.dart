import 'package:intl/intl.dart';

/// Formatage des montants, dates et durées (français, dinar tunisien).
class Fmt {
  Fmt._();

  static final NumberFormat _tnd = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: 'TND',
    decimalDigits: 2,
  );
  static final NumberFormat _int = NumberFormat.decimalPattern('fr_FR');
  static final NumberFormat _dec1 = NumberFormat('#,##0.0', 'fr_FR');

  static String money(double amount) => _tnd.format(amount);
  static String number(num n) => _int.format(n);
  static String dec1(num n) => _dec1.format(n);

  static String day(DateTime d) => DateFormat('EEEE d MMMM', 'fr_FR').format(d);
  static String dayShort(DateTime d) =>
      DateFormat('EEE d MMM', 'fr_FR').format(d);
  static String date(DateTime d) => DateFormat('dd/MM/yyyy', 'fr_FR').format(d);
  static String time(DateTime d) => DateFormat('HH:mm', 'fr_FR').format(d);
  static String dateTime(DateTime d) =>
      DateFormat("EEE d MMM 'à' HH:mm", 'fr_FR').format(d);
  static String monthYear(DateTime d) =>
      DateFormat('MMMM yyyy', 'fr_FR').format(d);
  static String weekdayLetter(DateTime d) =>
      DateFormat('E', 'fr_FR').format(d).substring(0, 1).toUpperCase();

  /// Durée « 1 h 05 », « 12 min », « 45 s ».
  static String duration(Duration d) {
    if (d.inHours > 0) {
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      return '${d.inHours} h $m';
    }
    if (d.inMinutes > 0) return '${d.inMinutes} min';
    return '${d.inSeconds} s';
  }

  /// Chronomètre « 03:25 » ou « 1:03:25 ».
  static String clock(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  /// Date relative façon fil d'actualité : « il y a 3 h », « hier »…
  static String relative(DateTime d, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final diff = ref.difference(d);
    if (diff.isNegative) {
      final ahead = d.difference(ref);
      if (ahead.inMinutes < 60) return 'dans ${ahead.inMinutes + 1} min';
      if (ahead.inHours < 24) return 'dans ${ahead.inHours} h';
      if (ahead.inDays == 1) return 'demain';
      return 'dans ${ahead.inDays} j';
    }
    if (diff.inMinutes < 1) return "à l'instant";
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays == 1) return 'hier';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
    return date(d);
  }

  static String kg(double v) =>
      v == v.roundToDouble() ? '${v.toInt()} kg' : '${dec1(v)} kg';

  static String plural(int n, String singular, [String? pluralForm]) =>
      '$n ${n > 1 ? (pluralForm ?? '${singular}s') : singular}';
}
