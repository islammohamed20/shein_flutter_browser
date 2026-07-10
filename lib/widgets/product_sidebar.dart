import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import '../services/background_product_loader.dart';
import '../services/product_preview_manager.dart';
import '../services/tab_manager.dart';

/// Detected product info (read-only extraction)
class ProductInfo {
  final String url;
  final String title;
  final String? price;
  final String? originalPrice;
  final String? currency;
  final String? sku;
  final List<String> images;
  final String? description;
  final String? rating;
  final String? reviewCount;
  final DateTime detectedAt;

  ProductInfo({
    required this.url,
    required this.title,
    this.price,
    this.originalPrice,
    this.currency,
    this.sku,
    this.images = const [],
    this.description,
    this.rating,
    this.reviewCount,
    required this.detectedAt,
  });

  Map<String, dynamic> toJson() => {
    'url': url,
    'title': title,
    'price': price,
    'originalPrice': originalPrice,
    'currency': currency,
    'sku': sku,
    'images': images,
    'description': description,
    'rating': rating,
    'reviewCount': reviewCount,
    'detectedAt': detectedAt.toIso8601String(),
  };
}

/// Product detector - reads product details from current page (read-only)
/// ChangeNotifier so UI auto-refreshes when a product is detected
class ProductDetector extends ChangeNotifier {
  static final ProductDetector _instance = ProductDetector._internal();
  factory ProductDetector() => _instance;
  ProductDetector._internal();

  final List<ProductInfo> _detectedProducts = [];
  List<ProductInfo> get products => List.unmodifiable(_detectedProducts);
  int get count => _detectedProducts.length;

  /// Check if URL is a SHEIN product detail page
  bool isProductPage(String url) {
    final lower = url.toLowerCase();
    // SHEIN product URL patterns:
    // /xxxx-p-123456.html
    // /product/xxxx
    // m.shein.com/xxx-p-123456.html
    if (lower.contains('-p-') && lower.contains('.html')) return true;
    if (lower.contains('/product/')) return true;
    if (lower.contains('/goods?')) return true;
    // Mobile pattern: /p-123456.html
    final pPattern = RegExp(r'/p-\d+\.html', caseSensitive: false);
    if (pPattern.hasMatch(lower)) return true;
    return false;
  }

