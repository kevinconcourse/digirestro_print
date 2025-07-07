import 'dart:developer';
import 'package:digirestro_print/digirestro_print.dart';
import 'package:digirestro_esc_pos_utils/digirestro_esc_pos_utils.dart';
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
  PrinterType selectedPrinterType = PrinterType.bluetooth;
  late PosPrinter posPrinter;
  List<BlueDevice> bluetoothDevices = [];
  List usbPrinters = [];
  dynamic selectedUsbPrinter;

  @override
  void initState() {
    super.initState();
    posPrinter = PosPrinter(printerType: selectedPrinterType);
  }

  void updatePrinterType(PrinterType type) {
    setState(() {
      selectedPrinterType = type;
      posPrinter = PosPrinter(printerType: selectedPrinterType);
      bluetoothDevices = [];
      usbPrinters = [];
      selectedUsbPrinter = null;
    });
  }

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
            DropdownButton<PrinterType>(
              value: selectedPrinterType,
              items: const [
                DropdownMenuItem(
                  value: PrinterType.bluetooth,
                  child: Text('Bluetooth'),
                ),
                DropdownMenuItem(
                  value: PrinterType.usb,
                  child: Text('USB'),
                ),
              ],
              onChanged: (type) {
                if (type != null) updatePrinterType(type);
              },
            ),
            if (selectedPrinterType == PrinterType.bluetooth)
              TextButton(
                onPressed: () async {
                  bluetoothDevices = await posPrinter.scanForDevices();
                  setState(() {});
                  log(bluetoothDevices.toString());
                },
                child: const Text('Scan for Bluetooth devices'),
              ),
            if (selectedPrinterType == PrinterType.usb)
              TextButton(
                onPressed: () async {
                  await posPrinter.scanForUsbDevices();
                  setState(() {
                    usbPrinters = posPrinter.usbPrinters;
                  });
                  log(usbPrinters.toString());
                },
                child: const Text('Scan for USB printers'),
              ),
            if (selectedPrinterType == PrinterType.bluetooth)
              TextButton(
                onPressed: () async {
                  try {
                    if (bluetoothDevices.isEmpty) return;
                    final bluetoothData = await posPrinter.connectToDevice(
                      device: bluetoothDevices.first,
                    );
                    log(bluetoothData.toString());
                  } catch (e) {
                    log(e.toString());
                  }
                },
                child: const Text('Connect To Bluetooth Printer'),
              ),
            if (selectedPrinterType == PrinterType.usb)
              Column(
                children: [
                  DropdownButton(
                    value: selectedUsbPrinter,
                    hint: const Text('Select USB Printer'),
                    items: usbPrinters.map<DropdownMenuItem>((printer) {
                      return DropdownMenuItem(
                        value: printer,
                        child: Text(printer.name ?? 'Unknown'),
                      );
                    }).toList(),
                    onChanged: (printer) {
                      setState(() {
                        selectedUsbPrinter = printer;
                      });
                    },
                  ),
                  TextButton(
                    onPressed: () async {
                      if (selectedUsbPrinter == null) return;
                      final result = await posPrinter
                          .connectToUsbPrinter(selectedUsbPrinter);
                      log(result.toString());
                    },
                    child: const Text('Connect To USB Printer'),
                  ),
                ],
              ),
            TextButton(
              onPressed: () async {
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
                    text: 'TDO-123123',
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
                    text: 'Admin',
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

                if (selectedPrinterType == PrinterType.bluetooth) {
                  posPrinter.disconnect();
                  posPrinter.printReceipt();
                } else if (selectedPrinterType == PrinterType.usb) {
                  await posPrinter.printUsbReceipt(posPrinter.printerDataBytes);
                  await posPrinter.disconnectUsbPrinter();
                }
              },
              child: const Text('Test Print'),
            ),
          ],
        ),
      ),
    );
  }
}
