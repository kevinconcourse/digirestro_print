import 'dart:developer';
import 'package:digirestro_print/digirestro_print.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digirestro Print Package Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
  });

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final PosPrinter posPrinter = PosPrinter(printerType: PrinterType.bluetooth);
  List<BlueDevice> bluetoothDevices = [];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Digirestro'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () async {
                bluetoothDevices = await posPrinter.scanForDevices();
                setState(() {});
                log(bluetoothDevices.toString());
              },
              child: const Text(
                'Scan for devices',
              ),
            ),
            TextButton(
              onPressed: () async {
                try {
                  /// GO FOR LAN
                  // final lanData = await posPrinter.connectToDevice(
                  //   ipAddress: '192.168.0.133',
                  // );
                  // log(lanData.toString());

                  /// GO FOR BLUETOOTH

                  final bluetoothData = await posPrinter.connectToDevice(
                    device: bluetoothDevices[8],
                  );
                  log(bluetoothData.toString());
                } catch (e) {
                  log(e.toString());
                }
              },
              child: const Text(
                'Connect To Printer',
              ),
            ),
            TextButton(
              onPressed: () {
                posPrinter.row(
                  [
                    PosColumn(
                      text: '\t',
                      width: 2,
                      styles: const PosStyles(
                        align: PosAlign.center,
                        height: PosTextSize.size4,
                      ),
                    ),
                    PosColumn(
                      text: 'KOT |  Added',
                      width: 8,
                      styles: const PosStyles(
                        align: PosAlign.center,
                        bold: true,
                        fontType: PosFontType.fontA,
                      ),
                    ),
                    PosColumn(
                      text: '\t',
                      width: 2,
                      styles: const PosStyles(
                        align: PosAlign.center,
                      ),
                    ),
                  ],
                );
                posPrinter.hr();
                posPrinter.row([
                  PosColumn(text: 'Order No.:', width: 6),
                  PosColumn(
                    text: "TDO-123123",
                    width: 6,
                    styles: const PosStyles(
                      align: PosAlign.right,
                    ),
                  ),
                ]);
                posPrinter.row([
                  PosColumn(text: 'Table No.:', width: 6),
                  PosColumn(
                    text: 'Table 123',
                    width: 6,
                    styles: const PosStyles(
                      align: PosAlign.right,
                    ),
                  ),
                ]);
                posPrinter.row([
                  PosColumn(text: 'Kot No.:', width: 6),
                  PosColumn(
                    text: '2',
                    width: 6,
                    styles: const PosStyles(
                      align: PosAlign.right,
                    ),
                  ),
                ]);
                posPrinter.row([
                  PosColumn(text: 'Captain Name:', width: 6),
                  PosColumn(
                    text: "Admin",
                    width: 6,
                    styles: const PosStyles(
                      align: PosAlign.right,
                    ),
                  ),
                ]);
                posPrinter.row([
                  PosColumn(text: 'Date & Time :', width: 6),
                  PosColumn(
                    text: '2022-01-01',
                    width: 6,
                    styles: const PosStyles(
                      align: PosAlign.right,
                    ),
                  ),
                ]);
                posPrinter.hr();
                posPrinter.feed(1);
                posPrinter.cut();

                posPrinter.disconnect();
                posPrinter.printReceipt();
              },
              child: const Text(
                'Test Print',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
