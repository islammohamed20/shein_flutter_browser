import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/tab_manager.dart';
import '../models/browser_tab.dart';

/// Tab switcher widget - shows all open tabs
/// Based on Flutter Browser App tab viewer
class TabSwitcher extends StatelessWidget {
  final VoidCallback? onClose;

  const TabSwitcher({super.key, this.onClose});

  @override
  Widget build(BuildContext context) {
    final tabManager = context.watch<TabManager>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : Colors.grey.shade100,
      appBar: AppBar(
        title: Text('التبويبات (${tabManager.tabCount})'),
        actions: [
          if (!tabManager.hasMaxTabs)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'تبويب جديد',
              onPressed: () async {
                await tabManager.createTab();
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: tabManager.isEmpty
          ? _buildEmptyState(context)
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              itemCount: tabManager.tabCount,
              itemBuilder: (context, index) {
                final tab = tabManager.tabs[index];
                final isActive = index == tabManager.activeTabIndex;
                return _buildTabCard(context, tab, index, isActive, tabManager);
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.tab, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'لا توجد تبويبات',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildTabCard(
    BuildContext context,
    BrowserTab tab,
    int index,
    bool isActive,
    TabManager tabManager,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        tabManager.switchToTab(index);
        if (onClose != null) onClose!();
        Navigator.pop(context);
      },
      child: Card(
        elevation: isActive ? 8 : 2,
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isActive
              ? const BorderSide(color: Color(0xFFFF69B4), width: 2)
              : BorderSide.none,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Screenshot preview
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: tab.screenshot != null
                    ? Image.memory(tab.screenshot!, fit: BoxFit.cover)
                    : Container(
                        color: isDark
                            ? const Color(0xFF2A2A3E)
                            : Colors.grey.shade200,
                        child: const Center(
                          child: Icon(Icons.web, size: 48, color: Colors.grey),
                        ),
                      ),
              ),
            ),

            // Tab info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Favicon
                      if (tab.favicon != null)
                        Image.network(
                          tab.favicon!.url.toString(),
                          width: 16,
                          height: 16,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.language, size: 16),
                        )
                      else
                        const Icon(Icons.language, size: 16),
                      const SizedBox(width: 8),

                      // Title
                      Expanded(
                        child: Text(
                          tab.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Close button
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () async {
                          if (tab.isLoading) {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('إغلاق التبويب'),
                                content: const Text(
                                  'الصفحة قيد التحميل. هل تريد إغلاقها؟',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('إلغاء'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('إغلاق'),
                                  ),
                                ],
                              ),
                            );
                            if (ok != true) return;
                          }
                          await tabManager.closeTab(index);
                          if (tabManager.isEmpty && context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // URL
                  Row(
                    children: [
                      Icon(
                        tab.isSecure ? Icons.lock : Icons.lock_open,
                        size: 12,
                        color: tab.isSecure ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          tab.url,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // Badges
                  if (tab.isIncognito || tab.isDesktopMode) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (tab.isIncognito)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'خاص',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.purple,
                              ),
                            ),
                          ),
                        if (tab.isIncognito && tab.isDesktopMode)
                          const SizedBox(width: 4),
                        if (tab.isDesktopMode)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'سطح المكتب',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
