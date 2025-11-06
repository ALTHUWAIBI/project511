# Fix Report: YouTube Video URL Persistence

## Root Cause

The YouTube video URL was not being saved when editing lectures due to two issues:

1. **Form Layer (`edit_lecture_page.dart`)**:
   - The form was passing `videoUrl` in the `media` map, but not extracting `videoId` from the URL
   - The form initialization only checked `media['videoUrl']` and didn't fallback to `video_path` or `videoId` fields

2. **Repository Layer (`local_repository.dart`)**:
   - The `updateSheikhLecture` method only looked for `videoPath` or `video_path` in the media map, but the form sends `videoUrl`
   - The method didn't extract `videoId` from the URL
   - The method didn't store `videoId` in the database
   - When `videoUrl` was cleared, `videoId` wasn't cleared

## Files Changed

### 1. `lib/screens/sheikh/edit_lecture_page.dart`
- **Added import**: `import 'package:new_project/utils/youtube_utils.dart';`
- **Fixed form initialization** (lines 346-362):
  - Now checks multiple sources: `media['videoUrl']`, `video_path`, and constructs URL from `videoId` if needed
- **Fixed save logic** (lines 889-906):
  - Extracts `videoId` from `videoUrl` using `YouTubeUtils.extractVideoId()`
  - Includes both `videoUrl` and `videoId` in the media map passed to repository

### 2. `lib/repository/local_repository.dart`
- **Fixed `updateSheikhLecture` method** (lines 1592-1615):
  - Now checks for `videoUrl` (preferred), `videoPath`, or `video_path` in media map
  - Extracts `videoId` from URL if not directly provided
  - Stores both `video_path` (for backward compatibility) and `videoId` in database
  - Clears both `video_path` and `videoId` when `videoUrl` is cleared

## Schema Changes

No schema changes required. The `videoId` column already exists from migration v10 (`lib/database/app_database.dart`).

## Test Evidence

### Manual Test Scenario:
1. **Edit a lecture** → Paste `https://youtu.be/3ZPMMRDcBo` → Save
2. **Reopen lecture details** → Video block should appear with player
3. **Edit again** → Clear link → Save → Video should disappear

### Expected Behavior:
- ✅ Saving a valid YouTube link stores both `videoUrl` and `videoId` in `lectures` table
- ✅ Lecture Details show the player when `videoId` exists
- ✅ Clearing the URL removes both `video_path` and `videoId`
- ✅ Old lectures without video remain unaffected

## Rollback Steps

If issues arise, revert the following changes:

1. **`lib/screens/sheikh/edit_lecture_page.dart`**:
   - Remove `youtube_utils.dart` import
   - Revert form initialization to only check `media['videoUrl']`
   - Revert save logic to only pass `videoUrl` without extracting `videoId`

2. **`lib/repository/local_repository.dart`**:
   - Revert `updateSheikhLecture` to only handle `videoPath`/`video_path`
   - Remove `videoId` extraction and storage logic

## Notes

- The fix maintains backward compatibility by storing both `video_path` and `videoId`
- The form now handles multiple data sources (media object, direct fields) for better resilience
- All changes are minimal and focused on the video persistence issue

