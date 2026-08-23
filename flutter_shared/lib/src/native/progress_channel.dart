import 'package:flutter/services.dart';

import '../progress/progress_models.dart';

abstract interface class ProgressRepository {
  Future<ProgressSnapshot> load(ProgressRange range);
  Future<void> perform(String action);
}

class NativeProgressRepository implements ProgressRepository {
  const NativeProgressRepository();

  static const _channel = MethodChannel('com.apoorvdarshan.fudai/progress');

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
