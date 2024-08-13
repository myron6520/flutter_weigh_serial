import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_weigh_serial/src/device_model/usb_serial_device_ex.dart';
import 'package:flutter_weigh_serial/src/extension/usb_serial_ex.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter_weigh_serial/src/usb_serial/platform/usb_serial_android.dart';
import 'package:flutter_weigh_serial/src/usb_serial/platform/usb_serial_windows.dart';
import 'package:flutter_weigh_serial/src/weight_frame.dart';
import '../flutter_weigh_serial.dart';
import 'package:usb_serial/usb_serial.dart' as usb_serial_lib;

/// 称重功能提供者
class WeighSerialProvider {
  late final UsbSerialFactory serialFactory;

  WeighSerialProvider() {
    serialFactory = UsbSerialFactory();
    usb_serial_lib.UsbSerial.usbEventStream?.listen((event) {
      if (event.event == usb_serial_lib.UsbEvent.ACTION_USB_ATTACHED) {
        findAndConnect();
      }
    });
  }
  final List<UsbSerial> _ports = [];
  final controller = StreamController<WeighResult>.broadcast();

  /// 用于监听输出流
  Stream<WeighResult> get readStream => controller.stream;
  // 第一步，初始化, 并连接称重设备
  Future<bool> findAndConnect() async {
    await close();
    final devices = await serialFactory.usbSerial.getAvailablePorts();
    for (var weighDevice in devices) {
      if (!weighDevice.isWeighDevice) {
        continue;
      }
      UsbSerial? serial;
      if (Platform.isAndroid) {
        serial = UsbSerialAndroid();
      }
      if (Platform.isWindows) {
        serial = UsbSerialWindows();
      }

      if (serial != null) {
        try {
          WeightParser.instance.onGetWeightFrame = (frame) {
            WeighResult? res =
                parseDHData(frame.data) ?? parseDJData(frame.data);
            if (res != null) {
              controller.sink.add(res);
            }
          };
          serial.readStream.listen((event) {
            WeightParser.instance.addData(event);
            // WeighResult? res = parseDHData(event) ?? parseDJData(event);
            // if (res != null) {
            //   controller.sink.add(res);
            // }
          });
          await serial.create(weighDevice);
          await serial.open();

          _ports.add(serial);
        } catch (e) {}
      }
    }
    return _ports.isNotEmpty;
  }

  WeighResult? parseDHData(List<int> event) {
    try {
      if (event.length > 2 && event[0] == 0x0A && event[1] == 0x0D) {
        debugPrint("event: ${event.toString()}");
        final originalStr = ascii
            .decode(event
                .where((element) =>
                    element != 0x0 && element != 0x0A && element != 0x0D)
                .toList())
            .trim();
        List<String> arr = originalStr.split(" ");
        double weight = double.tryParse(arr.first) ?? 0;
        if (arr.length > 1) {
          double price = double.tryParse(arr[1]) ?? 0;
        }
        if (arr.length > 2) {
          double cost = double.tryParse(arr[2]) ?? 0;
        }

        return WeighResult(
          isStable: true,
          weight: weight,
        );
      }
      return null;
    } catch (e) {}
    return null;
  }

  WeighResult? parseDJData(List<int> event) {
    try {
      final originalStr = utf8.decode(event);
      debugPrint("originalStr:$originalStr");
      //标记数据是否稳定
      final stable = originalStr.contains('S');
      int unit = 1000;
      int lastIndex = originalStr.indexOf('kg');
      if (lastIndex < 0) {
        lastIndex = originalStr.indexOf('g');
        unit = 1;
      }

      var resultStr = originalStr
          .substring(0, lastIndex)
          .replaceAll(' ', '')
          .replaceAll(RegExp(r'[A-Za-z]'), '')
          .replaceAll(RegExp(r'[^0-9.-]'), '');
      final weight = double.tryParse(resultStr.trim()) ?? 0;
      return WeighResult(
        isStable: stable,
        weight: weight * unit,
      );
    } catch (e) {}
    return null;
  }

  // 最后一步， 关闭
  Future<bool> close() async {
    for (var port in _ports) {
      await port.close();
    }
    _ports.clear();
    return true;
  }
}
