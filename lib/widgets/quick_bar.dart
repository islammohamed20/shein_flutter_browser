import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/settings_provider.dart';
import '../services/tab_manager.dart';
import '../models/browser_tab.dart';
import '../widgets/product_sidebar.dart';
import 'tab_switcher.dart';

/// Resolves iconName string → IconData
IconData _iconFor(String name) {
  switch (name) {
    case 'arrow_back':
      return Icons.arrow_back_ios_rounded;
    case 'arrow_forward':
      return Icons.arrow_forward_ios_rounded;
    case 'refresh':
      return Icons.refresh_rounded;
    case 'home':
      return Icons.home_rounded;
    case 'add':
      return Icons.add;
    case 'close':
      return Icons.close;
    case 'desktop_windows':
      return Icons.desktop_windows_rounded;
    case 'phone_android':
      return Icons.phone_android_rounded;
    case 'bookmark_border':
      return Icons.bookmark_border_rounded;
    case 'bookmark':
      return Icons.bookmark_rounded;
    case 'inventory_2':
      return Icons.inventory_2_outlined;
    case 'search':
      return Icons.search_rounded;
    case 'visibility_off':
      return Icons.visibility_off_rounded;
    case 'local_offer':
      return Icons.local_offer_rounded;
    case 'new_releases':
      return Icons.new_releases_rounded;
    case 'copy':
      return Icons.copy_rounded;
    case 'settings':
      return Icons.settings_outlined;
    default:
      return Icons.circle_outlined;
  }
}

// ─── Quick Bar Widget ───
class QuickBar extends StatelessWidget {
  final BrowserTab activeTab;
  final VoidCallback? onOpenProducts;

  const QuickBar({super.key, required this.activeTab, this.onOpenProducts});

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();
    final tabManager = context.watch<TabManager>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = sp.quickBar.where((i) => i.enabled).toList();

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Tab count chip
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const TabSwitcher(),
                fullscreenDialog: true,
              ),
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
                  width: 1.2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tab_rounded,
                    size: 16,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${tabManager.tabCount}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? Colors.grey.shade300
                          : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Scrollable action buttons
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: items.length,
              itemBuilder: (ctx, i) => _QuickBarButton(
                key: ValueKey(items[i].id),
                item: items[i],
                activeTab: activeTab,
                sp: sp,
                tabManager: tabManager,
                onOpenProducts: onOpenProducts,
                isDark: isDark,
              ),
            ),
          ),

          // Edit bar button
          IconButton(
            icon: Icon(
              Icons.tune_rounded,
              size: 18,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
            ),
            tooltip: 'تخصيص الشريط',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36),
            onPressed: () => _showEditBar(context, sp),
          ),
        ],
      ),
    );
  }

  void _showEditBar(BuildContext context, SettingsProvider sp) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: sp,
          child: const _EditBarScreen(),
        ),
        fullscreenDialog: true,
      ),
    );
  }
}

// ─── Single button ───
class _QuickBarButton extends StatelessWidget {
  final QuickBarItem item;
  final BrowserTab activeTab;
  final SettingsProvider sp;
  final TabManager tabManager;
  final VoidCallback? onOpenProducts;
  final bool isDark;