  /// Extract product details from current page (READ-ONLY, no modification)
  Future<ProductInfo?> extractFromPage(
    InAppWebViewController controller,
    String url,
  ) async {
    try {
      final result = await controller.evaluateJavascript(
        source: '''
(function() {
  // Read-only extraction - no modification to the page
  
  // Title
  var title = '';
  var titleEl = document.querySelector('h1[class*="product"], [class*="product-name"], [class*="goods-name"], [data-testid*="product-name"], .product-intro__name, h1');
  if (titleEl) title = titleEl.textContent.trim();
  if (!title) {
    title = document.title || '';
  }
  
  // Price
  var price = '';
  var priceEl = document.querySelector('[class*="product-price"], [class*="sale-price"], [class*="price-sale"], .price, [data-testid*="price"], [class*="goods-price"]');
  if (priceEl) price = priceEl.textContent.trim();
  
  // Original price
  var originalPrice = '';
  var origPriceEl = document.querySelector('[class*="original-price"], [class*="retail-price"], [class*="price-original"], s[class*="price"], del[class*="price"]');
  if (origPriceEl) originalPrice = origPriceEl.textContent.trim();
  
  // Currency
  var currency = '';
  var currencyEl = document.querySelector('[class*="currency"], [data-currency]');
  if (currencyEl) {
    currency = currencyEl.getAttribute('data-currency') || currencyEl.textContent.trim();
  }
  // Try to detect from price text
  if (!currency && price) {
    var match = price.match(/([A-Z]{3}|\$|€|£|ر.س|ج.م|د.إ)/);
    if (match) currency = match[1];
  }
  
  // SKU - try multiple methods
  var sku = '';
  var skuEl = document.querySelector('[class*="goods-sn"], [class*="product-sn"], [data-sku], [class*="sku"], [class*="item-id"]');
  if (skuEl) {
    sku = skuEl.getAttribute('data-sku') || skuEl.getAttribute('data-goods-sn') || skuEl.textContent.trim();
  }
  // Try from URL
  if (!sku) {
    var urlMatch = url.match(/-p-(d+).html/);
    if (urlMatch) sku = urlMatch[1];
  }
  // Try from meta or JSON-LD
  if (!sku) {
    var jsonLd = document.querySelector('script[type="application/ld+json"]');
    if (jsonLd) {
      try {
        var data = JSON.parse(jsonLd.textContent);
        if (Array.isArray(data)) data = data[0];
        if (data.sku) sku = data.sku;
        if (data.mpn) sku = data.mpn || sku;
      } catch(e) {}
    }
  }
  
  // Images
  var images = [];
  var imgEls = document.querySelectorAll('[class*="gallery"] img, [class*="product-img"] img, [class*="main-img"] img, .product-intro__img img, [class*="swiper"] img[class*="product"], img[class*="goods-img"]');
  imgEls.forEach(function(img) {
    var src = img.src || img.getAttribute('data-src') || img.getAttribute('data-original') || '';
    if (src && src.indexOf('http') === 0 && images.indexOf(src) === -1) {
      images.push(src);
    }
  });
  // Fallback: any large images on product page
  if (images.length === 0) {
    var allImgs = document.querySelectorAll('img[src*="shein"], img[data-src*="shein"]');
    allImgs.forEach(function(img) {
      var src = img.src || img.getAttribute('data-src') || '';
      if (src && src.indexOf('http') === 0 && src.indexOf('logo') === -1 && src.indexOf('icon') === -1 && images.indexOf(src) === -1) {
        images.push(src);
      }
    });
  }
  
  // Description
  var description = '';
  var descEl = document.querySelector('[class*="product-desc"], [class*="description"], [class*="goods-desc"], meta[name="description"]');
  if (descEl) {
    description = descEl.getAttribute('content') || descEl.textContent.trim();
  }
  if (!description) {
    var metaDesc = document.querySelector('meta[name="description"]');
    if (metaDesc) description = metaDesc.getAttribute('content') || '';
  }
  
  // Rating
  var rating = '';
  var ratingEl = document.querySelector('[class*="rating"], [class*="stars"], [data-rating]');
  if (ratingEl) {
    rating = ratingEl.getAttribute('data-rating') || ratingEl.textContent.trim();
  }
  
  // Review count
  var reviewCount = '';
  var reviewEl = document.querySelector('[class*="review-count"], [class*="comment-count"], [class*="reviews-num"]');
  if (reviewEl) reviewCount = reviewEl.textContent.trim();
  
  // JSON-LD structured data (richest source)
  var jsonLdData = null;
  var jsonLdScripts = document.querySelectorAll('script[type="application/ld+json"]');
  for (var i = 0; i < jsonLdScripts.length; i++) {
    try {
      var parsed = JSON.parse(jsonLdScripts[i].textContent);
      if (Array.isArray(parsed)) parsed = parsed.find(function(x) { return x['@type'] === 'Product'; }) || parsed[0];
      if (parsed && (parsed['@type'] === 'Product' || parsed.name)) {
        jsonLdData = parsed;
        break;
      }
    } catch(e) {}
  }
  
  // Merge JSON-LD data if available
  if (jsonLdData) {
    if (!title && jsonLdData.name) title = jsonLdData.name;
    if (!sku && jsonLdData.sku) sku = jsonLdData.sku;
    if (!description && jsonLdData.description) description = jsonLdData.description;
    if (jsonLdData.offers) {
      var offers = Array.isArray(jsonLdData.offers) ? jsonLdData.offers[0] : jsonLdData.offers;
      if (!price && offers.price) price = String(offers.price);
      if (!currency && offers.priceCurrency) currency = offers.priceCurrency;
    }
    if (jsonLdData.aggregateRating) {
      if (!rating && jsonLdData.aggregateRating.ratingValue) rating = String(jsonLdData.aggregateRating.ratingValue);
      if (!reviewCount && jsonLdData.aggregateRating.reviewCount) reviewCount = String(jsonLdData.aggregateRating.reviewCount);
    }
    if (jsonLdData.image) {
      var jsonImgs = Array.isArray(jsonLdData.image) ? jsonLdData.image : [jsonLdData.image];
      jsonImgs.forEach(function(src) {
        if (src && images.indexOf(src) === -1) images.push(src);
      });
    }
  }
  
  return JSON.stringify({
    title: title,
    price: price,
    originalPrice: originalPrice,
    currency: currency,
    sku: sku,
    images: images.slice(0, 10),
    description: description.substring(0, 500),
    rating: rating,
    reviewCount: reviewCount
  });
})();
''',
      );

      if (result == null) return null;

      final data = jsonDecode(result) as Map<String, dynamic>;
      final info = ProductInfo(
        url: url,
        title: data['title'] ?? '',
        price: data['price'],
        originalPrice: data['originalPrice'],
        currency: data['currency'],
        sku: data['sku'],
        images:
            (data['images'] as List?)?.map((e) => e.toString()).toList() ?? [],
        description: data['description'],
        rating: data['rating'],
        reviewCount: data['reviewCount'],
        detectedAt: DateTime.now(),
      );

      // Avoid duplicates
      final existingIdx = _detectedProducts.indexWhere((p) => p.url == url);
      if (existingIdx >= 0) {
        _detectedProducts[existingIdx] = info;
      } else {
        _detectedProducts.insert(0, info);
      }

      notifyListeners();
      return info;
    } catch (e) {
      debugPrint('[ProductDetector] Extract error: $e');
      return null;
    }
  }

