import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTheme { light, dark, system }

enum SiteLanguage { arabic, english }

class BookmarkItem {
  final String title;
  final String url;
  final DateTime addedAt;

  BookmarkItem({required this.title, required this.url, DateTime? addedAt})
    : addedAt = addedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'title': title,
    'url': url,
    'addedAt': addedAt.toIso8601String(),
  };

  factory BookmarkItem.fromJson(Map<String, dynamic> json) => BookmarkItem(
    title: json['title'] ?? '',
    url: json['url'] ?? '',
    addedAt: DateTime.tryParse(json['addedAt'] ?? '') ?? DateTime.now(),
  );
}

class HistoryItem {
  final String title;
  final String url;
  final DateTime visitedAt;

  HistoryItem({required this.title, required this.url, DateTime? visitedAt})
    : visitedAt = visitedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'title': title,
    'url': url,
    'visitedAt': visitedAt.toIso8601String(),
  };

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
    title: json['title'] ?? '',
    url: json['url'] ?? '',
    visitedAt: DateTime.tryParse(json['visitedAt'] ?? '') ?? DateTime.now(),
  );
}

/// نوع زر الـ Quick Bar
enum QuickBarAction {
  back, // رجوع
  forward, // أمام
  reload, // تحديث
  home, // الرئيسية
  newTab, // تبويب جديد
  closeTab, // إغلاق تبويب
  toggleDesktop, // موبايل / ديسكتوب
  bookmark, // حفظ مفضلة
  products, // المنتجات المكتشفة
  findInPage, // بحث في الصفحة
  incognito, // تبويب خفي
  settings, // الإعدادات
  sheinWomen, // SHEIN نساء
  sheinMen, // SHEIN رجال
  sheinKids, // SHEIN أطفال
  sheinSale, // SHEIN تخفيضات
  sheinNew, // SHEIN وصل حديثاً
  copyUrl, // نسخ الرابط
  shareUrl, // مشاركة الرابط
}

class QuickBarItem {
  final String id;
  final QuickBarAction action;
  final String label;
  final String iconName;
  bool enabled;

  QuickBarItem({
    required this.id,
    required this.action,
    required this.label,
    required this.iconName,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'action': action.name,
    'label': label,
    'iconName': iconName,
    'enabled': enabled,
  };

  factory QuickBarItem.fromJson(Map<String, dynamic> json) => QuickBarItem(
    id: json['id'] ?? '',
    action: QuickBarAction.values.firstWhere(
      (e) => e.name == json['action'],
      orElse: () => QuickBarAction.reload,
    ),
    label: json['label'] ?? '',
    iconName: json['iconName'] ?? 'refresh',
    enabled: json['enabled'] ?? true,
  );

  static List<QuickBarItem> defaults() => [
    QuickBarItem(
      id: 'back',
      action: QuickBarAction.back,
      label: 'رجوع',
      iconName: 'arrow_back',
    ),
    QuickBarItem(
      id: 'forward',
      action: QuickBarAction.forward,
      label: 'أمام',
      iconName: 'arrow_forward',
    ),
    QuickBarItem(
      id: 'reload',
      action: QuickBarAction.reload,
      label: 'تحديث',
      iconName: 'refresh',
    ),
    QuickBarItem(
      id: 'home',
      action: QuickBarAction.home,
      label: 'رئيسية',
      iconName: 'home',
    ),
    QuickBarItem(
      id: 'newtab',
      action: QuickBarAction.newTab,
      label: 'تبويب',
      iconName: 'add',
    ),
    QuickBarItem(
      id: 'bookmark',
      action: QuickBarAction.bookmark,
      label: 'حفظ',
      iconName: 'bookmark_border',
      enabled: true,
    ),
    QuickBarItem(
      id: 'products',
      action: QuickBarAction.products,
      label: 'منتجات',
      iconName: 'inventory_2',
      enabled: true,
    ),
    QuickBarItem(
      id: 'desktop',
      action: QuickBarAction.toggleDesktop,
      label: 'وضع',
      iconName: 'desktop_windows',
      enabled: false,
    ),
    QuickBarItem(
      id: 'find',
      action: QuickBarAction.findInPage,
      label: 'بحث',
      iconName: 'search',
      enabled: false,
    ),
    QuickBarItem(
      id: 'incognito',
      action: QuickBarAction.incognito,
      label: 'خفي',
      iconName: 'visibility_off',
      enabled: false,
    ),
    QuickBarItem(
      id: 'sale',
      action: QuickBarAction.sheinSale,
      label: 'تخفيضات',
      iconName: 'local_offer',
      enabled: false,
    ),
    QuickBarItem(
      id: 'new',
      action: QuickBarAction.sheinNew,
      label: 'جديد',
      iconName: 'new_releases',
      enabled: false,
    ),
    QuickBarItem(
      id: 'copy',
      action: QuickBarAction.copyUrl,
      label: 'نسخ',
      iconName: 'copy',
      enabled: false,
    ),
    QuickBarItem(
      id: 'settings',
      action: QuickBarAction.settings,
      label: 'إعدادات',
      iconName: 'settings',
      enabled: false,
    ),
  ];
}

class SettingsProvider extends ChangeNotifier {
  static const _keyTheme = 'app_theme';
  static const _keyRegion = 'shein_region';
  static const _keyUa = 'custom_ua';
  static const _keyJsEnabled = 'js_enabled';
  static const _keyDesktopMode = 'desktop_mode';
  static const _keyAdBlocking = 'ad_blocking';
  static const _keyBookmarks = 'bookmarks';
  static const _keyHistory = 'history';
  static const _keyQuickBar = 'quick_bar';
  static const _keySiteLanguage = 'site_language';

