import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'dart:developer' as developer;

/// AppDatabase - Robust SQLite database singleton with versioned migrations
/// Provides crash-proof database access with defensive retry and self-healing
class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  static Database? _database;
  static Future<void>? _initFuture;
  static const int _currentVersion = 10; // Bumped for videoId in lectures
  static const String _dbName = 'main_app.db'; // Single canonical DB file name

  AppDatabase._internal();

  factory AppDatabase() => _instance;

  /// Get database instance - thread-safe initialization
  Future<Database> get database async {
    if (_database != null) return _database!;

    // Ensure single initialization
    if (_initFuture == null) {
      _initFuture = _initialize();
    }

    await _initFuture;
    return _database!;
  }

  /// Initialize database with strict gate - runs only once
  Future<void> _initialize() async {
    try {
      final databasesPath = await getDatabasesPath();
      final dbDir = Directory(databasesPath);

      if (!await dbDir.exists()) {
        await dbDir.create(recursive: true);
        developer.log(
          '[AppDatabase] Created database directory: $databasesPath',
        );
      }

      final path = join(databasesPath, _dbName);

      // Check for corruption and backup if needed
      await _handleCorruption(path);

      _database = await openDatabase(
        path,
        version: _currentVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onDowngrade: _onDowngrade,
        singleInstance: true,
      );

      // Configure database
      await _configureDatabase(_database!);

      // Ensure schema is applied
      await _ensureSchema(_database!);

      final dbVersion = await _readUserVersion(_database!);
      developer.log(
        '[AppDatabase] Database initialized - path: $path, user_version: $dbVersion',
      );
    } catch (e, stackTrace) {
      developer.log(
        '[AppDatabase] ❌ Initialization failed: $e',
        name: 'AppDatabase',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Configure database with PRAGMA settings
  Future<void> _configureDatabase(Database db) async {
    try {
      await db.execute('PRAGMA foreign_keys=ON;');
      developer.log('[AppDatabase] Foreign keys enabled');
    } catch (e) {
      developer.log('[AppDatabase] ⚠️ Could not enable foreign keys: $e');
    }

    try {
      await db.execute('PRAGMA journal_mode=WAL;');
      developer.log('[AppDatabase] WAL mode enabled');
    } catch (e) {
      developer.log('[AppDatabase] ⚠️ Could not enable WAL mode: $e');
    }

    try {
      await db.execute('PRAGMA synchronous=NORMAL;');
    } catch (e) {
      developer.log('[AppDatabase] ⚠️ Could not set synchronous mode: $e');
    }
  }

  /// Read user_version from database using PRAGMA
  Future<int> _readUserVersion(Database db) async {
    try {
      final result = await db.rawQuery('PRAGMA user_version');
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      developer.log('[AppDatabase] ⚠️ Could not read user_version: $e');
      return 0;
    }
  }

  /// Set user_version in database using PRAGMA
  Future<void> _setUserVersion(Database db, int version) async {
    try {
      await db.execute('PRAGMA user_version = $version');
      developer.log('[AppDatabase] Set user_version to $version');
    } catch (e) {
      developer.log('[AppDatabase] ⚠️ Could not set user_version: $e');
      rethrow;
    }
  }

  /// Handle potential database corruption - Non-destructive integrity check
  /// Only deletes database if PRAGMA quick_check fails twice consecutively
  Future<void> _handleCorruption(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      developer.log(
        '[AppDatabase] Database file does not exist - will be created on first use',
      );
      return;
    }

    developer.log('[AppDatabase] Checking database integrity | path: $path');

    // Perform read-only integrity check using PRAGMA quick_check
    // This is safer than opening with version callbacks which can trigger migrations
    Database? testDb;
    try {
      // Open database WITHOUT version/onCreate/onUpgrade to prevent accidental reinitialization
      testDb = await openDatabase(
        path,
        readOnly: true,
        singleInstance: false, // Use separate instance for integrity check
      );

      // Use PRAGMA quick_check for integrity verification
      final integrityResult = await testDb.rawQuery('PRAGMA quick_check');
      final result = integrityResult.first['quick_check'] as String?;

      if (result == 'ok') {
        developer.log(
          '[AppDatabase] ✅ Integrity check passed - database is healthy',
        );
        await testDb.close();

        // Clear any existing corruption marker since database is healthy
        final failureMarkerPath = '$path.corruption_marker';
        final failureMarker = File(failureMarkerPath);
        if (await failureMarker.exists()) {
          await failureMarker.delete();
          developer.log(
            '[AppDatabase] Cleared corruption marker - database is healthy',
          );
        }

        return; // Database is healthy, no action needed
      } else {
        developer.log('[AppDatabase] ⚠️ Integrity check failed: $result');
        await testDb.close();
        throw Exception('Database integrity check failed: $result');
      }
    } catch (e) {
      if (testDb != null) {
        try {
          await testDb.close();
        } catch (_) {
          // Ignore close errors
        }
      }

      // First failure - log but don't delete yet
      developer.log(
        '[AppDatabase] ⚠️ First integrity check failed: $e | Will retry on next startup if issue persists',
      );

      // Check for previous failure marker (stored in a separate file)
      final failureMarkerPath = '$path.corruption_marker';
      final failureMarker = File(failureMarkerPath);

      if (await failureMarker.exists()) {
        // Second consecutive failure - database is truly corrupted
        developer.log(
          '[AppDatabase] ❌ Second consecutive integrity failure - database is corrupted',
        );

        try {
          // Create backup before deletion
          final backupPath =
              '$path.bak.${DateTime.now().millisecondsSinceEpoch}';
          await file.copy(backupPath);
          developer.log('[AppDatabase] Backup created: $backupPath');

          // Delete corrupted database
          await file.delete();
          developer.log('[AppDatabase] Corrupted database deleted');

          // Remove failure marker
          if (await failureMarker.exists()) {
            await failureMarker.delete();
          }
        } catch (backupError) {
          developer.log(
            '[AppDatabase] ❌ Could not create backup or delete corrupted database: $backupError',
          );
          rethrow;
        }
      } else {
        // First failure - create marker for next startup
        try {
          await failureMarker.writeAsString(
            DateTime.now().millisecondsSinceEpoch.toString(),
          );
          developer.log(
            '[AppDatabase] Created corruption marker - will verify again on next startup',
          );
        } catch (_) {
          // Ignore marker creation errors
        }
      }
    }
  }

  /// Initial schema creation (v1)
  Future<void> _onCreate(Database db, int version) async {
    await db.transaction((txn) async {
      await _migrationV1(db);
      developer.log('[AppDatabase] Initial schema created (v1)');
    });
    // Set user_version after initial creation
    await _setUserVersion(db, version);
  }

  /// Database upgrade handler
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    developer.log(
      '[AppDatabase] Upgrading database from v$oldVersion to v$newVersion',
    );

    await db.transaction((txn) async {
      // Apply migrations sequentially
      for (int version = oldVersion + 1; version <= newVersion; version++) {
        switch (version) {
          case 1:
            await _migrationV1(db);
            break;
          case 2:
            await _migrationV2(db);
            break;
          case 3:
            await _migrationV3(db);
            break;
          case 4:
            await _migrationV4(db);
            break;
          case 5:
            await _migrationV5(db);
            break;
          case 6:
            await _migrationV6(db);
            break;
          case 7:
            await _migrationV7(db);
            break;
          case 8:
            await _migrationV8(db);
            break;
          case 9:
            await _migrationV9(db);
            break;
          case 10:
            await _migrationV10(db);
            break;
          default:
            developer.log(
              '[AppDatabase] ⚠️ Unknown migration version: $version',
            );
        }
      }
    });

    // Set user_version after successful migration
    await _setUserVersion(db, newVersion);

    developer.log(
      '[AppDatabase] Upgrade completed - user_version set to $newVersion',
    );
  }

  /// Database downgrade handler (should not happen in production)
  Future<void> _onDowngrade(Database db, int oldVersion, int newVersion) async {
    developer.log(
      '[AppDatabase] ⚠️ Downgrade detected from v$oldVersion to v$newVersion - not supported',
    );
    throw Exception(
      'Database downgrade not supported. Current version: $oldVersion, requested: $newVersion',
    );
  }

  /// Migration v1: Initial schema with all critical tables
  Future<void> _migrationV1(Database db) async {
    // Users table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        username TEXT UNIQUE NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        is_admin INTEGER NOT NULL DEFAULT 0,
        name TEXT,
        gender TEXT,
        birth_date TEXT,
        profile_image_url TEXT,
        uniqueId TEXT,
        role TEXT,
        created_at INTEGER,
        updated_at INTEGER
      )
    ''');

    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS ux_users_email ON users(email)',
    );

    // Subcategories table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS subcategories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        section TEXT NOT NULL,
        description TEXT,
        icon_name TEXT,
        created_at INTEGER
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_subcats_section ON subcategories(section)',
    );

    // Lectures table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lectures (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        video_path TEXT,
        section TEXT NOT NULL,
        subcategory_id TEXT,
        sheikhId TEXT,
        sheikhName TEXT,
        categoryId TEXT,
        categoryName TEXT,
        subcategoryName TEXT,
        startTime INTEGER,
        endTime INTEGER,
        status TEXT CHECK(status IN ('draft','published','archived','deleted')) DEFAULT 'draft',
        isPublished INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER,
        updatedAt INTEGER
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_lectures_section ON lectures(section)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_lectures_sheikh ON lectures(sheikhId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_lectures_start ON lectures(startTime)',
    );

    // Sheikhs table - CRITICAL: Must be in v1 for fresh installs
    // uniqueId is TEXT(8) - exactly 8 digits, enforced by CHECK constraint
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sheikhs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uniqueId TEXT NOT NULL UNIQUE CHECK(LENGTH(uniqueId) = 8 AND uniqueId GLOB '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'),
        name TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        category TEXT,
        passwordHash TEXT,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        isDeleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS ux_sheikhs_uniqueId ON sheikhs(uniqueId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sheikhs_isDeleted ON sheikhs(isDeleted)',
    );

    // FTS5 table (optional, with fallback)
    try {
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS lectures_fts USING fts5(
          title,
          description,
          content='lectures',
          content_rowid='rowid'
        )
      ''');

      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS lectures_fts_insert AFTER INSERT ON lectures BEGIN
          INSERT INTO lectures_fts(rowid, title, description)
          VALUES (new.rowid, new.title, new.description);
        END
      ''');

      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS lectures_fts_update AFTER UPDATE ON lectures BEGIN
          UPDATE lectures_fts SET title = new.title, description = new.description
          WHERE rowid = new.rowid;
        END
      ''');

      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS lectures_fts_delete AFTER DELETE ON lectures BEGIN
          DELETE FROM lectures_fts WHERE rowid = old.rowid;
        END
      ''');

      developer.log('[AppDatabase] FTS5 table created');
    } catch (e) {
      developer.log('[AppDatabase] ⚠️ FTS5 not available: $e');
    }

    // Metadata table for FTS5 availability
    await db.execute('''
      CREATE TABLE IF NOT EXISTS _fts5_metadata (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    try {
      await db.insert('_fts5_metadata', {
        'key': 'available',
        'value': 'false',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {
      // Ignore if already exists
    }
  }

  /// Migration v2: Any additional schema changes
  Future<void> _migrationV2(Database db) async {
    // v2 currently has no additional changes
    // Sheikhs table was moved to v1 to fix fresh install issue
    developer.log('[AppDatabase] Migration v2 applied (no changes needed)');
  }

  /// Migration v3: Add passwordHash to sheikhs and backfill from users
  Future<void> _migrationV3(Database db) async {
    developer.log(
      '[AppDatabase] Applying migration v3: sheikhs passwordHash + backfill',
    );

    // Add passwordHash column if it doesn't exist
    try {
      await db.execute('ALTER TABLE sheikhs ADD COLUMN passwordHash TEXT');
      developer.log('[AppDatabase] Added passwordHash column to sheikhs');
    } catch (e) {
      // Column might already exist, ignore
      developer.log('[AppDatabase] passwordHash column may already exist: $e');
    }

    // Update createdAt/updatedAt to INTEGER if they're TEXT
    try {
      // Check if columns are TEXT by trying to read a sample
      final sample = await db.query('sheikhs', limit: 1);
      if (sample.isNotEmpty) {
        final createdAt = sample.first['createdAt'];
        // If createdAt is a string, we need to convert existing data
        if (createdAt is String) {
          developer.log(
            '[AppDatabase] Converting sheikhs timestamps from TEXT to INTEGER',
          );
          // For existing rows, convert ISO8601 strings to milliseconds
          final allSheikhs = await db.query('sheikhs');
          for (final sheikh in allSheikhs) {
            final id = sheikh['id'];
            int? createdAtMs;
            int? updatedAtMs;

            try {
              if (sheikh['createdAt'] is String) {
                final dateStr = sheikh['createdAt'] as String;
                final date = DateTime.parse(dateStr);
                createdAtMs = date.millisecondsSinceEpoch;
              } else {
                createdAtMs = sheikh['createdAt'] as int?;
              }
            } catch (_) {
              createdAtMs = DateTime.now().millisecondsSinceEpoch;
            }

            try {
              if (sheikh['updatedAt'] is String) {
                final dateStr = sheikh['updatedAt'] as String;
                final date = DateTime.parse(dateStr);
                updatedAtMs = date.millisecondsSinceEpoch;
              } else {
                updatedAtMs = sheikh['updatedAt'] as int?;
              }
            } catch (_) {
              updatedAtMs = DateTime.now().millisecondsSinceEpoch;
            }

            await db.update(
              'sheikhs',
              {
                'createdAt':
                    createdAtMs ?? DateTime.now().millisecondsSinceEpoch,
                'updatedAt':
                    updatedAtMs ?? DateTime.now().millisecondsSinceEpoch,
              },
              where: 'id = ?',
              whereArgs: [id],
            );
          }
        }
      }
    } catch (e) {
      developer.log('[AppDatabase] Could not convert timestamps: $e');
    }

    // Backfill sheikhs from users table (if users with role='sheikh' exist)
    try {
      final usersWithSheikhRole = await db.query(
        'users',
        where: 'role = ? AND uniqueId IS NOT NULL',
        whereArgs: ['sheikh'],
      );

      int backfilled = 0;
      for (final user in usersWithSheikhRole) {
        final uniqueId = user['uniqueId'] as String?;
        if (uniqueId == null || uniqueId.isEmpty) continue;

        // Normalize to 8 digits
        final normalized = uniqueId.trim().replaceAll(RegExp(r'[^0-9]'), '');
        if (normalized.length != 8) continue;

        // Check if sheikh already exists
        final existing = await db.query(
          'sheikhs',
          where: 'uniqueId = ?',
          whereArgs: [normalized],
          limit: 1,
        );

        if (existing.isEmpty) {
          // Insert into sheikhs table
          final now = DateTime.now().millisecondsSinceEpoch;
          await db.insert('sheikhs', {
            'uniqueId': normalized,
            'name': user['name'] ?? 'غير محدد',
            'email': user['email'],
            'phone': user['phone'],
            'category': user['category'],
            'passwordHash': user['password_hash'],
            'createdAt': now,
            'updatedAt': now,
            'isDeleted': 0,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          backfilled++;
        } else {
          // Update existing sheikh with passwordHash if missing
          final existingSheikh = existing.first;
          if (existingSheikh['passwordHash'] == null &&
              user['password_hash'] != null) {
            await db.update(
              'sheikhs',
              {'passwordHash': user['password_hash']},
              where: 'id = ?',
              whereArgs: [existingSheikh['id']],
            );
            backfilled++;
          }
        }
      }

      if (backfilled > 0) {
        developer.log(
          '[AppDatabase] Backfilled $backfilled sheikh(s) from users table',
        );
      } else {
        developer.log('[AppDatabase] No sheikhs to backfill from users table');
      }
    } catch (e) {
      developer.log('[AppDatabase] Error during backfill: $e');
      // Continue - backfill is non-critical
    }

    developer.log('[AppDatabase] Migration v3 completed');
  }

  /// Migration v4: Verify sheikhs uniqueId integrity and enforce 8-digit constraint
  /// Note: SQLite doesn't support ALTER TABLE ADD CONSTRAINT, so we verify data integrity
  /// The CHECK constraint is applied on new table creation (v1)
  Future<void> _migrationV4(Database db) async {
    developer.log(
      '[AppDatabase] Applying migration v4: Verify sheikhs uniqueId integrity',
    );

    try {
      // Verify all existing uniqueId values are exactly 8 digits
      final allSheikhs = await db.query('sheikhs');
      int corrected = 0;

      for (final sheikh in allSheikhs) {
        final uniqueId = sheikh['uniqueId'] as String?;
        if (uniqueId == null) continue;

        // Normalize to 8 digits
        final normalized = uniqueId.replaceAll(RegExp(r'[^0-9]'), '');
        if (normalized.length != 8) {
          developer.log(
            '[AppDatabase] ⚠️ Invalid uniqueId found: $uniqueId (id: ${sheikh['id']})',
          );
          // Skip correction - let application handle invalid data
          continue;
        }

        // If uniqueId needs normalization, update it
        if (uniqueId != normalized) {
          final id = sheikh['id'];
          try {
            await db.update(
              'sheikhs',
              {
                'uniqueId': normalized,
                'updatedAt': DateTime.now().millisecondsSinceEpoch,
              },
              where: 'id = ?',
              whereArgs: [id],
            );
            corrected++;
          } catch (e) {
            developer.log(
              '[AppDatabase] Could not normalize uniqueId for id $id: $e',
            );
          }
        }
      }

      if (corrected > 0) {
        developer.log(
          '[AppDatabase] Normalized $corrected sheikh uniqueId(s) to 8 digits',
        );
      } else {
        developer.log(
          '[AppDatabase] All sheikh uniqueIds are valid (8 digits)',
        );
      }
    } catch (e) {
      developer.log('[AppDatabase] Error during v4 migration: $e');
      // Continue - verification is non-critical
    }

    developer.log('[AppDatabase] Migration v4 completed');
  }

  /// Migration v5: One-time backfill from users table to sheikhs table
  /// Idempotent: safe to run multiple times (uses INSERT OR IGNORE)
  Future<void> _migrationV5(Database db) async {
    developer.log(
      '[AppDatabase] Applying migration v5: Backfill sheikhs from users table',
    );

    try {
      // Check if users table exists and has sheikhs
      final usersWithSheikhRole = await db.query(
        'users',
        where: 'role = ? AND uniqueId IS NOT NULL AND uniqueId != ?',
        whereArgs: ['sheikh', ''],
      );

      if (usersWithSheikhRole.isEmpty) {
        developer.log(
          '[AppDatabase] No sheikhs found in users table to backfill',
        );
        return;
      }

      int backfilled = 0;
      int updated = 0;

      for (final user in usersWithSheikhRole) {
        final uniqueId = user['uniqueId'] as String?;
        if (uniqueId == null || uniqueId.isEmpty) continue;

        // Normalize to 8 digits
        final normalized = uniqueId.trim().replaceAll(RegExp(r'[^0-9]'), '');
        if (normalized.length != 8) {
          developer.log(
            '[AppDatabase] Skipping invalid uniqueId: $uniqueId (not 8 digits)',
          );
          continue;
        }

        // Check if sheikh already exists in sheikhs table
        final existing = await db.query(
          'sheikhs',
          where: 'uniqueId = ?',
          whereArgs: [normalized],
          limit: 1,
        );

        final now = DateTime.now().millisecondsSinceEpoch;
        final passwordHash = user['password_hash'] as String?;

        if (existing.isEmpty) {
          // Insert new sheikh from users table
          try {
            await db.insert('sheikhs', {
              'uniqueId': normalized,
              'name': user['name'] ?? 'غير محدد',
              'email': user['email'],
              'phone': user['phone'],
              'category': user['category'],
              'passwordHash': passwordHash,
              'createdAt': user['created_at'] ?? now,
              'updatedAt': user['updated_at'] ?? now,
              'isDeleted': 0,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
            backfilled++;
          } catch (e) {
            developer.log(
              '[AppDatabase] Error inserting sheikh $normalized: $e',
            );
          }
        } else {
          // Update existing sheikh with passwordHash if missing
          final existingSheikh = existing.first;
          if (existingSheikh['passwordHash'] == null && passwordHash != null) {
            await db.update(
              'sheikhs',
              {'passwordHash': passwordHash, 'updatedAt': now},
              where: 'id = ?',
              whereArgs: [existingSheikh['id']],
            );
            updated++;
          }
        }
      }

      if (backfilled > 0 || updated > 0) {
        developer.log(
          '[AppDatabase] Backfill completed: $backfilled inserted, $updated updated',
        );
      } else {
        developer.log('[AppDatabase] No sheikhs needed backfilling');
      }
    } catch (e) {
      developer.log('[AppDatabase] Error during v5 backfill: $e');
      // Continue - backfill is non-critical
    }

    developer.log('[AppDatabase] Migration v5 completed');
  }

  /// Migration v6: Normalize lecture section keys and backfill publish flags
  /// - Maps Arabic section names (الفقه, etc.) to canonical keys (fiqh, etc.)
  /// - Sets isPublished=1 and status='published' for existing lectures that should be visible
  Future<void> _migrationV6(Database db) async {
    developer.log(
      '[AppDatabase] Applying migration v6: Normalize lecture sections and backfill publish flags',
    );

    try {
      // Get all lectures
      final allLectures = await db.query('lectures');

      int normalizedSections = 0;
      int publishedLectures = 0;

      for (final lecture in allLectures) {
        final id = lecture['id'] as String;
        final section = lecture['section'] as String?;
        final isPublished = (lecture['isPublished'] as int? ?? 0) == 1;
        final status = lecture['status'] as String? ?? 'draft';

        // Normalize section key
        String? normalizedSection;
        if (section != null) {
          switch (section.trim()) {
            case 'الفقه':
              normalizedSection = 'fiqh';
              break;
            case 'الحديث':
              normalizedSection = 'hadith';
              break;
            case 'السيرة':
              normalizedSection = 'seerah';
              break;
            case 'التفسير':
              normalizedSection = 'tafsir';
              break;
            case 'fiqh':
            case 'hadith':
            case 'seerah':
            case 'tafsir':
              normalizedSection = section.trim();
              break;
            default:
              normalizedSection = section.trim().toLowerCase();
          }

          if (normalizedSection != section) {
            await db.update(
              'lectures',
              {'section': normalizedSection},
              where: 'id = ?',
              whereArgs: [id],
            );
            normalizedSections++;
          }
        }

        // Backfill publish flags: if lecture is not archived/deleted and has content,
        // set it to published
        if (status != 'archived' &&
            status != 'deleted' &&
            (!isPublished || status == 'draft')) {
          final title = lecture['title'] as String?;
          if (title != null && title.isNotEmpty) {
            await db.update(
              'lectures',
              {'isPublished': 1, 'status': 'published'},
              where: 'id = ?',
              whereArgs: [id],
            );
            publishedLectures++;
          }
        }
      }

      if (normalizedSections > 0 || publishedLectures > 0) {
        developer.log(
          '[AppDatabase] Migration v6: Normalized $normalizedSections section(s), published $publishedLectures lecture(s)',
        );
      } else {
        developer.log('[AppDatabase] Migration v6: No changes needed');
      }
    } catch (e) {
      developer.log('[AppDatabase] Error during v6 migration: $e');
      // Continue - migration is non-critical
    }

    developer.log('[AppDatabase] Migration v6 completed');
  }

  /// Migration v7: Create categories table
  /// Categories are organized by section (fiqh, hadith, tafsir, seerah)
  Future<void> _migrationV7(Database db) async {
    developer.log(
      '[AppDatabase] Applying migration v7: Create categories table',
    );

    try {
      // Create categories table
      // Note: section_id is TEXT to match current section representation (fiqh, hadith, etc.)
      // This can be changed to INTEGER with a sections lookup table in a future migration
      await db.execute('''
        CREATE TABLE IF NOT EXISTS categories (
          id TEXT PRIMARY KEY,
          section_id TEXT NOT NULL,
          name TEXT NOT NULL,
          description TEXT,
          sortOrder INTEGER DEFAULT 0,
          isDeleted INTEGER NOT NULL DEFAULT 0,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL
        )
      ''');

      // Create indexes
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_categories_section ON categories(section_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_categories_isDeleted ON categories(isDeleted)',
      );

      developer.log('[AppDatabase] Categories table created with indexes');
    } catch (e) {
      developer.log('[AppDatabase] Error during v7 migration: $e');
      rethrow;
    }

    developer.log('[AppDatabase] Migration v7 completed');
  }

  /// Migration v8: Add isDeleted column to lectures and normalize data
  /// - Adds isDeleted column (default 0)
  /// - Normalizes Arabic section names to canonical keys
  /// - Sets isPublished=1, status='published', isDeleted=0 for approved lectures
  Future<void> _migrationV8(Database db) async {
    developer.log(
      '[AppDatabase] Applying migration v8: Add isDeleted column and normalize data',
    );

    try {
      // Add isDeleted column if it doesn't exist
      try {
        await db.execute(
          'ALTER TABLE lectures ADD COLUMN isDeleted INTEGER NOT NULL DEFAULT 0',
        );
        developer.log('[AppDatabase] Added isDeleted column to lectures');
      } catch (e) {
        // Column may already exist, check first
        final columns = await db.rawQuery("PRAGMA table_info(lectures)");
        final hasIsDeleted = columns.any((col) => col['name'] == 'isDeleted');
        if (!hasIsDeleted) {
          developer.log('[AppDatabase] Error adding isDeleted column: $e');
          rethrow;
        } else {
          developer.log('[AppDatabase] isDeleted column already exists');
        }
      }

      // Create index on isDeleted
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_lectures_isDeleted ON lectures(isDeleted)',
      );

      // Create composite indexes for performance
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_lectures_section_published ON lectures(section, isPublished, isDeleted)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_lectures_subcat_published ON lectures(subcategory_id, isPublished, isDeleted)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_lectures_category_published ON lectures(categoryId, isPublished, isDeleted)',
      );

      // Normalize section values: Arabic → canonical keys
      final sectionMap = {
        'الفقه': 'fiqh',
        'الحديث': 'hadith',
        'السيرة': 'seerah',
        'التفسير': 'tafsir',
      };

      int normalizedSections = 0;
      for (final entry in sectionMap.entries) {
        final result = await db.rawUpdate(
          "UPDATE lectures SET section = ? WHERE section = ?",
          [entry.value, entry.key],
        );
        if (result > 0) {
          normalizedSections += result;
        }
      }

      // For lectures with status='published' or isPublished=1, ensure consistency
      // Set isPublished=1, status='published', isDeleted=0
      final publishedResult = await db.rawUpdate(
        "UPDATE lectures SET isPublished = 1, status = 'published', isDeleted = 0 WHERE (isPublished = 1 OR status = 'published') AND (isDeleted IS NULL OR isDeleted = 0)",
      );

      // For archived lectures, ensure isPublished=0, isDeleted=0
      await db.rawUpdate(
        "UPDATE lectures SET isPublished = 0, isDeleted = 0 WHERE status = 'archived' AND (isDeleted IS NULL OR isDeleted = 0)",
      );

      // For deleted lectures, set isDeleted=1
      await db.rawUpdate(
        "UPDATE lectures SET isDeleted = 1 WHERE status = 'deleted'",
      );

      developer.log(
        '[AppDatabase] Migration v8: Normalized $normalizedSections section(s), updated $publishedResult published lecture(s)',
      );
    } catch (e) {
      developer.log('[AppDatabase] Error during v8 migration: $e');
      rethrow;
    }

    developer.log('[AppDatabase] Migration v8 completed');
  }

  /// Migration v9: Add category_id to subcategories table
  /// - Adds category_id column to subcategories
  /// - Creates index on category_id
  Future<void> _migrationV9(Database db) async {
    developer.log(
      '[AppDatabase] Applying migration v9: Add category_id to subcategories',
    );

    try {
      // Check if category_id column already exists
      final columns = await db.rawQuery("PRAGMA table_info(subcategories)");
      final hasCategoryId = columns.any((col) => col['name'] == 'category_id');

      if (!hasCategoryId) {
        // Add category_id column
        await db.execute(
          'ALTER TABLE subcategories ADD COLUMN category_id TEXT',
        );
        developer.log(
          '[AppDatabase] Added category_id column to subcategories',
        );
      } else {
        developer.log('[AppDatabase] category_id column already exists');
      }

      // Create index on category_id
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_subcategories_category_id ON subcategories(category_id)',
      );

      // Backfill orphaned subcategories: try to assign them to a category in the same section
      // This is a best-effort fix - ideally subcategories should be recreated with proper category_id
      final orphanedSubcats = await db.rawQuery(
        "SELECT id, section FROM subcategories WHERE category_id IS NULL OR category_id = ''",
      );

      int backfilled = 0;
      for (final subcat in orphanedSubcats) {
        final subcatId = subcat['id'] as String?;
        final section = subcat['section'] as String?;
        if (subcatId == null || section == null) continue;

        // Find first category in the same section
        final categories = await db.query(
          'categories',
          where: 'section_id = ? AND isDeleted = ?',
          whereArgs: [section, 0],
          limit: 1,
        );

        if (categories.isNotEmpty) {
          final categoryId = categories.first['id'] as String?;
          if (categoryId != null) {
            await db.update(
              'subcategories',
              {'category_id': categoryId},
              where: 'id = ?',
              whereArgs: [subcatId],
            );
            backfilled++;
            developer.log(
              '[AppDatabase] Backfilled orphaned subcategory $subcatId with category $categoryId',
            );
          }
        }
      }

      if (backfilled > 0) {
        developer.log(
          '[AppDatabase] Backfilled $backfilled orphaned subcategories with category_id',
        );
      }

      developer.log('[AppDatabase] Migration v9 completed');
    } catch (e) {
      developer.log('[AppDatabase] Error during v9 migration: $e');
      rethrow;
    }
  }

  /// Migration v10: Add videoId column to lectures table for YouTube videos
  Future<void> _migrationV10(Database db) async {
    developer.log(
      '[AppDatabase] Applying migration v10: Add videoId to lectures',
    );

    try {
      // Check if videoId column already exists
      final columns = await db.rawQuery("PRAGMA table_info(lectures)");
      final hasVideoId = columns.any((col) => col['name'] == 'videoId');

      if (!hasVideoId) {
        // Add videoId column
        await db.execute('ALTER TABLE lectures ADD COLUMN videoId TEXT');
        developer.log('[AppDatabase] Added videoId column to lectures');

        // Create index on videoId for faster lookups
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_lectures_videoId ON lectures(videoId)',
        );
      } else {
        developer.log('[AppDatabase] videoId column already exists');
      }
    } catch (e) {
      developer.log('[AppDatabase] Error during v10 migration: $e');
      rethrow;
    }

    developer.log('[AppDatabase] Migration v10 completed');
  }

  /// Ensure schema is applied - used for defensive retry
  Future<void> _ensureSchema(Database db) async {
    try {
      // Use PRAGMA user_version instead of getVersion()
      final currentVersion = await _readUserVersion(db);
      if (currentVersion < _currentVersion) {
        developer.log(
          '[AppDatabase] Schema version mismatch - applying migrations (current: $currentVersion, target: $_currentVersion)',
        );
        await _onUpgrade(db, currentVersion, _currentVersion);
      } else if (currentVersion > _currentVersion) {
        developer.log(
          '[AppDatabase] ⚠️ Database version ($currentVersion) is newer than app version ($_currentVersion)',
        );
        // Don't downgrade - just log warning
      }

      // Verify critical tables exist
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('users', 'subcategories', 'lectures', 'sheikhs', 'categories')",
      );
      final tableNames = tables.map((row) => row['name'] as String).toSet();
      final requiredTables = {
        'users',
        'subcategories',
        'lectures',
        'sheikhs',
        'categories',
      };

      if (!requiredTables.every((t) => tableNames.contains(t))) {
        final missing = requiredTables.difference(tableNames);
        developer.log('[AppDatabase] ⚠️ Missing tables detected: $missing');
        throw Exception('Required tables missing: $missing');
      }
    } catch (e) {
      developer.log('[AppDatabase] Error ensuring schema: $e');
      rethrow;
    }
  }

  /// Defensive retry wrapper - catches "no such table" errors and retries once
  Future<T> withRetry<T>(
    Future<T> Function() operation, {
    String? operationName,
  }) async {
    try {
      return await operation();
    } on DatabaseException catch (e) {
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('no such table') ||
          errorMessage.contains('no such column') ||
          errorMessage.contains('no such index')) {
        developer.log(
          '[AppDatabase] ⚠️ Schema error detected: ${operationName ?? 'operation'} - $e',
        );
        developer.log('[AppDatabase] Attempting schema repair and retry...');

        try {
          final db = await database;
          await _ensureSchema(db);
          developer.log(
            '[AppDatabase] Schema repair completed, retrying operation',
          );
          return await operation();
        } catch (retryError) {
          developer.log(
            '[AppDatabase] ❌ Retry failed: $retryError',
            error: retryError,
          );
          rethrow;
        }
      }
      rethrow;
    }
  }

  /// Health check - verify critical tables exist
  Future<bool> healthCheck() async {
    try {
      final db = await database;
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('users', 'subcategories', 'lectures', 'sheikhs', 'categories')",
      );
      final tableNames = tables.map((row) => row['name'] as String).toSet();
      final requiredTables = {
        'users',
        'subcategories',
        'lectures',
        'sheikhs',
        'categories',
      };
      final allPresent = requiredTables.every((t) => tableNames.contains(t));

      if (!allPresent) {
        developer.log(
          '[AppDatabase] Health check failed - missing tables: ${requiredTables.difference(tableNames)}',
        );
      }

      return allPresent;
    } catch (e) {
      developer.log('[AppDatabase] Health check error: $e');
      return false;
    }
  }

  /// Get database path
  Future<String> getDatabasePath() async {
    final databasesPath = await getDatabasesPath();
    return join(databasesPath, _dbName);
  }

  /// Get row count for a table
  Future<int> getRowCount(String tableName) async {
    final db = await database;
    return await withRetry(() async {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName',
      );
      return Sqflite.firstIntValue(result) ?? 0;
    }, operationName: 'getRowCount($tableName)');
  }

  /// Get database instance (alias for compatibility)
  Future<Database> get db async => database;

  /// Check if FTS5 is available
  Future<bool> isFts5Available() async {
    try {
      final db = await database;
      final metadata = await db.rawQuery(
        "SELECT value FROM _fts5_metadata WHERE key='available'",
      );
      if (metadata.isNotEmpty) {
        return (metadata.first['value'] as String?) == 'true';
      }
      // Fallback: check if FTS5 table exists
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='lectures_fts'",
      );
      return tables.isNotEmpty;
    } catch (e) {
      developer.log('[AppDatabase] Error checking FTS5: $e');
      return false;
    }
  }

  /// Close database
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _initFuture = null;
    }
  }
}
