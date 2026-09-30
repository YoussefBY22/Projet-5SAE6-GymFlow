import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/config.dart';
import '../core/errors.dart';
import '../models/enums.dart';

/// Stockage local des fichiers uploadés (photos, vidéos) dans le dossier
/// privé de l'application, avec contrôle du type et de la taille.
class MediaStorage {
  /// Vérifie extension et taille (fonction pure, testée).
  static void validate(String fileName, int sizeBytes, MediaKind kind) {
    final ext = p.extension(fileName).replaceFirst('.', '').toLowerCase();
    if (kind == MediaKind.image) {
      if (!AppConfig.imageExtensions.contains(ext)) {
        throw const ValidationException(
          'Format d\'image non accepté (JPG, PNG ou WEBP).',
        );
      }
      if (sizeBytes > AppConfig.maxImageBytes) {
        throw const ValidationException('Image trop lourde (10 Mo maximum).');
      }
    } else {
      if (!AppConfig.videoExtensions.contains(ext)) {
        throw const ValidationException(
          'Format vidéo non accepté (MP4, MOV, WEBM, 3GP, MKV).',
        );
      }
      if (sizeBytes > AppConfig.maxVideoBytes) {
        throw const ValidationException('Vidéo trop lourde (100 Mo maximum).');
      }
    }
    if (sizeBytes <= 0) throw const ValidationException('Fichier vide.');
  }

  /// Copie le fichier choisi dans le dossier de l'application et renvoie
  /// son nouveau chemin.
  Future<String> importFile(String sourcePath, MediaKind kind) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const ValidationException('Fichier introuvable.');
    }
    validate(sourcePath, await source.length(), kind);
    final dir = Directory(
      p.join((await getApplicationDocumentsDirectory()).path, 'media'),
    );
    if (!await dir.exists()) await dir.create(recursive: true);
    final ext = p.extension(sourcePath).toLowerCase();
    final name = '${kind.name}_${DateTime.now().microsecondsSinceEpoch}$ext';
    final copy = await source.copy(p.join(dir.path, name));
    return copy.path;
  }
}
