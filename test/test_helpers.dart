import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:new_project/provider/pro_login.dart';
import 'package:new_project/provider/lecture_provider.dart';
import 'package:new_project/provider/hierarchy_provider.dart';

/// Mock AuthProvider for testing
class MockAuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool _isGuest = true;
  bool _isReady = true;
  Map<String, dynamic>? _currentUser;
  String? _errorMessage;
  bool _isLoading = false;

  bool get isLoggedIn => _isLoggedIn;
  bool get isGuest => _isGuest;
  bool get isAuthenticated => _isLoggedIn && !_isGuest;
  bool get isReady => _isReady;
  Map<String, dynamic>? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  String? get currentUid => _currentUser?['uid'];
  String? get role => _currentUser?['role'];
  String? get currentRole => _currentUser?['role'];
  String get displayName => _currentUser?['name'] ?? 'Test User';

  // Mock methods
  void setLoggedInUser(Map<String, dynamic> user) {
    _currentUser = user;
    _isLoggedIn = true;
    _isGuest = false;
    _isReady = true;
    notifyListeners();
  }

  void setGuestMode() {
    _currentUser = null;
    _isLoggedIn = false;
    _isGuest = true;
    _isReady = true;
    notifyListeners();
  }

  void setNoSession() {
    _currentUser = null;
    _isLoggedIn = false;
    _isGuest = true;
    _isReady = true;
    notifyListeners();
  }

  void setSheikhSession([Map<String, dynamic>? sheikhData]) {
    _currentUser =
        sheikhData ??
        {
          'uid': 'test-sheikh-id',
          'name': 'الشيخ التجريبي',
          'email': 'sheikh@example.com',
          'role': 'sheikh',
        };
    _isLoggedIn = true;
    _isGuest = false;
    _isReady = true;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  Future<void> initialize() async {
    _isReady = true;
    notifyListeners();
  }

  Future<bool> loginUser({
    required String email,
    required String password,
  }) async {
    setLoading(true);
    await Future.delayed(const Duration(milliseconds: 100));

    if (email == 'test@test.com' && password == 'password') {
      setLoggedInUser({
        'uid': 'test-uid',
        'email': email,
        'name': 'Test User',
        'role': 'user',
      });
      setLoading(false);
      return true;
    } else {
      setError('Invalid credentials');
      setLoading(false);
      return false;
    }
  }

  Future<void> signOut() async {
    setGuestMode();
  }

  void clearError() {
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  // Handle any missing methods
  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

/// Mock LectureProvider for testing
class MockLectureProvider extends ChangeNotifier {
  bool get isLoading => false;
  String? get errorMessage => null;
  List<Map<String, dynamic>> get sheikhLectures => [];
  Map<String, dynamic> get sheikhStats => {
    'totalLectures': 0,
    'upcomingToday': 0,
    'lastUpdated': null,
  };

  Future<bool> addSheikhLecture({
    required String sheikhId,
    required String sheikhName,
    required String section,
    required String categoryId,
    required String categoryName,
    String? subcategoryId,
    String? subcategoryName,
    required String title,
    String? description,
    required DateTime startTime,
    DateTime? endTime,
    Map<String, dynamic>? location,
    Map<String, dynamic>? media,
  }) async {
    // Mock successful save
    return true;
  }

  Future<void> loadSheikhLectures(String sheikhId) async {
    // Mock implementation
  }

  Future<void> loadSheikhStats(String sheikhId) async {
    // Mock implementation
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

  // Handle any missing methods
  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

/// Mock HierarchyProvider for testing
class MockHierarchyProvider extends ChangeNotifier {
  String? get selectedSection => 'fiqh';
  List<Map<String, dynamic>> get categories => [
    {'id': 'cat1', 'name': 'أحكام الصلاة'},
    {'id': 'cat2', 'name': 'أحكام الزكاة'},
  ];
  List<Map<String, dynamic>> get subcategories => [];
  List<Map<String, dynamic>> get lectures => [];
  bool get isLoading => false;
  String? get errorMessage => null;

  Future<void> setSelectedSection(String section) async {
    // Mock implementation
  }

  Future<void> loadCategoriesBySection(String section) async {
    // Mock implementation
  }

  Future<void> loadSubcategoriesByCategory(String categoryId) async {
    // Mock implementation
  }

  Future<void> loadLecturesWithHierarchy({
    required String section,
    String? categoryId,
    String? subcategoryId,
  }) async {
    // Mock implementation
  }

  Stream<List<Map<String, dynamic>>> getCategoriesStream(String section) {
    return Stream.value(categories);
  }

  Stream<List<Map<String, dynamic>>> getSubcategoriesStream(String categoryId) {
    return Stream.value(subcategories);
  }

  Stream<List<Map<String, dynamic>>> getLecturesStream({
    required String section,
    String? categoryId,
    String? subcategoryId,
  }) {
    return Stream.value(lectures);
  }

  void clearData() {
    // Mock implementation
  }

  // Handle any missing methods
  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

/// Creates a test widget with all necessary providers
Widget createTestWidgetWithProviders(
  Widget child, {
  MockAuthProvider? authProvider,
  MockLectureProvider? lectureProvider,
  MockHierarchyProvider? hierarchyProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(
        value: (authProvider ?? MockAuthProvider()) as AuthProvider,
      ),
      ChangeNotifierProvider<LectureProvider>.value(
        value: (lectureProvider ?? MockLectureProvider()) as LectureProvider,
      ),
      ChangeNotifierProvider<HierarchyProvider>.value(
        value:
            (hierarchyProvider ?? MockHierarchyProvider()) as HierarchyProvider,
      ),
    ],
    child: MaterialApp(
      home: child,
      theme: ThemeData(
        primarySwatch: Colors.green,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
      ),
    ),
  );
}

/// Creates a simple test widget without providers
Widget createTestWidget(Widget child) {
  return MaterialApp(
    home: child,
    theme: ThemeData(
      primarySwatch: Colors.green,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
    ),
  );
}
