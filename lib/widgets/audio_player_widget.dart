import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:developer' as developer;

/// Simple inline audio player widget
/// Supports play/pause and external link fallback
class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final VoidCallback? onPlay;
  final VoidCallback? onPause;
  final Function(VoidCallback)?
  onPauseCallbackReady; // Callback to register pause function

  const AudioPlayerWidget({
    super.key,
    required this.audioUrl,
    this.onPlay,
    this.onPause,
    this.onPauseCallbackReady,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  bool _isPlaying = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // Register pause callback with parent after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onPauseCallbackReady?.call(_pauseAudio);
    });
  }

  @override
  void dispose() {
    _pauseAudio();
    super.dispose();
  }

  void _playAudio() {
    setState(() {
      _isPlaying = true;
    });
    widget.onPlay?.call();
    assert(() {
      developer.log('[AudioPlayer] Playing: ${widget.audioUrl}');
      return true;
    }());
  }

  void _pauseAudio() {
    if (_isPlaying) {
      setState(() {
        _isPlaying = false;
      });
      widget.onPause?.call();
      assert(() {
        developer.log('[AudioPlayer] Paused: ${widget.audioUrl}');
        return true;
      }());
    }
  }

  Future<void> _openExternally() async {
    final uri = Uri.parse(widget.audioUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا يمكن فتح رابط الصوت'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      assert(() {
        developer.log('[AudioPlayer] Error opening audio: $e');
        return true;
      }());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ أثناء فتح رابط الصوت'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorState();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle : Icons.play_circle,
                    color: Colors.green,
                    size: 48,
                  ),
                  onPressed: () {
                    if (_isPlaying) {
                      _pauseAudio();
                    } else {
                      _playAudio();
                    }
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isPlaying ? 'جاري التشغيل...' : 'اضغط للتشغيل',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.audioUrl,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new),
                  color: Colors.green,
                  onPressed: _openExternally,
                  tooltip: 'فتح في المتصفح',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.orange[600]),
            const SizedBox(height: 12),
            const Text(
              'فشل تحميل الصوت',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openExternally,
                icon: const Icon(Icons.open_in_new),
                label: const Text('فتح خارجياً'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
