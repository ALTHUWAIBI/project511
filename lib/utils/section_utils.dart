/// Utility functions for section key normalization
/// Ensures consistent use of canonical English keys (fiqh, hadith, etc.)
/// instead of Arabic labels (الفقه, الحديث, etc.)

/// Map Arabic section names to canonical English keys
String normalizeSectionKey(String? section) {
  if (section == null || section.isEmpty) {
    return 'unknown';
  }

  // Map Arabic names to canonical keys
  switch (section.trim()) {
    case 'الفقه':
      return 'fiqh';
    case 'الحديث':
      return 'hadith';
    case 'السيرة':
      return 'seerah';
    case 'التفسير':
      return 'tafsir';
    // If already a canonical key, return as-is
    case 'fiqh':
    case 'hadith':
    case 'seerah':
    case 'tafsir':
      return section.trim();
    // Default: lowercase and return
    default:
      return section.trim().toLowerCase();
  }
}

/// Get Arabic display name for a canonical section key
String getSectionNameAr(String section) {
  switch (section.toLowerCase()) {
    case 'fiqh':
      return 'الفقه';
    case 'hadith':
      return 'الحديث';
    case 'seerah':
      return 'السيرة';
    case 'tafsir':
      return 'التفسير';
    default:
      return section;
  }
}

/// List of valid canonical section keys
const List<String> canonicalSectionKeys = [
  'fiqh',
  'hadith',
  'seerah',
  'tafsir',
];

/// Check if a section key is canonical
bool isCanonicalSectionKey(String section) {
  return canonicalSectionKeys.contains(section.toLowerCase());
}
