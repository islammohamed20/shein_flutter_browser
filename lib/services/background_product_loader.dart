import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../widgets/product_sidebar.dart';

/// حالة المُحمِّل الخلفي
enum LoaderStatus { idle, scanning, loading, done }

/// يحمّل صفحات المنتجات في الخلفية (HeadlessInAppWebView) دون مغادرة
/// المستخدم لصفحة الفئة. كل تحميل يُطلق طلبات SHEIN الحقيقية فيلتقطها
/// Reqable عبر الشبكة، ثم نستخرج التفاصيل ونعرضها في القائمة الجانبية.
class BackgroundProductLoader extends ChangeNotifier {
  static final BackgroundProductLoader _instance =
      BackgroundProductLoader._internal();
  factory BackgroundProductLoader() => _instance;
  BackgroundProductLoader._internal();

  final ProductDetector _detector = ProductDetector();

  HeadlessInAppWebView? _headless;
  final Queue<String> _queue = Queue<String>();
  final Set<String> _processedUrls = {};
  bool _cancelled = false;

  LoaderStatus _status = LoaderStatus.idle;
  String? _currentUrl;
  String _currentTitle = '';
  int _processed = 0;
  int _total = 0;
  int _secondsLeft = 0;
  Timer? _countdownTimer;

  // ─── Getters ───
  LoaderStatus get status => _status;
  String? get currentUrl => _currentUrl;
  String get currentTitle => _currentTitle;
  int get processed => _processed;
  int get total => _total;
  int get secondsLeft => _secondsLeft;
  bool get isBusy =>
      _status == LoaderStatus.scanning || _status == LoaderStatus.loading;

  /// المدة (بالثواني) لكل منتج في الخلفية - تكفي SHEIN لإطلاق APIs
  /// وReqable لالتقاطها قبل الانتقال للتالي
  static const int perProductSeconds = 10;

  /// أقصى عدد روابط يُعالَج في الدفعة الواحدة (تجنب الإفراط)
  static const int maxBatch = 30;