  void clear() {
    _detectedProducts.clear();
    notifyListeners();
  }
}

/// Side panel widget showing detected products (read-only extraction)
class ProductSidebar extends StatefulWidget {
  final VoidCallback? onClose;

  /// مسح صفحة الفئة الحالية وتحميل المنتجات في الخلفية
  final VoidCallback? onScan;

  const ProductSidebar({super.key, this.onClose, this.onScan});

  @override
  State<ProductSidebar> createState() => _ProductSidebarState();
}

class _ProductSidebarState extends State<ProductSidebar> {
  final ProductDetector _detector = ProductDetector();
  final BackgroundProductLoader _loader = BackgroundProductLoader();
  final ProductPreviewManager _previewManager = ProductPreviewManager();

  @override
  void initState() {
    super.initState();
    _detector.addListener(_onDetectorUpdate);
    _loader.addListener(_onDetectorUpdate);
    _previewManager.addListener(_onDetectorUpdate);
  }

  void _onDetectorUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _detector.removeListener(_onDetectorUpdate);
    _loader.removeListener(_onDetectorUpdate);
    _previewManager.removeListener(_onDetectorUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final products = _detector.products;
    final previews = _previewManager.previews;

    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        border: Border(
          left: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(isDark, products.length),
          if (widget.onScan != null) _buildScanBar(isDark),
          if (_loader.isBusy) _buildProgressBanner(isDark),
          // ─── قسم المعاينات المصغرة ───
          if (previews.isNotEmpty || _previewManager.autoDetectEnabled)
            _buildPreviewSection(isDark, previews),
          if (products.isNotEmpty)
            Expanded(child: _buildProductsList(isDark, products))
          else
            Expanded(child: _buildEmptyState(isDark)),
        ],
      ),
    );
  }

  // ─── شريط المسح الخلفي ───
  Widget _buildScanBar(bool isDark) {
    final busy = _loader.isBusy;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: isDark ? const Color(0xFF161625) : Colors.grey.shade100,
      child: SizedBox(
        width: double.infinity,
        child: busy
            ? OutlinedButton.icon(
                icon: const Icon(Icons.stop_circle_outlined, size: 18),
                label: const Text('إيقاف المسح'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade400,
                  side: BorderSide(color: Colors.red.shade300),
                ),
                onPressed: () => _loader.cancel(),
              )
            : ElevatedButton.icon(
                icon: const Icon(Icons.radar_rounded, size: 18),
                label: const Text('مسح منتجات هذه الصفحة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF69B4),
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                onPressed: widget.onScan,
              ),
      ),
    );
  }

  // ─── شريط التقدم أثناء التحميل الخلفي ───
  Widget _buildProgressBanner(bool isDark) {
    final scanning = _loader.status == LoaderStatus.scanning;
    final total = _loader.total;
    final done = _loader.processed;
    final pct = total > 0 ? done / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFFFF69B4).withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFFF69B4)),
                  value: scanning ? null : (pct == 0 ? null : pct),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  scanning
                      ? 'جارٍ قراءة روابط المنتجات...'
                      : 'تحميل في الخلفية ($done / $total)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF69B4),
                  ),
                ),
              ),
              if (_loader.secondsLeft > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF69B4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_loader.secondsLeft}ث',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          if (!scanning && _loader.currentTitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _loader.currentTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }

  // ─── قسم المعاينات المصغرة ───
  Widget _buildPreviewSection(bool isDark, List<ProductPreview> previews) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161625) : Colors.grey.shade100,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.preview_rounded,
                size: 16,
                color: const Color(0xFFFF69B4),
              ),
              const SizedBox(width: 6),
              Text(
                'معاينات حية',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              if (_previewManager.autoDetectEnabled)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF69B4).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'تلقائي',
                    style: TextStyle(fontSize: 10, color: Color(0xFFFF69B4)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (previews.isEmpty)
            Text(
              'مرر صفحة المنتجات لاكتشاف ومعاينة المنتجات تلقائياً',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            )
          else
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: previews.length,
                itemBuilder: (ctx, i) =>
                    _buildPreviewCard(isDark, previews[i], i),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(bool isDark, ProductPreview preview, int index) {
    return GestureDetector(
      onTap: () {
        // افتح في تبويب جديد
        final tabManager = context.read<TabManager>();
        tabManager.createTab(url: preview.url);
        widget.onClose?.call();
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFFFF69B4).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // المعاينة المصغرة
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(10),
                    ),
                    child: preview.screenshot != null
                        ? Image.memory(
                            preview.screenshot!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          )
                        : Container(
                            color: isDark
                                ? const Color(0xFF1A1A2E)
                                : Colors.grey.shade100,
                            child: Center(
                              child: preview.isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFFFF69B4),
                                      ),
                                    )
                                  : Icon(
                                      Icons.image_not_supported,
                                      color: Colors.grey.shade500,
                                      size: 28,
                                    ),
                            ),
                          ),
                  ),
                  // عداد تنازلي
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 10,
                            color: preview.secondsLeft <= 3
                                ? Colors.red.shade300
                                : Colors.white,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${preview.secondsLeft}ث',
                            style: TextStyle(
                              fontSize: 10,
                              color: preview.secondsLeft <= 3
                                  ? Colors.red.shade300
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // زر إغلاق
                  Positioned(
                    top: 4,
                    left: 4,
                    child: GestureDetector(
                      onTap: () => _previewManager.removePreview(index),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // العنوان
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preview.title.isNotEmpty ? preview.title : 'تحميل...',
                    style: const TextStyle(fontSize: 10),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.touch_app,
                        size: 10,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'اضغط للفتح',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, int count) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F1A) : Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.visibility_outlined,
            color: const Color(0xFFFF69B4),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'المنتجات المكتشفة',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  count > 0
                      ? '$count منتج مكتشف'
                      : 'تصفح منتجات SHEIN لاكتشافها',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          // زر تفعيل/تعطيل المعاينة التلقائية
          IconButton(
            icon: Icon(
              _previewManager.autoDetectEnabled
                  ? Icons.preview_rounded
                  : Icons.preview_outlined,
              size: 20,
              color: _previewManager.autoDetectEnabled
                  ? const Color(0xFFFF69B4)
                  : Colors.grey,
            ),
            tooltip: _previewManager.autoDetectEnabled
                ? 'إيقاف المعاينة التلقائية'
                : 'تفعيل المعاينة التلقائية',
            onPressed: () {
              _previewManager.setAutoDetect(!_previewManager.autoDetectEnabled);
            },
          ),
          if (count > 0)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'مسح',
              onPressed: () {
                _detector.clear();
                setState(() {});
              },
            ),
          IconButton(icon: const Icon(Icons.close), onPressed: widget.onClose),
        ],
      ),
    );
  }

  Widget _buildProductsList(bool isDark, List<ProductInfo> products) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _buildProductCard(isDark, product);
      },
    );
  }

  Widget _buildProductCard(bool isDark, ProductInfo product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            if (product.images.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  product.images.first,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 140,
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    child: Icon(
                      Icons.image_not_supported,
                      color: Colors.grey.shade500,
                      size: 32,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 10),

            // Title
            Text(
              product.title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),

            // Price row
            Row(
              children: [
                if (product.price != null && product.price!.isNotEmpty)
                  Text(
                    product.price!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF69B4),
                    ),
                  ),
                if (product.originalPrice != null &&
                    product.originalPrice!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    product.originalPrice!,
                    style: TextStyle(
                      fontSize: 12,
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
                if (product.currency != null &&
                    product.currency!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF69B4).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      product.currency!,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFFFF69B4),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // SKU + Rating row
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (product.sku != null && product.sku!.isNotEmpty)
                  _buildInfoChip(isDark, Icons.tag, 'SKU: ${product.sku}'),
                if (product.rating != null && product.rating!.isNotEmpty)
                  _buildInfoChip(
                    isDark,
                    Icons.star,
                    'تقييم: ${product.rating}',
                  ),
                if (product.reviewCount != null &&
                    product.reviewCount!.isNotEmpty)
                  _buildInfoChip(
                    isDark,
                    Icons.comment,
                    '${product.reviewCount} مراجعة',
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Images count
            if (product.images.length > 1)
              Row(
                children: [
                  Icon(
                    Icons.photo_library,
                    size: 14,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${product.images.length} صور',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),

            const SizedBox(height: 8),
            // URL
            Text(
              product.url,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            // Time
            Text(
              '${product.detectedAt.hour}:${product.detectedAt.minute.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(bool isDark, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_rounded, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'تصفح منتجات SHEIN\nسيتم اكتشاف التفاصيل تلقائياً',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFF69B4).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'قراءة فقط - بدون تدخل',
              style: TextStyle(fontSize: 11, color: Color(0xFFFF69B4)),
            ),
          ),
        ],
      ),
    );
  }
}
