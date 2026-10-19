import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/ai_assistant_service.dart';
import '../services/backend.dart';

/// Bulle flottante de l'assistant IA (en bas à droite) : elle flotte
/// doucement et ouvre la discussion au toucher.
class AiChatBubble extends StatefulWidget {
  const AiChatBubble({super.key});

  @override
  State<AiChatBubble> createState() => _AiChatBubbleState();
}

class _AiChatBubbleState extends State<AiChatBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  // La discussion reste ouverte d'une ouverture à l'autre.
  final List<ChatMessage> _messages = [];

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  void _open() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => _ChatSheet(messages: _messages),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _float,
      builder: (context, child) {
        final t = _float.value * 2 * math.pi;
        return Transform.translate(
          offset: Offset(3 * math.cos(t), 6 * math.sin(t)),
          child: child,
        );
      },
      child: Tooltip(
        message: 'Assistant GymFlow',
        child: Material(
          key: const Key('ai_bubble'),
          color: AppColors.red,
          shape: const CircleBorder(),
          elevation: 6,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _open,
            child: const SizedBox(
              width: 58,
              height: 58,
              child: Icon(
                Icons.auto_awesome,
                color: AppColors.white,
                semanticLabel: 'Ouvrir l\'assistant',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatSheet extends StatefulWidget {
  const _ChatSheet({required this.messages});
  final List<ChatMessage> messages;

  @override
  State<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<_ChatSheet> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _waiting = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final q = (preset ?? _input.text).trim();
    if (q.isEmpty || _waiting) return;
    final history = List<ChatMessage>.of(widget.messages);
    setState(() {
      widget.messages.add(ChatMessage(true, q));
      _waiting = true;
      _input.clear();
    });
    _toBottom();
    final answer = await Backend.I.assistant.ask(q, history);
    if (!mounted) return;
    setState(() {
      widget.messages.add(ChatMessage(false, answer));
      _waiting = false;
    });
    _toBottom();
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  });

  @override
  Widget build(BuildContext context) {
    final msgs = widget.messages;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, Gap.s),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppColors.red),
                  const SizedBox(width: Gap.s),
                  Expanded(
                    child: Text(
                      'Assistant GymFlow',
                      style: AppText.title(size: 18),
                    ),
                  ),
                  Text('Gemini', style: AppText.label(size: 11)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: msgs.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(Gap.m),
                      children: [
                        Text(
                          'Posez une question sur la salle, les cours, la boutique '
                          'ou l\'application.',
                          style: AppText.body(color: AppColors.inkSoft),
                        ),
                        const SizedBox(height: Gap.m),
                        for (final s in const [
                          'Quels cours ont lieu cette semaine ?',
                          'Comment annuler une réservation ?',
                          'Comment partager ma séance ?',
                          'Conseille-moi un exercice pour le dos',
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: Gap.s),
                            child: ActionChip(
                              label: Text(s),
                              onPressed: () => _send(s),
                            ),
                          ),
                      ],
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(Gap.m),
                      itemCount: msgs.length + (_waiting ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == msgs.length) {
                          return const Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.all(Gap.s),
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        }
                        final m = msgs[i];
                        return Align(
                          alignment: m.fromUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: Gap.s),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            constraints: const BoxConstraints(maxWidth: 420),
                            decoration: BoxDecoration(
                              color: m.fromUser
                                  ? AppColors.navy
                                  : AppColors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: SelectableText(
                              m.text,
                              style: AppText.body(
                                size: 14,
                                color: m.fromUser
                                    ? AppColors.white
                                    : AppColors.ink,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Gap.m, Gap.s, Gap.s, Gap.m),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('ai_input'),
                        controller: _input,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        maxLength: 500,
                        decoration: const InputDecoration(
                          hintText: 'Votre question…',
                          counterText: '',
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton.filled(
                      key: const Key('ai_send'),
                      tooltip: 'Envoyer',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.red,
                        foregroundColor: AppColors.white,
                      ),
                      onPressed: _waiting ? null : _send,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
