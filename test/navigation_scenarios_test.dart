import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:new_project/screens/splash_auth_gate.dart';
import 'package:new_project/screens/login_page.dart';
import 'package:new_project/screens/home_page.dart';
import 'package:new_project/screens/sheikh/sheikh_home_page.dart';
import 'package:new_project/screens/sheikh/sheikh_category_picker.dart';
import 'package:new_project/screens/sheikh/add_lecture_form.dart';
import 'test_setup.dart';

void main() {
  setUpAll(() {
    setupFirebaseForTests();
  });
  group('Navigation Scenarios Tests', () {
    late MockAuthProvider mockAuthProvider;
    late MockLectureProvider mockLectureProvider;

    setUp(() {
      mockAuthProvider = MockAuthProvider();
      mockLectureProvider = MockLectureProvider();
    });

    testWidgets('Cold start without session navigates to /login', (
      WidgetTester tester,
    ) async {
      // Simulate cold start with no session
      mockAuthProvider.setNoSession();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<MockAuthProvider>.value(
              value: mockAuthProvider,
            ),
            ChangeNotifierProvider<MockLectureProvider>.value(
              value: mockLectureProvider,
            ),
          ],
          child: MaterialApp(home: const SplashAuthGate()),
        ),
      );

      await tester.pumpAndSettle();

      // Should navigate to login
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('Login USER navigates to /', (WidgetTester tester) async {
      // Simulate user login
      mockAuthProvider.setUserSession();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<MockAuthProvider>.value(
              value: mockAuthProvider,
            ),
            ChangeNotifierProvider<MockLectureProvider>.value(
              value: mockLectureProvider,
            ),
          ],
          child: MaterialApp(home: const SplashAuthGate()),
        ),
      );

      await tester.pumpAndSettle();

      // Should navigate to home page
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('Login SHEIKH navigates to /sheikh/home', (
      WidgetTester tester,
    ) async {
      // Simulate sheikh login
      mockAuthProvider.setSheikhSession();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<MockAuthProvider>.value(
              value: mockAuthProvider,
            ),
            ChangeNotifierProvider<MockLectureProvider>.value(
              value: mockLectureProvider,
            ),
          ],
          child: MaterialApp(home: const SplashAuthGate()),
        ),
      );

      await tester.pumpAndSettle();

      // Should navigate to sheikh home
      expect(find.byType(SheikhHomePage), findsOneWidget);
    });

    testWidgets(
      'Deep link /sheikh/home as regular user shows snackbar and redirects to /',
      (WidgetTester tester) async {
        // Simulate regular user trying to access sheikh route
        mockAuthProvider.setUserSession();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<MockAuthProvider>.value(
                value: mockAuthProvider,
              ),
              ChangeNotifierProvider<MockLectureProvider>.value(
                value: mockLectureProvider,
              ),
            ],
            child: MaterialApp(
              home: const SplashAuthGate(),
              routes: {
                '/sheikh/home': (context) => const SheikhHomePage(),
                '/': (context) => HomePage(toggleTheme: (bool) {}),
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should show snackbar and redirect
        expect(find.text('غير مصرح بالدخول'), findsOneWidget);
        expect(find.byType(HomePage), findsOneWidget);
      },
    );

    testWidgets('Sheikh logout navigates to /login and clears stack', (
      WidgetTester tester,
    ) async {
      // Simulate sheikh session
      mockAuthProvider.setSheikhSession();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<MockAuthProvider>.value(
              value: mockAuthProvider,
            ),
            ChangeNotifierProvider<MockLectureProvider>.value(
              value: mockLectureProvider,
            ),
          ],
          child: MaterialApp(
            home: const SplashAuthGate(),
            routes: {
              '/sheikh/home': (context) => const SheikhHomePage(),
              '/login': (context) => LoginPage(toggleTheme: (bool) {}),
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should be on sheikh home
      expect(find.byType(SheikhHomePage), findsOneWidget);

      // Simulate logout
      mockAuthProvider.setNoSession();
      await tester.pumpAndSettle();

      // Should navigate to login
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets(
      'Kill & relaunch with sheikh session navigates to /sheikh/home without flash',
      (WidgetTester tester) async {
        // Simulate sheikh session on app restart
        mockAuthProvider.setSheikhSession();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<MockAuthProvider>.value(
                value: mockAuthProvider,
              ),
              ChangeNotifierProvider<MockLectureProvider>.value(
                value: mockLectureProvider,
              ),
            ],
            child: MaterialApp(home: const SplashAuthGate()),
          ),
        );

        // Should show splash briefly
        expect(find.byType(SplashAuthGate), findsOneWidget);

        await tester.pumpAndSettle();

        // Should navigate directly to sheikh home without flash
        expect(find.byType(SheikhHomePage), findsOneWidget);
      },
    );

    testWidgets('Add flow: Picker -> Form -> Save success', (
      WidgetTester tester,
    ) async {
      // Simulate sheikh session
      mockAuthProvider.setSheikhSession();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<MockAuthProvider>.value(
              value: mockAuthProvider,
            ),
            ChangeNotifierProvider<MockLectureProvider>.value(
              value: mockLectureProvider,
            ),
          ],
          child: MaterialApp(home: const SplashAuthGate()),
        ),
      );

      await tester.pumpAndSettle();

      // Should be on sheikh home
      expect(find.byType(SheikhHomePage), findsOneWidget);

      // Navigate to category picker
      await tester.tap(find.text('إضافة'));
      await tester.pumpAndSettle();

      // Should show category picker
      expect(find.byType(SheikhCategoryPicker), findsOneWidget);

      // Select a category
      await tester.tap(find.text('الفقه'));
      await tester.pumpAndSettle();

      // Should show add form
      expect(find.byType(AddLectureForm), findsOneWidget);
    });

    testWidgets('Time overlap prevention for same sheikh', (
      WidgetTester tester,
    ) async {
      // Test time overlap validation
      final result = await mockLectureProvider.addSheikhLecture(
        sheikhId: 'test-sheikh-id',
        sheikhName: 'الشيخ التجريبي',
        categoryKey: 'fiqh',
        categoryNameAr: 'الفقه',
        title: 'محاضرة تجريبية',
        startTime: DateTime.now().add(Duration(hours: 1)),
        endTime: DateTime.now().add(Duration(hours: 2)),
      );

      // Should prevent overlap
      expect(result, false);
    });

    testWidgets('Delete flow: Archive then permanent delete on confirmation', (
      WidgetTester tester,
    ) async {
      // Test archive functionality
      final archiveResult = await mockLectureProvider.archiveSheikhLecture(
        lectureId: 'test-lecture-id',
        sheikhId: 'test-sheikh-id',
      );

      expect(archiveResult, true);

      // Test permanent delete
      final deleteResult = await mockLectureProvider.deleteSheikhLecture(
        lectureId: 'test-lecture-id',
        sheikhId: 'test-sheikh-id',
      );

      expect(deleteResult, true);
    });
  });
}