  /// 1) قراءة روابط بطاقات المنتجات الظاهرة في صفحة الفئة (READ-ONLY)
  /// يمرّر الصفحة أولاً لتحميل البطاقات الكسولة ثم يستخرج الروابط
  Future<List<String>> extractCardUrls(
    InAppWebViewController controller,
  ) async {
    try {
      // تمرير الصفحة تدريجياً لتحميل البطاقات الكسولة (lazy load)
      for (int i = 0; i < 3; i++) {
        await controller.evaluateJavascript(
          source: '''
window.scrollBy(0, window.innerHeight * 0.8);
''',
        );
        await Future.delayed(const Duration(milliseconds: 800));
      }
      // العودة للأعلى
      await controller.evaluateJavascript(source: 'window.scrollTo(0, 0);');

      final result = await controller.evaluateJavascript(
        source: '''
(function() {
  function normalizeUrl(href) {
    try {
      if (!href || href.indexOf('http') !== 0) return '';
      var u = new URL(href, window.location.href);
      // احتفظ بالنطاق والمسار الأساسي فقط لمنتجات SHEIN
      return u.href;
    } catch (e) { return ''; }
  }

  function looksLikeProduct(href) {
    if (!href) return false;
    return (href.indexOf('-p-') > -1 && href.indexOf('.html') > -1) ||
           href.indexOf('/product/') > -1 ||
           href.indexOf('/goods?') > -1 ||
           /\/p-\d+\.html/.test(href);
  }

  var links = [];
  var seen = {};

  // ── المرحلة 1: محاولة قراءة الحالة الأولية من المتغيرات العامة ──
  try {
    var initial = window.__INITIAL_STATE__ || window.__data || window._SSR_HYDRATED_DATA;
    if (initial) {
      var text = JSON.stringify(initial);
      var matches = text.match(/https?:\\/\\/[^"'\\s]+\\/[^"'\\s]*-p-\\d+\\.html/g) || [];
      matches.forEach(function(m) {
        m = normalizeUrl(m);
        if (m && !seen[m] && looksLikeProduct(m)) { seen[m] = true; links.push(m); }
      });
    }
  } catch(e) {}

  // ── المرحلة 2: selectors موسعة ──
  var selectors = [
    'a[href*="-p-"]',
    'a[href*="/product/"]',
    'a[href*="/goods?"]',
    'a[href*="shein"][href*=".html"]',
    '[data-href*="-p-"]',
    '[data-href*=".html"]',
    '[data-goods-id] a',
    '[data-product-id] a',
    '[data-spu] a',
    'a[class*="product"]',
    'a[class*="goods"]',
    'a[class*="card"]',
    'a[class*="item"]'
  ];
  document.querySelectorAll(selectors.join(', ')).forEach(function(el) {
    var href = el.href || el.getAttribute('data-href') || el.getAttribute('href') || '';
    href = normalizeUrl(href);
    if (href && !seen[href] && looksLikeProduct(href)) {
      seen[href] = true;
      links.push(href);
    }
  });

  // ── المرحلة 3: fallback لجميع الروابط + الصور/العناصر التي تحمل data-src ──
  if (links.length === 0) {
    document.querySelectorAll('a[href], [data-href]').forEach(function(el) {
      var href = el.href || el.getAttribute('data-href') || '';
      href = normalizeUrl(href);
      if (href && !seen[href] && looksLikeProduct(href)) {
        seen[href] = true;
        links.push(href);
      }
    });
    // روابط قد تكون مدفونة في src للصور كبيرة الحجم
    document.querySelectorAll('img[src*="-p-"], img[data-src*="-p-"]').forEach(function(img) {
      var src = img.src || img.getAttribute('data-src') || '';
      var match = src.match(/(https?:\\/\\/[^"'\\s]+-p-\\d+\\.html)/);
      if (match) {
        var href = normalizeUrl(match[1]);
        if (href && !seen[href]) { seen[href] = true; links.push(href); }
      }
    });
  }

  return JSON.stringify(links);
})();
''',
      );
      if (result == null) return [];
      final decoded = jsonDecode(result.toString());
      if (decoded is! List) return [];
      return decoded
          .map((e) => e.toString())
          .where((e) => e.startsWith('http'))
          .toList();
    } catch (e) {
      debugPrint('[BgLoader] extractCardUrls error: $e');
      return [];
    }
  }

  /// 2) بدء المسح والتحميل الخلفي
  /// [controller] = متحكّم صفحة الفئة الحالية
  /// [userAgent]  = نفس UA المتصفح حتى تتطابق الجلسة
  Future<void> scanAndLoad(
    InAppWebViewController controller,
    String userAgent,
  ) async {
    if (isBusy) {
      throw StateError(
        'المسح قيد التشغيل بالفعل. انتظر انتهاء الدفعة الحالية أو أوقفها.',
      );
    }
    _cancelled = false;
    _status = LoaderStatus.scanning;
    notifyListeners();

    final currentUrl = (await controller.getUrl())?.toString() ?? 'غير معروف';
    debugPrint('[BgLoader] Starting scan on: $currentUrl');
    final urls = await extractCardUrls(controller);
    debugPrint('[BgLoader] Found ${urls.length} product URLs');
    if (urls.isEmpty) {
      _status = LoaderStatus.idle;
      notifyListeners();
      throw StateError(
        'لم يُعثَر على روابط منتجات في هذه الصفحة.\n'
        'تأكد أنك في صفحة فئة SHEIN (مثلاً: Dresses) وليس صفحة منتج واحد.\n'
        'الرابط الحالي: $currentUrl',
      );
    }

    _queue
      ..clear()
      ..addAll(urls.where((u) => !_processedUrls.contains(u)).take(maxBatch));
    _total = _queue.length;
    _processed = 0;
    _status = LoaderStatus.loading;
    notifyListeners();

    await _processNext(userAgent);
  }

