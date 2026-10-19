import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/content.dart';
import '../../services/backend.dart';
import '../../widgets/animations.dart';
import '../../widgets/common.dart';
import '../../widgets/pickers.dart';

// --- IMPORTS IA ---
import 'package:gymflow/services/ai/cloud_ai_service.dart';
import 'package:gymflow/services/ai/local_ai_service.dart';

/// File de validation (coachs et admin) : contenus proposés par les
/// abonnés, à accepter (publiés pour tous) ou refuser avec un motif.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  static String routeOf(ContentKind k) => switch (k) {
    ContentKind.exercise => Routes.exercise,
    ContentKind.workout => Routes.workout,
    ContentKind.program => Routes.program,
  };

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  // --- VARIABLES IA ---
  final CloudAIService _cloudAI = CloudAIService();
  final LocalAIService _localAI = LocalAIService();
  
  // État pour le dialogue de refus avec IA
  String? _aiGeneratedReason;
  bool _isGeneratingReason = false;

  // État pour l'analyse locale
  String? _localScanResult;

  @override
  void dispose() {
    _localAI.dispose();
    super.dispose();
  }

  // --- MÉTHODE 1 : API Cloud (Générer un motif de refus) ---
  Future<void> _generateReasonWithAI(String itemName) async {
    setState(() {
      _isGeneratingReason = true;
      _aiGeneratedReason = "Rédaction du motif par l'IA...";
    });

    // Prompt envoyé à Gemini
    final prompt = """
    Tu es un coach sportif bienveillant. Tu dois refuser la publication de l'élément suivant : "$itemName".
    Rédige un motif de refus en français (2 phrases maximum). 
    Sois poli, explique que la sécurité ou la qualité n'est pas suffisante, et donne un conseil pour s'améliorer.
    """;

    try {
      final reason = await _cloudAI.generateText(prompt);
      if (mounted) {
        setState(() {
          _aiGeneratedReason = reason;
          _isGeneratingReason = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiGeneratedReason = "Erreur IA : impossible de générer le motif.";
          _isGeneratingReason = false;
        });
      }
    }
  }

  // --- MÉTHODE 2 : Modèle Local (Analyse de texte) ---
  Future<void> _analyzeTextWithLocalAI(String textToAnalyze) async {
    final result = await _localAI.analyzeSentiment(textToAnalyze);
    setState(() {
      _localScanResult = result;
    });
  }

  Future<void> _reject(BuildContext context, LibraryItem x) async {
    // On réinitialise l'IA avant d'ouvrir le dialogue
    _aiGeneratedReason = null;
    _localScanResult = null;

    final reason = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Refuser « ${x.name} »'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- CARTE 1 : IA Cloud (Générer motif) ---
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.cloud, color: Colors.blue, size: 20),
                                const SizedBox(width: 8),
                                const Text("Coach IA (API Cloud)", style: TextStyle(fontWeight: FontWeight.bold)),
                                const Spacer(),
                                TextButton(
                                  onPressed: _isGeneratingReason 
                                    ? null 
                                    : () async {
                                        await _generateReasonWithAI(x.name);
                                        setStateDialog(() {});
                                      },
                                  child: const Text("Générer"),
                                ),
                              ],
                            ),
                            if (_aiGeneratedReason != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  _aiGeneratedReason!,
                                  style: const TextStyle(fontStyle: FontStyle.italic),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- CARTE 2 : Modèle Local (Analyse de texte) ---
                    Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.phone_android, color: Colors.green, size: 20),
                                const SizedBox(width: 8),
                                const Text("Modèle Local (Analyse)", style: TextStyle(fontWeight: FontWeight.bold)),
                                const Spacer(),
                                TextButton(
                                  onPressed: () async {
                                    await _analyzeTextWithLocalAI(_aiGeneratedReason ?? "");
                                    setStateDialog(() {});
                                  },
                                  child: const Text("Analyser"),
                                ),
                              ],
                            ),
                            if (_localScanResult != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  _localScanResult!,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // --- CHAMP DE SAISIE DU MOTIF ---
                    const Text("Motif communiqué à l'auteur :"),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: _aiGeneratedReason, // Pré-rempli si l'IA a généré
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Ex. ajoutez une étape, précisez le repos…',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        // On garde une trace de ce que l'utilisateur tape
                        _aiGeneratedReason = value; 
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Annuler"),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, _aiGeneratedReason);
                  },
                  child: const Text("Envoyer le refus"),
                ),
              ],
            );
          },
        );
      },
    );

    if (reason == null || reason.isEmpty || !context.mounted) return;
    
    // Appel à votre logique métier existante (INCHANGÉE)
    await runAction(
      context,
      () => Backend.I.library.reject(x.kind, x.id, reason),
      success: 'Refus envoyé à l\'auteur.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    return Scaffold(
      appBar: AppBar(title: const Text('Propositions à valider')),
      body: ListenableBuilder(
        listenable: b.bus,
        builder: (context, _) {
          final queue = b.library.reviewQueue();
          if (queue.isEmpty) {
            return const EmptyState(
              icon: Icons.fact_check_outlined,
              title: 'Rien à valider',
              message:
                  'Les exercices, workouts et programmes proposés par les '
                  'membres apparaîtront ici.',
            );
          }
          return ListView(
            padding: pagePadding(context, maxWidth: 900),
            children: [
              const GfCard(
                color: AppColors.cream,
                child: InfoRow(
                  Icons.info_outline,
                  'Vérifiez la sécurité des consignes (charges, amplitude, '
                  'repos) et la qualité des médias avant de publier. '
                  'Un refus doit toujours être motivé.',
                ),
              ),
              const SizedBox(height: Gap.m),
              for (var i = 0; i < queue.length; i++)
                FadeSlideIn(
                  index: i,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: Gap.s),
                    child: _ReviewCard(
                      item: queue[i],
                      onReject: () => _reject(context, queue[i]),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// --- LE WIDGET _ReviewCard RESTE TOTALEMENT INCHANGÉ ---
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.item, required this.onReject});
  final LibraryItem item;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    final x = item;
    final deps = b.library
        .dependenciesOf(x)
        .where((d) => d.publication.isPending)
        .toList();
    return GfCard(
      key: ValueKey('review_${x.id}'),
      onTap: () => Navigator.pushNamed(
        context,
        ReviewScreen.routeOf(x.kind),
        arguments: x.id,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.navy,
                child: Icon(x.kind.icon, color: AppColors.white, size: 20),
              ),
              const SizedBox(width: Gap.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(x.name, style: AppText.subtitle()),
                    if (x.altName != null)
                      Text(
                        x.altName!,
                        style: AppText.label(
                          size: 12,
                        ).copyWith(fontStyle: FontStyle.italic),
                      ),
                    Text(
                      '${x.kind.label} · ${b.library.authorLabel(x)}'
                      '${x.publication.submittedAt == null ? '' : ' · ${Fmt.relative(x.publication.submittedAt!, now: b.now())}'}',
                      style: AppText.label(size: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.navy),
            ],
          ),
          if (deps.isNotEmpty) ...[
            const SizedBox(height: Gap.s),
            InfoRow(
              Icons.link,
              'Publié avec : ${deps.map((d) => '${d.kind.lower} « ${d.name} »').join(', ')}',
            ),
          ],
          const SizedBox(height: Gap.s),
          Wrap(
            spacing: Gap.s,
            runSpacing: Gap.s,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.red),
                onPressed: onReject,
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Refuser'),
              ),
              ElevatedButton.icon(
                key: ValueKey('approve_${x.id}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: AppColors.white,
                ),
                onPressed: () => runAction(
                  context,
                  () => b.library.approve(x.kind, x.id),
                  success: '« ${x.name} » est publié.',
                ),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Publier'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}