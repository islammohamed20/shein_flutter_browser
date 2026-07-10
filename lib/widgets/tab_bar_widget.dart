import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/tab_manager.dart';
import 'tab_switcher.dart';

/// Compact tab bar showing current tab + tab count
class TabBarWidget extends StatelessWidget {
  const TabBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final tabManager = context.watch<TabManager>();
    final activeTab = tabManager.activeTab;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (activeTab == null) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.grey.shade100,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
          ),
        ),
      ),
      child: Row(
        children: [
          // Tab count + switcher button
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TabSwitcher(),
                  fullscreenDialog: true,
                ),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tab, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '${tabManager.tabCount}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Current tab title
          Expanded(
            child: Text(
              activeTab.title,
              style: const TextStyle(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // New tab button
          if (!tabManager.hasMaxTabs)
            IconButton(
              icon: const Icon(Icons.add, size: 20),
              tooltip: 'تبويب جديد',
              onPressed: () async {
                await tabManager.createTab();
              },
            ),
        ],
      ),
    );
  }
}
