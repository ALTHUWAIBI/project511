import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:new_project/offline/firestore_shims.dart';
import 'package:new_project/provider/lecture_provider.dart';
import 'package:new_project/provider/hierarchy_provider.dart';
import 'package:new_project/provider/prayer_times_provider.dart';
import 'package:new_project/provider/location_provider.dart';
import 'package:new_project/provider/pro_login.dart';
import 'package:new_project/utils/time.dart';
import 'fiqh_section.dart';
import 'hadith_section.dart';
import 'tafsir_section.dart';
import 'seerah_section.dart';
import 'notifications_page.dart';
import 'settings_page.dart';
import 'section_categories_page.dart';
import '../widgets/mosque_map_preview.dart';
import '../widgets/app_drawer.dart';
import '../utils/page_transition.dart';

class HomePage extends StatefulWidget {
  final Function(bool) toggleTheme;
  const HomePage({Key? key, required this.toggleTheme}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // State for user interactions
  final Set<String> _bookmarkedLectures = <String>{};
  final Set<String> _likedLectures = <String>{};

  // Navigation debouncing to prevent double-taps
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    // Load location and calculate prayer times - defer to avoid blocking first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPrayerTimes();
    });
  }

  Future<void> _loadPrayerTimes() async {
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );
    final prayerTimesProvider = Provider.of<PrayerTimesProvider>(
      context,
      listen: false,
    );

    // Get current location
    await locationProvider.getCurrentLocation();

    // Calculate prayer times based on location
    if (locationProvider.currentPosition != null) {
      await prayerTimesProvider.calculatePrayerTimes(
        locationProvider.currentPosition,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('الرئيسية'),
            if (authProvider.isGuest) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('وضع الضيف', style: TextStyle(fontSize: 12)),
              ),
            ],
          ],
        ),
        centerTitle: true,
      ),
      drawer: AppDrawer(toggleTheme: widget.toggleTheme),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // Refresh all lectures and hierarchy
            final lectureProvider = Provider.of<LectureProvider>(
              context,
              listen: false,
            );
            final hierarchyProvider = Provider.of<HierarchyProvider>(
              context,
              listen: false,
            );
            await Future.wait([
              lectureProvider.loadAllSections(),
              hierarchyProvider.loadHomeHierarchy(forceRefresh: true),
            ]);
          },
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Column(
                    children: [
                      Image.asset('assets/logo.png', width: 80, height: 80),
                      const SizedBox(height: 8),
                      const Text(
                        'محاضرات',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSectionChip(
                        title: 'الحديث',
                        sectionKey: 'hadith',
                        icon: Icons.auto_stories,
                        isDarkMode: isDarkMode,
                      ),
                      _buildSectionChip(
                        title: 'التفسير',
                        sectionKey: 'tafsir',
                        icon: Icons.menu_book,
                        isDarkMode: isDarkMode,
                      ),
                      _buildSectionChip(
                        title: 'السيرة',
                        sectionKey: 'seerah',
                        icon: Icons.book,
                        isDarkMode: isDarkMode,
                      ),
                      _buildSectionChip(
                        title: 'الفقه',
                        sectionKey: 'fiqh',
                        icon: Icons.library_books,
                        isDarkMode: isDarkMode,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // أوقات الصلاة
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildPrayerTimesSection(),
                ),
                const SizedBox(height: 24),
                // My List section for signed-in users
                Consumer<AuthProvider>(
                  builder: (context, auth, child) {
                    if (auth.canInteract) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'قائمتي',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _showMyList(context),
                                  child: const Text('عرض الكل'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_bookmarkedLectures.isNotEmpty ||
                                _likedLectures.isNotEmpty)
                              Container(
                                height: 60,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: [
                                    if (_bookmarkedLectures.isNotEmpty)
                                      _buildQuickActionCard(
                                        'المحاضرات المحفوظة',
                                        Icons.bookmark,
                                        Colors.blue,
                                        _bookmarkedLectures.length,
                                      ),
                                    if (_likedLectures.isNotEmpty)
                                      _buildQuickActionCard(
                                        'المحاضرات المعجبة',
                                        Icons.favorite,
                                        Colors.red,
                                        _likedLectures.length,
                                      ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: const Center(
                                  child: Text(
                                    'ابدأ بحفظ المحاضرات المفضلة',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                const SizedBox(height: 24),
                // خريطة المسجد النبوي
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'خريطة المسجد النبوي',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      MosqueMapPreview(toggleTheme: widget.toggleTheme),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // المضافة مؤخرًا (Recently Added - keep for backward compatibility)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Selector<LectureProvider, List<Map<String, dynamic>>>(
                    selector: (context, provider) => provider.recentLectures,
                    builder: (context, recentLectures, child) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'المضافة مؤخرًا',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              if (recentLectures.isNotEmpty)
                                TextButton(
                                  onPressed: () {
                                    Provider.of<LectureProvider>(
                                      context,
                                      listen: false,
                                    ).loadAllSections();
                                  },
                                  child: const Icon(
                                    Icons.refresh,
                                    size: 20,
                                    color: Colors.green,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (recentLectures.isEmpty)
                            Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.library_books,
                                        size: 48,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'لا توجد محاضرات بعد',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else
                            ...recentLectures.map((lecture) {
                              // Handle both canonical keys and Arabic names for section
                              final section =
                                  lecture['section']?.toString() ?? 'unknown';
                              IconData sectionIcon = Icons.menu_book_outlined;
                              if (section == 'fiqh' || section == 'الفقه') {
                                sectionIcon = Icons.library_books;
                              } else if (section == 'hadith' ||
                                  section == 'الحديث') {
                                sectionIcon = Icons.auto_stories;
                              } else if (section == 'tafsir' ||
                                  section == 'التفسير') {
                                sectionIcon = Icons.menu_book;
                              } else if (section == 'seerah' ||
                                  section == 'السيرة') {
                                sectionIcon = Icons.book;
                              }

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Selector<AuthProvider, bool>(
                                  selector: (context, provider) =>
                                      provider.canInteract,
                                  builder: (context, canInteract, child) {
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.green,
                                        child: Icon(
                                          sectionIcon,
                                          color: Colors.white,
                                        ),
                                      ),
                                      title: Text(
                                        lecture['title']?.toString() ??
                                            'بدون عنوان',
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (lecture['description']
                                                  ?.toString()
                                                  .isNotEmpty ==
                                              true)
                                            Text(
                                              lecture['description']
                                                      ?.toString() ??
                                                  '',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'القسم: ${_getSectionDisplayName(lecture['section']?.toString() ?? '')}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Bookmark button for signed-in users
                                          IconButton(
                                            onPressed: canInteract
                                                ? () => _toggleBookmark(
                                                    lecture['id']?.toString() ??
                                                        '',
                                                  )
                                                : null,
                                            icon: Icon(
                                              _isBookmarked(
                                                    lecture['id']?.toString() ??
                                                        '',
                                                  )
                                                  ? Icons.bookmark
                                                  : Icons.bookmark_border,
                                              color: canInteract
                                                  ? Colors.green
                                                  : Colors.grey,
                                            ),
                                            tooltip: canInteract
                                                ? 'حفظ المحاضرة'
                                                : 'سجّل الدخول للحفظ',
                                          ),
                                          // Like button for signed-in users
                                          IconButton(
                                            onPressed: canInteract
                                                ? () => _toggleLike(
                                                    lecture['id']?.toString() ??
                                                        '',
                                                  )
                                                : null,
                                            icon: Icon(
                                              _isLiked(
                                                    lecture['id']?.toString() ??
                                                        '',
                                                  )
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                              color: canInteract
                                                  ? Colors.red
                                                  : Colors.grey,
                                            ),
                                            tooltip: canInteract
                                                ? 'إعجاب'
                                                : 'سجّل الدخول للإعجاب',
                                          ),
                                          // Video indicator
                                          if (lecture['video_path']
                                                  ?.toString()
                                                  .isNotEmpty ==
                                              true)
                                            const Icon(
                                              Icons.video_library,
                                              color: Colors.green,
                                            ),
                                        ],
                                      ),
                                      onTap: () {
                                        _showLectureDetails(context, lecture);
                                      },
                                    );
                                  },
                                ),
                              );
                            }).toList(),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'الإشعارات',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'الإعدادات',
          ),
        ],
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) {
            SmoothPageTransition.navigateTo(
              context,
              NotificationsPage(toggleTheme: widget.toggleTheme),
            );
          } else if (index == 2) {
            SmoothPageTransition.navigateTo(
              context,
              SettingsPage(toggleTheme: widget.toggleTheme),
            );
          }
        },
      ),
    );
  }

  Widget _buildPrayerTimesSection() {
    return Consumer2<PrayerTimesProvider, LocationProvider>(
      builder: (context, prayerTimesProvider, locationProvider, child) {
        if (prayerTimesProvider.isLoading || locationProvider.isLoading) {
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(
                child: CircularProgressIndicator(color: Colors.green),
              ),
            ),
          );
        }

        if (prayerTimesProvider.errorMessage != null ||
            locationProvider.errorMessage != null) {
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.orange,
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    prayerTimesProvider.errorMessage ??
                        locationProvider.errorMessage ??
                        'خطأ في تحميل أوقات الصلاة',
                    style: const TextStyle(color: Colors.orange),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _loadPrayerTimes,
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة المحاولة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (prayerTimesProvider.prayerTimes == null) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'أوقات الصلاة',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.refresh,
                    color: Colors.green,
                    size: 20,
                  ),
                  onPressed: _loadPrayerTimes,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Next prayer indicator
            if (prayerTimesProvider.nextPrayer.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade400, Colors.green.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.notifications_active,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'الصلاة القادمة',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${prayerTimesProvider.getArabicPrayerName(prayerTimesProvider.nextPrayer)} ${prayerTimesProvider.getFormattedPrayerTime(prayerTimesProvider.nextPrayer)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            prayerTimesProvider.getTimeUntilNextPrayer(),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            // Prayer times grid
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildPrayerTimeItem(
                            'fajr',
                            Icons.wb_twilight,
                            prayerTimesProvider,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildPrayerTimeItem(
                            'sunrise',
                            Icons.wb_sunny,
                            prayerTimesProvider,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildPrayerTimeItem(
                            'dhuhr',
                            Icons.wb_sunny_outlined,
                            prayerTimesProvider,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPrayerTimeItem(
                            'asr',
                            Icons.cloud,
                            prayerTimesProvider,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildPrayerTimeItem(
                            'maghrib',
                            Icons.nightlight,
                            prayerTimesProvider,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildPrayerTimeItem(
                            'isha',
                            Icons.bedtime,
                            prayerTimesProvider,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (locationProvider.locationName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'بتوقيت ${locationProvider.locationName}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPrayerTimeItem(
    String prayerKey,
    IconData icon,
    PrayerTimesProvider provider,
  ) {
    final isNext = provider.isNextPrayer(prayerKey);
    final arabicName = provider.getArabicPrayerName(prayerKey);
    final time = provider.getFormattedPrayerTime(prayerKey);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: isNext ? Colors.green.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isNext
            ? Border.all(color: Colors.green, width: 2)
            : Border.all(color: Colors.transparent, width: 2),
      ),
      child: Column(
        children: [
          Icon(icon, color: isNext ? Colors.green : Colors.grey, size: 20),
          const SizedBox(height: 4),
          Text(
            arabicName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
              color: isNext ? Colors.green : Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            time,
            style: TextStyle(
              fontSize: 10,
              color: isNext ? Colors.green : Colors.grey[600],
              fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic dateValue) {
    try {
      DateTime date;
      if (dateValue is Timestamp) {
        date = dateValue.toDate();
      } else if (dateValue is String) {
        date = DateTime.parse(dateValue);
      } else if (dateValue is DateTime) {
        date = dateValue;
      } else {
        return 'تاريخ غير صالح';
      }
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'تاريخ غير صالح';
    }
  }

  void _showLectureDetails(BuildContext context, Map<String, dynamic> lecture) {
    // Null-safe field extraction
    final title = lecture['title']?.toString() ?? 'بدون عنوان';
    final section = lecture['section']?.toString() ?? '';
    final description = lecture['description']?.toString() ?? '';
    final videoPath = lecture['video_path']?.toString();
    final createdAt = safeDateFromDynamic(
      lecture['createdAt'] ?? lecture['created_at'],
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (section.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'القسم: ${_getSectionDisplayName(section)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (description.isNotEmpty) ...[
                const Text(
                  'الوصف:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(description),
                const SizedBox(height: 16),
              ],
              if (videoPath != null && videoPath.isNotEmpty) ...[
                const Row(
                  children: [
                    Icon(Icons.video_library, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'يحتوي على فيديو',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (createdAt != null)
                Text(
                  'تاريخ الإضافة: ${_formatDate(createdAt)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  /// Build section chip (navigates to SectionCategoriesPage)
  Widget _buildSectionChip({
    required String title,
    required String sectionKey,
    required IconData icon,
    required bool isDarkMode,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isNavigating
            ? null
            : () {
                setState(() {
                  _isNavigating = true;
                });
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SectionCategoriesPage(
                      sectionKey: sectionKey,
                      sectionNameAr: title,
                      isDarkMode: isDarkMode,
                      toggleTheme: widget.toggleTheme,
                    ),
                  ),
                ).then((_) {
                  // Reset navigation flag after navigation completes
                  if (mounted) {
                    setState(() {
                      _isNavigating = false;
                    });
                  }
                });
              },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white,
                child: Icon(icon, color: Colors.black),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper methods for user interactions
  bool _isBookmarked(String lectureId) {
    return _bookmarkedLectures.contains(lectureId);
  }

  bool _isLiked(String lectureId) {
    return _likedLectures.contains(lectureId);
  }

  void _toggleBookmark(String lectureId) {
    setState(() {
      if (_bookmarkedLectures.contains(lectureId)) {
        _bookmarkedLectures.remove(lectureId);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم إلغاء حفظ المحاضرة')));
      } else {
        _bookmarkedLectures.add(lectureId);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حفظ المحاضرة')));
      }
    });
  }

  void _toggleLike(String lectureId) {
    setState(() {
      if (_likedLectures.contains(lectureId)) {
        _likedLectures.remove(lectureId);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم إلغاء الإعجاب')));
      } else {
        _likedLectures.add(lectureId);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم الإعجاب بالمحاضرة')));
      }
    });
  }

  /// Get Arabic display name for section (canonical key or Arabic name)
  String _getSectionDisplayName(String section) {
    final normalized = section.toLowerCase();
    switch (normalized) {
      case 'fiqh':
        return 'الفقه';
      case 'hadith':
        return 'الحديث';
      case 'tafsir':
        return 'التفسير';
      case 'seerah':
        return 'السيرة';
      default:
        // If already Arabic, return as-is
        return section;
    }
  }

  Widget _buildQuickActionCard(
    String title,
    IconData icon,
    Color color,
    int count,
  ) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: InkWell(
        onTap: () => _showMyList(context),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      '$count عنصر',
                      style: TextStyle(
                        fontSize: 10,
                        color: color.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMyList(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('قائمتي'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_bookmarkedLectures.isNotEmpty) ...[
                const Text(
                  'المحاضرات المحفوظة',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ..._bookmarkedLectures.map(
                  (id) => ListTile(
                    leading: const Icon(Icons.bookmark, color: Colors.blue),
                    title: Text('محاضرة $id'),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _bookmarkedLectures.remove(id);
                        });
                        Navigator.pop(context);
                        _showMyList(context); // Refresh dialog
                      },
                    ),
                  ),
                ),
                const Divider(),
              ],
              if (_likedLectures.isNotEmpty) ...[
                const Text(
                  'المحاضرات المعجبة',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ..._likedLectures.map(
                  (id) => ListTile(
                    leading: const Icon(Icons.favorite, color: Colors.red),
                    title: Text('محاضرة $id'),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _likedLectures.remove(id);
                        });
                        Navigator.pop(context);
                        _showMyList(context); // Refresh dialog
                      },
                    ),
                  ),
                ),
              ],
              if (_bookmarkedLectures.isEmpty && _likedLectures.isEmpty)
                const Text('لا توجد عناصر في قائمتك'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}

class CategoryIcon extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isDarkMode;

  const CategoryIcon({
    Key? key,
    required this.title,
    required this.icon,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Get toggleTheme from parent
          final homePageState = context
              .findAncestorStateOfType<_HomePageState>();
          final toggleTheme = homePageState?.widget.toggleTheme;

          switch (title) {
            case 'الفقه':
              SmoothPageTransition.navigateTo(
                context,
                FiqhSectionPage(
                  isDarkMode: isDarkMode,
                  toggleTheme: toggleTheme,
                ),
              );
              break;
            case 'الحديث':
              SmoothPageTransition.navigateTo(
                context,
                HadithSectionPage(
                  isDarkMode: isDarkMode,
                  toggleTheme: toggleTheme,
                ),
              );
              break;
            case 'التفسير':
              SmoothPageTransition.navigateTo(
                context,
                TafsirSectionPage(
                  isDarkMode: isDarkMode,
                  toggleTheme: toggleTheme,
                ),
              );
              break;
            case 'السيرة':
              SmoothPageTransition.navigateTo(
                context,
                SeerahSectionPage(
                  isDarkMode: isDarkMode,
                  toggleTheme: toggleTheme,
                ),
              );
              break;
          }
        },
        child: Column(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white,
              child: Icon(icon, color: Colors.black),
            ),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