  AppTheme _theme = AppTheme.system;
  String _region = 'https://ar.shein.com';
  String? _customUa;
  bool _jsEnabled = true;
  bool _desktopMode = false;
  bool _adBlocking = false;
  List<BookmarkItem> _bookmarks = [];
  List<HistoryItem> _history = [];
  List<QuickBarItem> _quickBar = QuickBarItem.defaults();
  SiteLanguage _siteLanguage = SiteLanguage.arabic;

  // ─── Getters ───
  AppTheme get theme => _theme;
  String get region => _region;
  String? get customUa => _customUa;
  bool get jsEnabled => _jsEnabled;
  bool get desktopMode => _desktopMode;
  bool get adBlocking => _adBlocking;
  List<BookmarkItem> get bookmarks => List.unmodifiable(_bookmarks);
  List<HistoryItem> get history => List.unmodifiable(_history);
  SiteLanguage get siteLanguage => _siteLanguage;

  ThemeMode get themeMode {
    switch (_theme) {
      case AppTheme.light:
        return ThemeMode.light;
      case AppTheme.dark:
        return ThemeMode.dark;
      case AppTheme.system:
        return ThemeMode.system;
    }
  }

  static const Map<String, String> regions = {
    '🇸🇦 السعودية': 'https://ar.shein.com',
    '🇪🇬 مصر': 'https://eg.shein.com',
    '🇦🇪 الإمارات': 'https://ae.shein.com',
    '🇰🇼 الكويت': 'https://kw.shein.com',
    '🇧🇭 البحرين': 'https://bh.shein.com',
    '🇶🇦 قطر': 'https://qa.shein.com',
    '🇴🇲 عُمان': 'https://om.shein.com',
    '🇯🇴 الأردن': 'https://jo.shein.com',
    '🇫🇷 فرنسا': 'https://fr.shein.com',
    '🇩🇪 ألمانيا': 'https://de.shein.com',
    '🇮🇹 إيطاليا': 'https://it.shein.com',
    '🇪🇸 إسبانيا': 'https://es.shein.com',
    '🇬🇧 بريطانيا': 'https://uk.shein.com',
    '🇮🇳 الهند': 'https://in.shein.com',
    '🇮🇩 إندونيسيا': 'https://id.shein.com',
    '🌐 الرئيسية EN': 'https://www.shein.com',
    '📱 موبايل': 'https://m.shein.com',
  };

