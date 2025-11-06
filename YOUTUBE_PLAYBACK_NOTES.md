# YouTube Playback Implementation Notes

## Summary
This document describes the YouTube video playback feature added to the Flutter app for both admin preview and end-user viewing.

## Implementation Details

### 1. Database Schema
- **Migration v10**: Added `videoId` column to `lectures` table
- **Index**: Created `idx_lectures_videoId` for faster lookups
- **Storage**: Both `videoUrl` (original link) and `videoId` (canonical ID) are stored

### 2. YouTube URL Parsing
- **Utility**: `lib/utils/youtube_utils.dart` (already existed)
- **Supported Formats**:
  - `https://youtu.be/<id>`
  - `https://www.youtube.com/watch?v=<id>`
  - `https://www.youtube.com/shorts/<id>`
  - `https://www.youtube.com/embed/<id>`
- **Extraction**: Automatically extracts 11-character video ID from any supported format

### 3. Reusable Player Widget
- **File**: `lib/widgets/youtube_player_widget.dart`
- **Features**:
  - Thumbnail preview (lazy loading)
  - Inline playback on tap
  - Lifecycle management (pauses on navigation, app pause, etc.)
  - Error handling with fallback to "Open in YouTube"
  - 16:9 aspect ratio
  - Fullscreen support via YouTube controls

### 4. Admin Add/Edit Lecture Flow
- **File**: `lib/screens/sheikh/add_lecture_form.dart`
- **Features**:
  - URL validation on input
  - Real-time video ID extraction
  - Preview section appears after valid URL entered
  - Inline player in preview (no dialog)
  - Stores both `videoUrl` and `videoId` on save

### 5. End User Lecture View
- **File**: `lib/screens/lectures_list_page.dart`
- **Features**:
  - Video player card at top of lecture details
  - Thumbnail first, then inline player on tap
  - Auto-pause on navigation
  - Handles both `videoId` and `videoUrl` fields

### 6. Repository Updates
- **File**: `lib/repository/local_repository.dart`
- **Changes**:
  - `addSheikhLecture()` now extracts and stores `videoId`
  - Extracts from `media['videoId']`, `media['videoUrl']`, or `video_path`
  - Stores `videoId` in database column

## Lifecycle Management
- **Pause triggers**:
  - App lifecycle: `AppLifecycleState.paused` or `inactive`
  - Navigation: `deactivate()` called
  - Route pop: Automatic via Flutter lifecycle
- **Resume**: Player state preserved, user can resume manually

## Error Handling
- **Private/removed videos**: Shows error state with "Open in YouTube" button
- **Invalid URLs**: Validation error shown in form
- **Network issues**: Thumbnail shows, player fails gracefully
- **Offline**: Thumbnail cached, play button disabled

## Data Flow

### Admin Flow:
1. Admin pastes YouTube URL → `_videoUrlController`
2. `_validateYouTubeUrl()` extracts `videoId`
3. Preview section shows `YouTubePlayerWidget`
4. On save: `media['videoUrl']` and `media['videoId']` sent to repository
5. Repository stores both `video_path` (URL) and `videoId` (ID)

### End User Flow:
1. Lecture detail view reads `videoId` or `video_path` from database
2. If `videoId` exists, use directly
3. If only `video_path` exists, extract `videoId` from URL
4. Render `YouTubePlayerWidget` with thumbnail
5. User taps → inline player appears

## URL Patterns Supported
- Standard: `https://www.youtube.com/watch?v=VIDEO_ID`
- Short: `https://youtu.be/VIDEO_ID`
- Shorts: `https://www.youtube.com/shorts/VIDEO_ID`
- Embed: `https://www.youtube.com/embed/VIDEO_ID`
- With params: All formats support `&t=`, `?si=`, etc. (params ignored, ID extracted)

## Known Limitations
- **Private videos**: Cannot be played inline; shows error + external link
- **Age-restricted videos**: May require YouTube app
- **Shorts**: Parsed to standard video ID (works normally)
- **Timestamps**: Not currently supported (can be added later)

## Testing Checklist
- [x] Admin can paste YouTube URL and see preview
- [x] Preview shows thumbnail, then inline player on tap
- [x] Save stores both `videoUrl` and `videoId`
- [x] End user sees video player in lecture details
- [x] Player pauses on navigation away
- [x] Player pauses on app backgrounding
- [x] Error state shows for invalid/private videos
- [x] "Open in YouTube" button works
- [x] Thumbnail loads correctly
- [x] No crashes on invalid URLs

## Files Modified
1. `lib/database/app_database.dart` - Migration v10
2. `lib/widgets/youtube_player_widget.dart` - New reusable widget
3. `lib/screens/sheikh/add_lecture_form.dart` - Preview section
4. `lib/repository/local_repository.dart` - videoId storage
5. `lib/screens/lectures_list_page.dart` - Enhanced player

## Dependencies
- `youtube_player_flutter: ^9.0.0` (already in pubspec.yaml)
- `url_launcher: ^6.3.1` (already in pubspec.yaml)

## Performance Notes
- Thumbnails cached by Flutter image cache
- Player only initialized after user tap (lazy loading)
- Lifecycle management prevents memory leaks
- No autoplay (saves bandwidth)

