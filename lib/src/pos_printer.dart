import 'dart:developer';
import 'dart:io';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart' as bt;
import 'package:digirestro_print/src/enums.dart';
import 'package:digirestro_print/src/models/device.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fb;
import 'package:flutter_blue_plus/gen/flutterblueplus.pb.dart' as proto;
import 'package:image/image.dart';

class PosPrinter {
  /// This field is library to handle in Android Platform
  bt.BlueThermalPrinter? bluetoothAndroid;
  fb.FlutterBluePlus? bluetoothIos;

  final PrinterType printerType;

  PosPrinter({
    required this.printerType,
    this.paperSize = PaperSize.mm80,
  }) {
    if (printerType == PrinterType.bluetooth) {
      if (Platform.isAndroid) {
        bluetoothAndroid = bt.BlueThermalPrinter.instance;
      }
      if (Platform.isIOS) {
        bluetoothIos = fb.FlutterBluePlus.instance;
      }
    }
  }

  final PaperSize? paperSize;
  CapabilityProfile? profile;

  /// State to get printer is connected
  bool _isConnected = false;

  /// Getter value [_isConnected]
  bool get isConnected => _isConnected;

  /// Selected device after connecting
  late BlueDevice? selectedBluetoothDevice;

  /// Bluetooth Device model for iOS
  fb.BluetoothDevice? _bluetoothDeviceIOS;

  Socket? _socket;
  late Generator _generator;

  // ************************ Scan Bluetooth Device ************************

