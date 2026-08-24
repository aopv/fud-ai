import 'dart:async';

import 'package:flutter/services.dart';

enum FudAppTab { home, progress, coach, settings, workouts }

extension FudAppTabChannelValue on FudAppTab {
  String get channelValue => name;

  static FudAppTab parse(Object? value) => FudAppTab.values.firstWhere(
    (tab) => tab.name == value,
    orElse: () => FudAppTab.home,
  );
}

class AppShellSnapshot {
  const AppShellSnapshot({
    required this.platform,
    required this.isDark,
    required this.usesNativeNavigation,
    required this.selectedTab,
    required this.bottomContentInset,
    required this.workoutsLabel,
    required this.updateAvailable,
  });

  final String platform;
  final bool isDark;
  final bool usesNativeNavigation;
  final FudAppTab selectedTab;
  final double bottomContentInset;
  final String workoutsLabel;
  final bool updateAvailable;

  factory AppShellSnapshot.fromJson(Map<Object?, Object?> json) {
    return AppShellSnapshot(
      platform: json['platform'] as String? ?? 'unknown',
      isDark: json['isDark'] as bool? ?? false,
      usesNativeNavigation: json['usesNativeNavigation'] as bool? ?? false,
      selectedTab: FudAppTabChannelValue.parse(json['selectedTab']),
      bottomContentInset: (json['bottomContentInset'] as num?)?.toDouble() ?? 0,
      workoutsLabel: json['workoutsLabel'] as String? ?? 'WORKOUTS',
      updateAvailable: json['updateAvailable'] as bool? ?? false,
    );
  }
}

abstract interface class AppRepository {
  Stream<String?> get changes;

  Future<AppShellSnapshot> loadShell();

  Future<Map<Object?, Object?>> loadPage(FudAppTab tab);

  Future<Object?> perform(
    String action, {
    Map<String, Object?> arguments = const {},
  });

  Future<void> selectTab(FudAppTab tab);
}

class NativeAppRepository implements AppRepository {
  NativeAppRepository({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName) {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static const _channelName = 'com.apoorvdarshan.fudai/app';
  final MethodChannel _channel;
  final StreamController<String?> _changes = StreamController.broadcast();

  @override
  Stream<String?> get changes => _changes.stream;

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method == 'snapshotChanged') {
      final arguments = call.arguments as Map<Object?, Object?>?;
      _changes.add(arguments?['tab'] as String?);
    }
  }

  @override
  Future<AppShellSnapshot> loadShell() async {
    final raw = await _channel.invokeMethod<Object?>('getShellSnapshot');
    return AppShellSnapshot.fromJson(Map<Object?, Object?>.from(raw! as Map));
  }

  @override
  Future<Map<Object?, Object?>> loadPage(FudAppTab tab) async {
    final raw = await _channel.invokeMethod<Object?>('getPageSnapshot', {
      'tab': tab.channelValue,
    });
    return Map<Object?, Object?>.from(raw! as Map);
  }

  @override
  Future<Object?> perform(
    String action, {
    Map<String, Object?> arguments = const {},
  }) {
    return _channel.invokeMethod<Object?>('performAction', {
      'action': action,
      ...arguments,
    });
  }

  @override
  Future<void> selectTab(FudAppTab tab) {
    return _channel.invokeMethod<void>('selectTab', {'tab': tab.channelValue});
  }
}
