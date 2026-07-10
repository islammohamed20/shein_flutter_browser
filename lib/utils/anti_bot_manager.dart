import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Anti-bot detection bypass manager
///
/// Makes the browser appear as a human user to SHEIN by:
/// - Realistic User-Agent with matching headers
/// - Random mouse movements and scroll patterns
/// - Human-like timing delays
/// - Natural viewport and screen properties
/// - Realistic navigator properties
class AntiBotManager {
  static final AntiBotManager _instance = AntiBotManager._internal();
  factory AntiBotManager() => _instance;
  AntiBotManager._internal();

  Timer? _simulationTimer;

  // ─── Enhanced User-Agents ───

  /// Realistic mobile UA with all details
  static const String mobileUASamsung =
      'Mozilla/5.0 (Linux; Android 13; SM-S908B Build/TP1A.220624.014; wv) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 '
      'Chrome/120.0.6099.230 Mobile Safari/537.36';

  static const String mobileUAChrome =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7 Build/TQ3A.230901.001; wv) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 '
      'Chrome/120.0.6099.230 Mobile Safari/537.36';

  static const String desktopUAChrome =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/120.0.6099.230 Safari/537.36';

  /// Get a realistic UA
  static String getUserAgent({bool desktop = false}) {
    if (desktop) return desktopUAChrome;
    // Randomly pick between Samsung and Pixel
    final rng = Random();
    return rng.nextBool() ? mobileUASamsung : mobileUAChrome;
  }

  // ─── JavaScript Injection Scripts ───

  /// Simplified anti-bot script - only essential Navigator patches
  /// Removed complex Canvas/WebGL/Timing patches for stability
  String get antiBotInjectionScript => '''
(function() {
  'use strict';
  
  // Guard: prevent multiple initializations
  if (window.__antiBotInitialized) {
    return;
  }
  window.__antiBotInitialized = true;
  
  // ─── Navigator basic patches ───
  try {
    Object.defineProperty(navigator, 'platform', {
      get: function() { return 'Win32'; }
    });
  } catch(e) {}
  
  try {
    Object.defineProperty(navigator, 'hardwareConcurrency', {
      get: function() { return 8; }
    });
  } catch(e) {}
  
  try {
    Object.defineProperty(navigator, 'maxTouchPoints', {
      get: function() { return 10; }
    });
  } catch(e) {}
  
  try {
    Object.defineProperty(navigator, 'languages', {
      get: function() { return ['ar', 'en-US', 'en']; }
    });
  } catch(e) {}
  
  // ─── Remove automation flags ───
  try {
    delete window.cdc_adoQpoasnfa76pfcZLmcfl_Array;
    delete window.cdc_adoQpoasnfa76pfcZLmcfl_Promise;
    delete window.cdc_adoQpoasnfa76pfcZLmcfl_Symbol;
    delete window.webdriver;
  } catch(e) {}
  
  try {
    Object.defineProperty(navigator, 'webdriver', {
      get: function() { return false; }
    });
  } catch(e) {}
  
  console.log('[AntiBot] Initialized (simplified mode)');
})();
''';

  /// Human behavior simulation script
  /// Generates random mouse movements, scrolls, and touch events
  String get humanBehaviorScript => '''
(function() {
  'use strict';
  
  // Guard: prevent multiple simulation loops
  if (window.__humanBehaviorStarted) {
    return;
  }
  window.__humanBehaviorStarted = true;
  
  let lastMouseMove = Date.now();
  let mouseMoveCount = 0;
  let scrollCount = 0;
  
  // ─── Random mouse movements ───
  function simulateMouseMove() {
    const x = Math.random() * window.innerWidth;
    const y = Math.random() * window.innerHeight;
    const event = new MouseEvent('mousemove', {
      bubbles: true,
      cancelable: true,
      clientX: x,
      clientY: y,
      screenX: x,
      screenY: y,
      view: window
    });
    document.dispatchEvent(event);
    mouseMoveCount++;
    lastMouseMove = Date.now();
  }
  
  // ─── Random scroll ───
  function simulateScroll() {
    const scrollAmount = Math.floor(Math.random() * 100) + 20;
    const direction = Math.random() > 0.3 ? 1 : -1;
    window.scrollBy({ 
      top: scrollAmount * direction, 
      behavior: 'smooth' 
    });
    scrollCount++;
  }
  
  // ─── Random touch events (mobile) ───
  function simulateTouch() {
    const x = Math.random() * window.innerWidth;
    const y = Math.random() * window.innerHeight;
    const touch = new TouchEvent('touchstart', {
      touches: [new Touch({ identifier: 0, target: document.body, clientX: x, clientY: y })],
      bubbles: true
    });
    document.dispatchEvent(touch);
  }
  
  // ─── Random focus/blur (human tab switching) ───
  function simulateFocusBlur() {
    if (Math.random() > 0.8) {
      document.dispatchEvent(new Event('blur'));
      setTimeout(function() {
        document.dispatchEvent(new Event('focus'));
      }, Math.random() * 2000 + 500);
    }
  }
  
  // ─── Main simulation loop ───
  // Random intervals to appear human
  function runSimulation() {
    const delay = Math.random() * 5000 + 2000; // 2-7 seconds
    setTimeout(function() {
      const action = Math.random();
      if (action < 0.4) {
        simulateMouseMove();
      } else if (action < 0.7) {
        simulateScroll();
      } else if (action < 0.85) {
        simulateTouch();
      } else {
        simulateFocusBlur();
      }
      runSimulation();
    }, delay);
  }
  
  // Start simulation after page loads
  if (document.readyState === 'complete') {
    runSimulation();
  } else {
    window.addEventListener('load', runSimulation);
  }
  
  // ─── Random reading time before interaction ───
  // Humans don't click immediately - they read first
  window.addEventListener('load', function() {
    setTimeout(function() {
      // Simulate initial mouse movement after "reading"
      simulateMouseMove();
    }, Math.random() * 3000 + 1000);
  });
  
  console.log('[AntiBot] Human behavior simulation started');
})();
''';

  /// Headers that match the UA
  Map<String, String> get realisticHeaders => {
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,'
        'image/avif,image/webp,image/apng,*/*;q=0.8,'
        'application/signed-exchange;v=b3;q=0.7',
    'Accept-Language': 'ar,en-US;q=0.9,en;q=0.8',
    'Accept-Encoding': 'gzip, deflate, br',
    'Cache-Control': 'max-age=0',
    'Sec-Ch-Ua':
        '"Not_A Brand";v="8", "Chromium";v="120", '
        '"Google Chrome";v="120"',
    'Sec-Ch-Ua-Mobile': '?1',
    'Sec-Ch-Ua-Platform': '"Android"',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'none',
    'Sec-Fetch-User': '?1',
    'Upgrade-Insecure-Requests': '1',
    'X-Requested-With': 'com.android.chrome',
  };

  /// Start human simulation on a WebView controller
  void startSimulation(InAppWebViewController? controller) {
    if (controller == null) return;

    controller
        .evaluateJavascript(source: humanBehaviorScript)
        .then((_) {
          debugPrint('[AntiBot] Human simulation started');
        })
        .catchError((e) {
          debugPrint('[AntiBot] Failed to start simulation: $e');
        });
  }

  /// Stop simulation
  void stopSimulation() {
    _simulationTimer?.cancel();
  }

  /// Inject anti-bot script on page load (call once per page)
  Future<void> injectOnPageLoad(InAppWebViewController? controller) async {
    if (controller == null) return;

    try {
      // Only inject Navigator patches (simplified for stability)
      await controller.evaluateJavascript(source: antiBotInjectionScript);
      // Skip human behavior simulation on Windows (causes crashes)
      debugPrint('[AntiBot] Navigator patches injected successfully');
    } catch (e) {
      debugPrint('[AntiBot] Injection error: $e');
    }
  }

  /// Check if current URL is a SHEIN page
  bool isSheinPage(String url) {
    return url.contains('shein.com') || url.contains('shein.co');
  }

  void dispose() {
    stopSimulation();
  }
}
