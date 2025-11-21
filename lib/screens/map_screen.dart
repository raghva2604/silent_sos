import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/poi_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  Position? _currentPosition;
  bool _locationPermissionGranted = false;
  String? _nearestCivilization;
  String? _nearestTransport;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(12.9716, 77.5946), // Default to Bangalore
    zoom: 14.0,
  );

  final Set<Marker> _markers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPermissionAndInit();
  }

  Future<void> _checkPermissionAndInit() async {
    try {
      final status = await Permission.location.status;
      if (!status.isGranted) {
        final newStatus = await Permission.location.request();
        if (!newStatus.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission is required to show the map.')));
          }
          setState(() => _locationPermissionGranted = false);
          return;
        }
      }
      setState(() => _locationPermissionGranted = true);
      await _getUserLocation();
    } catch (e) {
      debugPrint('Location permission check failed: $e');
    }
  }

  Future<void> _getUserLocation() async {
    try {
      // Use LocationSettings per new Geolocator API to avoid deprecated param
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (_currentPosition == null) return;

      final newPosition = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);

      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: newPosition, zoom: 16.0),
      ));

      setState(() {
        _markers.add(
          Marker(
            markerId: const MarkerId('currentLocation'),
            position: newPosition,
            infoWindow: const InfoWindow(title: 'My Location'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          ),
        );
        _isLoading = false;
      });

      // Fetch nearby POI info (non-blocking, best-effort)
      try {
        final civ = await POIService.nearestCivilization(newPosition.latitude, newPosition.longitude);
        final trans = await POIService.nearestTransport(newPosition.latitude, newPosition.longitude);
        setState(() {
          _nearestCivilization = civ.isNotEmpty ? civ : null;
          _nearestTransport = trans.isNotEmpty ? trans : null;
        });
      } catch (e) {
        debugPrint('POI lookup failed: $e');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get location: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _findCivilization() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Still waiting for location...')),
      );
      return;
    }

    // A broad search query to find signs of civilization
    const searchQuery = 'gas station OR store OR town OR village OR cafe OR restaurant';
    final query = Uri.encodeComponent(searchQuery);
    final lat = _currentPosition!.latitude;
    final lon = _currentPosition!.longitude;

    final mapsUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query&location=$lat,$lon'
    );

    if (await canLaunchUrl(mapsUrl)) {
      await launchUrl(mapsUrl, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps.')),
        );
      }
    }
  }

  Future<void> _findTransport() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Still waiting for location...')),
      );
      return;
    }

    // Broad transport related search: bus/rail/metro/taxi/airport
    const searchQuery = 'bus station OR train station OR transit station OR metro station OR taxi stand OR airport';
    final query = Uri.encodeComponent(searchQuery);
    final lat = _currentPosition!.latitude;
    final lon = _currentPosition!.longitude;

    final mapsUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query&location=$lat,$lon'
    );

    if (await canLaunchUrl(mapsUrl)) {
      await launchUrl(mapsUrl, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Location'),
      ),
      body: _locationPermissionGranted
          ? Stack(
              children: [
                GoogleMap(
                  mapType: MapType.normal,
                  initialCameraPosition: _initialPosition,
                  onMapCreated: (GoogleMapController controller) {
                    if (!_controller.isCompleted) _controller.complete(controller);
                    // Ensure we attempt to get the user's location once the map is ready
                    // (this helps avoid timing issues where getCurrentPosition races with map creation).
                    if (_currentPosition == null) {
                      _getUserLocation();
                    }
                  },
                  markers: _markers,
                  myLocationButtonEnabled: _locationPermissionGranted,
                  myLocationEnabled: _locationPermissionGranted,
                ),
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                if (!_isLoading && (_nearestCivilization != null || _nearestTransport != null))
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Card(
                        color: const Color(0xFF0E0E14).withAlpha((0.9 * 255).round()),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_nearestCivilization != null) Text('Nearest place: $_nearestCivilization', style: const TextStyle(color: Colors.white)),
                              if (_nearestTransport != null) Text('Nearest transport: $_nearestTransport', style: const TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_off, size: 64, color: Colors.white70),
                    const SizedBox(height: 12),
                    const Text('Location permission is required to show the map.', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _checkPermissionAndInit,
                      child: const Text('Request Permission'),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'transport',
            onPressed: _findTransport,
            label: const Text('Find Transport'),
            icon: const Icon(Icons.train),
            backgroundColor: Colors.blueGrey[900],
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'civil',
            onPressed: _findCivilization,
            label: const Text('Find Nearest Civilization'),
            icon: const Icon(Icons.explore),
          ),
        ],
      ),
    );
  }
}
