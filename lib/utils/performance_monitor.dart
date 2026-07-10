import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Performance monitoring utility
/// 
/// Tracks app performance metrics like:
/// - Memory usage
/// - Frame rendering time
/// - WebView load times
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  final Map<String, DateTime> _timers = {};
  final List<PerformanceMetric> _metrics = [];

  /// Start a performance timer
  void startTimer(String name) {
    _timers[name] = DateTime.now();
    developer.log('Performance timer started: $name');
  }

  /// End a performance timer and record the metric
  void endTimer(String name) {
    final start = _timers[name];
    if (start == null) {
      debugPrint('Warning: Timer $name was not started');
      return;
    }

    final duration = DateTime.now().difference(start);
    _metrics.add(PerformanceMetric(
      name: name,
      duration: duration,
      timestamp: DateTime.now(),
    ));

    _timers.remove(name);
    
    developer.log(
      'Performance: $name took ${duration.inMilliseconds}ms',
      name: 'Performance',
    );

    // Warn if operation is slow
    if (duration.inMilliseconds > 1000) {
      debugPrint('⚠️ SLOW OPERATION: $name took ${duration.inMilliseconds}ms');
    }
  }

  /// Get all recorded metrics
  List<PerformanceMetric> get metrics => List.unmodifiable(_metrics);

  /// Get average duration for a specific operation
  Duration? getAverageDuration(String name) {
    final filtered = _metrics.where((m) => m.name == name).toList();
    if (filtered.isEmpty) return null;

    final total = filtered.fold<int>(
      0,
      (sum, m) => sum + m.duration.inMilliseconds,
    );

    return Duration(milliseconds: total ~/ filtered.length);
  }

  /// Clear all metrics
  void clear() {
    _metrics.clear();
    _timers.clear();
  }

  /// Print summary
  void printSummary() {
    if (_metrics.isEmpty) {
      debugPrint('No performance metrics recorded');
      return;
    }

    debugPrint('\n=== Performance Summary ===');
    final grouped = <String, List<PerformanceMetric>>{};
    
    for (final metric in _metrics) {
      grouped.putIfAbsent(metric.name, () => []).add(metric);
    }

    for (final entry in grouped.entries) {
      final avg = getAverageDuration(entry.key);
      final count = entry.value.length;
      debugPrint('${entry.key}: ${avg?.inMilliseconds}ms (${count}x)');
    }
    debugPrint('===========================\n');
  }
}

class PerformanceMetric {
  final String name;
  final Duration duration;
  final DateTime timestamp;

  PerformanceMetric({
    required this.name,
    required this.duration,
    required this.timestamp,
  });
}

/// Extension to easily measure async operations
extension PerformanceTimer<T> on Future<T> {
  Future<T> measure(String name) async {
    PerformanceMonitor().startTimer(name);
    try {
      return await this;
    } finally {
      PerformanceMonitor().endTimer(name);
    }
  }
}
