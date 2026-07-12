import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/tab_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _uaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final sp = context.read<SettingsProvider>();
    _uaCtrl.text = sp.customUa ?? '';
  }

  @override
  void dispose() {
    _uaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'الإعدادات',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // ─── الموقع ───
          _sectionTitle('🌐 موقع SHEIN'),
          Card(
            elevation: 0,
            color: isDark ? const Color(0xFF1E1E2E) : Colors.grey.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: sp.region,
                  icon: const Icon(Icons.arrow_drop_down),
                  borderRadius: BorderRadius.circular(10),
                  items: SettingsProvider.regions.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.value,
                          child: Text(
                            e.key,
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) sp.setRegion(v);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── لغة الموقع ───
          _sectionTitle('🔤 لغة الموقع'),
          Card(
            elevation: 0,
            color: isDark ? const Color(0xFF1E1E2E) : Colors.grey.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.language, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<SiteLanguage>(
                        isExpanded: true,
                        value: sp.siteLanguage,
                        icon: const Icon(Icons.arrow_drop_down),
                        borderRadius: BorderRadius.circular(10),
                        items: const [
                          DropdownMenuItem(
                            value: SiteLanguage.arabic,
                            child: Text(
                              'العربية',
                              style: TextStyle(fontSize: 15),
                            ),
                          ),
                          DropdownMenuItem(
                            value: SiteLanguage.english,
                            child: Text(
                              'English',
                              style: TextStyle(fontSize: 15),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) sp.setSiteLanguage(v);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── المظهر ───
          _sectionTitle('🎨 المظهر'),
          _themeCard('فاتح', AppTheme.light, sp),
          _themeCard('داكن', AppTheme.dark, sp),
          _themeCard('حسب النظام', AppTheme.system, sp),
          const SizedBox(height: 16),

          // ─── التصفح ───
          _sectionTitle('🛡️ التصفح'),
          Card(
            elevation: 0,
            color: isDark ? const Color(0xFF1E1E2E) : Colors.grey.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('تفعيل JavaScript'),
                  subtitle: const Text('مطلوب لعمل SHEIN'),
                  value: sp.jsEnabled,
                  onChanged: (v) => sp.setJsEnabled(v),
                  activeColor: const Color(0xFFFF69B4),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  title: const Text('وضع سطح المكتب'),
                  subtitle: Text(
                    sp.desktopMode
                        ? 'يتم عرض نسخة الكمبيوتر'
                        : 'يتم عرض نسخة الهاتف',
                  ),
                  value: sp.desktopMode,
                  onChanged: (v) async {
                    await sp.setDesktopMode(v);
                    // تطبيق التغيير على التبويب النشط فوراً
                    final tabManager = context.read<TabManager>();
                    final activeTab = tabManager.activeTab;
                    final controller = activeTab?.controller;
                    if (controller != null && activeTab != null) {
                      await controller.setSettings(
                        settings: InAppWebViewSettings(
                          userAgent: sp.userAgentFor(v),
                          useWideViewPort: v,
                        ),
                      );
                      final newUrl = sp.adaptUrlForMode(activeTab.url, v);
                      if (newUrl != activeTab.url) {
                        activeTab.url = newUrl;
                        await controller.loadUrl(
                          urlRequest: URLRequest(url: WebUri(newUrl)),
                        );
                      } else {
                        await controller.reload();
                      }
                    }
                  },
                  activeColor: const Color(0xFFFF69B4),
                  secondary: Icon(
                    sp.desktopMode
                        ? Icons.desktop_windows_rounded
                        : Icons.phone_android_rounded,
                    color: sp.desktopMode ? const Color(0xFFFF69B4) : null,
                    size: 22,
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  title: const Text('مانع الإعلانات'),
                  subtitle: const Text(
                    'حظر إعلانات Google و DoubleClick والبنرات الإعلانية',
                  ),
                  value: sp.adBlocking,
                  onChanged: (v) => sp.setAdBlocking(v),
                  activeColor: const Color(0xFFFF69B4),
                  secondary: Icon(
                    Icons.block_rounded,
                    color: sp.adBlocking ? const Color(0xFFFF69B4) : null,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ─── User-Agent ───
          Card(
            elevation: 0,
            color: isDark ? const Color(0xFF1E1E2E) : Colors.grey.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'User-Agent مخصص (اختياري)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _uaCtrl,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: sp.defaultUserAgent,
                      hintStyle: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF2A2A3E)
                          : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.save, size: 20),
                        onPressed: () => sp.setCustomUa(_uaCtrl.text.trim()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'الحالي: ${sp.effectiveUserAgent.substring(0, 60)}...',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── المفضلة والسجل ───
          _sectionTitle('📑 المفضلة والسجل'),
          Card(
            elevation: 0,
            color: isDark ? const Color(0xFF1E1E2E) : Colors.grey.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFFFB800),
                    size: 22,
                  ),
                  title: const Text('المفضلة'),
                  subtitle: Text(
                    '${sp.bookmarks.length} صفحة محفوظة',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: sp.bookmarks.isNotEmpty
                      ? TextButton(
                          onPressed: () async {
                            final ok = await _confirmDialog(
                              'مسح المفضلة',
                              'سيتم حذف جميع الصفحات المفضلة. متأكد؟',
                            );
                            if (ok) await sp.clearBookmarks();
                          },
                          child: const Text(
                            'مسح',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.redAccent,
                            ),
                          ),
                        )
                      : null,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(
                    Icons.history_rounded,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    size: 22,
                  ),
                  title: const Text('سجل التصفح'),
                  subtitle: Text(
                    '${sp.history.length} صفحة في السجل',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: sp.history.isNotEmpty
                      ? TextButton(
                          onPressed: () async {
                            final ok = await _confirmDialog(
                              'مسح السجل',
                              'سيتم حذف سجل التصفح بالكامل. متأكد؟',
                            );
                            if (ok) await sp.clearHistory();
                          },
                          child: const Text(
                            'مسح',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.redAccent,
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── البيانات ───
          _sectionTitle('🗂️ البيانات'),
          Card(
            elevation: 0,
            color: isDark ? const Color(0xFF1E1E2E) : Colors.grey.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'مسح الكاش والكوكيز',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  subtitle: const Text('سيتم تسجيل الخروج من SHEIN'),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final ok = await _confirmDialog(
                      'تأكيد',
                      'سيتم مسح الكاش والكوكيز وجميع البيانات المحفوظة بما فيها المفضلة والسجل. متأكد؟',
                    );
                    if (ok) {
                      await sp.clearAllData();
                      messenger.showSnackBar(
                        const SnackBar(content: Text('تم مسح البيانات')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Center(
            child: Text(
              'SHEIN Browser v2.0.0',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade600 : Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'متصفح تسوق ذكي 🛍️',
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ─── Helpers ───

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Color(0xFFFF69B4),
        ),
      ),
    );
  }

  Widget _themeCard(String label, AppTheme value, SettingsProvider sp) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = sp.theme == value;
    return Card(
      elevation: 0,
      color: selected
          ? (isDark ? const Color(0xFF2A1A2E) : const Color(0xFFFFF0F5))
          : (isDark ? const Color(0xFF1E1E2E) : Colors.grey.shade50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: selected
            ? const BorderSide(color: Color(0xFFFF69B4), width: 1.5)
            : BorderSide.none,
      ),
      child: ListTile(
        title: Text(label),
        trailing: selected
            ? const Icon(Icons.check_circle, color: Color(0xFFFF69B4))
            : null,
        onTap: () => sp.setTheme(value),
      ),
    );
  }

  Future<bool> _confirmDialog(String title, String content) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return ok == true;
  }
}
