import 'package:flutter/foundation.dart';
import 'package:flutter_weigh_serial/src/usb_serial/usb_serial.dart';
import '../weigh_transform/weigh_transformer.dart';
import '../weigh_result.dart';
import 'dart:convert';

extension UsbSerialWeighExtension on UsbSerial {
  Stream<List<int>> get validDataStream {
    return WeighStreamTransformer().bind(
      readStream.expand((element) => element),
    );
  }

  Stream<WeighResult> get weighResultStream {
    return validDataStream.map(
      (event) {
        debugPrint("originalStr event:$event");
        final originalStr = ascii.decode(event);
        debugPrint("originalStr:$originalStr");
        //标记数据是否稳定
        final stable = originalStr.contains('S');
        int unit = 1000;
        int lastIndex = originalStr.indexOf('kg');
        if (lastIndex < 0) {
          lastIndex = originalStr.indexOf('g');
          unit = 1;
        }

        var resultStr = originalStr.substring(0, lastIndex).replaceAll(' ', '').replaceAll(RegExp(r'[A-Za-z]'), '').replaceAll(RegExp(r'[^0-9.-]'), '');
        final weight = double.tryParse(resultStr.trim()) ?? 0;
        return WeighResult(
          isStable: stable,
          weight: weight * unit,
        );
      },
    );
  }
}
