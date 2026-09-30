import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../core/theme.dart';
import '../models/enums.dart';
import '../models/exercise.dart';
import 'common.dart';

/// Extrait l'identifiant d'une vidéo YouTube depuis un lien ou un ID.
/// Formats acceptés : watch?v=, youtu.be/, shorts/, embed/, ID seul.
String? youtubeId(String input) {
  final s = input.trim();
  if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(s)) return s;
  final uri = Uri.tryParse(s);
  if (uri == null || !uri.hasScheme) return null;
  final host = uri.host.replaceFirst('www.', '').replaceFirst('m.', '');
  String? id;
  if (host == 'youtu.be') {
    id = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
  } else if (host.endsWith('youtube.com') ||
      host.endsWith('youtube-nocookie.com')) {
    if (uri.queryParameters['v'] != null) {
      id = uri.queryParameters['v'];
    } else if (uri.pathSegments.length >= 2 &&
        ['shorts', 'embed', 'live', 'v'].contains(uri.pathSegments.first)) {
      id = uri.pathSegments[1];
    }
  }
  if (id == null || !RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)) return null;
  return id;
}

String youtubeThumb(String id) =>
    'https://img.youtube.com/vi/$id/hqdefault.jpg';

/// Vignettes possibles d'un exercice, par ordre de préférence :
/// 1re image (wger ou upload), puis miniature de la vidéo YouTube.
List<String> exerciseThumbs(Exercise e) {
  final ytId = e.media
      .where((m) => m.kind == MediaKind.youtube)
      .map((m) => youtubeId(m.source))
      .whereType<String>()
      .firstOrNull;
  return [
    if (e.images.isNotEmpty) e.images.first.source,
    if (ytId != null) youtubeThumb(ytId),
  ];
}

String? exerciseThumb(Exercise e) => exerciseThumbs(e).firstOrNull;

/// Image d'un exercice avec repli automatique (image → YouTube → icône).
class ExerciseImage extends StatelessWidget {
  const ExerciseImage(
    this.exercise, {
    super.key,
    this.fit = BoxFit.cover,
    this.cacheWidth = 800,
  });

  final Exercise exercise;
  final BoxFit fit;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    final thumbs = exerciseThumbs(exercise);
    return NetImage(
      thumbs.firstOrNull,
      fit: fit,
      cacheWidth: cacheWidth,
      fallbackSources: thumbs.skip(1).toList(),
    );
  }
}

/// Lecteur YouTube intégré (lu directement dans l'application).
/// Le lecteur n'est créé qu'au toucher de la miniature (performance).
class YoutubeView extends StatefulWidget {
  const YoutubeView({super.key, required this.videoId, this.autoStart = false});
  final String videoId;
  final bool autoStart;

  @override
  State<YoutubeView> createState() => _YoutubeViewState();
}

class _YoutubeViewState extends State<YoutubeView> {
  YoutubePlayerController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) _start();
  }

  void _start() {
    setState(() {
      _controller = YoutubePlayerController.fromVideoId(
        videoId: widget.videoId,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showFullscreenButton: true,
          interfaceLanguage: 'fr',
          captionLanguage: 'fr',
          strictRelatedVideos: true,
        ),
      );
    });
  }

  @override
  void didUpdateWidget(covariant YoutubeView old) {
    super.didUpdateWidget(old);
    if (old.videoId != widget.videoId && _controller != null) {
      _controller!.loadVideoById(videoId: widget.videoId);
    }
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  Future<void> _openExternal() async {
    final uri = Uri.parse('https://www.youtube.com/watch?v=${widget.videoId}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Gap.radius),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: c != null
                ? YoutubePlayer(controller: c, aspectRatio: 16 / 9)
                : GestureDetector(
                    onTap: _start,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        NetImage(
                          youtubeThumb(widget.videoId),
                          fallbackIcon: Icons.smart_display,
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(color: Color(0x66000000)),
                        ),
                        Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: AppColors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow,
                              color: AppColors.white,
                              size: 40,
                              semanticLabel: 'Lire la vidéo',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _openExternal,
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Ouvrir dans YouTube'),
          ),
        ),
      ],
    );
  }
}

/// Lecteur de vidéo (fichier uploadé ou URL MP4) : video_player + chewie.
/// La vidéo est initialisée à la demande et libérée au `dispose`.
class VideoFileView extends StatefulWidget {
  const VideoFileView({
    super.key,
    required this.source,
    this.autoStart = false,
  });
  final String source;
  final bool autoStart;

  @override
  State<VideoFileView> createState() => _VideoFileViewState();
}

class _VideoFileViewState extends State<VideoFileView> {
  VideoPlayerController? _video;
  ChewieController? _chewie;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final video = widget.source.startsWith('http')
        ? VideoPlayerController.networkUrl(Uri.parse(widget.source))
        : VideoPlayerController.file(File(widget.source));
    try {
      await video.initialize();
      if (!mounted) {
        await video.dispose();
        return;
      }
      setState(() {
        _video = video;
        _chewie = ChewieController(
          videoPlayerController: video,
          autoPlay: true,
          looping: true,
          aspectRatio: video.value.aspectRatio,
          materialProgressColors: ChewieProgressColors(
            playedColor: AppColors.red,
            handleColor: AppColors.red,
            bufferedColor: AppColors.navyMuted,
            backgroundColor: AppColors.inkSoft,
          ),
        );
        _loading = false;
      });
    } catch (_) {
      await video.dispose();
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Lecture impossible (connexion ou format).';
        });
      }
    }
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chewie = _chewie;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Gap.radius),
      child: AspectRatio(
        aspectRatio: chewie?.aspectRatio ?? 16 / 9,
        child: Container(
          color: AppColors.navy,
          child: chewie != null
              ? Chewie(controller: chewie)
              : Center(
                  child: _loading
                      ? const CircularProgressIndicator(color: AppColors.gold)
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton.filled(
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.red,
                                foregroundColor: AppColors.white,
                                minimumSize: const Size(64, 64),
                              ),
                              onPressed: _init,
                              icon: const Icon(Icons.play_arrow, size: 36),
                              tooltip: 'Lire la vidéo',
                            ),
                            const SizedBox(height: Gap.s),
                            Text(
                              _error ?? 'Vidéo de démonstration',
                              style: AppText.label(color: AppColors.white),
                            ),
                          ],
                        ),
                ),
        ),
      ),
    );
  }
}

/// Affiche un média d'exercice selon son type.
class MediaView extends StatelessWidget {
  const MediaView(this.media, {super.key, this.autoStart = false});
  final MediaItem media;
  final bool autoStart;

  @override
  Widget build(BuildContext context) {
    switch (media.kind) {
      case MediaKind.youtube:
        final id = youtubeId(media.source);
        if (id == null) return const SizedBox.shrink();
        return YoutubeView(videoId: id, autoStart: autoStart);
      case MediaKind.video:
        return VideoFileView(source: media.source, autoStart: autoStart);
      case MediaKind.image:
        return ClipRRect(
          borderRadius: BorderRadius.circular(Gap.radius),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: Container(
              color: AppColors.white,
              child: NetImage(media.source, fit: BoxFit.contain),
            ),
          ),
        );
    }
  }
}