  // ─── User Agents (Real Chrome, no WebView markers) ───
  static const String _mobileUa =
      'Mozilla/5.0 (Linux; Android 14; SM-S928B) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/125.0.6422.165 Mobile Safari/537.36';
  static const String _desktopUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/125.0.0.0 Safari/537.36';

  String get defaultUserAgent => _desktopMode ? _desktopUa : _mobileUa;

  String get effectiveUserAgent =>
      _customUa?.trim().isNotEmpty == true ? _customUa! : defaultUserAgent;

  // ─── Ad Block Script ───
  String get adBlockScript => '''
(function() {
  // Hide common ad elements
  var adSelectors = [
    'ins.adsbygoogle', 'iframe[src*="ads"]', 'iframe[src*="doubleclick"]',
    'div[id*="google_ads"]', 'div[id*="ad-container"]',
    'div[class*="ad-banner"]', 'div[class*="advertisement"]',
    '[id*="ad-banner"]', '[class*="ad-wrapper"]',
    'div[data-ad]', 'div[data-ad-slot]',
    '.ad-slot', '.ad-unit', '.ad-placement'
  ];
  for (var i = 0; i < adSelectors.length; i++) {
    var els = document.querySelectorAll(adSelectors[i]);
    for (var j = 0; j < els.length; j++) {
      els[j].style.setProperty('display', 'none', 'important');
    }
  }
  // Block ad scripts from loading
  var observer = new MutationObserver(function(mutations) {
    mutations.forEach(function(m) {
      m.addedNodes.forEach(function(node) {
        if (node.nodeType === 1) {
          var src = node.src || node.getAttribute('src') || '';
          if (src.indexOf('ads') > -1 || src.indexOf('doubleclick') > -1 || 
              src.indexOf('googlesyndication') > -1 || src.indexOf('adserver') > -1) {
            node.remove();
          }
        }
      });
    });
  });
  observer.observe(document.body || document.documentElement, {childList: true, subtree: true});
})();
''';

  // ─── Load / Save ───
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _theme = AppTheme.values[p.getInt(_keyTheme) ?? 2];
    _region = p.getString(_keyRegion) ?? regions.values.first;
    _customUa = p.getString(_keyUa);
    _jsEnabled = p.getBool(_keyJsEnabled) ?? true;
    _desktopMode = p.getBool(_keyDesktopMode) ?? false;
    _adBlocking = p.getBool(_keyAdBlocking) ?? false;
    _siteLanguage = SiteLanguage.values[p.getInt(_keySiteLanguage) ?? 0];

    // تحميل المفضلة
    final bookmarksJson = p.getString(_keyBookmarks);
    if (bookmarksJson != null) {
      try {
        final List<dynamic> list = jsonDecode(bookmarksJson);
        _bookmarks = list.map((e) => BookmarkItem.fromJson(e)).toList();
      } catch (_) {
        _bookmarks = [];
      }
    }

    // تحميل السجل
    final historyJson = p.getString(_keyHistory);
    if (historyJson != null) {
      try {
        final List<dynamic> list = jsonDecode(historyJson);
        _history = list.map((e) => HistoryItem.fromJson(e)).toList();
      } catch (_) {
        _history = [];
      }
    }

    // تحميل Quick Bar
    final qbJson = p.getString(_keyQuickBar);
    if (qbJson != null) {
      try {
        final List<dynamic> list = jsonDecode(qbJson);
        _quickBar = list.map((e) => QuickBarItem.fromJson(e)).toList();
      } catch (_) {
        _quickBar = QuickBarItem.defaults();
      }
    }

    notifyListeners();
  }

  Future<void> setSiteLanguage(SiteLanguage lang) async {
    _siteLanguage = lang;
    // تحديث region حسب اللغة
    if (lang == SiteLanguage.arabic) {
      _region = 'https://ar.shein.com';
    } else {
      _region = 'https://www.shein.com';
    }
    final p = await SharedPreferences.getInstance();
    await p.setInt(_keySiteLanguage, lang.index);
    await p.setString(_keyRegion, _region);
    notifyListeners();
  }

