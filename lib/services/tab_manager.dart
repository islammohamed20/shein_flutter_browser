import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/browser_tab.dart';
import '../utils/device_optimizer.dart';

/// Manages multiple browser tabs
///
/// Features:
/// - Create/close/switch tabs
/// - Save/restore tab state
/// - Limit max tabs based on device capability
class TabManager extends ChangeNotifier {
  final DeviceOptimizer _deviceOptimizer = DeviceOptimizer();
  int get maxTabs => _deviceOptimizer.maxTabs;

  static const _keySavedTabs = 'saved_tabs_state';
  static const _keyRecentlyClosed = 'recently_closed_tabs';

  final List<BrowserTab> _tabs = [];
  int _activeTabIndex = -1;
  final List<Map<String, dynamic>> _recentlyClosed = [];

  List<Map<String, dynamic>> get recentlyClosed =>
      List.unmodifiable(_recentlyClosed);

  List<BrowserTab> get tabs => List.unmodifiable(_tabs);
  int get activeTabIndex => _activeTabIndex;
  BrowserTab? get activeTab =>
      _activeTabIndex >= 0 && _activeTabIndex < _tabs.length
      ? _tabs[_activeTabIndex]
      : null;

  int get tabCount => _tabs.length;
  bool get hasMaxTabs => _tabs.length >= maxTabs;
  bool get isEmpty => _tabs.isEmpty;

  /// Create a new tab
  Future<BrowserTab?> createTab({
    String? url,
    bool makeActive = true,
    bool isIncognito = false,
  }) async {
    if (_tabs.length >= maxTabs) {
      debugPrint('Cannot create tab: max tabs reached ($maxTabs)');
      return null;
    }

    final tab = BrowserTab(
      id: DateTime.now().millisecondsSinceEpoch,
      initialUrl: url ?? 'about:blank',
      isIncognito: isIncognito,
    );

    _tabs.add(tab);

    if (makeActive || _tabs.length == 1) {
      _activeTabIndex = _tabs.length - 1;
    }

    notifyListeners();
    return tab;
  }

  /// Close a tab by index
  Future<void> closeTab(int index) async {
    if (index < 0 || index >= _tabs.length) return;

    final tab = _tabs[index];
    // Save to recently closed (non-incognito only)
    if (!tab.isIncognito) {
      _recentlyClosed.insert(0, {
        'url': tab.url,
        'title': tab.title,
        'closedAt': DateTime.now().toIso8601String(),
      });
      if (_recentlyClosed.length > 10) {
        _recentlyClosed.removeLast();
      }
      _saveRecentlyClosed();
    }
    tab.dispose();
    _tabs.removeAt(index);

    // Adjust active tab index
    if (_tabs.isEmpty) {
      _activeTabIndex = -1;
    } else if (_activeTabIndex >= _tabs.length) {
      _activeTabIndex = _tabs.length - 1;
    } else if (_activeTabIndex > index) {
      _activeTabIndex--;
    }

    notifyListeners();
  }

  /// Close a specific tab
  Future<void> closeTabById(int id) async {
    final index = _tabs.indexWhere((t) => t.id == id);
    if (index >= 0) {
      await closeTab(index);
    }
  }

  /// Close all tabs
  Future<void> closeAllTabs() async {
    for (final tab in _tabs) {
      tab.dispose();
    }
    _tabs.clear();
    _activeTabIndex = -1;
    notifyListeners();
  }

  /// Close all tabs except the active one
  Future<void> closeOtherTabs() async {
    if (_activeTabIndex < 0) return;

    final activeTab = _tabs[_activeTabIndex];

    // Dispose other tabs
    for (int i = 0; i < _tabs.length; i++) {
      if (i != _activeTabIndex) {
        _tabs[i].dispose();
      }
    }

    _tabs.clear();
    _tabs.add(activeTab);
    _activeTabIndex = 0;

    notifyListeners();
  }

  /// Switch to a tab
  void switchToTab(int index) {
    if (index < 0 || index >= _tabs.length) return;
    if (_activeTabIndex == index) return;

    _activeTabIndex = index;
    notifyListeners();
  }

  /// Switch to a tab by ID
  void switchToTabById(int id) {
    final index = _tabs.indexWhere((t) => t.id == id);
    if (index >= 0) {
      switchToTab(index);
    }
  }

  /// Move tab to new position
  void moveTab(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _tabs.length) return;
    if (newIndex < 0 || newIndex >= _tabs.length) return;
    if (oldIndex == newIndex) return;

    final tab = _tabs.removeAt(oldIndex);
    _tabs.insert(newIndex, tab);

    // Update active index
    if (_activeTabIndex == oldIndex) {
      _activeTabIndex = newIndex;
    } else if (oldIndex < _activeTabIndex && newIndex >= _activeTabIndex) {
      _activeTabIndex--;
    } else if (oldIndex > _activeTabIndex && newIndex <= _activeTabIndex) {
      _activeTabIndex++;
    }

    notifyListeners();
  }

  /// Save tabs state
  Map<String, dynamic> saveState() {
    return {
      'tabs': _tabs.map((t) => t.toJson()).toList(),
      'activeTabIndex': _activeTabIndex,
    };
  }

  /// Save session to SharedPreferences
  Future<void> saveSession() async {
    try {
      final p = await SharedPreferences.getInstance();
      final state = saveState();
      await p.setString(_keySavedTabs, jsonEncode(state));
    } catch (e) {
      debugPrint('Save session error: $e');
    }
  }

  /// Restore session from SharedPreferences
  Future<void> restoreSession() async {
    try {
      final p = await SharedPreferences.getInstance();
      final json = p.getString(_keySavedTabs);
      if (json != null) {
        final state = jsonDecode(json) as Map<String, dynamic>;
        await restoreState(state);
      }
    } catch (e) {
      debugPrint('Restore session error: $e');
    }
  }

  /// Load recently closed tabs from storage
  Future<void> loadRecentlyClosed() async {
    try {
      final p = await SharedPreferences.getInstance();
      final json = p.getString(_keyRecentlyClosed);
      if (json != null) {
        final List<dynamic> list = jsonDecode(json);
        _recentlyClosed.clear();
        _recentlyClosed.addAll(list.cast<Map<String, dynamic>>());
      }
    } catch (e) {
      debugPrint('Load recently closed error: $e');
    }
  }

  /// Save recently closed to storage
  Future<void> _saveRecentlyClosed() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_keyRecentlyClosed, jsonEncode(_recentlyClosed));
    } catch (e) {
      debugPrint('Save recently closed error: $e');
    }
  }

  /// Reopen a recently closed tab
  Future<void> reopenClosedTab(int index) async {
    if (index < 0 || index >= _recentlyClosed.length) return;
    final item = _recentlyClosed[index];
    _recentlyClosed.removeAt(index);
    _saveRecentlyClosed();
    await createTab(url: item['url'] as String?);
  }

  /// Restore tabs state
  Future<void> restoreState(Map<String, dynamic> state) async {
    await closeAllTabs();

    final tabsJson = state['tabs'] as List<dynamic>?;
    if (tabsJson != null) {
      for (final json in tabsJson) {
        final tab = BrowserTab.fromJson(json as Map<String, dynamic>);
        _tabs.add(tab);
      }
    }

    _activeTabIndex = state['activeTabIndex'] as int? ?? 0;
    if (_activeTabIndex >= _tabs.length) {
      _activeTabIndex = _tabs.isEmpty ? -1 : _tabs.length - 1;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    saveSession();
    for (final tab in _tabs) {
      tab.dispose();
    }
    _tabs.clear();
    super.dispose();
  }
}
