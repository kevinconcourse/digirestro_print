class BlueDevice {
  BlueDevice({
    required this.name,
    required this.address,
    this.connected = false,
    this.type = 0,
  });

  /// Name of bluetooth device, Android and iOS have same field name
  final String name;

  /// [address] value in Android get from model with same field name
  /// But in iOS get from id.id
  final String address;

  int? type;
  bool? connected;
}

class UsbDevice {
  UsbDevice({
    this.name,
    this.vendorId,
    this.productId,
    this.serialNumber,
  });

  /// Name of the USB printer
  final String? name;

  /// Vendor ID of the USB printer
  final String? vendorId;

  /// Product ID of the USB printer
  final String? productId;

  /// Serial number of the USB printer
  final String? serialNumber;
}
