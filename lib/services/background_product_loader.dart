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
  Future<List<String>> extractCardUrls(
    InAppWebViewController controller,
  ) async {
    try {
      final result = await controller.evaluateJavascript(
        source: '''
(function() {
  // قراءة فقط - لا تعديل على الصفحة
  var links = [];
  var seen = {};
  // روابط بطاقات المنتجات في SHEIN
  var anchors = document.querySelectorAll(
    'a[href*="-p-"], a[href*="/product/"], a[href*="-p-"][class*="product"]'
  );
  anchors.forEach(function(a) {
    var href = a.href || '';
    // تأكد أنه رابط منتج تفصيلي
    var isProduct = (href.indexOf('-p-') > -1 && href.indexOf('.html') > -1) ||
                    href.indexOf('/product/') > -1;
    if (isProduct && !seen[href]) {
      seen[href] = true;
      links.push(href);
    }
  });
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
    if (isBusy) return;
    _cancelled = false;
    _status = LoaderStatus.scanning;
    notifyListeners();

    final urls = await extractCardUrls(controller);
    if (urls.isEmpty) {
      _status = LoaderStatus.idle;
      notifyListeners();
      return;
    }

    _queue
      ..clear()
      ..addAll(urls.take(maxBatch));
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
    _currentUrl = url;
    _currentTitle = '';
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
        cacheMode: CacheMode.LOAD_CACHE_ELSE_NETWORK,
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
    await _disposeHeadless();
    _status = LoaderStatus.idle;
    _currentUrl = null;
    _secondsLeft = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _headless?.dispose();
    super.dispose();
  }
}
