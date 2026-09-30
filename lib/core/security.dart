import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Hachage des mots de passe : PBKDF2-HMAC-SHA256 avec sel aléatoire.
/// Le mot de passe en clair n'est jamais stocké, affiché ni journalisé.
class PasswordHasher {
  PasswordHasher({this.iterations = defaultIterations, Random? random})
    : _random = random ?? Random.secure();

  static const int defaultIterations = 12000;
  static const int _keyLength = 32;
  static const int _saltLength = 16;

  final int iterations;
  final Random _random;

  /// Génère un sel aléatoire encodé en base64.
  String newSalt() {
    final bytes = Uint8List(_saltLength);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return base64Encode(bytes);
  }

  /// Calcule l'empreinte base64 d'un mot de passe avec le sel donné.
  String hash(String password, String salt, {int? rounds}) {
    final key = pbkdf2(
      utf8.encode(password),
      base64Decode(salt),
      rounds ?? iterations,
      _keyLength,
    );
    return base64Encode(key);
  }

  /// Vérifie un mot de passe en temps constant.
  bool verify(String password, String salt, String expected, int rounds) {
    final candidate = hash(password, salt, rounds: rounds);
    return constantTimeEquals(candidate, expected);
  }

  /// Implémentation PBKDF2 (RFC 8018) avec HMAC-SHA256.
  static Uint8List pbkdf2(
    List<int> password,
    List<int> salt,
    int rounds,
    int keyLength,
  ) {
    final hmac = Hmac(sha256, password);
    final out = BytesBuilder();
    var block = 1;
    while (out.length < keyLength) {
      final blockIndex = Uint8List(4)
        ..buffer.asByteData().setUint32(0, block);
      var u = hmac.convert([...salt, ...blockIndex]).bytes;
      final t = Uint8List.fromList(u);
      for (var i = 1; i < rounds; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      out.add(t);
      block++;
    }
    return Uint8List.fromList(out.toBytes().sublist(0, keyLength));
  }

  /// Comparaison en temps constant (évite les attaques temporelles).
  static bool constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}

/// Jeton de session aléatoire (stocké dans flutter_secure_storage).
String newSessionToken([Random? random]) {
  final r = random ?? Random.secure();
  final bytes = List<int>.generate(32, (_) => r.nextInt(256));
  return base64UrlEncode(bytes);
}

/// Empreinte SHA-256 d'un jeton : seule l'empreinte est gardée en base.
String tokenDigest(String token) => sha256.convert(utf8.encode(token)).toString();
