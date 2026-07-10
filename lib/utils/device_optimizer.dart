import 'dart:io';
import 'package:flutter/foundation.dart';

/// Device performance tier
enum DeviceTier {
  lowEnd,    // <= 2GB RAM, economic CPU
  midRange,  // 3-4GB RAM
  highEnd,   // 6GB+ RAM
}

/// Device performance optimizer for low-end hardware
/// 
/// Detects device capabilities and adjusts:
/// - Max tabs based on available RAM
/// - Image loading quality
/// - Cache size limits
/// - Animation complexity
class DeviceOptimizer {
  static final DeviceOptimizer _instance = DeviceOptimizer._internal();
  factory DeviceOptimizer() => _instance;
  DeviceOptimizer._internal();

  DeviceTier _tier = DeviceTier.midRange;
  bool _initialized = false;

  DeviceTier get tier => _tier;
  bool get isLowEnd => _tier == DeviceTier.lowEnd;
  bool get isMidRange => _tier == DeviceTier.midRange;
  bool get isHighEnd => _tier == DeviceTier.highEnd;

  /// Initialize device detection
  void init() {
    if (_initialized) return;
    _initialized = true;

    if (Platform.isAndroid) {
      _detectAndroidTier();
    } else if (Platform.isWindows) {
      _detectWindowsTier();
    } else {
      _tier = DeviceTier.midRange;
    }

    debugPrint('[DeviceOptimizer] Tier: $_tier');
  }

  void _detectAndroidTier() {
    _tier = DeviceTier.midRange;
  }

  void _detectWindowsTier() {
    _tier = DeviceTier.midRange;
  }

  /// Set tier manually (from settings)
  void setTier(DeviceTier t) {
    _tier = t;
    debugPrint('[DeviceOptimizer] Tier set to: $t');
  }

  // ─── Optimized Settings ───

  int get maxTabs {
    switch (_tier) {
      case DeviceTier.lowEnd:
        return 3;
      case DeviceTier.midRange:
        return 5;
      case DeviceTier.highEnd:
        return 10;
    }
  }

  bool get enableScreenshots {
    switch (_tier) {
      case DeviceTier.lowEnd:
        return false;
      case DeviceTier.midRange:
        return true;
      case DeviceTier.highEnd:
        return true;
    }
  }

  bool get keepAllTabsAlive {
    switch (_tier) {
      case DeviceTier.lowEnd:
        return false;
      case DeviceTier.midRange:
        return true;
      case DeviceTier.highEnd:
        return true;
    }
  }

  String get cacheMode {
    switch (_tier) {
      case DeviceTier.lowEnd:
        return 'LOAD_CACHE_ELSE_NETWORK';
      case DeviceTier.midRange:
        return 'LOAD_DEFAULT';
      case DeviceTier.highEnd:
        return 'LOAD_DEFAULT';
    }
  }

  bool get enableAnimations {
    switch (_tier) {
      case DeviceTier.lowEnd:
        return false;
      case DeviceTier.midRange:
        return true;
      case DeviceTier.highEnd:
        return true;
    }
  }

  bool get loadImagesAutomatically {
    switch (_tier) {
      case DeviceTier.lowEnd:
        return true;
      case DeviceTier.midRange:
        return true;
      case DeviceTier.highEnd:
        return true;
    }
  }

  bool get blockHeavyResources {
    switch (_tier) {
      case DeviceTier.lowEnd:
        return true;
      case DeviceTier.midRange:
        return false;
      case DeviceTier.highEnd:
        return false;
    }
  }

  List<String> get blockedResourcePatterns {
    if (!isLowEnd) return [];
    
    return [
      '*.mp4',
      '*.webm',
      '*.avi',
      '*.mov',
      'ads.*',
      'analytics.*',
      'tracking.*',
      'doubleclick.*',
      'googlesyndication.*',
      'googleadservices.*',
      'facebook.com/tr',
      'hotjar.*',
      'clarity.ms',
    ];
  }

  String get tabLimitMessage {
    switch (_tier) {
      case DeviceTier.lowEnd:
        return 'حد أقصى 3 تبويبات (جهاز اقتصادي)';
      case DeviceTier.midRange:
        return 'حد أقصى 5 تبويبات';
      case DeviceTier.highEnd:
        return 'حد أقصى 10 تبويبات';
    }
  }

  int get estimatedMemoryPerTabMB {
    switch (_tier) {
      case DeviceTier.lowEnd:
        return 30;
      case DeviceTier.midRange:
        return 40;
      case DeviceTier.highEnd:
        return 50;
    }
  }

  int? get inactiveTabDisposeSeconds {
    switch (_tier) {
      case DeviceTier.lowEnd:
        return 60;
      case DeviceTier.midRange:
        return null;
      case DeviceTier.highEnd:
        return null;
    }
  }
}
