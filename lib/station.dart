import 'dart:math';

import 'package:bus_tracking/Bus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Station {
  final int id;
  final LatLng position;

  Station({required this.id, required this.position});
}

double calculateDistance(LatLng start, LatLng end) {
  var earthRadius = 6371; // Radius of the earth in km
  var dLat = _deg2rad(end.latitude - start.latitude); // deg2rad below
  var dLon = _deg2rad(end.longitude - start.longitude);
  var a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_deg2rad(start.latitude)) *
          cos(_deg2rad(end.latitude)) *
          sin(dLon / 2) *
          sin(dLon / 2);
  var c = 2 * atan2(sqrt(a), sqrt(1 - a));
  var distance = earthRadius * c; // Distance in km
  return distance;
}

double _deg2rad(double deg) {
  return deg * (pi / 180);
}

Future<void> estimateArrivalTimes(
    List<Bus> buses, List<Station> stations, double averageSpeedKmPerHr) async {
  for (var bus in buses) {
    for (var station in stations) {
      double distanceToStation =
          calculateDistance(bus.position, station.position);
      // Assuming averageSpeedKmPerHr is the average speed of the bus
      double travelTimeHours = distanceToStation / averageSpeedKmPerHr;
      int travelTimeMinutes = (travelTimeHours * 60).round();
      // Now you have the travel time in minutes for each bus to each station
      // You can use this to calculate and display the estimated arrival time
      print(
          'Bus ${bus.id} to Station ${station.id}: $travelTimeMinutes minutes');
    }
  }
}
