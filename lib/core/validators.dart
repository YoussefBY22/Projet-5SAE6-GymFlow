/// Validateurs des formulaires (utilisés dans les `TextFormField.validator`).
class Validators {
  Validators._();

  static final RegExp _email = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

  static String? required(String? v, [String field = 'Ce champ']) {
    if (v == null || v.trim().isEmpty) return '$field est obligatoire.';
    return null;
  }

  static String? email(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return "L'adresse e-mail est obligatoire.";
    if (value.length > 120 || !_email.hasMatch(value)) {
      return 'Adresse e-mail invalide.';
    }
    return null;
  }

  /// Mot de passe : 8 caractères minimum, une lettre et un chiffre.
  static String? password(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Le mot de passe est obligatoire.';
    if (value.length < 8) return '8 caractères minimum.';
    if (value.length > 64) return '64 caractères maximum.';
    if (!RegExp(r'[A-Za-z]').hasMatch(value) ||
        !RegExp(r'\d').hasMatch(value)) {
      return 'Au moins une lettre et un chiffre.';
    }
    return null;
  }

  static String? name(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Le nom est obligatoire.';
    if (value.length < 2) return 'Nom trop court.';
    if (value.length > 60) return 'Nom trop long (60 max).';
    if (RegExp(r'[<>{}\[\]\\]').hasMatch(value)) {
      return 'Caractères non autorisés.';
    }
    return null;
  }

  static String? Function(String?) text({
    required String field,
    int min = 1,
    int max = 500,
    bool optional = false,
  }) {
    return (v) {
      final value = v?.trim() ?? '';
      if (value.isEmpty) return optional ? null : '$field est obligatoire.';
      if (value.length < min) return '$field : $min caractères minimum.';
      if (value.length > max) return '$field : $max caractères maximum.';
      return null;
    };
  }

  static String? Function(String?) intRange({
    required String field,
    required int min,
    required int max,
    bool optional = false,
  }) {
    return (v) {
      final value = v?.trim() ?? '';
      if (value.isEmpty) return optional ? null : '$field est obligatoire.';
      final n = int.tryParse(value);
      if (n == null) return '$field : nombre entier attendu.';
      if (n < min || n > max) return '$field : entre $min et $max.';
      return null;
    };
  }

  static String? Function(String?) decimalRange({
    required String field,
    required double min,
    required double max,
    bool optional = false,
  }) {
    return (v) {
      final value = (v?.trim() ?? '').replaceAll(',', '.');
      if (value.isEmpty) return optional ? null : '$field est obligatoire.';
      final n = double.tryParse(value);
      if (n == null) return '$field : nombre attendu.';
      if (n < min || n > max) return '$field : entre $min et $max.';
      return null;
    };
  }

  static String? url(String? v, {bool optional = true}) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return optional ? null : "L'adresse est obligatoire.";
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || !uri.scheme.startsWith('http')) {
      return 'Adresse web invalide (https://…).';
    }
    return null;
  }

  static double? parseDecimal(String? v) =>
      double.tryParse((v ?? '').trim().replaceAll(',', '.'));
}
