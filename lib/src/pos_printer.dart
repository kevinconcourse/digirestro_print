import 'dart:developer';
import 'dart:io';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:digirestro_print/src/enums.dart';
import 'package:digirestro_print/src/models/device.dart';
import 'package:flutter/services.dart';

class PosPrinter {
  /// This field is library to handle in Android Platform
  BlueThermalPrinter? bluetoothAndroid;

  final PrinterType printerType;

  PosPrinter({
    required this.printerType,
    this.paperSize = PaperSize.mm80,
  }) {
    if (printerType == PrinterType.bluetooth) {
      bluetoothAndroid = BlueThermalPrinter.instance;
    }
  }

  final PaperSize? paperSize;

  /// State to get printer is connected
  bool _isConnected = false;

  /// Getter value [_isConnected]
  bool get isConnected => _isConnected;

  /// Selected device after connecting
  late BlueDevice? selectedBluetoothDevice;

  Socket? _socket;
  late Generator _generator;

  // ************************ Scan Bluetooth Device ************************

  /// THIS WILL WORK ONLY FOR BLUETOOTH
  Future<List<BlueDevice>> scanForDevices() async {
    /// We dont need to scan for lan printers because we have pre configuration of Lan.
    try {
      List<BlueDevice> pairedDeviceList = [];

      if (!(await bluetoothAndroid!.isOn)!) {
        throw Exception('Please turn on Bluetooth');
      }
      bluetoothAndroid!.isOn;
      final List<BluetoothDevice> resultDevices =
          await bluetoothAndroid!.getBondedDevices();
      pairedDeviceList = resultDevices
          .map(
            (BluetoothDevice bluetoothDevice) => BlueDevice(
              name: bluetoothDevice.name ?? '',
              address: bluetoothDevice.address ?? '',
              type: bluetoothDevice.type,
            ),
          )
          .toList();
      return pairedDeviceList;
    } catch (e) {
      rethrow;
    }
  }

  // ************************ CONNECT TO DEVICES ************************

  Future<ConnectionStatus> connectToDevice({
    int port = 9100,
    Duration timeout = const Duration(seconds: 5),
    BlueDevice? device,
    String? ipAddress,
  }) async {
    try {
      /// FOR LAN (WIFI)
      ///
      final profile = await CapabilityProfile.load();
      _generator = Generator(paperSize!, profile, spaceBetweenRows: 5);
      if (printerType == PrinterType.lan) {
        if (ipAddress == null || ipAddress.isEmpty) {
          return Future<ConnectionStatus>.value(ConnectionStatus.timeout);
        }
        _socket = await Socket.connect(ipAddress, port, timeout: timeout);
        _socket!.add(_generator.reset());
        _isConnected = true;
        return Future<ConnectionStatus>.value(ConnectionStatus.connected);
      } else

      /// FOR BLUETOOTH
      ///
      if (printerType == PrinterType.bluetooth) {
        /// RETURN IF DEVICE IS NULL
        if (device == null) {
          return Future<ConnectionStatus>.value(ConnectionStatus.timeout);
        }
        selectedBluetoothDevice = device;
        final BluetoothDevice bluetoothDeviceAndroid = BluetoothDevice(
            selectedBluetoothDevice!.name, selectedBluetoothDevice!.address);
        await bluetoothAndroid?.connect(bluetoothDeviceAndroid);
        _isConnected = true;
        selectedBluetoothDevice!.connected = true;
        return Future<ConnectionStatus>.value(ConnectionStatus.connected);
      }

      /// RETURN TIMEOUT EXCEPTION
      ///
      else {
        _isConnected = false;
        return Future<ConnectionStatus>.value(ConnectionStatus.timeout);
      }
    } catch (e) {
      _isConnected = false;
      log('$runtimeType - Error $e');
      rethrow;
    }
  }

  // ************************ Disconnect ************************

  /// [delayMs]: milliseconds to wait after destroying the socket
  Future<ConnectionStatus> disconnect({int? delayMs}) async {
    try {
      /// LAN
      ///
      if (printerType == PrinterType.lan) {
        _socket?.destroy();
        if (delayMs != null) {
          await Future.delayed(Duration(milliseconds: delayMs), () => null);
        }
        _isConnected = false;
        return Future<ConnectionStatus>.value(ConnectionStatus.disconnect);
      }

      /// BLUETOOTH
      ///
      if (printerType == PrinterType.bluetooth) {
        if (await bluetoothAndroid?.isConnected ?? false) {
          await bluetoothAndroid?.disconnect();
        }
        _isConnected = false;
        return Future<ConnectionStatus>.value(ConnectionStatus.disconnect);
      }
    } catch (e) {
      rethrow;
    }
    return Future<ConnectionStatus>.value(ConnectionStatus.timeout);
  }

  // ************************ Printer Commands ************************

  List<int> printerDataBytes = [];
  void hr({String ch = '-', int? len, int linesAfter = 0}) {
    final listData = _generator.hr(ch: ch, linesAfter: linesAfter);

    if (printerType == PrinterType.lan) {
      _socket!.add(listData);
    }
    if (printerType == PrinterType.bluetooth) {
      printerDataBytes += listData;
    }
  }

  void cut({PosCutMode mode = PosCutMode.full}) {
    final listData = _generator.cut(mode: mode);

    if (printerType == PrinterType.lan) {
      _socket!.add(listData);
    }
    if (printerType == PrinterType.bluetooth) {
      printerDataBytes += listData;
    }
  }

  void feed(int n) {
    final listData = _generator.feed(n);

    if (printerType == PrinterType.lan) {
      _socket!.add(listData);
    }
    if (printerType == PrinterType.bluetooth) {
      printerDataBytes += listData;
    }
  }

  void emptyLines(int n) {
    final listData = _generator.emptyLines(n);

    if (printerType == PrinterType.lan) {
      _socket!.add(listData);
    }
    if (printerType == PrinterType.bluetooth) {
      printerDataBytes += listData;
    }
  }

  void text(
    String text, {
    PosStyles styles = const PosStyles(),
    int linesAfter = 0,
    bool containsChinese = false,
    int? maxCharsPerLine,
  }) {
    final listData = _generator.text(text,
        styles: styles,
        linesAfter: linesAfter,
        containsChinese: containsChinese,
        maxCharsPerLine: maxCharsPerLine);

    if (printerType == PrinterType.lan) {
      _socket!.add(listData);
    }
    if (printerType == PrinterType.bluetooth) {
      printerDataBytes += listData;
    }
  }

  void row(List<PosColumn> cols) {
    final listData = _generator.row(cols);

    if (printerType == PrinterType.lan) {
      _socket!.add(listData);
    }
    if (printerType == PrinterType.bluetooth) {
      printerDataBytes += listData;
    }
  }

  Future<void> printReceipt({List<int>? printData}) async {
    try {
      if (printerType == PrinterType.bluetooth) {
        if (selectedBluetoothDevice == null) {
          throw Exception('Device Not Selected');
        }

        if (!_isConnected && selectedBluetoothDevice != null) {
          await connectToDevice(device: selectedBluetoothDevice);
        }
        bluetoothAndroid!.writeBytes(Uint8List.fromList(printerDataBytes));
      }
    } catch (e) {
      rethrow;
    }
  }
}
