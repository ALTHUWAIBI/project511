import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:new_project/screens/splash_auth_gate.dart';
import 'package:new_project/screens/login/login_tabbed.dart';
import 'package:new_project/screens/register_page.dart';
import 'package:new_project/screens/Admin_home_page.dart';
import 'package:new_project/screens/sheikh/sheikh_home_page.dart';
import 'package:new_project/screens/home_page.dart';
import 'package:new_project/screens/admin_login_screen.dart';
import 'package:new_project/screens/admin_test_screen.dart';
import 'package:new_project/screens/admin_add_sheikh_page.dart';
import 'package:new_project/widgets/role_guards.dart';
import 'package:new_project/provider/pro_login.dart';
import 'package:new_project/provider/location_provider.dart';
import 'package:new_project/provider/lecture_provider.dart';
import 'package:new_project/provider/subcategory_provider.dart';
import 'package:new_project/provider/prayer_times_provider.dart';
import 'package:new_project/provider/sheikh_provider.dart';
import 'package:new_project/provider/chapter_provider.dart';
import 'package:new_project/provider/hierarchy_provider.dart';
import 'package:new_project/database/app_database.dart';
import 'package:new_project/repository/local_repository.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:async';
import 'dart:developer' as developer;

void main() async {
  final stopwatch = Stopwatch()..start();

  WidgetsFlutterBinding.ensureInitialized();

  // Load bundled SQLite with FTS5 support (Android) - non-blocking
  unawaited(_loadSQLiteLibrary());

  // Enable full error reporting
  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
  };

  // Start app immediately - database will warm up after first frame
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProvider(create: (context) => LocationProvider()),
        ChangeNotifierProvider(create: (context) => LectureProvider()),
        ChangeNotifierProvider(create: (context) => SubcategoryProvider()),
        ChangeNotifierProvider(create: (context) => PrayerTimesProvider()),
        ChangeNotifierProvider(create: (context) => SheikhProvider()),
        ChangeNotifierProvider(create: (context) => ChapterProvider()),
        ChangeNotifierProvider(create: (context) => HierarchyProvider()),
      ],
      child: const MyApp(),
    ),
  );

  // Warm up database after first frame (non-blocking)
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_warmUpDatabase());
  });

  stopwatch.stop();
  assert(() {
    developer.log(
      '[PERF] main() completed in ${stopwatch.elapsedMilliseconds}ms',
    );
    return true;
  }());
}

// Load SQLite library asynchronously (non-blocking)
Future<void> _loadSQLiteLibrary() async {
  try {
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    assert(() {
      developer.log('[SQLite] Bundled SQLite library loaded');
      return true;
    }());
  } catch (e) {
    assert(() {
      developer.log('[SQLite] Could not load bundled SQLite: $e');
      return true;
    }());
    // Continue - will fall back to device SQLite
  }
}

// Warm up database connection after first frame (non-blocking)
Future<void> _warmUpDatabase() async {
  final stopwatch = Stopwatch()..start();
  try {
    assert(() {
      developer.log('[DB] Warming up database connection...');
      return true;
    }());

    // Initialize AppDatabase - lazy initialization will happen on first use
    final appDatabase = AppDatabase();
    // Touch the database to trigger initialization
    await appDatabase.database;

    stopwatch.stop();
    assert(() {
      developer.log(
        '[PERF] Database warm-up completed in ${stopwatch.elapsedMilliseconds}ms',
      );
      return true;
    }());
  } catch (e) {
    stopwatch.stop();
    assert(() {
      developer.log('[DB] Database warm-up error: $e');
      return true;
    }());
  }
}

