// Petits utilitaires de (dé)sérialisation JSON partagés par les modèles.

typedef Json = Map<String, dynamic>;

int? dateToJson(DateTime? d) => d?.millisecondsSinceEpoch;

DateTime? dateFromJson(Object? v) =>
    v == null ? null : DateTime.fromMillisecondsSinceEpoch((v as num).toInt());

DateTime dateOr(Object? v, DateTime fallback) => dateFromJson(v) ?? fallback;

List<String> stringList(Object? v) =>
    v == null ? <String>[] : (v as List).map((e) => e.toString()).toList();

double toDouble(Object? v, [double fallback = 0]) =>
    v == null ? fallback : (v as num).toDouble();

double? toDoubleOrNull(Object? v) => v == null ? null : (v as num).toDouble();

int toInt(Object? v, [int fallback = 0]) =>
    v == null ? fallback : (v as num).toInt();

int? toIntOrNull(Object? v) => v == null ? null : (v as num).toInt();

List<Json> jsonList(Object? v) => v == null
    ? <Json>[]
    : (v as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
