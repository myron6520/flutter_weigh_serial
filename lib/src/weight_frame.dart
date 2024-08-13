import 'dart:typed_data';

import 'package:flutter/cupertino.dart';

enum ProtocolType {
  DA_HUA,
  DING_JIAN,
}

class WeightFrame {
  final List<int> data = [];
  final ProtocolType type;

  WeightFrame({required this.type});
  void addData(int data) {
    this.data.add(data);
  }

  void addAllData(List<int> data) {
    this.data.addAll(data);
  }
}

class WeightParser {
  WeightParser._();
  static WeightParser? _instance;

  static WeightParser get instance {
    _instance ??= WeightParser._();
    return _instance!;
  }

  factory WeightParser() => instance;

  void Function(WeightFrame)? onGetWeightFrame;

  List<int> _data = [];

  void addData(Uint8List data) {
    _data.addAll(data);

    WeightFrame? frame;
    int sIndex = -1;
    for (int i = 0; i < _data.length; i++) {
      int f = _data[i];
      if (f == 0x0A) {
        if (i + 1 < _data.length) {
          int s = _data[i + 1];
          if (s == 0x0D) {
            if (frame != null) {
              debugPrint("frame:${frame.data}");
              onGetWeightFrame?.call(frame);
              _data = _data.sublist(i);
              break;
            }
            frame = WeightFrame(type: ProtocolType.DA_HUA);
            frame.addData(0x0A);
            frame.addData(0x0D);
          }
        }
      }
      //"S"
      if (f == 0x53) {
        sIndex = i;
      }
      //"g"
      if (f == 0x67) {
        if (sIndex >= 0) {
          frame = WeightFrame(type: ProtocolType.DING_JIAN);
          frame.addAllData(data.sublist(sIndex, i + 1));
          _data = _data.sublist(i);
          onGetWeightFrame?.call(frame);
          break;
        }
      }
      frame?.addData(f);
    }
  }
}