// Initialize AppDatabase (robust SQLite with migrations)
// NOTE: This function is kept for backward compatibility but is no longer called in main()
// Database initialization is now handled by _warmUpDatabase() after first frame
// ignore: unused_element
Future<void> _initializeAppDatabase() async {
  try {
    developer.log('[DB] Initializing AppDatabase...');

    // Initialize AppDatabase - ensures schema exists before any queries
    final appDatabase = AppDatabase();
    await appDatabase.database;

    // Log DB path on first open
    final dbPath = await appDatabase.getDatabasePath();
    developer.log('[DB] Database path: $dbPath');

    // Read user_version to prove persistence
    try {
      final db = await appDatabase.database;
      final userVersionResult = await db.rawQuery('PRAGMA user_version');
      final userVersion = Sqflite.firstIntValue(userVersionResult) ?? 0;
      developer.log('[DB] user_version: $userVersion');
    } catch (e) {
      developer.log('[DB] Could not read user_version: $e');
    }

    // Log sheikh count (non-deleted) to prove persistence
    try {
      final db = await appDatabase.database;
      final sheikhCountResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM sheikhs WHERE isDeleted = 0',
      );
      final sheikhCount = Sqflite.firstIntValue(sheikhCountResult) ?? 0;
      developer.log('[DB] sheikhs(non-deleted): $sheikhCount');
    } catch (e) {
      developer.log('[DB] Could not count sheikhs: $e');
    }

    // Log lecture counts for diagnostics
    try {
      final db = await appDatabase.database;
      // Count published, non-deleted lectures
      final publishedCountResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM lectures WHERE isDeleted = 0 AND isPublished = 1',
      );
      final publishedCount = Sqflite.firstIntValue(publishedCountResult) ?? 0;
      developer.log('[DB] lectures(published, non-deleted): $publishedCount');

      // Count by section
      final sectionCountResult = await db.rawQuery(
        'SELECT section, COUNT(*) as count FROM lectures WHERE isDeleted = 0 AND isPublished = 1 GROUP BY section',
      );
      for (final row in sectionCountResult) {
        final section = row['section']?.toString() ?? 'unknown';
        final count = row['count'] as int? ?? 0;
        developer.log('[DB] lectures by section: $section = $count');
      }
    } catch (e) {
      developer.log('[DB] Could not count lectures: $e');
    }

    final isHealthy = await appDatabase.healthCheck();
    if (!isHealthy) {
      developer.log('[DB] ⚠️ Health check failed - some tables missing');
    } else {
      developer.log('[DB] ✅ Health check passed - all critical tables present');
    }

    // Verify SQLite version and compile options
    try {
      final db = await appDatabase.database;
      final versionResult = await db.rawQuery(
        'SELECT sqlite_version() as version',
      );
      final sqliteVersion =
          versionResult.first['version'] as String? ?? 'unknown';
      developer.log('[DB] SQLite version: $sqliteVersion');

      final compileOptsResult = await db.rawQuery('PRAGMA compile_options');
      final compileOpts = compileOptsResult
          .map((row) => row['compile_options'] as String? ?? '')
          .toList()
          .join(', ');
      developer.log('[DB] Compile options: $compileOpts');
      if (compileOpts.contains('FTS5')) {
        developer.log('[DB] ✅ FTS5 support detected');
      } else {
        developer.log(
          '[DB] ⚠️ FTS5 not in compile options - will use fallback',
        );
      }
    } catch (e) {
      developer.log('[DB] Could not query SQLite info: $e');
    }

    // Initialize repository
    final repository = LocalRepository();

    // Initialize default subcategories
    await repository.initializeDefaultSubcategoriesIfEmpty();

    // Create default admin account if none exists
    await repository.ensureDefaultAdmin();
    developer.log('[DB] Default admin account ensured');

    // Log row counts
    final counts = await repository.getTableCounts();
    developer.log(
      '[DB] users: ${counts['users']} | subcategories: ${counts['subcategories']} | lectures: ${counts['lectures']} | sheikhs: ${counts['sheikhs'] ?? 0}',
    );

    // Diagnostic logging: Published lectures count and section distribution
    try {
      final db = await appDatabase.database;

      // Count published lectures
      final publishedCountResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM lectures WHERE isPublished = 1 AND status NOT IN (?, ?)',
        ['archived', 'deleted'],
      );
      final publishedCount = Sqflite.firstIntValue(publishedCountResult) ?? 0;
      developer.log(
        '[DB] Published lectures (isPublished=1, not deleted): $publishedCount',
      );

      // Section distribution
      final sectionDistResult = await db.rawQuery(
        'SELECT section, COUNT(*) as count FROM lectures WHERE isPublished = 1 AND status NOT IN (?, ?) GROUP BY section',
        ['archived', 'deleted'],
      );
      if (sectionDistResult.isNotEmpty) {
        final sectionDist = sectionDistResult
            .map((row) {
              return '${row['section']}: ${row['count']}';
            })
            .join(', ');
        developer.log('[DB] Section distribution: $sectionDist');
      } else {
        developer.log('[DB] No published lectures found in any section');
      }
    } catch (e) {
      developer.log('[DB] Could not query lecture diagnostics: $e');
    }

    developer.log('[DB] Initialization completed');
  } catch (e) {
    developer.log('[DB] Initialization error: $e', name: 'main');
    // Continue with app initialization even if DB setup fails
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Defer initialization to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize AuthProvider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.initialize();

      setState(() {
        _initialized = true;
      });
    } catch (e) {
      debugPrint('App initialization error: $e');
      // Still set initialized to true to prevent infinite loading
      setState(() {
        _initialized = true;
      });
    }
  }

  void toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'محاضرات',
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFFE4E5D3),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        colorScheme: ColorScheme.light(
          primary: Colors.green,
          secondary: Colors.green.shade700,
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        fontFamily: 'Arial',
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      themeMode: _themeMode,
      home: const SplashAuthGate(),
      routes: {
        '/login': (context) => const LoginTabbedScreen(),
        '/register': (context) => const RegisterPage(),
        '/main': (context) => HomePage(toggleTheme: (isDark) {}),
        '/admin/login': (context) => const AdminLoginScreen(),
        '/admin/test': (context) => const AdminTestScreen(),
        '/admin/add-sheikh': (context) =>
            const AdminGuard(child: AdminAddSheikhPage()),
        '/sheikh/home': (context) => const SheikhGuard(child: SheikhHomePage()),
        '/admin/home': (context) => const AdminGuard(child: AdminPanelPage()),
        '/supervisor/home': (context) =>
            const AdminGuard(child: AdminPanelPage()),
      },
    );
  }
}
