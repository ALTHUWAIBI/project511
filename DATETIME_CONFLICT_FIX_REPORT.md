# Date-Time Conflict Logic Upgrade Report

## Objective

Enhanced the lecture scheduling conflict detection to be fully date-sensitive, ensuring that conflicts are detected only when lectures occur at the **exact same timestamp** (same Sheikh, same category, same year, month, day, hour, and minute).

## Problem Analysis

### Previous Behavior
The system used **overlapping time range** detection:
- Checked if lecture time ranges overlapped (e.g., 10:00-11:00 vs 10:30-11:30)
- This could block lectures that should be allowed if they had any time overlap

### Required Behavior
The system should only block lectures when:
- Same `sheikhId` (same sheikh)
- Same `categoryId` (same category)
- **Exact same timestamp** (same year, month, day, hour, minute)

This allows:
- ✅ Same sheikh, different category, same datetime → **Allowed**
- ✅ Different sheikh, same category, same datetime → **Allowed**
- ✅ Same sheikh, same category, different date (same time) → **Allowed**
- ✅ Same sheikh, same category, same date, different time → **Allowed**
- ❌ Same sheikh, same category, exact same datetime → **Blocked**

## Changes Made

### 1. `lib/repository/local_repository.dart`

**`hasOverlappingLectures` method**:
- **Changed SQL query** from overlapping range check to **exact timestamp match**
- **Before**: `((startTime < ? AND (endTime IS NULL OR endTime > ?)) OR (startTime >= ? AND startTime < ?))`
- **After**: `startTime = ?` (exact match)
- **Removed** `endTime` from conflict detection (only `startTime` matters for exact match)
- **Enhanced logging** to show readable datetime format for diagnostics
- **Updated documentation** to clarify exact timestamp matching

**Key Changes:**
```dart
// OLD: Overlapping time range check
String whereClause =
    'sheikhId = ? AND categoryId = ? AND isDeleted = ? AND ((startTime < ? AND (endTime IS NULL OR endTime > ?)) OR (startTime >= ? AND startTime < ?))';

// NEW: Exact timestamp match
String whereClause =
    'sheikhId = ? AND categoryId = ? AND isDeleted = ? AND startTime = ?';
```

### 2. `lib/provider/lecture_provider.dart`

**`addSheikhLecture` method**:
- **Enhanced logging** to show datetime being checked
- **Updated error message** from "يوجد محاضرة أخرى في نفس الفئة والوقت" to "يوجد محاضرة أخرى في نفس الفئة والتاريخ والوقت بالضبط"
- **Added comments** explaining exact datetime matching

**`updateSheikhLecture` method**:
- **Enhanced logging** to show datetime being checked (including lectureId)
- **Updated error message** to match add method
- **Added comments** explaining exact datetime matching

### 3. `lib/screens/sheikh/add_lecture_form.dart`

**`_saveLecture` method**:
- **Normalized `DateTime` creation** to set seconds and milliseconds to 0
- **Added comments** explaining datetime precision
- This ensures exact matching: two lectures at "10:00" will match exactly, not "10:00:00.123" vs "10:00:00.456"

**Key Changes:**
```dart
// OLD: DateTime with default seconds/milliseconds
final startDateTime = DateTime(
  year, month, day, hour, minute,
);

// NEW: DateTime with seconds and milliseconds normalized to 0
final startDateTime = DateTime(
  year, month, day, hour, minute,
  0, // seconds = 0
  0, // milliseconds = 0
);
```

### 4. `lib/screens/sheikh/edit_lecture_page.dart`

**`_updateLecture` method**:
- **Normalized `DateTime` creation** to set seconds and milliseconds to 0 (same as add form)
- **Added comments** explaining datetime precision
- Ensures consistency between add and edit operations

## Technical Details

### Timestamp Storage
- `startTime` is stored as `millisecondsSinceEpoch` (INTEGER in SQLite)
- This includes **full date-time precision**: year, month, day, hour, minute, second, millisecond
- Converting `DateTime` to UTC ensures consistent timezone handling

