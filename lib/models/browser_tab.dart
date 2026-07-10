import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Represents a single browser tab
/// Based on Flutter Browser App's WebViewModel
class BrowserTab extends ChangeNotifier {
  final int id;
  final bool isIncognito;

  InAppWebViewController? _controller;
  PullToRefreshController? _pullToRefreshController;
  FindInteractionController? _findInteractionController;

  String _url;
  String _title;
  Favicon? _favicon;
  bool _isLoading;
  bool _loaded;
  double _progress;
  bool _canGoBack;
  bool _canGoForward;
  bool _isDesktopMode;
  bool _isSecure;
  Uint8List? _screenshot;
  DateTime? _lastVisited;
  final DateTime _createdTime;

  final keepAlive = InAppWebViewKeepAlive();

  BrowserTab({
    required this.id,
    required String initialUrl,
    this.isIncognito = false,
    DateTime? createdTime,
  }) : _url = initialUrl,
       _title = 'تبويب جديد',
       _favicon = null,
       _isLoading = false,
       _loaded = false,
       _progress = 0,
       _canGoBack = false,
       _canGoForward = false,
       _isDesktopMode = false,
       _isSecure = false,
       _screenshot = null,
       _createdTime = createdTime ?? DateTime.now(),
       _lastVisited = DateTime.now();

  // Getters
  InAppWebViewController? get controller => _controller;
  PullToRefreshController? get pullToRefreshController =>
      _pullToRefreshController;
  FindInteractionController? get findInteractionController =>
      _findInteractionController;
  String get url => _url;
  String get title => _title;
  Favicon? get favicon => _favicon;
  bool get isLoading => _isLoading;
  bool get loaded => _loaded;
  double get progress => _progress;
  bool get canGoBack => _canGoBack;
  bool get canGoForward => _canGoForward;
  bool get isDesktopMode => _isDesktopMode;
  bool get isSecure => _isSecure;
  Uint8List? get screenshot => _screenshot;
  DateTime get createdTime => _createdTime;
  DateTime? get lastVisited => _lastVisited;
  bool get isBlank => _url.isEmpty || _url == 'about:blank';

  // Setters
  set controller(InAppWebViewController? value) {
    _controller = value;
    notifyListeners();
  }

  set pullToRefreshController(PullToRefreshController? value) {
    _pullToRefreshController = value;
  }

  set findInteractionController(FindInteractionController? value) {
    _findInteractionController = value;
  }

  set url(String value) {
    if (_url != value) {
      _url = value;
      _lastVisited = DateTime.now();
      _isSecure = value.startsWith('https://');
      notifyListeners();
    }
  }

  set title(String value) {
    if (_title != value) {
      _title = value;
      notifyListeners();
    }
  }

  set favicon(Favicon? value) {
    if (_favicon != value) {
      _favicon = value;
      notifyListeners();
    }
  }

  set isLoading(bool value) {
    if (_isLoading != value) {
      _isLoading = value;
      notifyListeners();
    }
  }

  set loaded(bool value) {
    if (_loaded != value) {
      _loaded = value;
      notifyListeners();
    }
  }

  set progress(double value) {
    if (_progress != value) {
      _progress = value.clamp(0.0, 1.0);
      notifyListeners();
    }
  }

  set canGoBack(bool value) {
    if (_canGoBack != value) {
      _canGoBack = value;
      notifyListeners();
    }
  }

  set canGoForward(bool value) {
    if (_canGoForward != value) {
      _canGoForward = value;
      notifyListeners();
    }
  }

  set isDesktopMode(bool value) {
    if (_isDesktopMode != value) {
      _isDesktopMode = value;
      notifyListeners();
    }
  }

  set isSecure(bool value) {
    if (_isSecure != value) {
      _isSecure = value;
      notifyListeners();
    }
  }

  set screenshot(Uint8List? value) {
    _screenshot = value;
    notifyListeners();
  }

  // Methods
  Future<void> loadUrl(String newUrl) async {
    if (_controller == null) return;
    _url = newUrl;
    _isLoading = true;
    _lastVisited = DateTime.now();
    notifyListeners();

    await _controller!.loadUrl(urlRequest: URLRequest(url: WebUri(newUrl)));
  }

  Future<void> reload() async {
    if (_controller == null) return;
    _isLoading = true;
    notifyListeners();
    await _controller!.reload();
  }

  Future<void> goBack() async {
    if (_controller == null || !_canGoBack) return;
    await _controller!.goBack();
  }

  Future<void> goForward() async {
    if (_controller == null || !_canGoForward) return;
    await _controller!.goForward();
  }

  Future<void> stopLoading() async {
    if (_controller == null) return;
    await _controller!.stopLoading();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateNavigationState() async {
    if (_controller == null) return;
    _canGoBack = await _controller!.canGoBack();
    _canGoForward = await _controller!.canGoForward();
    notifyListeners();
  }

  // Screenshot capture
  Future<void> takeScreenshot() async {
    if (_controller == null) return;
    try {
      final data = await _controller!.takeScreenshot();
      _screenshot = data;
      notifyListeners();
    } catch (e) {
      debugPrint('Screenshot error: $e');
    }
  }

  // Serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': _url,
      'title': _title,
      'isIncognito': isIncognito,
      'isDesktopMode': _isDesktopMode,
      'createdTime': _createdTime.toIso8601String(),
      'lastVisited': _lastVisited?.toIso8601String(),
    };
  }

  factory BrowserTab.fromJson(Map<String, dynamic> json) {
    final createdTimeStr = json['createdTime'] as String?;
    final tab = BrowserTab(
      id: json['id'] as int,
      initialUrl: json['url'] as String? ?? 'about:blank',
      isIncognito: json['isIncognito'] as bool? ?? false,
      createdTime: createdTimeStr != null
          ? DateTime.tryParse(createdTimeStr)
          : null,
    );

    tab._title = json['title'] as String? ?? 'تبويب جديد';
    tab._isDesktopMode = json['isDesktopMode'] as bool? ?? false;

    final lastVisitedStr = json['lastVisited'] as String?;
    if (lastVisitedStr != null) {
      tab._lastVisited = DateTime.tryParse(lastVisitedStr);
    }

    return tab;
  }

  @override
  void dispose() {
    _controller = null;
    super.dispose();
  }

  @override
  String toString() {
    return 'BrowserTab(id: $id, url: $_url, title: $_title)';
  }
}
