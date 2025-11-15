import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:new_project/provider/hierarchy_provider.dart';

/// Dialog widget for selecting a lecture section (Fiqh, Tafsir, Hadith, Seerah)
/// Replaces the full-screen section selection page with a modal dialog
class SectionSelectionDialog extends StatefulWidget {
  const SectionSelectionDialog({super.key});

  @override
  State<SectionSelectionDialog> createState() => _SectionSelectionDialogState();
}

class _SectionSelectionDialogState extends State<SectionSelectionDialog> {
  // Navigation debounce guard to prevent double taps
  bool _isNavigating = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            const Text(
              'اختر فئة المحاضرة',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 24),

            // Section buttons (matching original order)
            _buildSectionButton(
              context,
              'الفقه',
              Icons.mosque,
              const Color(0xFF4CAF50), // Soft green
              'fiqh',
            ),
            const SizedBox(height: 12),
            _buildSectionButton(
              context,
              'السيرة',
              Icons.person,
              const Color(0xFF42A5F5), // Soft blue
              'seerah',
            ),
            const SizedBox(height: 12),
            _buildSectionButton(
              context,
              'التفسير',
              Icons.menu_book,
              const Color(0xFF9C27B0), // Soft purple
              'tafsir',
            ),
            const SizedBox(height: 12),
            _buildSectionButton(
              context,
              'الحديث',
              Icons.chat,
              const Color(0xFFEF5350), // Soft red/orange
              'hadith',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionButton(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    String sectionKey,
  ) {
    return ElevatedButton.icon(
      onPressed: _isNavigating
          ? null // Disable button while navigating
          : () async {
              // Guard against double taps
              if (_isNavigating) return;
              setState(() => _isNavigating = true);

              try {
                // Set the selected section in the provider (non-blocking)
                // Don't await - let it load in background while navigating
                Provider.of<HierarchyProvider>(
                  context,
                  listen: false,
                ).setSelectedSection(sectionKey).catchError((error) {
                  // Log error but don't block navigation
                  debugPrint(
                    '[SectionSelectionDialog] Error setting section: $error',
                  );
                });

                // Close the dialog and return true to indicate section was selected
                if (mounted) {
                  Navigator.of(context).pop(true);
                }
              } catch (error) {
                // Log error but still close dialog
                debugPrint('[SectionSelectionDialog] Error: $error');
                if (mounted) {
                  Navigator.of(context).pop(true);
                }
              } finally {
                if (mounted) {
                  setState(() => _isNavigating = false);
                }
              }
            },
      icon: Icon(icon, size: 24),
      label: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28), // Fully rounded (pill shape)
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        elevation: 2,
      ),
    );
  }
}
