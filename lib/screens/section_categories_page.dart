import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:new_project/provider/hierarchy_provider.dart';
import 'package:new_project/screens/category_subcategories_page.dart';
import '../widgets/app_drawer.dart';

class SectionCategoriesPage extends StatefulWidget {
  final String sectionKey;
  final String sectionNameAr;
  final bool isDarkMode;
  final Function(bool)? toggleTheme;

  const SectionCategoriesPage({
    super.key,
    required this.sectionKey,
    required this.sectionNameAr,
    required this.isDarkMode,
    this.toggleTheme,
  });

  @override
  State<SectionCategoriesPage> createState() => _SectionCategoriesPageState();
}

class _SectionCategoriesPageState extends State<SectionCategoriesPage> {
  @override
  void initState() {
    super.initState();
    // Set selected section and load categories - defer to avoid blocking first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final hierarchyProvider = Provider.of<HierarchyProvider>(
        context,
        listen: false,
      );
      hierarchyProvider.setSelectedSection(widget.sectionKey);
      hierarchyProvider.loadCategoriesBySection(widget.sectionKey);
    });
  }

  Future<void> _refreshCategories() async {
    final hierarchyProvider = Provider.of<HierarchyProvider>(
      context,
      listen: false,
    );
    await hierarchyProvider.loadCategoriesBySection(widget.sectionKey);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isDarkMode
          ? const Color(0xFF121212)
          : const Color(0xFFE4E5D3),
      appBar: AppBar(
        title: Text(widget.sectionNameAr),
        centerTitle: true,
        backgroundColor: Colors.green,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshCategories,
          ),
          if (widget.toggleTheme != null)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
        ],
      ),
      drawer: widget.toggleTheme != null
          ? AppDrawer(toggleTheme: widget.toggleTheme!)
          : null,
      body: Consumer<HierarchyProvider>(
        builder: (context, hierarchyProvider, child) {
          if (hierarchyProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (hierarchyProvider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 80, color: Colors.red[400]),
                  const SizedBox(height: 16),
                  Text(
                    hierarchyProvider.errorMessage!,
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshCategories,
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }

          final categories = hierarchyProvider.categories;

          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.category_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد فئات في هذا القسم',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'سيتم عرض الفئات هنا عند إضافتها',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshCategories,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView.builder(
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: widget.isDarkMode
                        ? const Color(0xFF1E1E1E)
                        : Colors.white,
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: Colors.green,
                        radius: 30,
                        child: const Icon(
                          Icons.category,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      title: Text(
                        category['name'] ?? 'بدون اسم',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: category['description'] != null
                          ? Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                category['description'],
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          : null,
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.green,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CategorySubcategoriesPage(
                              section: widget.sectionKey,
                              sectionNameAr: widget.sectionNameAr,
                              categoryId: category['id'] ?? '',
                              categoryName: category['name'] ?? 'بدون اسم',
                              isDarkMode: widget.isDarkMode,
                              toggleTheme: widget.toggleTheme,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        backgroundColor: widget.isDarkMode
            ? const Color(0xFF1E1E1E)
            : Colors.white,
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
        onTap: (index) {
          if (index == 1) {
            Navigator.popUntil(context, (route) => route.isFirst);
          }
        },
      ),
    );
  }
}
