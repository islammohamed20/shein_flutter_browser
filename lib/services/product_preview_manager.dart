import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../widgets/product_sidebar.dart';

/// نموذج معاينة منتج مصغرة
class ProductPreview {
  final String url;
  String title;
  Uint8List? screenshot;
  bool isLoading;
  int secondsLeft;
  Timer? _countdownTimer;
  HeadlessInAppWebView? _headless;

  ProductPreview({
    required this.url,
    this.title = '',
    this.screenshot,
    this.isLoading = true,
    this.secondsLeft = 10,
  });

  void dispose() {
    _countdownTimer?.cancel();
    _headless?.dispose();
    _headless = null;
  }
}

/// يدير معاينات مصغرة متعددة لصفحات المنتجات
/// يفتح كل رابط في HeadlessInAppWebView، يلتقط screenshot،
/// يعرضه لمدة 10 ثواني ثم يُغلقه تلقائياً
class ProductPreviewManager extends ChangeNotifier {
  static final ProductPreviewManager _instance =
      ProductPreviewManager._internal();
  factory ProductPreviewManager() => _instance;
  ProductPreviewManager._internal();

  final ProductDetector _detector = ProductDetector();

  final List<ProductPreview> _previews = [];
  List<ProductPreview> get previews => List.unmodifiable(_previews);

  /// أقصى عدد معاينات في نفس الوقت
  static const int maxConcurrentPreviews = 3;

  /// مدة عرض كل معاينة (ثواني)
  static const int previewDuration = 10;

  /// روابط قيد المعالجة (لتجنب التكرار)
  final Set<String> _processingUrls = {};

  /// روابط تمت معالجتها (لتجنب إعادة فتح نفس المنتج)
  final Set<String> _processedUrls = {};
  static const int maxProcessedUrls = 200;

  bool _autoDetectEnabled = false;
  bool get autoDetectEnabled => _autoDetectEnabled;

  /// تفعيل/تعطيل الاكتشاف التلقائي أثناء التصفح
  void setAutoDetect(bool enabled) {
    debugPrint(
      '[PreviewManager] ${enabled ? "✅ Enabled" : "❌ Disabled"} auto-detect',
    );
    _autoDetectEnabled = enabled;
    if (!enabled) {
      clearAll();
    }
    notifyListeners();
  }

  /// إنشاء معاينة جديدة لرابط منتج (متوازية)
  void addPreview(String url, String userAgent) {
    if (_previews.length >= maxConcurrentPreviews) return;
    if (_processingUrls.contains(url)) return;
    if (_processedUrls.contains(url)) return;

    _processingUrls.add(url);

    final preview = ProductPreview(url: url);
    _previews.insert(0, preview);
    notifyListeners();

    // تشغيل بالتوازي (fire-and-forget)
    _runPreview(preview, url, userAgent);
  }

