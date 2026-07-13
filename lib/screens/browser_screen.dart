import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/settings_provider.dart';
import '../services/tab_manager.dart';
import '../models/browser_tab.dart';
import '../utils/device_optimizer.dart';
import '../widgets/quick_bar.dart';
import '../widgets/product_sidebar.dart';
import '../widgets/tab_switcher.dart' as tab_switcher;
import '../services/background_product_loader.dart';
import '../services/product_preview_manager.dart';
import 'settings_screen.dart';

/// Browser screen with multi-tab support
/// Optimized for 7"+ tablets with split-view layout
class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  final DeviceOptimizer _deviceOptimizer = DeviceOptimizer();
  final ProductDetector _productDetector = ProductDetector();
  final TextEditingController _urlController = TextEditingController();

  // Tablet breakpoint
  static const double tabletBreakpoint = 600.0;

  Timer? _spaUrlTimer;

  /// تحديث حقل URL في AppBar دون انتظار rebuild
  void _updateUrlBar(String url) {
    if (mounted && _urlController.text != url) {
      _urlController.text = url;
    }
  }

  @override
  void initState() {
    super.initState();
    _deviceOptimizer.init();

    // استطلاع دوري لالتقاط تغيّرات SPA التي لا تُطلق onLoadStop/onUpdateVisitedHistory
    _spaUrlTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final tabManager = context.read<TabManager>();
      final activeTab = tabManager.activeTab;
      if (activeTab?.controller == null) return;
      try {
        final currentUrl = await activeTab!.controller!.getUrl();
        final urlString = currentUrl?.toString() ?? '';
        if (urlString.isNotEmpty && urlString != activeTab.url) {
          activeTab.url = urlString;
          _updateUrlBar(urlString);
        }
      } catch (_) {}
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final tabManager = context.read<TabManager>();
      final sp = context.read<SettingsProvider>();
      debugPrint(
        '[BrowserScreen] Desktop mode: ${sp.desktopMode}, Region: ${sp.region}',
      );
      if (tabManager.isEmpty) {
        // Try to restore previous session
        await tabManager.restoreSession();
        if (tabManager.isEmpty) {
          // إنشاء تبويب جديد مع تطبيق وضع سطح المكتب على الرابط
          final startUrl = sp.adaptUrlForMode(sp.region, sp.desktopMode);
          debugPrint('[BrowserScreen] Creating new tab with URL: $startUrl');
          tabManager.createTab(url: startUrl);
        } else {
          // تطبيق وضع سطح المكتب على التبويبات المستعادة
          debugPrint(
            '[BrowserScreen] Restoring ${tabManager.tabs.length} tabs',
          );
          for (final tab in tabManager.tabs) {
            tab.isDesktopMode = sp.desktopMode;
            final adapted = sp.adaptUrlForMode(tab.url, sp.desktopMode);
            debugPrint('[BrowserScreen] Tab ${tab.id}: ${tab.url} -> $adapted');
            if (adapted != tab.url) {
              tab.url = adapted;
            }
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _scrollDetectTimer?.cancel();
    _spaUrlTimer?.cancel();
    super.dispose();
  }

  bool get _isTablet => MediaQuery.of(context).size.width >= tabletBreakpoint;

  @override
  Widget build(BuildContext context) {
    final tabManager = context.watch<TabManager>();
    final sp = context.watch<SettingsProvider>();

    // تحديث TextField عند تغيّر URL التبويب النشط
    if (tabManager.tabs.isNotEmpty && tabManager.activeTab != null) {
      final activeTab = tabManager.activeTab!;
      final newUrl = activeTab.url.isEmpty ? sp.region : activeTab.url;
      if (_urlController.text != newUrl) {
        _urlController.text = newUrl;
      }
    }

    if (tabManager.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final activeTab = tabManager.activeTab!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isTablet) {
      return _buildTabletLayout(context, activeTab, sp, isDark, tabManager);
    }
    return _buildPhoneLayout(context, activeTab, sp, isDark, tabManager);
  }

  // ─── Tablet Layout (7"+) ───
  Widget _buildTabletLayout(
    BuildContext context,
    BrowserTab activeTab,
    SettingsProvider sp,
    bool isDark,
    TabManager tabManager,
  ) {
    return Scaffold(
      appBar: _buildAppBar(context, activeTab, sp, isDark),
      endDrawer: Drawer(
        width: 340,
        child: ProductSidebar(
          onClose: () => Navigator.of(context).pop(),
          onScan: () => _startBackgroundScan(activeTab, sp),
        ),
      ),
      body: Row(
        children: [
          // Left sidebar - navigation
          _buildTabletSidebar(isDark, activeTab, sp),

          // Main content
          Expanded(
            child: Column(
              children: [
                Builder(
                  builder: (ctx) => QuickBar(
                    activeTab: activeTab,
                    onOpenProducts: () => Scaffold.of(ctx).openEndDrawer(),
                  ),
                ),
                if (activeTab.isLoading)
                  LinearProgressIndicator(
                    value: activeTab.progress,
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFFF69B4)),
                  ),
                Expanded(child: _buildWebViewContainer(tabManager, sp)),
                _buildBottomBar(activeTab, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Phone Layout ───
  Widget _buildPhoneLayout(
    BuildContext context,
    BrowserTab activeTab,
    SettingsProvider sp,
    bool isDark,
    TabManager tabManager,
  ) {
    return Scaffold(
      appBar: _buildAppBar(context, activeTab, sp, isDark),
      endDrawer: Drawer(
        width: 340,
        child: ProductSidebar(
          onClose: () => Navigator.of(context).pop(),
          onScan: () => _startBackgroundScan(activeTab, sp),
        ),
      ),
      body: Column(
        children: [
          Builder(
            builder: (ctx) => QuickBar(
              activeTab: activeTab,
              onOpenProducts: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
          if (activeTab.isLoading)
            LinearProgressIndicator(
              value: activeTab.progress,
              minHeight: 2,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation(Color(0xFFFF69B4)),
            ),
          Expanded(child: _buildWebViewContainer(tabManager, sp)),
          _buildBottomBar(activeTab, isDark),
        ],
      ),
    );
  }

  // ─── Tablet Sidebar ───
  Widget _buildTabletSidebar(
    bool isDark,
    BrowserTab activeTab,
    SettingsProvider sp,
  ) {
    return Container(
      width: 64,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F5F7),
        border: Border(
          right: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
          ),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          // SHEIN logo / home
          _sidebarIcon(
            Icons.home_rounded,
            'الرئيسية',
            isDark,
            () => activeTab.loadUrl(sp.region),
          ),

          _sidebarDivider(isDark),

          // Tab switcher
          _sidebarIcon(
            Icons.tab_rounded,
            'التبويبات',
            isDark,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const tab_switcher.TabSwitcher(),
                fullscreenDialog: true,
              ),
            ),
          ),

          // Incognito tab
          _sidebarIcon(
            Icons.visibility_off_rounded,
            'خفي',
            isDark,
            () => context.read<TabManager>().createTab(isIncognito: true),
            isActive: activeTab.isIncognito,
          ),

          _sidebarDivider(isDark),

          // SHEIN shortcuts
          _sidebarSection(isDark, 'SHEIN'),
          _sidebarIcon(
            Icons.local_offer_rounded,
            'تخفيضات',
            isDark,
            () => activeTab.loadUrl('${sp.region}/sale/'),
          ),
          _sidebarIcon(
            Icons.new_releases_rounded,
            'جديد',
            isDark,
            () => activeTab.loadUrl('${sp.region}/new/'),
          ),
          _sidebarIcon(
            Icons.woman_rounded,
            'نساء',
            isDark,
            () => activeTab.loadUrl('${sp.region}/women/'),
          ),
          _sidebarIcon(
            Icons.man_rounded,
            'رجال',
            isDark,
            () => activeTab.loadUrl('${sp.region}/men/'),
          ),

          const Spacer(),

          // ─── Bottom ───
          _sidebarDivider(isDark),
          _sidebarIcon(
            Icons.settings_outlined,
            'إعدادات',
            isDark,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _sidebarSection(bool isDark, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 7,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _sidebarDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      ),
    );
  }

  Widget _sidebarIcon(
    IconData icon,
    String label,
    bool isDark,
    VoidCallback? onTap, {
    bool isActive = false,
  }) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 48,
          height: 48,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFFF69B4).withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: isActive
                    ? const Color(0xFFFF69B4)
                    : isDark
                    ? Colors.grey.shade400
                    : Colors.grey.shade700,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 8,
                  color: isActive
                      ? const Color(0xFFFF69B4)
                      : isDark
                      ? Colors.grey.shade500
                      : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── App Bar ───
  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    BrowserTab activeTab,
    SettingsProvider sp,
    bool isDark,
  ) {
    return AppBar(
      elevation: 0,
      titleSpacing: _isTablet ? 16 : 8,
      bottom: activeTab.isLoading
          ? PreferredSize(
              preferredSize: const Size.fromHeight(2),
              child: LinearProgressIndicator(
                value: activeTab.progress > 0 ? activeTab.progress : null,
                minHeight: 2,
                backgroundColor: Colors.transparent,
                valueColor: const AlwaysStoppedAnimation(Color(0xFFFF69B4)),
              ),
            )
          : null,
      title: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _urlController,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: InputBorder.none,
                  prefixIcon: Icon(
                    activeTab.isSecure ? Icons.lock : Icons.lock_open,
                    size: 14,
                    color: activeTab.isSecure ? Colors.green : Colors.grey,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search_rounded, size: 16),
                    onPressed: () {
                      final controller = _urlController;
                      if (controller.text.isNotEmpty) {
                        activeTab.loadUrl(controller.text);
                      }
                    },
                  ),
                ),
                textInputAction: TextInputAction.go,
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    activeTab.loadUrl(value);
                  }
                },
              ),
            ),
          ),
        ],
      ),
      actions: [
        // Reload / Stop
        IconButton(
          icon: Icon(
            activeTab.isLoading
                ? Icons.stop_circle_outlined
                : Icons.refresh_rounded,
            size: 20,
          ),
          tooltip: activeTab.isLoading ? 'إيقاف' : 'تحديث',
          onPressed: activeTab.isLoading
              ? () => activeTab.stopLoading()
              : () => activeTab.reload(),
        ),

        // Bookmark
        IconButton(
          icon: Icon(
            sp.isBookmarked(activeTab.url)
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            size: 20,
            color: sp.isBookmarked(activeTab.url)
                ? const Color(0xFFFF69B4)
                : null,
          ),
          tooltip: sp.isBookmarked(activeTab.url)
              ? 'إزالة المفضلة'
              : 'حفظ مفضلة',
          onPressed: () => sp.toggleBookmark(activeTab.title, activeTab.url),
        ),

        // Products sidebar (all layouts)
        Builder(
          builder: (ctx) {
            final count = ProductDetector().count;
            return Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.inventory_2_outlined, size: 20),
                  tooltip: 'المنتجات المكتشفة',
                  onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                ),
                if (count > 0)
                  Positioned(
                    top: 6,
                    right: 6,
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
                  ),
              ],
            );
          },
        ),

        // Settings
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'الإعدادات',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ─── WebView Container ───
  Widget _buildWebViewContainer(TabManager tabManager, SettingsProvider sp) {
    return IndexedStack(
      index: tabManager.activeTabIndex,
      children: tabManager.tabs.map((tab) {
        return _buildWebViewForTab(tab, sp);
      }).toList(),
    );
  }

  Widget _buildWebViewForTab(BrowserTab tab, SettingsProvider sp) {
    final pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(
        color: const Color(0xFFFF69B4),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      onRefresh: () async {
        if (tab.controller != null) {
          await tab.controller!.reload();
        }
      },
    );
    tab.pullToRefreshController = pullToRefreshController;

    return InAppWebView(
      key: ValueKey(tab.id),
      keepAlive: tab.keepAlive,
      initialUrlRequest: URLRequest(url: WebUri(tab.url)),
      pullToRefreshController: pullToRefreshController,
      initialSettings: InAppWebViewSettings(
        // Core settings
        javaScriptEnabled: sp.jsEnabled,
        userAgent: sp.userAgentFor(tab.isDesktopMode || sp.desktopMode),

        // Allow mixed content (HTTP in HTTPS) - important for SHEIN
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,

        // Enable all storage types for lazy loading
        domStorageEnabled: true,
        databaseEnabled: true,
        allowFileAccess: true,
        allowContentAccess: true,

        // Third-party cookies for sessions
        thirdPartyCookiesEnabled: true,

        // Disable safe browsing to avoid interference
        safeBrowsingEnabled: false,

        // Image loading
        loadsImagesAutomatically: true,
        blockNetworkImage: false,

        // Viewport settings
        useWideViewPort: tab.isDesktopMode || sp.desktopMode,
        loadWithOverviewMode: true,
        supportZoom: true,
        builtInZoomControls: true,
        displayZoomControls: false,

        // Cache: استخدم الكاش أولاً ثم الشبكة - يوفر الباندويدث ويسرع التحميل
        cacheMode: CacheMode.LOAD_CACHE_ELSE_NETWORK,
        cacheEnabled: true,

        // Media
        mediaPlaybackRequiresUserGesture: true,
        allowsInlineMediaPlayback: true,

        // Network
        useShouldOverrideUrlLoading: false,

        // Text encoding
        defaultTextEncodingName: 'UTF-8',

        // Geolocation (some sites need it)
        geolocationEnabled: true,
      ),
      onWebViewCreated: (controller) {
        tab.controller = controller;
      },
      onLoadStart: (controller, url) {
        final newUrl = url.toString();
        tab.url = newUrl;
        _updateUrlBar(newUrl);
        tab.isLoading = true;
        tab.loaded = false;
        // Note: anti-bot injection happens only on onLoadStop to avoid duplicates
      },
      onLoadStop: (controller, url) async {
        final newUrl = url.toString();
        tab.url = newUrl;
        _updateUrlBar(newUrl);
        tab.isLoading = false;
        tab.loaded = true;
        await tab.updateNavigationState();

        // Screenshot only if device can handle it
        if (_deviceOptimizer.enableScreenshots) {
          tab.takeScreenshot();
        }

        final title = await controller.getTitle();
        if (title != null && title.isNotEmpty) {
          tab.title = title;
        }

        // Ad blocker only (if enabled in settings)
        if (sp.adBlocking) {
          try {
            await controller.evaluateJavascript(source: sp.adBlockScript);
          } catch (e) {
            // Ignore
          }
        }

        // Auto-detect product details (read-only, no page modification)
        if (url != null && _productDetector.isProductPage(url.toString())) {
          await _productDetector.extractFromPage(controller, url.toString());
        }
      },
      onProgressChanged: (controller, progress) {
        tab.progress = progress / 100;
        if (progress >= 100) {
          pullToRefreshController.endRefreshing();
        }
      },
      onTitleChanged: (controller, title) {
        if (title != null && title.isNotEmpty) {
          tab.title = title;
        }
      },
      onUpdateVisitedHistory: (controller, url, androidIsReload) {
        if (url != null) {
          final newUrl = url.toString();
          // تحديث URL التبويب دائماً — ضروري لتتبّع SPA
          tab.url = newUrl;
          _updateUrlBar(newUrl);
          if (!tab.isIncognito) {
            sp.addToHistory(tab.title, newUrl);
          }
        }
        // كشف المنتجات عند تنقّل SPA (تغيّر URL بدون onLoadStop)
        if (url != null && _productDetector.isProductPage(url.toString())) {
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted && tab.controller != null) {
              _productDetector.extractFromPage(controller, url.toString());
            }
          });
        }
      },
      onScrollChanged: (controller, x, y) {
        // Trigger auto-detection on scroll if enabled
        final previewManager = ProductPreviewManager();
        if (previewManager.autoDetectEnabled) {
          _onScrollDetect(controller, sp);
        }
      },
      onConsoleMessage: (controller, consoleMessage) {
        // Only log AntiBot messages and errors, not SHEIN's internal logs
        final msg = consoleMessage.message;
        if (msg.contains('AntiBot') ||
            msg.contains('error') ||
            msg.contains('Error')) {
          debugPrint('JS [${tab.title}]: $msg');
        }
      },
      onReceivedError: (controller, request, error) {
        if (request.isForMainFrame == true) {
          debugPrint('WebView main error [${tab.title}]: ${error.description}');
          tab.isLoading = false;
        }
      },
      onReceivedHttpError: (controller, request, response) {
        if (request.isForMainFrame == true &&
            (response.statusCode ?? 0) >= 500) {
          debugPrint(
            'HTTP ${response.statusCode} [${tab.title}] - retrying...',
          );
          Future.delayed(const Duration(seconds: 2), () {
            if (tab.controller != null) {
              controller.reload();
            }
          });
        }
      },
      onLongPressHitTestResult: (controller, hitTestResult) async {
        await _showContextMenu(controller, hitTestResult, tab, sp);
      },
    );
  }

  // ─── Share URL ───
  void _shareUrl(String url, String title) {
    Share.share(url, subject: title);
  }

  // ─── Scroll-based product preview detection ───
  Timer? _scrollDetectTimer;
  void _onScrollDetect(InAppWebViewController controller, SettingsProvider sp) {
    _scrollDetectTimer?.cancel();
    _scrollDetectTimer = Timer(const Duration(milliseconds: 800), () {
      debugPrint('[BrowserScreen] 🔍 Detecting products on scroll...');
      ProductPreviewManager().detectAndPreview(
        controller,
        sp.effectiveUserAgent,
      );
    });
  }

  // ─── Context Menu (Long Press) ───
  Future<void> _showContextMenu(
    InAppWebViewController controller,
    InAppWebViewHitTestResult hitTestResult,
    BrowserTab tab,
    SettingsProvider sp,
  ) async {
    final extra = hitTestResult.extra ?? '';
    final type = hitTestResult.type;

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Preview text
              if (extra.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    extra,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ),
              const Divider(height: 1),

              // ─── Link actions ───
              if (type == InAppWebViewHitTestResultType.SRC_ANCHOR_TYPE ||
                  type ==
                      InAppWebViewHitTestResultType.SRC_IMAGE_ANCHOR_TYPE) ...[
                _ctxItem(
                  ctx,
                  Icons.open_in_new_rounded,
                  'فتح في تبويب جديد',
                  () {
                    context.read<TabManager>().createTab(url: extra);
                  },
                ),
                _ctxItem(ctx, Icons.copy_rounded, 'نسخ الرابط', () {
                  Clipboard.setData(ClipboardData(text: extra));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم نسخ الرابط'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }),
              ],

              // ─── Image actions ───
              if (type == InAppWebViewHitTestResultType.IMAGE_TYPE ||
                  type ==
                      InAppWebViewHitTestResultType.SRC_IMAGE_ANCHOR_TYPE) ...[
                _ctxItem(ctx, Icons.copy_rounded, 'نسخ رابط الصورة', () {
                  Clipboard.setData(ClipboardData(text: extra));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم نسخ رابط الصورة'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }),
                _ctxItem(ctx, Icons.open_in_new_rounded, 'فتح الصورة', () {
                  tab.loadUrl(extra);
                }),
              ],

              // ─── Always available ───
              _ctxItem(ctx, Icons.refresh_rounded, 'إعادة تحميل الصفحة', () {
                tab.reload();
              }),
              _ctxItem(ctx, Icons.copy_rounded, 'نسخ رابط الصفحة', () {
                Clipboard.setData(ClipboardData(text: tab.url));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم نسخ الرابط'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }),
              _ctxItem(ctx, Icons.share_rounded, 'مشاركة الصفحة', () {
                Share.share(tab.url, subject: tab.title);
              }),
              _ctxItem(
                ctx,
                sp.isBookmarked(tab.url)
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                sp.isBookmarked(tab.url)
                    ? 'إزالة من المفضلة'
                    : 'حفظ في المفضلة',
                () => sp.toggleBookmark(tab.title, tab.url),
              ),
              _ctxItem(ctx, Icons.tab_rounded, 'فتح في تبويب جديد', () {
                context.read<TabManager>().createTab(url: tab.url);
              }),
              // Recently closed tabs
              if (context.read<TabManager>().recentlyClosed.isNotEmpty)
                _ctxItem(
                  ctx,
                  Icons.history_rounded,
                  'إعادة فتح تبويب مغلق',
                  () {
                    final tm = context.read<TabManager>();
                    showModalBottomSheet(
                      context: context,
                      builder: (c) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'التبويبات المغلقة recently',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            ...tm.recentlyClosed.asMap().entries.map((e) {
                              return ListTile(
                                leading: const Icon(Icons.history, size: 20),
                                title: Text(
                                  e.value['title'] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  e.value['url'] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                onTap: () {
                                  Navigator.pop(c);
                                  tm.reopenClosedTab(e.key);
                                },
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              _ctxItem(
                ctx,
                Icons.cleaning_services_rounded,
                'تحديث وحذف الكاش',
                () async {
                  await InAppWebViewController.clearAllCache();
                  tab.reload();
                },
              ),
              // Cookie management
              _ctxItem(
                ctx,
                Icons.cookie_outlined,
                'حذف كوكيز هذا الموقع',
                () async {
                  final uri = Uri.parse(tab.url);
                  await CookieManager.instance().deleteCookies(
                    url: WebUri('${uri.scheme}://${uri.host}'),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم حذف كوكيز الموقع'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                  tab.reload();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _ctxItem(
    BuildContext ctx,
    IconData icon,
    String label,
    VoidCallback action,
  ) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20, color: const Color(0xFFFF69B4)),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      onTap: () {
        Navigator.pop(ctx);
        action();
      },
    );
  }

  // ─── Background product scan ───
  Future<void> _startBackgroundScan(
    BrowserTab activeTab,
    SettingsProvider sp,
  ) async {
    final controller = activeTab.controller;
    if (controller == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('الصفحة غير جاهزة بعد')));
      }
      return;
    }
    try {
      await BackgroundProductLoader().scanAndLoad(
        controller,
        sp.effectiveUserAgent,
      );
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Bad state: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // ─── Bottom Bar ───
  Widget _buildBottomBar(BrowserTab activeTab, bool isDark) {
    if (_isTablet) {
      // On tablet, bottom bar is more spacious
      return Container(
        height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _navButton(
                Icons.arrow_back_ios_rounded,
                activeTab.canGoBack,
                () => activeTab.goBack(),
              ),
              _navButton(
                Icons.arrow_forward_ios_rounded,
                activeTab.canGoForward,
                () => activeTab.goForward(),
              ),
              _navButton(Icons.refresh_rounded, true, () => activeTab.reload()),
              _navButton(Icons.home_rounded, true, () {
                final sp = context.read<SettingsProvider>();
                activeTab.loadUrl(sp.region);
              }),
              if (activeTab.isLoading)
                _navButton(
                  Icons.stop_circle_outlined,
                  true,
                  () => activeTab.stopLoading(),
                ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _navButton(
              Icons.arrow_back_ios_rounded,
              activeTab.canGoBack,
              () => activeTab.goBack(),
            ),
            _navButton(
              Icons.arrow_forward_ios_rounded,
              activeTab.canGoForward,
              () => activeTab.goForward(),
            ),
            _navButton(Icons.refresh_rounded, true, () => activeTab.reload()),
            _navButton(Icons.home_rounded, true, () {
              final sp = context.read<SettingsProvider>();
              activeTab.loadUrl(sp.region);
            }),
            if (activeTab.isLoading)
              _navButton(
                Icons.stop_circle_outlined,
                true,
                () => activeTab.stopLoading(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _navButton(IconData icon, bool enabled, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, size: 22),
      color: enabled ? Theme.of(context).iconTheme.color : Colors.grey,
      onPressed: enabled ? onTap : null,
      splashRadius: 24,
    );
  }
}
