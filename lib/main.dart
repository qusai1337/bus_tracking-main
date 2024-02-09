// ignore_for_file: prefer_final_fields, use_super_parameters, unused_field, non_constant_identifier_names, prefer_collection_literals, prefer_const_declarations, unused_element, prefer_const_constructors, prefer_interpolation_to_compose_strings, override_on_non_overriding_member, avoid_print, division_optimization, await_only_futures, use_build_context_synchronously, unnecessary_null_comparison, prefer_const_literals_to_create_immutables, unnecessary_string_interpolations

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:bus_tracking/map_logic.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import 'package:motion_tab_bar_v2/motion-tab-bar.dart';
import 'package:motion_tab_bar_v2/motion-tab-controller.dart';
import 'Bus.dart';
import 'mapType.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
      ),
      home: LoadingScreen(),
    );
  }
}

class _HomePage extends StatefulWidget {
  const _HomePage({Key? key}) : super(key: key);
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  final MapLogic mapLogic = MapLogic();
  int routeId = 0;
  bool _isSearching = false;
  late MapTypeOption _selectedMapType;
  Polyline? _routePolyline;
  StationMarker? _selectedStation;
  Completer<GoogleMapController> _controller = Completer();
  late GoogleMapController _mapController;
  TextEditingController _searchController = TextEditingController();
  Set<Polyline> _polylines = Set();
  List<Marker> _markers = <Marker>[];
  List<Marker> _Busmarkers = <Marker>[];
  int _selectedIndex = 0;
  late MotionTabBarController _motionTabController;
  Timer? _timer;
  static final CameraPosition ps = const CameraPosition(
    target: LatLng(31.898043, 35.204269),
    zoom: 14.4746,
  );
  Future<void> _addRouteLine(LatLng userLocation, String travelMode) async {
    if (_selectedStation != null) {
      List<LatLng> polylinePoints = await _getPolylinePoints(
        userLocation,
        _selectedStation!.position,
        travelMode,
      );
      if (_routePolyline != null) {
        _polylines.remove(_routePolyline);
      }
      Polyline polyline = Polyline(
        polylineId: PolylineId('routeLine'),
        points: polylinePoints,
        width: 5,
      );
      _polylines.add(polyline);
      _routePolyline = polyline;
      setState(() {});
    }
  }

