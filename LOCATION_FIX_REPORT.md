# Location Data Fix Report

## Root Cause

The `location` data (including `locationUrl` and `locationName`) was not appearing in lecture details because:

1. **Database Schema**: The `lectures` table did not have a `location` column to store location data.
2. **Save Path**: The `addSheikhLecture` and `updateSheikhLecture` methods received `location` as a parameter but did not persist it to the database.
3. **Read Path**: Even if location was stored, the read methods did not deserialize the JSON location data when retrieving lectures.

## Files Changed

### 1. `lib/database/app_database.dart`
- **Migration v11**: Added new migration to add `location TEXT` column to `lectures` table
- **Version bump**: Updated `_currentVersion` from 10 to 11
- **Migration handler**: Added `_migrationV11` method with idempotent column addition

### 2. `lib/repository/local_repository.dart`
- **Import**: Added `dart:convert` for JSON serialization/deserialization
- **Helper method**: Added `_deserializeLocation()` to safely deserialize location JSON from database
- **`addSheikhLecture`**: 
  - Serializes `location` map to JSON before inserting
  - Stores JSON string in `location` column
  - Added diagnostic logging
- **`updateSheikhLecture`**: 
  - Serializes `location` map to JSON before updating
  - Updates `location` column with JSON string
  - Added diagnostic logging
- **All read methods**: Updated to deserialize location JSON:
  - `getAllLectures()`
  - `getLecturesBySection()`
  - `getLecturesByCategory()`
  - `getLecturesBySubcategory()`
  - `getLecture()`
  - `getLecturesBySheikh()`
  - `getLecturesBySheikhAndCategory()`
  - `getHomeHierarchy()` (both mapped lectures and uncategorized lectures)

### 3. `lib/screens/lecture_detail_screen.dart`
- **Already implemented**: `_buildLocationCard()` method displays location with Google Maps button
- **Location extraction**: Correctly reads from `lecture['location']` map
- **Google Maps integration**: `_openInGoogleMaps()` handles various URL formats (full URLs, coordinates, place names)

### 4. `lib/screens/sheikh/add_lecture_form.dart`
- **Already implemented**: `_locationUrlController` and `_buildLocationUrlField()` exist
- **Save logic**: Already includes `locationUrl` in location map when saving

### 5. `lib/screens/sheikh/edit_lecture_page.dart`
- **Already implemented**: `_locationUrlController` and `_buildLocationUrlField()` exist
- **Load logic**: Already reads `locationUrl` from lecture data
- **Save logic**: Already includes `locationUrl` in location map when updating

## Schema Changes

- **New column**: `location TEXT` in `lectures` table (stores JSON)
- **Migration**: v11 adds the column idempotently (checks if exists before adding)

## Data Flow

### Save Path (Add/Edit Lecture):
1. Form collects `locationName` (label) and `locationUrl` (Google Maps link)
2. Creates `location` map: `{'label': locationName, 'url': locationUrl, 'locationUrl': locationUrl}`
3. Repository serializes map to JSON: `jsonEncode(location)`
4. Database stores JSON string in `location` column

### Read Path (Display Lecture):
1. Database returns `location` as JSON string
2. Repository deserializes: `jsonDecode(locationStr)` → `Map<String, dynamic>`
3. Lecture detail screen reads: `lecture['location']['label']` and `lecture['location']['url']`
4. UI displays location name and "View on Map" button

## Test Evidence

### Expected Behavior:
- ✅ Adding a lecture with location name and URL → both saved to database
- ✅ Editing a lecture → location data preserved and updated correctly
- ✅ Opening lecture details → location name and "View on Map" button appear
- ✅ Clicking "View on Map" → opens Google Maps app with correct location
- ✅ Old lectures without location → display gracefully (no errors, location section hidden)

## Rollback Steps

If issues arise, revert the following:

1. **`lib/database/app_database.dart`**:
   - Revert version to 10
   - Remove `_migrationV11` method and case 11 from switch

2. **`lib/repository/local_repository.dart`**:
   - Remove `dart:convert` import
   - Remove `_deserializeLocation()` method
   - Remove location serialization in `addSheikhLecture` and `updateSheikhLecture`
   - Remove location deserialization from all read methods

## Notes

- Location data is stored as JSON for flexibility (can add more fields later)
- The migration is idempotent and safe (checks if column exists)
- All read methods now consistently deserialize location data
- Backward compatible: old lectures without location work fine (null handling)
- Diagnostic logging added for troubleshooting