  Future<void> _saveBookmarks() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _keyBookmarks,
      jsonEncode(_bookmarks.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _saveHistory() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _keyHistory,
      jsonEncode(_history.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _saveQuickBar() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _keyQuickBar,
      jsonEncode(_quickBar.map((e) => e.toJson()).toList()),
    );
  }

  // ─── Quick Bar ───
  List<QuickBarItem> get quickBar => List.unmodifiable(_quickBar);

  Future<void> saveQuickBar(List<QuickBarItem> items) async {
    _quickBar = items;
    await _saveQuickBar();
    notifyListeners();
  }

  Future<void> resetQuickBar() async {
    _quickBar = QuickBarItem.defaults();
    await _saveQuickBar();
    notifyListeners();
  }

  // ─── Theme ───
  Future<void> setTheme(AppTheme t) async {
    _theme = t;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_keyTheme, t.index);
    notifyListeners();
  }

  // ─── Region ───
  Future<void> setRegion(String url) async {
    _region = url;
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyRegion, url);
    notifyListeners();
  }

  // ─── Custom UA ───
  Future<void> setCustomUa(String? ua) async {
    _customUa = ua;
    final p = await SharedPreferences.getInstance();
    if (ua == null || ua.isEmpty) {
      await p.remove(_keyUa);
    } else {
      await p.setString(_keyUa, ua);
    }
    notifyListeners();
  }

  // ─── JavaScript ───
  Future<void> setJsEnabled(bool v) async {
    _jsEnabled = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyJsEnabled, v);
    notifyListeners();
  }

  // ─── Desktop Mode ───
  Future<void> setDesktopMode(bool v) async {
    _desktopMode = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyDesktopMode, v);
    notifyListeners();
  }

  // ─── Ad Blocking ───
  Future<void> setAdBlocking(bool v) async {
    _adBlocking = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyAdBlocking, v);
    notifyListeners();
  }

  // ─── Bookmarks ───
  bool isBookmarked(String url) {
    return _bookmarks.any((b) => b.url == url);
  }

  Future<void> toggleBookmark(String title, String url) async {
    final idx = _bookmarks.indexWhere((b) => b.url == url);
    if (idx >= 0) {
      _bookmarks.removeAt(idx);
    } else {
      _bookmarks.insert(0, BookmarkItem(title: title, url: url));
    }
    await _saveBookmarks();
    notifyListeners();
  }

  Future<void> removeBookmark(String url) async {
    _bookmarks.removeWhere((b) => b.url == url);
    await _saveBookmarks();
    notifyListeners();
  }

  // ─── History ───
  Future<void> addToHistory(String title, String url) async {
    if (url.isEmpty || url == 'about:blank' || url.startsWith('app://')) return;
    // إزالة الإدخال القديم لنفس الرابط لتجنب التكرار
    _history.removeWhere((h) => h.url == url);
    _history.insert(0, HistoryItem(title: title, url: url));
    // الاحتفاظ بآخر 200 إدخال فقط
    if (_history.length > 200) {
      _history = _history.sublist(0, 200);
    }
    await _saveHistory();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _history.clear();
    await _saveHistory();
    notifyListeners();
  }

  Future<void> clearBookmarks() async {
    _bookmarks.clear();
    await _saveBookmarks();
    notifyListeners();
  }

  // ─── Clear All ───
  Future<void> clearAllData() async {
    final p = await SharedPreferences.getInstance();
    await p.clear();
    _theme = AppTheme.system;
    _region = regions.values.first;
    _customUa = null;
    _jsEnabled = true;
    _desktopMode = false;
    _adBlocking = false;
    _bookmarks = [];
    _history = [];
    _quickBar = QuickBarItem.defaults();
    _siteLanguage = SiteLanguage.arabic;
    notifyListeners();
  }
}