  Future<List<LatLng>> _getPolylinePoints(
      LatLng origin, LatLng destination, String travelMode) async {
    String orsApiKey =
        '5b3ce3597851110001cf6248ceb20dbd20f6477a9ade64693e422b18'; // Replace with your OpenRouteService API key
    String profile = (travelMode == 'walking') ? 'foot-walking' : 'driving-car';

    String apiUrl =
        'https://api.openrouteservice.org/v2/directions/$profile?api_key=$orsApiKey&start=${origin.longitude},${origin.latitude}&end=${destination.longitude},${destination.latitude}';
    final response = await http.get(Uri.parse(apiUrl));
    print('API Response: ${response.body}');
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> features = data['features'];
      if (features.isNotEmpty) {
        final List<dynamic> coordinates =
            features[0]['geometry']['coordinates'];
        List<LatLng> polylinePoints = coordinates
            .map((coord) => LatLng(coord[1] as double, coord[0] as double))
            .toList();
        return polylinePoints;
      }
    }
    return [];
  }

  late List<StationMarker> _stationMarkers = <StationMarker>[];
  double minDistance = double.infinity;
  Duration? _timeEstimationWalking;
  Duration? _timeEstimationCar;
  Future<Position> getUserCurrentLocation() async {
    await Geolocator.requestPermission()
        .then((value) {})
        .onError((error, stackTrace) async {
      await Geolocator.requestPermission();
      print("ERROR" + error.toString());
    });
    return await Geolocator.getCurrentPosition();
  }

  Future<void> _getUserCurrentLocationAndSetCamera() async {
    try {
      Position currentLocation = await getUserCurrentLocation();
      _mapController.animateCamera(CameraUpdate.newLatLngZoom(
        LatLng(currentLocation.latitude, currentLocation.longitude),
        14,
      ));
      _markers.add(
        Marker(
          markerId: MarkerId("currentLocation"),
          position: LatLng(currentLocation.latitude, currentLocation.longitude),
          icon: BitmapDescriptor.defaultMarker,
        ),
      );
      setState(() {});
    } catch (e) {
      print('Error getting current location: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _getUserCurrentLocationAndSetCamera();
    _addStationMarkers();

    _selectedMapType = MapTypeOption.Normal;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void dispose1() {
    _motionTabController.dispose();
    super.dispose();
  }

  Future<void> _addStationMarkers() async {
    try {
      List<StationMarker> stations = await _fetchStations();
      _markers.addAll(await Future.wait(stations.map((stationMarker) async {
        return stationMarker.createMarker(onTap: () {
          _onMarkerTapped(stationMarker);
        });
      })));
      _calculateClosestStation();
    } catch (e) {
      print('Error fetching stations: $e');
    }
  }

  bool _isFetching = false;
  Future<List<StationMarker>> _fetchStations() async {
    if (_isFetching) {
      return [];
    }

    try {
      _isFetching = true;

      final apiUrl = 'https://dfc4-83-244-103-51.ngrok-free.app/api/stations';
      Map<String, String> headers = {
        'ngrok-skip-browser-warning': 'true',
      };
      final response = await http.get(Uri.parse(apiUrl), headers: headers);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        await Future.delayed(Duration(seconds: 5));
        _isFetching = false;

        return data.map((stationData) {
          return StationMarker(
            id: stationData['id'].toString(),
            position: LatLng(
              stationData['latitude'] as double,
              stationData['longitude'] as double,
            ),
            title: stationData['name'] as String,
            distance: 0,
            additionalInfo: stationData['city'] as String? ?? '',
          );
        }).toList();
      } else {
        _isFetching = false;

        throw Exception('Failed to fetch stations');
      }
    } catch (e) {
      print('Error fetching stations: $e');
      return [
        StationMarker(
          id: "static-001",
          position: LatLng(31.898043, 35.204269),
          title: "Static Station",
          distance: 0,
          additionalInfo: "Static City",
        ),
        StationMarker(
          id: "static-002",
          position: LatLng(31.848752, 35.208636),
          title: "Static Station1",
          distance: 0,
          additionalInfo: "Static1 City",
        ),
      ];
    }
  }

  Future<void> _calculateClosestStation() async {
    try {
      Position currentLocation = await getUserCurrentLocation();
      for (var stationMarker in _stationMarkers) {
        // Skip stations with invalid coordinates
        if (stationMarker.position.latitude.abs() > 90 ||
            stationMarker.position.longitude.abs() > 180) {
          print(
              "Skipping invalid coordinates for station: ${stationMarker.title}");
          continue;
        }

        double distance = await Geolocator.distanceBetween(
          currentLocation.latitude,
          currentLocation.longitude,
          stationMarker.position.latitude,
          stationMarker.position.longitude,
        );
        stationMarker.timeEstimationCar =
            Duration(minutes: (distance / 250).toInt());
        print("Distance to ${stationMarker.title}: $distance meters");

        stationMarker.distance = distance;
        stationMarker.timeEstimationWalking =
            Duration(minutes: (distance / 50).toInt());
      }

      setState(() {});
    } catch (e) {
      print('Error calculating distances: $e');
    }
  }

  Future<void> _calculateTimeEstimation(
      Position currentLocation, LatLng destination) async {
    try {
      double distance = await Geolocator.distanceBetween(
        currentLocation.latitude,
        currentLocation.longitude,
        destination.latitude,
        destination.longitude,
      );
      print('Distance to ${_selectedStation!.title}: $distance meters');
      _selectedStation!.distance = distance;
      _selectedStation!.timeEstimationWalking = Duration(
        minutes: (_selectedStation!.distance! / 50).toInt(),
      );
      _selectedStation!.timeEstimationCar = Duration(
        minutes: (_selectedStation!.distance! / 100).toInt(),
      );
      setState(() {});
    } catch (e) {
      print('Error calculating time estimation: $e');
    }
  }

  Future<void> _onMarkerTapped(StationMarker stationMarker) async {
    _selectedStation = stationMarker;
    await _calculateTimeEstimation(
        await getUserCurrentLocation(), stationMarker.position);

    String selectedStationTitle = _selectedStation!.title;
    print('selected: ${_selectedStation!.title}');

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(15),
              topRight: Radius.circular(15),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.5),
                spreadRadius: 5,
                blurRadius: 7,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Station: ${_selectedStation!.title}',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.location_on, color: Colors.blue),
                  SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Distance: ${_selectedStation!.distance.toStringAsFixed(2)} meters',
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              if (_selectedStation!.timeEstimationWalking != null)
                Row(
                  children: [
                    Icon(Icons.directions_walk, color: Colors.green),
                    SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Walking Time: ${_selectedStation!.timeEstimationWalking!.inMinutes} minutes',
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              SizedBox(height: 10),
              if (_selectedStation!.timeEstimationCar != null)
                Row(
                  children: [
                    Icon(Icons.directions_car, color: Colors.red),
                    SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Car Time: ${_selectedStation!.timeEstimationCar!.inMinutes} minutes',
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  _clearPolylines();
                  _sendPostRequest(selectedStationTitle);
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  primary: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.0),
                  ),
                ),
                child: Text('Move', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        );
      },
    );
    setState(() {});
  }

  void _clearPolylines() {
    // Clear existing polylines from the map
    _polylines.clear();
    setState(() {});
  }

  Future<void> _sendPostRequest(String stationName) async {
    try {
      Position currentLocation = await getUserCurrentLocation();
      final apiUrl =
          'https://dfc4-83-244-103-51.ngrok-free.app/api/stations/StationToTravel';
      Map<String, String> headers = {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      };
      Map<String, dynamic> requestBody = {
        'stationDto': {'name': stationName},
        'currentLatitude': currentLocation.latitude,
        'currentLongitude': currentLocation.longitude,
      };
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: headers,
        body: json.encode(requestBody),
      );
      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        print('API Response: $data');
        if (data is Map<String, dynamic> && data.containsKey('routeId')) {
          int routeId = data['routeId'] as int;
          print('Route ID: $routeId');
          if (data.containsKey('stationsList') &&
              data['stationsList'] is List) {
            List<dynamic> stations = data['stationsList'];
            _processStations(currentLocation, stations);
          }
          await getBusesAndCreateMarkers(routeId);
          _updateMapWithMarkers();
        }
      } else {
        print('Failed to send the post request. Response: ${response.body}');
      }
    } catch (e) {
      print('Error sending post request: $e');
    }
  }

  void _processStations(
      Position currentLocation, List<dynamic> stations) async {
    _clearPolylines();
    LatLng origin = LatLng(
      currentLocation.latitude,
      currentLocation.longitude,
    );
    for (int i = 0; i < stations.length; i++) {
      LatLng destination = LatLng(
        stations[i]['latitude'] as double,
        stations[i]['longitude'] as double,
      );

      PolylineId polylineId = PolylineId('routeLine${stations[i]['id']}');
      String dist = stations[i]['name'];

      await _drawPolyline(
        userLocation: origin,
        destination: destination,
        travelMode: 'driving-car',
        color: i == 0 ? Colors.red : Colors.blue,
        polylineId: polylineId,
        width: i == 0 ? 3 : 6,
        zIndex: i == 0 ? 2 : 1,
        dist: dist,
      );
      origin = destination;
    }
    getBusesAndCreateMarkers(routeId);
  }

  bool _isSendingbus = false;

  Future<List<Marker>> getBusesAndCreateMarkers(int routeId) async {
    List<Marker> markers = [];
    if (_isSendingbus) {
      return [];
    }

    final apiUrl =
        'https://dfc4-83-244-103-51.ngrok-free.app/api/routes/$routeId/getBuss';
    try {
      _isSendingbus = true;
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      final response = await http.get(Uri.parse(apiUrl), headers: headers);
      if (response.statusCode == 200) {
        List<dynamic> busesData = json.decode(response.body);
        for (var busData in busesData) {
          double latitude = busData['latitude'];
          double longitude = busData['longitude'];
          if (latitude == 0.0 && longitude == 0.0) {
            continue;
          }
          Bus bus = Bus(
            id: busData['id'],
            permitNumber: busData['permitNumber'],
            position: LatLng(latitude, longitude),
            arrivalTimes: {},
          );
          Marker marker = await bus.createMarker();
          markers.add(marker);
        }
        setState(() {
          _Busmarkers = markers;
        });
        await Future.delayed(Duration(seconds: 5));

        _isSendingbus = false;
      } else {
        print('Failed to fetch buses. Response: ${response.body}');
      }
    } catch (e) {
      print('Error fetching buses: $e');
      _isSendingbus = false;
    }
    _startRealTimeUpdates(routeId);

    return markers;
  }

  void _updateMapWithMarkers() {
    setState(() {});
  }

  void _startRealTimeUpdates(int routeId) {
    _timer?.cancel();
    const updateInterval = Duration(seconds: 10);
    _timer = Timer.periodic(updateInterval, (Timer t) async {
      if (routeId != null) {
        await getBusesAndCreateMarkers(routeId);
        _updateMapWithMarkers();
      }
    });
  }

  Future<void> _moveCameraToPosition(LatLng position) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLng(position));
  }

  Future<void> _drawPolyline(
      {required LatLng userLocation,
      required LatLng destination,
      required String travelMode,
      required Color color,
      required PolylineId polylineId,
      required int width,
      required int zIndex,
      required String dist}) async {
    List<LatLng> polylinePoints =
        await _getPolylinePoints(userLocation, destination, travelMode);
    Polyline polyline = Polyline(
      polylineId: polylineId,
      points: polylinePoints,
      color: color,
      width: width,
      zIndex: zIndex,
    );
    _polylines.add(polyline);
    _showPolylineInfoBottomSheet(
      userLocation as LatLng,
      destination,
      travelMode,
      dist,
    );
    setState(() {});
  }

  Future<void> _showPolylineInfoBottomSheet(LatLng userLocation,
      LatLng destination, String travelMode, String dist) async {
    double distance = await Geolocator.distanceBetween(
      userLocation.latitude,
      userLocation.longitude,
      destination.latitude,
      destination.longitude,
    );

    Duration timeEstimation;
    if (travelMode == 'walking') {
      timeEstimation = Duration(minutes: (distance / 50).toInt());
    } else {
      timeEstimation = Duration(minutes: (distance / 100).toInt());
    }

    String originName = "Your current Location";
    String destinationName = dist;

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Route Information', textAlign: TextAlign.center),
              SizedBox(height: 16.0),
              Row(
                children: [
                  Icon(Icons.location_on, color: Colors.red),
                  Expanded(
                    child: Text(
                      originName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.flag, color: Colors.black),
                  Expanded(
                    child: Text(
                      destinationName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Divider(),
              ListTile(
                title: Text('Distance'),
                trailing: Text(
                    '${distance > 1000 ? (distance / 1000).toStringAsFixed(2) + " km" : distance.toStringAsFixed(2) + " meters"}'),
              ),
              ListTile(
                title: Text('Estimated Time'),
                trailing: Text(
                    '${timeEstimation.inMinutes > 60 ? (timeEstimation.inMinutes / 60).toStringAsFixed(2) + "Hours" : timeEstimation.inMinutes.toStringAsFixed(2) + "minutes"}'),
              ),
              SizedBox(height: 16.0),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

  static const List<BottomNavigationBarItem> _bottomNavBarItems = [
    BottomNavigationBarItem(
      icon: Icon(Icons.menu),
      label: 'Menu',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.bus_alert),
      label: 'Stations',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: ps,
            compassEnabled: true,
            myLocationEnabled: true,
            markers: {..._markers, ..._Busmarkers}
                .toSet(), // Combine both lists into a set
            polylines: _polylines,
            mapType: _getMapType(),
            gestureRecognizers: Set()
              ..add(Factory<OneSequenceGestureRecognizer>(
                () => EagerGestureRecognizer(),
              )),
            onTap: (LatLng latLng) async {},
            onMapCreated: (GoogleMapController controller) async {
              _controller.complete(controller);

              _mapController = controller;
            },
            zoomControlsEnabled: true,
          ),
        ],
      ),
      bottomNavigationBar: MotionTabBar(
        labels: ["Menu", "Stations", "TimeLine"],
        initialSelectedTab: "Stations",
        tabIconColor: Colors.grey,
        tabSelectedColor: Colors.blue,
        onTabItemSelected: (int value) {
          setState(() {
            _selectedIndex = value;
            switch (value) {
              case 0:
                _buildMenuItem();
                break;
              case 1:
                _showStations();
                break;
              case 2:
                break;
            }
          });
        },
        icons: [Icons.menu, Icons.bus_alert, Icons.timeline],
        textStyle: TextStyle(color: Colors.blue),
      ),
    );
  }

  Widget _buildShowStationsButton() {
    _getUserCurrentLocationAndSetCamera();
    return Theme(
      data: ThemeData(
        brightness: Brightness.light,
      ),
      child: IconButton(
        icon: Icon(Icons.bus_alert),
        onPressed: () {
          _showStations();
        },
        color: Colors.white,
      ),
    );
  }

  String _searchQuery = '';
  List<StationMarker> _filteredStations = [];

  void _showStations() async {
    try {
      List<StationMarker> allStations = await _fetchStations();
      _stationMarkers = allStations;
      await _calculateClosestStation();
      _filteredStations = _stationMarkers;
      showModalBottomSheet(
        useSafeArea: true,
        context: context,
        isScrollControlled: true,
        builder: (context) {
          return SizedBox(
            height: 600,
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('All Stations',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black)),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.black),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Search Stations',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) {
                      _searchQuery = value;
                      setState(() {
                        _filteredStations = allStations
                            .where((station) => station.title
                                .toLowerCase()
                                .contains(_searchQuery.toLowerCase()))
                            .toList();
                      });
                    },
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredStations.length,
                    itemBuilder: (context, index) {
                      return _buildStationCard(
                        _filteredStations[index],
                        _getColorForStation(_filteredStations[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      print('Error showing stations: $e');
    }
  }

  Color _getColorForStation(StationMarker station) {
    if (station.distance < 1000) {
      return Colors.green;
    } else if (station.distance < 2000) {
      return Colors.blue;
    } else {
      return Colors.red;
    }
  }

  Widget _buildStationCard(StationMarker station, Color cardColor) {
    return InkWell(
      onTap: () => _sendPostRequest(station.title),
      child: Card(
        elevation: 4,
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(60),
            bottomLeft: Radius.circular(60),
          ),
        ),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                cardColor.withOpacity(0.7),
                cardColor,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(60),
              bottomLeft: Radius.circular(60),
            ),
          ),
          child: Row(
            children: [
              Image.asset('assets/logo.png', width: 50),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(station.title,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    Text(
                      station.additionalInfo, // City
                      style: TextStyle(fontSize: 14, color: Colors.white),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '${station.distance.toStringAsFixed(2)} meters',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    if (station.timeEstimationWalking != null)
                      Text(
                        'Walking Time: ${station.timeEstimationWalking!.inMinutes} min',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    if (station.timeEstimationCar != null)
                      Text(
                        'Driving Time: ${station.timeEstimationCar!.inMinutes} min',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 30, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  MapType _getMapType() {
    switch (_selectedMapType) {
      case MapTypeOption.Normal:
        return MapType.normal;
      case MapTypeOption.Satellite:
        return MapType.satellite;
      case MapTypeOption.Hybrid:
        return MapType.hybrid;
      case MapTypeOption.Terrain:
        return MapType.terrain;
      default:
        throw UnimplementedError('Unexpected MapTypeOption: $_selectedMapType');
    }
  }

  void _buildMenuItem() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.map),
                title: Text('Change Map Type'),
                onTap: () {
                  Navigator.pop(context);
                  _showMapTypeSelector();
                },
              ),
              ListTile(
                leading: Icon(Icons.support),
                title: Text('Support'),
                onTap: () {
                  Navigator.pop(context);
                  _showSupportDialog();
                },
              ),
              ListTile(
                leading: Icon(Icons.feedback),
                title: Text('Feedback'),
                onTap: () async {
                  const url = 'http://127.0.0.1:5500/GDP/index.html#contact';
                  if (await canLaunch(url)) {
                    await launch(url);
                  } else {
                    throw 'Could not launch $url';
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.exit_to_app),
                title: Text('Exit'),
                onTap: () {
                  Navigator.pop(context); // Close the modal
                  exit;
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMapTypeSelector() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Map Type'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMapTypeOption(
                'Normal',
                MapTypeOption.Normal,
              ),
              _buildMapTypeOption(
                'Satellite',
                MapTypeOption.Satellite,
              ),
              _buildMapTypeOption(
                'Hybrid',
                MapTypeOption.Hybrid,
              ),
              _buildMapTypeOption(
                'Terrain',
                MapTypeOption.Terrain,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMapTypeOption(String title, MapTypeOption option) {
    return ListTile(
      title: Text(title),
      onTap: () {
        setState(() {
          _selectedMapType = option;
        });
        Navigator.pop(context);
      },
    );
  }

  Widget _buildSupportMenuItem() {
    return ListTile(
      leading: Icon(Icons.mail),
      title: Text('Support'),
      onTap: () {
        Navigator.pop(context);
        _showSupportDialog();
      },
    );
  }

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String message = '';
        return AlertDialog(
          title: Text('Support'),
          content: Column(
            children: [
              Text('Type your message:'),
              TextField(
                onChanged: (value) {
                  message = value;
                },
                maxLines: 4,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _sendSupportEmail(message);
              },
              child: Text('Send'),
            ),
          ],
        );
      },
    );
  }

  void _sendSupportEmail(String message) {
    print('Sending support message: $message');
  }
}

Future<StationMarker?> fetchNearestStation(LatLng userLocation) async {
  try {
    final apiUrl =
        'https://dfc4-83-244-103-51.ngrok-free.app/api/stations/nearestStation?userLat=${userLocation.latitude}&userLng=${userLocation.longitude}';
    Map<String, String> headers = {
      'ngrok-skip-browser-warning': 'true',
    };
    final response = await http.get(Uri.parse(apiUrl), headers: headers);
    if (response.statusCode == 200) {
      final dynamic data = json.decode(response.body);
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
      throw Exception('Failed to fetch the nearest station');
    }
  } catch (e) {
    print('Error fetching nearest station: $e');
    return null;
  }
}

class LoadingScreen extends StatefulWidget {
  @override
  _LoadingScreenState createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  _navigateToHome() async {
    await Future.delayed(Duration(seconds: 3));
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (context) => _HomePage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/logo.png'),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