  /// تشغيل معاينة واحدة في الخلفية
  Future<void> _runPreview(
    ProductPreview preview,
    String url,
    String userAgent,
  ) async {
    final completer = Completer<void>();

    preview._headless = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        userAgent: userAgent,
        javaScriptEnabled: true,
        domStorageEnabled: true,
        databaseEnabled: true,
        thirdPartyCookiesEnabled: true,
        cacheEnabled: true,
        cacheMode: CacheMode.LOAD_DEFAULT,
        mediaPlaybackRequiresUserGesture: true,
        blockNetworkImage: false,
        loadsImagesAutomatically: true,
        // تصغير العرض لمحاكاة شاشة مصغرة
        useWideViewPort: false,
        loadWithOverviewMode: true,
      ),
      onLoadStop: (controller, loadedUrl) async {
        if (_cancelled) {
          if (!completer.isCompleted) completer.complete();
          return;
        }

        // انتظار قصير ليكتمل المحتوى
        await Future.delayed(const Duration(seconds: 2));

        if (_cancelled) {
          if (!completer.isCompleted) completer.complete();
          return;
        }

        // التقط screenshot
        try {
          final screenshot = await controller.takeScreenshot();
          if (screenshot != null) {
            preview.screenshot = screenshot;
            preview.isLoading = false;
            notifyListeners();
          }
        } catch (e) {
          debugPrint('[PreviewManager] Screenshot error: $e');
          preview.isLoading = false;
          notifyListeners();
        }

        // استخراج تفاصيل المنتج
        if (loadedUrl != null &&
            _detector.isProductPage(loadedUrl.toString())) {
          await _detector.extractFromPage(controller, loadedUrl.toString());
        }

        // التقط العنوان
        final title = await controller.getTitle();
        if (title != null && title.isNotEmpty) {
          preview.title = title;
          notifyListeners();
        }

        if (!completer.isCompleted) completer.complete();
      },
      onReceivedError: (controller, request, error) {
        debugPrint('[PreviewManager] Error: ${error.description}');
        if (request.isForMainFrame == true && !completer.isCompleted) {
          completer.complete();
        }
      },
    );

    try {
      await preview._headless!.run();
      debugPrint('[PreviewManager] ✅ Started preview: $url');
    } catch (e) {
      debugPrint('[PreviewManager] ❌ Headless error: $e');
      _removePreview(preview);
      _processingUrls.remove(url);
      return;
    }

    // ابدأ العد التنازلي
    _startCountdown(preview);

    // انتظر اكتمال التحميل أو انتهاء المهلة
    await completer.future.timeout(
      const Duration(seconds: previewDuration),
      onTimeout: () {
        debugPrint('[PreviewManager] ⏱️ Timeout: $url');
      },
    );

    // انتظر بقية الوقت
    while (preview.secondsLeft > 0 && !_cancelled) {
      await Future.delayed(const Duration(milliseconds: 200));
    }

    _processedUrls.add(url);
    _processingUrls.remove(url);

    // Prevent unbounded growth
    if (_processedUrls.length > maxProcessedUrls) {
      _processedUrls.remove(_processedUrls.first);
    }

    // أزل المعاينة بعد انتهاء الوقت
    debugPrint('[PreviewManager] 🗑️ Removing: $url');
    _removePreview(preview);
  }

  void _startCountdown(ProductPreview preview) {
    preview._countdownTimer?.cancel();
    preview.secondsLeft = previewDuration;
    notifyListeners();
    preview._countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (preview.secondsLeft > 0) {
        preview.secondsLeft--;
        notifyListeners();
      } else {
        t.cancel();
      }
    });
  }

  void _removePreview(ProductPreview preview) {
    final idx = _previews.indexOf(preview);
    if (idx >= 0) {
      preview.dispose();
      _previews.removeAt(idx);
      notifyListeners();
    }
  }

  /// إزالة معاينة يدوياً (عند الضغط على X)
  void removePreview(int index) {
    if (index < 0 || index >= _previews.length) return;
    _removePreview(_previews[index]);
  }

  /// مسح جميع المعاينات
  void clearAll() {
    for (final p in _previews) {
      p.dispose();
    }
    _previews.clear();
    _processingUrls.clear();
    notifyListeners();
  }

  bool _cancelled = false;

  /// فحص روابط المنتجات الظاهرة في الصفحة وفتح معاينات للجديدة
  Future<void> detectAndPreview(
    InAppWebViewController controller,
    String userAgent,
  ) async {
    if (!_autoDetectEnabled) {
      debugPrint('[PreviewManager] ⚠️ Auto-detect is disabled');
      return;
    }
    _cancelled = false;

    debugPrint('[PreviewManager] 🔎 Scanning for product links...');
    try {
      final result = await controller.evaluateJavascript(
        source: '''
(function() {
  var links = [];
  var seen = {};
  
  // البحث عن أي روابط تحتوي على shein و .html
  var allAnchors = document.querySelectorAll('a');
  var count = 0;
  allAnchors.forEach(function(a) {
    var href = a.href || '';
    // أي رابط SHEIN ينتهي بـ .html
    if (href.indexOf('shein') > -1 && href.indexOf('.html') > -1) {
      if (!seen[href] && href.indexOf('http') === 0) {
        seen[href] = true;
        links.push(href);
        count++;
      }
    }
  });
  
  return JSON.stringify({links: links.slice(0, 10), total: count});
})();
''',
      );
      if (result == null) {
        debugPrint('[PreviewManager] ❌ No result from JS');
        return;
      }
      final decoded = result.toString();
      if (decoded.isEmpty) {
        debugPrint('[PreviewManager] ⚠️ Empty result');
        return;
      }
      Map<String, dynamic> data;
      try {
        data = jsonDecode(decoded) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('[PreviewManager] ❌ JSON decode error: $e');
        return;
      }
      final urls = data['links'] as List?;
      final total = data['total'] as int? ?? 0;
      if (urls == null || urls.isEmpty) {
        debugPrint(
          '[PreviewManager] ℹ️ No product links found (total scanned: $total)',
        );
        return;
      }

      debugPrint(
        '[PreviewManager] ✅ Found ${urls.length} product links (total: $total)',
      );

      // افتح معاينات للروابط الجديدة (حتى maxConcurrentPreviews)
      for (final url in urls) {
        if (_previews.length >= maxConcurrentPreviews) break;
        final urlStr = url.toString();
        if (!_processingUrls.contains(urlStr) &&
            !_processedUrls.contains(urlStr)) {
          // افتح المعاينة بدون انتظار (متوازية)
          addPreview(urlStr, userAgent);
        }
      }
    } catch (e) {
      debugPrint('[PreviewManager] detectAndPreview error: $e');
    }
  }

  @override
  void dispose() {
    _cancelled = true;
    for (final p in _previews) {
      p.dispose();
    }
    _previews.clear();
    super.dispose();
  }
}
