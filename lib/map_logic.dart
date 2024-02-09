import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class MapLogic {
  Future<StationMarker?> fetchStationByName(String stationName) async {
    try {
      final apiUrl =
          'https://dfc4-83-244-103-51.ngrok-free.app/api/stations/stationByName?name=$stationName';
      Map<String, String> headers = {
        'ngrok-skip-browser-warning': 'true',
      };

      final response = await http.get(Uri.parse(apiUrl), headers: headers);
      if (response.statusCode == 200) {
        try {
          final dynamic data = json.decode(response.body);
          if (data is Map<String, dynamic> &&
              data.containsKey('id') &&
              data.containsKey('latitude') &&
              data.containsKey('longitude') &&
              data.containsKey('name')) {
            return StationMarker(
              id: data['id'].toString(),
              position: LatLng(
                data['latitude'] as double,
                data['longitude'] as double,
              ),
              title: data['name'] as String,
              distance: 0,
              additionalInfo: data['city'] as String? ?? '',
            );
          } else {
            print('Invalid format in API response for station by name');
            return null;
          }
        } catch (e) {
          print('Error decoding JSON: $e');
          return null;
        }
      } else {
        throw Exception(
            'Failed to fetch the station bydddddddddddddd name. Response: ${response.body}');
      }
    } catch (e) {
      print('Error fetching station by name: $e');
      return null;
    }
  }
}

class StationMarker {
  final String id;
  final LatLng position;
  final String title;
  double distance;
  Duration? timeEstimationWalking;
  Duration? timeEstimationCar;
  late final String additionalInfo;

  StationMarker({
    required this.id,
    required this.position,
    required this.title,
    required this.additionalInfo,
    this.distance = 0.0,
    this.timeEstimationWalking,
    this.timeEstimationCar,
  });

  Future<Marker> createMarker({void Function()? onTap}) async {
    BitmapDescriptor customIcon =
        await _bitmapDescriptorFromAsset('assets/R.png');
    return Marker(
      markerId: MarkerId(id),
      position: position,
      icon: customIcon,
      onTap: onTap,
    );
  }

  Future<BitmapDescriptor> _bitmapDescriptorFromAsset(String assetName) async {
    ByteData data = await rootBundle.load(assetName);
    List<int> bytes = data.buffer.asUint8List();
    Uint8List uint8List = Uint8List.fromList(bytes);
    return BitmapDescriptor.fromBytes(uint8List);
  }
}
