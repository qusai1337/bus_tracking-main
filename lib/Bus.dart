import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Bus {
  final int id;
  final String permitNumber;
  final LatLng position;
  String? arrivalTimeToFirstStation; // Optional field for arrival time

  Bus({
    required this.id,
    required this.permitNumber,
    required this.position,
    this.arrivalTimeToFirstStation,
    required Map arrivalTimes,
  });

  // Setter for arrival time if you need to set it after instantiation
  void setArrivalTimeToFirstStation(String arrivalTime) {
    arrivalTimeToFirstStation = arrivalTime;
  }

  Future<Marker> createMarker() async {
    BitmapDescriptor customIcon =
        await _bitmapDescriptorFromAsset('assets/bus_icon.png');

    String snippetText =
        'Permit Number: $permitNumber' + '/nArrivs: $arrivalTimeToFirstStation';

    // Debug print
    print('Creating marker for Bus $id with snippet: $snippetText');

    return Marker(
      markerId: MarkerId('bus_$id'),
      position: position,
      icon: customIcon,
      infoWindow: InfoWindow(
        title: 'Bus ID: $id',
        snippet: snippetText, // Make sure this is the updated snippetText
      ),
      onTap: () {
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