### Normalization
- When creating `DateTime` from user input, seconds and milliseconds are set to 0
- This ensures that "10:00" always becomes "10:00:00.000", not "10:00:12.345"
- Two lectures at "10:00" will have identical timestamps

### Conflict Detection Logic
```sql
SELECT * FROM lectures
WHERE sheikhId = ? 
  AND categoryId = ? 
  AND isDeleted = 0 
  AND startTime = ?
LIMIT 1
```

This query:
1. Matches exact `sheikhId`
2. Matches exact `categoryId`
3. Matches exact `startTime` (full timestamp including date and time)
4. Returns conflict if any matching lecture exists

## Test Scenarios

### ✅ Scenario 1: Same Sheikh, Different Categories, Same Datetime
- **Setup**: Sheikh A has lecture in Category 1 on 2024-01-15 10:00
- **Action**: Try to add lecture for Sheikh A in Category 2 on 2024-01-15 10:00
- **Expected**: ✅ **Allowed** (different categories)

### ✅ Scenario 2: Different Sheikhs, Same Category, Same Datetime
- **Setup**: Sheikh A has lecture in Category 1 on 2024-01-15 10:00
- **Action**: Try to add lecture for Sheikh B in Category 1 on 2024-01-15 10:00
- **Expected**: ✅ **Allowed** (different sheikhs)

### ✅ Scenario 3: Same Sheikh, Same Category, Different Date (Same Time)
- **Setup**: Sheikh A has lecture in Category 1 on 2024-01-15 10:00
- **Action**: Try to add lecture for Sheikh A in Category 1 on 2024-01-16 10:00
- **Expected**: ✅ **Allowed** (different dates)

### ✅ Scenario 4: Same Sheikh, Same Category, Same Date, Different Time
- **Setup**: Sheikh A has lecture in Category 1 on 2024-01-15 10:00
- **Action**: Try to add lecture for Sheikh A in Category 1 on 2024-01-15 11:00
- **Expected**: ✅ **Allowed** (different times)

### ❌ Scenario 5: Same Sheikh, Same Category, Exact Same Datetime
- **Setup**: Sheikh A has lecture in Category 1 on 2024-01-15 10:00
- **Action**: Try to add another lecture for Sheikh A in Category 1 on 2024-01-15 10:00
- **Expected**: ❌ **Blocked** (exact conflict)

## Verification

The fix ensures:
1. ✅ **Exact timestamp matching**: Only identical timestamps trigger conflicts
2. ✅ **Date sensitivity**: Different dates are always allowed, even with same time
3. ✅ **Time precision**: Different times are always allowed, even on same date
4. ✅ **Normalization**: Seconds and milliseconds are normalized to 0 for consistency
5. ✅ **UTC handling**: All timestamps are converted to UTC for consistent comparison
6. ✅ **Enhanced logging**: Diagnostic logs show readable datetime format

## Rollback Steps

If issues arise, revert the following:

1. **`lib/repository/local_repository.dart`**:
   - Change SQL WHERE clause back to overlapping range check
   - Restore `endTime` parameter usage in conflict detection

2. **`lib/provider/lecture_provider.dart`**:
   - Revert error messages
   - Remove enhanced logging

3. **`lib/screens/sheikh/add_lecture_form.dart`** and **`lib/screens/sheikh/edit_lecture_page.dart`**:
   - Remove seconds and milliseconds normalization (use default DateTime constructor)

## Notes

- The change from overlapping range to exact match is **more permissive**: it allows more lectures to be scheduled
- This is intentional: the system now only blocks true duplicates (exact same datetime)
- Time range overlaps (e.g., 10:00-11:00 vs 10:30-11:30) are no longer considered conflicts
- If time range overlap detection is needed in the future, it should be a separate feature, not part of conflict detection
- All timestamps are stored and compared in UTC for consistency across timezones

