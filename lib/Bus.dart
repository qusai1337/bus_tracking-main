import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Bus {
  final int id;
  final String permitNumber;
  final LatLng position;

  Bus({
    required this.id,
    required this.permitNumber,
    required this.position,
  });

  Future<Marker> createMarker() async {
    BitmapDescriptor customIcon =
        await _bitmapDescriptorFromAsset('assets/bus_icon.png');

    return Marker(
      markerId: MarkerId(id.toString()),
      position: position,
      icon: customIcon,
      onTap: () {
        // Handle marker tap event for the bus
        // You can implement custom behavior here
        print('Bus tapped! Bus ID: $id, Permit Number: $permitNumber');
      },
    );
  }

  Future<BitmapDescriptor> _bitmapDescriptorFromAsset(String assetName) async {
    ByteData data = await rootBundle.load(assetName);
    List<int> bytes = data.buffer.asUint8List();
    Uint8List uint8List = Uint8List.fromList(bytes);
    return BitmapDescriptor.fromBytes(uint8List);
  }
}