  /// Use this function only for [bluetooth printers]
  Future<List<BlueDevice>> scanForDevices() async {
    /// We dont need to `scan` for `lan` printers
    /// because we have pre-configuration of `Lan Printers`.
    try {
      List<BlueDevice> pairedDeviceList = [];
      if (Platform.isAndroid) {
        if (!(await bluetoothAndroid!.isOn)!) {
          throw Exception('Please turn on Bluetooth');
        }
        bluetoothAndroid!.isOn;
        final List<bt.BluetoothDevice> resultDevices =
            await bluetoothAndroid!.getBondedDevices();
        pairedDeviceList = resultDevices
            .map(
              (bt.BluetoothDevice bluetoothDevice) => BlueDevice(
                name: bluetoothDevice.name ?? '',
                address: bluetoothDevice.address ?? '',
                type: bluetoothDevice.type,
              ),
            )
            .toList();
      } else if (Platform.isIOS) {
        bluetoothIos = fb.FlutterBluePlus.instance;
        final List<fb.BluetoothDevice> resultDevices = <fb.BluetoothDevice>[];
        if (!await fb.FlutterBluePlus.instance.isOn) {
          throw Exception('Please turn on Bluetooth');
        }
        // await bluetoothIos?.startScan(
        //   timeout: const Duration(seconds: 5),
        // );
        // bluetoothIos?.scanResults.listen((List<fb.ScanResult> scanResults) {
        //   for (final fb.ScanResult scanResult in scanResults) {
        //     resultDevices.add(scanResult.device);
        //   }
        // });
        final connectedDevices = await bluetoothIos?.connectedDevices;
        resultDevices.addAll(connectedDevices ?? []);
        await bluetoothIos?.stopScan();
        pairedDeviceList = resultDevices
            .toSet()
            .toList()
            .map(
              (fb.BluetoothDevice bluetoothDevice) => BlueDevice(
                address: bluetoothDevice.id.id,
                name: bluetoothDevice.name,
                type: bluetoothDevice.type.index,
              ),
            )
            .toList();
      }
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
      profile = await CapabilityProfile.load();
      _generator = Generator(paperSize!, profile!, spaceBetweenRows: 5);

      /// CONNECTION TO [LAN]
      if (printerType == PrinterType.lan) {
        if (ipAddress == null || ipAddress.isEmpty) {
          return Future<ConnectionStatus>.value(ConnectionStatus.timeout);
        }
        _socket = await Socket.connect(ipAddress, port, timeout: timeout);
        _socket!.add(_generator.reset());
        _isConnected = true;
        return Future<ConnectionStatus>.value(ConnectionStatus.connected);
      }

      /// CONNECTION TO [BLUETOOTH]
      else if (printerType == PrinterType.bluetooth) {
        /// RETURN IF DEVICE IS NULL
        if (device == null) {
          return Future<ConnectionStatus>.value(ConnectionStatus.timeout);
        }
        selectedBluetoothDevice = device;

        if (Platform.isAndroid) {
          final bt.BluetoothDevice bluetoothDeviceAndroid = bt.BluetoothDevice(
              selectedBluetoothDevice!.name, selectedBluetoothDevice!.address);
          if ((await bluetoothAndroid?.isDeviceConnected(bt.BluetoothDevice(
              selectedBluetoothDevice!.name,
              selectedBluetoothDevice!.address)))!) {
            _isConnected = true;
            selectedBluetoothDevice!.connected = true;
            printerDataBytes = [];
            return Future<ConnectionStatus>.value(ConnectionStatus.connected);
          }
          await bluetoothAndroid?.connect(bluetoothDeviceAndroid);
          _isConnected = true;
          selectedBluetoothDevice!.connected = true;
          printerDataBytes = [];
          return Future<ConnectionStatus>.value(ConnectionStatus.connected);
        } else {
          _bluetoothDeviceIOS = fb.BluetoothDevice.fromProto(
            proto.BluetoothDevice(
              name: selectedBluetoothDevice?.name ?? '',
              remoteId: selectedBluetoothDevice?.address ?? '',
              type: proto.BluetoothDevice_Type.valueOf(
                  selectedBluetoothDevice?.type ?? 0),
            ),
          );
          final List<fb.BluetoothDevice> connectedDevices =
              await bluetoothIos?.connectedDevices ?? <fb.BluetoothDevice>[];
          final int deviceConnectedIndex =
              connectedDevices.indexWhere((fb.BluetoothDevice bluetoothDevice) {
            return bluetoothDevice.id == _bluetoothDeviceIOS?.id;
          });
          if (deviceConnectedIndex < 0) {
            await _bluetoothDeviceIOS?.connect();
          }
          _isConnected = true;
          selectedBluetoothDevice?.connected = true;
          return Future<ConnectionStatus>.value(ConnectionStatus.connected);
        }
      } else if (printerType == PrinterType.imin) {
        /// CONNECTION TO [iMIN] Device
        return Future<ConnectionStatus>.value(ConnectionStatus.connected);
      } else {
        /// RETURN [TIMEOUT] [EXCEPTION]
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
        if (Platform.isAndroid) {
          if (await bluetoothAndroid?.isConnected ?? false) {
            await bluetoothAndroid?.disconnect();
          }
          _isConnected = false;
          return Future<ConnectionStatus>.value(ConnectionStatus.disconnect);
        } else {
          await _bluetoothDeviceIOS?.disconnect();
          _isConnected = false;
          return Future<ConnectionStatus>.value(ConnectionStatus.disconnect);
        }
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

  Future<void> image(
    Uint8List imageBytes, [
    PosAlign alignImage = PosAlign.center,
    String path = '',
  ]) async {
    if (printerType == PrinterType.bluetooth ||
        printerType == PrinterType.imin) {
      // bluetoothAndroid!.printImageBytes(imageBytes);
      bluetoothAndroid!.printImage(path);
      bluetoothAndroid!.printNewLine();
      // _generator = Generator(paperSize!, profile!, spaceBetweenRows: 5);
    }
    if (printerType == PrinterType.lan) {
      final Image? image = decodeImage(imageBytes);

      ///TEST
      if (image != null) {
        _socket!.add(_generator.image(
          image,
          align: alignImage,
        ));
      }
    }
  }

  Future<void> qrCode(
    String qrCodeText, {
    PosAlign align = PosAlign.center,
    QRSize size = QRSize.Size4,
    QRCorrection cor = QRCorrection.L,
    int width = 300,
    int height = 300,
  }) async {
    if (qrCodeText.isEmpty) {
      return;
    }
    if (printerType == PrinterType.bluetooth ||
        printerType == PrinterType.imin) {
      /// 1 Stands for Align Center
      bluetoothAndroid!.printQRcode(
        qrCodeText,
        width,
        height,
        1,
      );
      bluetoothAndroid!.printNewLine();
      bluetoothAndroid!.printNewLine();
      bluetoothAndroid!.printNewLine();
      bluetoothAndroid!.printNewLine();
      bluetoothAndroid!.paperCut();
      // bluetoothAndroid!.disconnect();
      // connectToDevice(device: selectedBluetoothDevice);
      // _generator = Generator(paperSize!, profile!, spaceBetweenRows: 5);
    }
    if (printerType == PrinterType.lan) {
      _socket!.add(
          _generator.qrcode(qrCodeText, align: align, size: size, cor: cor));
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

  Future<void> printReceipt([bool hasQr = false]) async {
    try {
      if (printerType == PrinterType.bluetooth) {
        if (selectedBluetoothDevice == null) {
          throw Exception('Device Not Selected');
        }

        if (!_isConnected && selectedBluetoothDevice != null) {
          await connectToDevice(device: selectedBluetoothDevice);
        }
        if (Platform.isAndroid) {
          bluetoothAndroid!.writeBytes(Uint8List.fromList(printerDataBytes));
          if (!hasQr) {
            bluetoothAndroid!.paperCut();
          }
        } else {
          final List<fb.BluetoothService> bluetoothServices =
              await _bluetoothDeviceIOS?.discoverServices() ??
                  <fb.BluetoothService>[];
          final fb.BluetoothService bluetoothService =
              bluetoothServices.firstWhere(
            (fb.BluetoothService service) => service.isPrimary,
          );
          final fb.BluetoothCharacteristic characteristic =
              bluetoothService.characteristics.firstWhere(
            (fb.BluetoothCharacteristic bluetoothCharacteristic) =>
                bluetoothCharacteristic.properties.write,
          );
          await characteristic.write(Uint8List.fromList(printerDataBytes),
              withoutResponse: true);
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  void addBluetoohLines(int lines) {
    for (int i = 0; i < lines; i++) {
      bluetoothAndroid!.printNewLine();
    }
  }
}