  const _QuickBarButton({
    super.key,
    required this.item,
    required this.activeTab,
    required this.sp,
    required this.tabManager,
    required this.onOpenProducts,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = _isActive(context);
    final bool isEnabled = _isEnabled();
    final Color color = isActive
        ? const Color(0xFFFF69B4)
        : isEnabled
        ? (isDark ? Colors.grey.shade300 : Colors.grey.shade700)
        : (isDark ? Colors.grey.shade700 : Colors.grey.shade400);

    IconData icon = _resolveIcon();

    return Tooltip(
      message: item.label,
      child: InkWell(
        onTap: isEnabled ? () => _execute(context) : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          decoration: isActive
              ? BoxDecoration(
                  color: const Color(0xFFFF69B4).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              // Badge for products
              if (item.action == QuickBarAction.products) _ProductBadge(),
            ],
          ),
        ),
      ),
    );
  }

  IconData _resolveIcon() {
    switch (item.action) {
      case QuickBarAction.reload:
        return activeTab.isLoading
            ? Icons.stop_circle_outlined
            : Icons.refresh_rounded;
      case QuickBarAction.toggleDesktop:
        return activeTab.isDesktopMode
            ? Icons.phone_android_rounded
            : Icons.desktop_windows_rounded;
      case QuickBarAction.bookmark:
        return sp.isBookmarked(activeTab.url)
            ? Icons.bookmark_rounded
            : Icons.bookmark_border_rounded;
      default:
        return _iconFor(item.iconName);
    }
  }

  bool _isActive(BuildContext context) {
    switch (item.action) {
      case QuickBarAction.toggleDesktop:
        return activeTab.isDesktopMode;
      case QuickBarAction.bookmark:
        return sp.isBookmarked(activeTab.url);
      default:
        return false;
    }
  }

  bool _isEnabled() {
    switch (item.action) {
      case QuickBarAction.back:
        return activeTab.canGoBack;
      case QuickBarAction.forward:
        return activeTab.canGoForward;
      default:
        return true;
    }
  }

  void _execute(BuildContext context) {
    switch (item.action) {
      case QuickBarAction.back:
        activeTab.goBack();
      case QuickBarAction.forward:
        activeTab.goForward();
      case QuickBarAction.reload:
        activeTab.isLoading ? activeTab.stopLoading() : activeTab.reload();
      case QuickBarAction.home:
        activeTab.loadUrl(sp.region);
      case QuickBarAction.newTab:
        tabManager.createTab();
      case QuickBarAction.closeTab:
        tabManager.closeTab(activeTab.id);
      case QuickBarAction.toggleDesktop:
        activeTab.isDesktopMode = !activeTab.isDesktopMode;
        activeTab.reload();
      case QuickBarAction.bookmark:
        sp.toggleBookmark(activeTab.title, activeTab.url);
      case QuickBarAction.products:
        onOpenProducts?.call();
      case QuickBarAction.findInPage:
        _doFindInPage(context);
      case QuickBarAction.incognito:
        tabManager.createTab(isIncognito: true);
      case QuickBarAction.settings:
        Navigator.pushNamed(context, '/settings');
      case QuickBarAction.sheinSale:
        activeTab.loadUrl('${sp.region}/sale/');
      case QuickBarAction.sheinNew:
        activeTab.loadUrl('${sp.region}/new/');
      case QuickBarAction.sheinWomen:
        activeTab.loadUrl('${sp.region}/women/');
      case QuickBarAction.sheinMen:
        activeTab.loadUrl('${sp.region}/men/');
      case QuickBarAction.sheinKids:
        activeTab.loadUrl('${sp.region}/kids/');
      case QuickBarAction.copyUrl:
        Clipboard.setData(ClipboardData(text: activeTab.url));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم نسخ الرابط'),
            duration: Duration(seconds: 1),
          ),
        );
      case QuickBarAction.shareUrl:
        Share.share(activeTab.url, subject: activeTab.title);
    }
  }

  void _doFindInPage(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'ابحث في الصفحة...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
                onSubmitted: (val) {
                  activeTab.controller?.findAllAsync(find: val);
                  Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Badge عدد المنتجات ───
class _ProductBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ProductDetector(),
      builder: (_, __) {
        final count = ProductDetector().count;
        if (count == 0) return const SizedBox.shrink();
        return Positioned(
          top: 0,
          right: 0,
          child: Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              color: Color(0xFFFF69B4),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 8,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Edit Bar Screen ───
class _EditBarScreen extends StatefulWidget {
  const _EditBarScreen();

  @override
  State<_EditBarScreen> createState() => _EditBarScreenState();
}

class _EditBarScreenState extends State<_EditBarScreen> {
  late List<QuickBarItem> _items;

  @override
  void initState() {
    super.initState();
    final sp = context.read<SettingsProvider>();
    _items = List.from(
      sp.quickBar.map(
        (e) => QuickBarItem(
          id: e.id,
          action: e.action,
          label: e.label,
          iconName: e.iconName,
          enabled: e.enabled,
        ),
      ),
    );
    // أضف أي عناصر افتراضية مفقودة
    for (final def in QuickBarItem.defaults()) {
      if (!_items.any((i) => i.id == def.id)) {
        _items.add(
          QuickBarItem(
            id: def.id,
            action: def.action,
            label: def.label,
            iconName: def.iconName,
            enabled: false,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = _items.where((i) => i.enabled).toList();
    final disabled = _items.where((i) => !i.enabled).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('تخصيص شريط الأدوات'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _items = QuickBarItem.defaults();
              });
            },
            child: const Text('إعادة تعيين'),
          ),
          TextButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('حفظ'),
            onPressed: _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Active buttons (reorderable)
          _buildSection(
            isDark,
            'الأزرار النشطة',
            Icons.check_circle_outline,
            Colors.green,
            'اضغط مطولاً للترتيب',
          ),
          const SizedBox(height: 8),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: (oldIdx, newIdx) {
              setState(() {
                if (newIdx > oldIdx) newIdx--;
                final item = enabled.removeAt(oldIdx);
                enabled.insert(newIdx, item);
                // Rebuild full list
                _items = [...enabled, ...disabled];
              });
            },
            children: enabled.map((item) {
              return _buildItemTile(item, true, isDark, key: Key(item.id));
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Inactive buttons
          _buildSection(
            isDark,
            'الأزرار المتاحة',
            Icons.add_circle_outline,
            const Color(0xFFFF69B4),
            'اضغط + لإضافتها',
          ),
          const SizedBox(height: 8),
          ...disabled.map(
            (item) => _buildItemTile(item, false, isDark, key: Key(item.id)),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    bool isDark,
    String title,
    IconData icon,
    Color color,
    String sub,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              sub,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildItemTile(
    QuickBarItem item,
    bool isEnabled,
    bool isDark, {
    required Key key,
  }) {
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 6),
      color: isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade50,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        dense: true,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isEnabled
                ? const Color(0xFFFF69B4).withValues(alpha: 0.12)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _iconFor(item.iconName),
            size: 18,
            color: isEnabled ? const Color(0xFFFF69B4) : Colors.grey,
          ),
        ),
        title: Text(item.label, style: const TextStyle(fontSize: 13)),
        subtitle: Text(
          _actionDescription(item.action),
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isEnabled)
              Icon(Icons.drag_handle, color: Colors.grey.shade400, size: 18),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                isEnabled
                    ? Icons.remove_circle_outline
                    : Icons.add_circle_outline,
                color: isEnabled ? Colors.red.shade400 : Colors.green.shade400,
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  final idx = _items.indexWhere((i) => i.id == item.id);
                  if (idx >= 0) _items[idx].enabled = !_items[idx].enabled;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  String _actionDescription(QuickBarAction a) {
    switch (a) {
      case QuickBarAction.back:
        return 'العودة للصفحة السابقة';
      case QuickBarAction.forward:
        return 'الانتقال للصفحة التالية';
      case QuickBarAction.reload:
        return 'إعادة تحميل / إيقاف التحميل';
      case QuickBarAction.home:
        return 'فتح الصفحة الرئيسية';
      case QuickBarAction.newTab:
        return 'فتح تبويب جديد';
      case QuickBarAction.closeTab:
        return 'إغلاق التبويب الحالي';
      case QuickBarAction.toggleDesktop:
        return 'التبديل بين موبايل وسطح المكتب';
      case QuickBarAction.bookmark:
        return 'حفظ الصفحة في المفضلة';
      case QuickBarAction.products:
        return 'عرض المنتجات المكتشفة';
      case QuickBarAction.findInPage:
        return 'البحث في محتوى الصفحة';
      case QuickBarAction.incognito:
        return 'فتح تبويب خفي';
      case QuickBarAction.settings:
        return 'فتح الإعدادات';
      case QuickBarAction.sheinSale:
        return 'فتح صفحة التخفيضات';
      case QuickBarAction.sheinNew:
        return 'فتح صفحة المنتجات الجديدة';
      case QuickBarAction.sheinWomen:
        return 'فتح قسم الملابس النسائية';
      case QuickBarAction.sheinMen:
        return 'فتح قسم الملابس الرجالية';
      case QuickBarAction.sheinKids:
        return 'فتح قسم الأطفال';
      case QuickBarAction.copyUrl:
        return 'نسخ رابط الصفحة الحالية';
      case QuickBarAction.shareUrl:
        return 'مشاركة رابط الصفحة';
    }
  }

  void _save() {
    context.read<SettingsProvider>().saveQuickBar(_items);
    Navigator.pop(context);
  }
}
