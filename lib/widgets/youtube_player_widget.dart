import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:new_project/utils/youtube_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:developer' as developer;

/// Reusable YouTube player widget with lifecycle management
/// Supports thumbnail preview, inline playback, and error handling
class YouTubePlayerWidget extends StatefulWidget {
  final String? videoId;
  final String? videoUrl;
  final bool autoPlay;
  final bool showControls;
  final double? aspectRatio;
  final VoidCallback? onPlay;
  final VoidCallback? onPause;
  final Function(VoidCallback)?
  onPauseCallbackReady; // Callback to register pause function

  const YouTubePlayerWidget({
    super.key,
    this.videoId,
    this.videoUrl,
    this.autoPlay = false,
    this.showControls = true,
    this.aspectRatio = 16 / 9,
    this.onPlay,
    this.onPause,
    this.onPauseCallbackReady,
  });

  @override
  State<YouTubePlayerWidget> createState() => _YouTubePlayerWidgetState();
}

class _YouTubePlayerWidgetState extends State<YouTubePlayerWidget>
    with WidgetsBindingObserver {
  YoutubePlayerController? _controller;
  bool _hasError = false;
  String? _errorMessage;
  String? _resolvedVideoId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resolveVideoId();
  }

  @override
  void didUpdateWidget(YouTubePlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId ||
        oldWidget.videoUrl != widget.videoUrl) {
      _resolveVideoId();
    }
  }

  void _resolveVideoId() {
    _resolvedVideoId = widget.videoId;
    if (_resolvedVideoId == null && widget.videoUrl != null) {
      _resolvedVideoId = YouTubeUtils.extractVideoId(widget.videoUrl!);
    }

    if (_resolvedVideoId != null && _resolvedVideoId!.isNotEmpty) {
      _initializeController();
    } else {
      setState(() {
        _hasError = true;
        _errorMessage = 'لا يمكن استخراج معرف الفيديو';
      });
    }
  }

  void _initializeController() {
    if (_resolvedVideoId == null || _resolvedVideoId!.isEmpty) return;

    _controller?.dispose();
    _controller = YoutubePlayerController(
      initialVideoId: _resolvedVideoId!,
      flags: YoutubePlayerFlags(
        autoPlay: widget.autoPlay,
        mute: false,
        isLive: false,
        forceHD: true,
        enableCaption: true,
        loop: false,
      ),
    )..addListener(_playerListener);

    // Register pause callback with parent
    widget.onPauseCallbackReady?.call(_pauseVideo);

    setState(() {
      _hasError = false;
      _errorMessage = null;
    });
  }

  void _playerListener() {
    if (_controller == null) return;

    if (_controller!.value.hasError) {
      setState(() {
        _hasError = true;
        _errorMessage = 'فشل تحميل الفيديو';
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pauseVideo();
    }
  }

  @override
  void deactivate() {
    _pauseVideo();
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  void _pauseVideo() {
    if (_controller != null && _controller!.value.isPlaying) {
      _controller!.pause();
      widget.onPause?.call();
    }
  }

  void _playVideo() {
    if (_controller != null && !_controller!.value.isPlaying) {
      _controller!.play();
      widget.onPlay?.call();
    }
  }

  Future<void> _openInYouTube() async {
    if (_resolvedVideoId == null) return;

    final url = YouTubeUtils.getWatchUrl(_resolvedVideoId!);
    final uri = Uri.parse(url);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا يمكن فتح رابط يوتيوب'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      assert(() {
        developer.log('[YouTubePlayer] Error opening YouTube: $e');
        return true;
      }());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ أثناء فتح يوتيوب'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError || _resolvedVideoId == null || _resolvedVideoId!.isEmpty) {
      return _buildErrorState();
    }

    if (_controller == null) {
      return _buildThumbnailPreview();
    }

    return _buildPlayer();
  }

  Widget _buildThumbnailPreview() {
    final thumbnailUrl = YouTubeUtils.getThumbnailUrl(_resolvedVideoId!);

    return GestureDetector(
      onTap: () {
        _initializeController();
        if (widget.autoPlay) {
          _playVideo();
        } else {
          // Notify that user wants to play (for mutual pause logic)
          widget.onPlay?.call();
        }
      },
      child: Container(
        width: double.infinity,
        height:
            MediaQuery.of(context).size.width / (widget.aspectRatio ?? 16 / 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300] ?? Colors.grey),
        ),
        clipBehavior: Clip.none,
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.hardEdge,
              child: Image.network(
                thumbnailUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: const Icon(
                      Icons.video_library,
                      size: 64,
                      color: Colors.grey,
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
              ),
            ),
            // Play button overlay
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(
                  Icons.play_circle_filled,
                  size: 64,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayer() {
    // Use clipBehavior: Clip.none to prevent platform view clipping
    return Container(
      width: double.infinity,
      height:
          MediaQuery.of(context).size.width / (widget.aspectRatio ?? 16 / 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300] ?? Colors.grey),
      ),
      clipBehavior: Clip.none,
      child: YoutubePlayer(
        controller: _controller!,
        showVideoProgressIndicator: widget.showControls,
        progressIndicatorColor: Colors.green,
        progressColors: const ProgressBarColors(
          playedColor: Colors.green,
          handleColor: Colors.green,
          bufferedColor: Colors.grey,
          backgroundColor: Colors.grey,
        ),
        onReady: () {
          assert(() {
            developer.log('[YouTubePlayer] Video ready: $_resolvedVideoId');
            return true;
          }());
        },
        onEnded: (data) {
          assert(() {
            developer.log('[YouTubePlayer] Video ended: $_resolvedVideoId');
            return true;
          }());
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      height:
          MediaQuery.of(context).size.width / (widget.aspectRatio ?? 16 / 9),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[200] ?? Colors.orange),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.orange[600]),
          const SizedBox(height: 12),
          Text(
            _errorMessage ?? 'فشل تحميل الفيديو',
            style: TextStyle(
              color: Colors.orange[700],
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          if (_resolvedVideoId != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openInYouTube,
              icon: const Icon(Icons.open_in_new),
              label: const Text('فتح في يوتيوب'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
