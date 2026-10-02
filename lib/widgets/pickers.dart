import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/errors.dart';
import '../core/theme.dart';
import '../models/enums.dart';
import '../services/backend.dart';
import 'common.dart';

/// Sélection de médias (image_picker / file_picker) avec contrôle du type
/// et de la taille, puis copie dans le dossier privé de l'application.

Future<String?> pickImageFile(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choisir dans la galerie'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Prendre une photo'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;
  try {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return null;
    return await Backend.I.media.importFile(file.path, MediaKind.image);
  } catch (e) {
    if (context.mounted) {
      showSnack(
        context,
        e is AppException ? e.message : 'Impossible d\'accéder aux photos.',
        error: true,
      );
    }
    return null;
  }
}

Future<String?> pickVideoFile(BuildContext context) async {
  try {
    final files = await FilePicker.pickFiles(type: FileType.video);
    if (files.isEmpty || files.first.path == null) return null;
    return await Backend.I.media.importFile(files.first.path!, MediaKind.video);
  } catch (e) {
    if (context.mounted) {
      showSnack(
        context,
        e is AppException ? e.message : 'Impossible d\'importer la vidéo.',
        error: true,
      );
    }
    return null;
  }
}

/// Boîte de saisie d'un lien (URL d'image, lien YouTube…).
Future<String?> askText(
  BuildContext context, {
  required String title,
  required String label,
  String? hint,
  String? Function(String?)? validator,
  String initial = '',
  bool obscure = false,
}) async {
  final formKey = GlobalKey<FormState>();
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          obscureText: obscure,
          decoration: InputDecoration(labelText: label, hintText: hint),
          validator: validator,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(96, 44)),
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(ctx, controller.text.trim());
            }
          },
          child: const Text('Valider'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

/// Titre de section de formulaire.
class FormSection extends StatelessWidget {
  const FormSection(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Gap.l, bottom: Gap.s),
    child: Text(title, style: AppText.subtitle(size: 16)),
  );
}

/// Liste déroulante typée pour les énumérations.
class EnumDropdown<T> extends StatelessWidget {
  const EnumDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.values,
    required this.labelOf,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      dropdownColor: AppColors.white,
      items: [
        for (final v in values)
          DropdownMenuItem(
            value: v,
            child: Text(labelOf(v), style: AppText.body()),
          ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
