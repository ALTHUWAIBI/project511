import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:new_project/provider/pro_login.dart';
import 'package:new_project/provider/lecture_provider.dart';
import 'package:new_project/provider/hierarchy_provider.dart';
import 'package:new_project/screens/home_page.dart';
import 'dart:developer' as developer;

class SplashAuthGate extends StatefulWidget {
  const SplashAuthGate({super.key});

  @override
  State<SplashAuthGate> createState() => _SplashAuthGateState();
}

class _SplashAuthGateState extends State<SplashAuthGate> {
  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      // Wait for AuthProvider to be ready
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (!authProvider.isReady) {
        // Wait a bit and retry
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          _loadInitialData();
        }
        return;
      }

      // Load all data from SQLite on startup
      final lectureProvider = Provider.of<LectureProvider>(
        context,
        listen: false,
      );
      final hierarchyProvider = Provider.of<HierarchyProvider>(
        context,
        listen: false,
      );

      // Load all lectures from SQLite
      await lectureProvider.loadAllSections();
      developer.log('[SplashAuthGate] Lectures loaded from SQLite');

      // Hydrate categories for all sections on startup
      final sections = ['fiqh', 'hadith', 'tafsir', 'seerah'];
      for (final section in sections) {
        try {
          await hierarchyProvider.loadCategoriesBySection(section);
          developer.log(
            '[SplashAuthGate] Categories loaded for section: $section',
          );
        } catch (e) {
          developer.log(
            '[SplashAuthGate] Error loading categories for $section: $e',
          );
          // Continue with other sections
        }
      }

      // Data is loaded, proceed to show UI
      if (mounted) {
        setState(() {
          _dataLoaded = true;
        });
      }
    } catch (e) {
      developer.log('[SplashAuthGate] Error loading initial data: $e');
      // Continue anyway - don't block app startup
      if (mounted) {
        setState(() {
          _dataLoaded = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isReady || !_dataLoaded) return const SplashLoading();

    // Always show HomePage (lectures screen) as guest home
    // If user has a session, show optional "Continue as..." button
    return HomePageWithSession(
      auth: auth,
      onContinue: (role) {
        // Handle continue as specific role
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            switch (role) {
              case 'admin':
                print('[Splash] Continue as admin → /admin/home');
                Navigator.pushReplacementNamed(context, '/admin/home');
                break;
              case 'sheikh':
                print('[Splash] Continue as sheikh → /sheikh/home');
                Navigator.pushReplacementNamed(context, '/sheikh/home');
                break;
              case 'supervisor':
                print('[Splash] Continue as supervisor → /supervisor/home');
                Navigator.pushReplacementNamed(context, '/supervisor/home');
                break;
              case 'user':
              default:
                print('[Splash] Continue as user → /main');
                Navigator.pushReplacementNamed(context, '/main');
                break;
            }
          }
        });
      },
    );
  }
}

class SplashLoading extends StatelessWidget {
  const SplashLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE4E5D3),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo/Icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(Icons.mosque, size: 80, color: Colors.white),
            ),
            const SizedBox(height: 30),
            // App Title
            const Text(
              'منصة زوار المسجد النبوي',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // Loading Indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
            const SizedBox(height: 10),
            const Text(
              'جاري التحميل...',
              style: TextStyle(fontSize: 16, color: Colors.green),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePageWithSession extends StatelessWidget {
  final AuthProvider auth;
  final Function(String role) onContinue;

  const HomePageWithSession({
    super.key,
    required this.auth,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    // Always show HomePage (lectures screen) as guest home
    // The HomePage already handles guest mode and session display
    return HomePage(
      toggleTheme: (isDark) {
        // Handle theme toggle if needed
      },
    );
  }
}
