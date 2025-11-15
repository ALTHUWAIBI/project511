/// Utility functions for handling PDF files and URLs
class PdfUtils {
  /// Determines if a PDF value is a remote URL or a local file path.
  ///
  /// This function checks:
  /// 1. The explicit `pdfType` field if provided ('file' or 'url')
  /// 2. If pdfType is missing/null, it detects by checking if the string
  ///    starts with 'http://' or 'https://'
  ///
  /// Returns true if the value is a URL, false if it's a local file path.
  ///
  /// This ensures backward compatibility with old data that might not have
  /// the `pdfType` field set.
  static bool isPdfUrl(String? pdfValue, String? pdfType) {
    if (pdfValue == null || pdfValue.isEmpty) {
      return false;
    }

    // First, check explicit pdfType if available
    if (pdfType != null && pdfType.isNotEmpty) {
      return pdfType == 'url';
    }

    // Fallback: detect by checking if it starts with http:// or https://
    final trimmed = pdfValue.trim();
    return trimmed.startsWith('http://') || trimmed.startsWith('https://');
  }

  /// Validates if a string is a valid URL format
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url.trim());
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }
}