  /// 3) معالجة الرابط التالي في الطابور
  Future<void> _processNext(String userAgent) async {
    if (_cancelled || _queue.isEmpty) {
      await _finish();
      return;
    }

    final url = _queue.removeFirst();
    _processedUrls.add(url);
    _currentUrl = url;
    _currentTitle = '';
    debugPrint('[BgLoader] Processing: $url');
    notifyListeners();

    final completer = Completer<void>();

    _headless = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        userAgent: userAgent,
        javaScriptEnabled: true,
        domStorageEnabled: true,
        databaseEnabled: true,
        thirdPartyCookiesEnabled: true,
        cacheEnabled: true,
        cacheMode: CacheMode.LOAD_NO_CACHE,
        mediaPlaybackRequiresUserGesture: true,
        // لا نحمّل الصور لتوفير الباندويدث - النص والـ APIs تكفي
        blockNetworkImage: false,
        loadsImagesAutomatically: true,
      ),
      onLoadStop: (ctrl, loadedUrl) async {
        // انتظار قصير ليكتمل JS و lazy content وتطلق APIs
        await Future.delayed(const Duration(seconds: 2));
        if (_cancelled) {
          if (!completer.isCompleted) completer.complete();
          return;
        }
        final title = await ctrl.getTitle();
        if (title != null && title.isNotEmpty) _currentTitle = title;
        notifyListeners();

        // استخراج التفاصيل الكاملة (يضيفها ProductDetector للقائمة)
        await _detector.extractFromPage(ctrl, url);
        if (!completer.isCompleted) completer.complete();
      },
      onReceivedError: (ctrl, request, error) {
        if (request.isForMainFrame == true && !completer.isCompleted) {
          completer.complete();
        }
      },
    );

    await _headless!.run();

    // عدّاد تنازلي يظهر في القائمة الجانبية
    _startCountdown();

    // ننتظر إما اكتمال التحميل أو انتهاء المهلة (perProductSeconds)
    await completer.future.timeout(
      const Duration(seconds: perProductSeconds),
      onTimeout: () {},
    );

    // إبقاء الصفحة حيّة لبقية الـ 10ث ليلتقطها Reqable كاملة
    await _waitRemaining();

    _processed++;
    notifyListeners();

    await _disposeHeadless();

    if (!_cancelled) {
      await _processNext(userAgent);
    } else {
      await _finish();
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _secondsLeft = perProductSeconds;
    notifyListeners();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft > 0) {
        _secondsLeft--;
        notifyListeners();
      } else {
        t.cancel();
      }
    });
  }

  Future<void> _waitRemaining() async {
    while (_secondsLeft > 0 && !_cancelled) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  Future<void> _disposeHeadless() async {
    _countdownTimer?.cancel();
    try {
      await _headless?.dispose();
    } catch (_) {}
    _headless = null;
  }

  Future<void> _finish() async {
    await _disposeHeadless();
    _status = LoaderStatus.done;
    _currentUrl = null;
    _currentTitle = '';
    _secondsLeft = 0;
    _processedUrls.clear();
    notifyListeners();
    // ارجع للوضع idle بعد لحظة
    await Future.delayed(const Duration(seconds: 1));
    if (_status == LoaderStatus.done) {
      _status = LoaderStatus.idle;
      notifyListeners();
    }
  }

  /// إيقاف العملية الجارية
  Future<void> cancel() async {
    _cancelled = true;
    _queue.clear();
    _processedUrls.clear();
    await _disposeHeadless();
    _status = LoaderStatus.idle;
    _currentUrl = null;
    _secondsLeft = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelled = true;
    _countdownTimer?.cancel();
    _queue.clear();
    _processedUrls.clear();
    _headless?.dispose().catchError((_) {});
    _headless = null;
    super.dispose();
  }
}
