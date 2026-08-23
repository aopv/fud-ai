import 'dart:async';

import 'package:flutter/services.dart';

import '../progress/progress_models.dart';

abstract interface class ProgressRepository {
  Future<ProgressSnapshot> load(ProgressRange range);
  Future<void> perform(String action);
  Stream<void> get changes;
}

class NativeProgressRepository implements ProgressRepository {
  const NativeProgressRepository();

  static const _channel = MethodChannel('com.apoorvdarshan.fudai/progress');
  static final _changes = StreamController<void>.broadcast();
  static bool _nativeHandlerInstalled = false;

  @override
  Stream<void> get changes {
    if (!_nativeHandlerInstalled) {
      _nativeHandlerInstalled = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'snapshotChanged') {
          _changes.add(null);
          return;
        }
        throw MissingPluginException(
          'Unknown native Progress callback: ${call.method}',
        );
      });
    }
    return _changes.stream;
  }

  @override
  Future<ProgressSnapshot> load(ProgressRange range) async {
    final response = await _channel.invokeMapMethod<Object?, Object?>(
      'getSnapshot',
      <String, Object?>{'range': range.channelValue},
    );
    if (response == null) {
      throw StateError('Native Progress snapshot was unavailable.');
    }
    return ProgressSnapshot.fromJson(response);
  }

  @override
  Future<void> perform(String action) {
    return _channel.invokeMethod<void>('performAction', <String, Object?>{
      'action': action,
    });
  }
}