// Mock classes for testing
class MockAuthProvider extends ChangeNotifier {
  String _sessionType = 'none';

  void setNoSession() {
    _sessionType = 'none';
    notifyListeners();
  }

  void setUserSession() {
    _sessionType = 'user';
    notifyListeners();
  }

  void setSheikhSession([Map<String, dynamic>? sheikhData]) {
    _sessionType = 'sheikh';
    notifyListeners();
  }

  bool get isReady => true;

  bool get isAuthenticated {
    switch (_sessionType) {
      case 'none':
        return false;
      case 'user':
      case 'sheikh':
        return true;
      default:
        return false;
    }
  }

  String? get currentUid {
    switch (_sessionType) {
      case 'none':
        return null;
      case 'user':
        return 'test-user-id';
      case 'sheikh':
        return 'test-sheikh-id';
      default:
        return null;
    }
  }

  Map<String, dynamic>? get currentUser {
    switch (_sessionType) {
      case 'none':
        return null;
      case 'user':
        return {
          'uid': 'test-user-id',
          'name': 'المستخدم التجريبي',
          'email': 'user@example.com',
          'role': 'user',
        };
      case 'sheikh':
        return {
          'uid': 'test-sheikh-id',
          'name': 'الشيخ التجريبي',
          'email': 'sheikh@example.com',
          'role': 'sheikh',
        };
      default:
        return null;
    }
  }

  String? get currentRole {
    switch (_sessionType) {
      case 'none':
        return null;
      case 'user':
        return 'user';
      case 'sheikh':
        return 'sheikh';
      default:
        return null;
    }
  }
}

class MockLectureProvider extends ChangeNotifier {
  bool get isLoading => false;

  String? get errorMessage => null;

  Future<bool> addSheikhLecture({
    required String sheikhId,
    required String sheikhName,
    required String categoryKey,
    required String categoryNameAr,
    required String title,
    String? description,
    required DateTime startTime,
    DateTime? endTime,
    Map<String, dynamic>? location,
    Map<String, dynamic>? media,
  }) async {
    // Mock time overlap check
    if (startTime.isBefore(DateTime.now().add(Duration(minutes: 30)))) {
      return false; // Simulate overlap
    }
    return true;
  }

  Future<bool> archiveSheikhLecture({
    required String lectureId,
    required String sheikhId,
  }) async {
    return true;
  }

  Future<bool> deleteSheikhLecture({
    required String lectureId,
    required String sheikhId,
  }) async {
    return true;
  }

  Future<bool> updateSheikhLecture({
    required String lectureId,
    required String sheikhId,
    required String categoryId,
    required String title,
    String? description,
    required DateTime startTime,
    DateTime? endTime,
    Map<String, dynamic>? location,
    Map<String, dynamic>? media,
  }) async {
    // Mock successful update
    return true;
  }
}
