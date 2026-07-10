import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Device performance tier
enum DeviceTier {
  lowEnd, // <= 2GB RAM, economic CPU
  midRange, // 3-4GB RAM
  highEnd, // 6GB+ RAM
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
    // Estimate based on CPU cores and screen resolution
    final cores = Platform.numberOfProcessors;
    final pixelRatio =
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    final width = WidgetsBinding
        .instance
        .platformDispatcher
        .views
        .first
        .physicalSize
        .width;
    final height = WidgetsBinding
        .instance
        .platformDispatcher
        .views
        .first
        .physicalSize
        .height;
    final totalPixels = width * height;

    // Heuristics:
    // - <= 4 cores or very low resolution → lowEnd
    // - 6-8 cores with mid resolution → midRange
    // - 8+ cores with high resolution → highEnd
    if (cores <= 4 || totalPixels < 720 * 1280) {
      _tier = DeviceTier.lowEnd;
    } else if (cores >= 8 && totalPixels >= 1080 * 2400) {
      _tier = DeviceTier.highEnd;
    } else {
      _tier = DeviceTier.midRange;
    }

    debugPrint(
      '[DeviceOptimizer] Android: cores=$cores, pixels=${width.toInt()}x${height.toInt()}, ratio=$pixelRatio → $_tier',
    );
  }

  void _detectWindowsTier() {
    final cores = Platform.numberOfProcessors;
    if (cores >= 8) {
      _tier = DeviceTier.highEnd;
    } else if (cores >= 4) {
      _tier = DeviceTier.midRange;
    } else {
      _tier = DeviceTier.lowEnd;
    }
    debugPrint('[DeviceOptimizer] Windows: cores=$cores → $_tier');
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
