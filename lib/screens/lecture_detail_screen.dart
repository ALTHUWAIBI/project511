import 'package:flutter/material.dart';
import 'package:new_project/widgets/youtube_player_widget.dart';
import 'package:new_project/widgets/audio_player_widget.dart';
import 'package:new_project/utils/youtube_utils.dart';
import 'package:url_launcher/url_launcher.dart';

/// Dedicated screen for viewing lecture details with video playback
/// Replaces Dialog to avoid platform view clipping issues
class LectureDetailScreen extends StatefulWidget {
  final Map<String, dynamic> lecture;

  const LectureDetailScreen({super.key, required this.lecture});

  @override
  State<LectureDetailScreen> createState() => _LectureDetailScreenState();
}

class _LectureDetailScreenState extends State<LectureDetailScreen> {
  // Callbacks to pause the other media when one starts playing
  VoidCallback? _pauseVideo;
  VoidCallback? _pauseAudio;

  @override
  Widget build(BuildContext context) {
    final title = widget.lecture['title']?.toString() ?? 'بدون عنوان';
    final description = widget.lecture['description']?.toString() ?? '';
    final section = widget.lecture['section']?.toString() ?? '';
    final startTime = widget.lecture['startTime'];
    final endTime = widget.lecture['endTime'];
    final location = widget.lecture['location'] as Map<String, dynamic>?;

    // Extract videoId - only check videoId, not other fields
    final videoId = widget.lecture['videoId']?.toString();
    final videoUrl =
        widget.lecture['video_path']?.toString() ??
        widget.lecture['media']?['videoUrl']?.toString();

    // Extract audioUrl
    final audioUrl =
        widget.lecture['media']?['audioUrl']?.toString() ??
        widget.lecture['audioUrl']?.toString();

    // Only show player if videoId exists (extract from URL if needed)
    String? resolvedVideoId = videoId;
    if ((resolvedVideoId == null || resolvedVideoId.isEmpty) &&
        videoUrl != null &&
        videoUrl.isNotEmpty) {
      resolvedVideoId = YouTubeUtils.extractVideoId(videoUrl);
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFE4E5D3),
        appBar: AppBar(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          title: Text(title),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section
              if (section.isNotEmpty) ...[
                _buildInfoCard(
                  'القسم',
                  _getSectionDisplayName(section),
                  Icons.category,
                ),
                const SizedBox(height: 12),
              ],

              // Start Time
              if (startTime != null) ...[
                _buildInfoCard(
                  'وقت البداية',
                  _formatDateTime(startTime),
                  Icons.schedule,
                ),
                const SizedBox(height: 12),
              ],

              // Description - placed after start time
              if (description.isNotEmpty) ...[
                _buildInfoCard('الوصف', description, Icons.description),
                const SizedBox(height: 12),
              ],

              // Video player - ONLY if videoId exists, placed after description
              if (resolvedVideoId != null && resolvedVideoId.isNotEmpty) ...[
                // Video title label
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.video_library,
                        color: Colors.green[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'مقطع الفيديو (يوتيوب)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                YouTubePlayerWidget(
                  videoId: resolvedVideoId,
                  videoUrl: videoUrl,
                  autoPlay: false,
                  showControls: true,
                  onPlay: () {
                    // Pause audio if playing
                    _pauseAudio?.call();
                  },
                  onPause: () {
                    // Video paused
                  },
                  onPauseCallbackReady: (pauseCallback) {
                    _pauseVideo = pauseCallback;
                  },
                ),
                const SizedBox(height: 12),
                // Open in YouTube button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openInYouTube(resolvedVideoId!),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('فتح في يوتيوب'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Audio player - if audioUrl exists, placed after video
              if (audioUrl != null && audioUrl.isNotEmpty) ...[
                // Audio title label
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.audiotrack,
                        color: Colors.green[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'الصوت',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                AudioPlayerWidget(
                  audioUrl: audioUrl,
                  onPlay: () {
                    // Pause video if playing
                    _pauseVideo?.call();
                  },
                  onPause: () {
                    // Audio paused
                  },
                  onPauseCallbackReady: (pauseCallback) {
                    _pauseAudio = pauseCallback;
                  },
                ),
                const SizedBox(height: 12),
              ],

              // End Time
              if (endTime != null) ...[
                _buildInfoCard(
                  'وقت النهاية',
                  _formatDateTime(endTime),
                  Icons.schedule,
                ),
                const SizedBox(height: 12),
              ],

              // Location
              if (location != null && location['label'] != null) ...[
                _buildInfoCard(
                  'الموقع',
                  location['label']?.toString() ?? 'غير محدد',
                  Icons.location_on,
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.green, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSectionDisplayName(String section) {
    final normalized = section.toLowerCase();
    switch (normalized) {
      case 'fiqh':
        return 'الفقه';
      case 'hadith':
        return 'الحديث';
      case 'tafsir':
        return 'التفسير';
      case 'seerah':
        return 'السيرة';
      default:
        return section;
    }
  }

  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return 'غير محدد';

    try {
      DateTime dateTime;
      if (timestamp is int) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else {
        return 'غير محدد';
      }

      return '${dateTime.day}/${dateTime.month}/${dateTime.year} - ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'غير محدد';
    }
  }

  Future<void> _openInYouTube(String videoId) async {
    final url = YouTubeUtils.getWatchUrl(videoId);
    final uri = Uri.parse(url);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Error handled silently - user can try again
    }
  }
}
