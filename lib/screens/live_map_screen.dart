import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> with TickerProviderStateMixin {
  final MapController mapController = MapController();

  LatLng currentLocation = LatLng(17.3850, 78.4867);

  List<LatLng> pathPoints = [];
  // other users can include optional label/avatar
  List<_User> otherUsers = [];

  // animation controller state
  LatLng? _animFrom;
  LatLng? _animTo;
  AnimationController? _moveController;
  AnimationController? _spiderController;
  Animation<double>? _spiderAnimation;
  Animation<double>? _moveAnimation;

  // clustering settings
  final double clusterRadiusMeters = 50.0;

  // spiderfy state: temporary expanded markers for tapped clusters
  final Map<int, List<_Spider>> _spiders = {};
  Timer? _spiderTimer;

  // enable device GPS fallback when remote fetch fails
  bool useGpsFallback = true;

  Timer? timer;

  @override
  void initState() {
    super.initState();

    // animation controller for smooth marker movement
    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _spiderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _spiderAnimation = CurvedAnimation(parent: _spiderController!, curve: Curves.easeOutCubic);

    fetchLocation();

    timer = Timer.periodic(
      const Duration(seconds: 5),
      (timer) => fetchLocation(),
    );
  }

  Future<void> fetchLocation() async {
    try {
      final response = await http.get(
        Uri.parse("http://13.203.67.82:3000/latest-location"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // support single object or list of locations
        if (data is List) {
          otherUsers = [];
          for (final item in data) {
              final double lat = double.parse(item['latitude'].toString());
              final double lng = double.parse(item['longitude'].toString());
              final String? label = item['label']?.toString();
              final String? avatar = item['avatar']?.toString();
              final LatLng loc = LatLng(lat, lng);
              otherUsers.add(_User(location: loc, label: label, avatarUrl: avatar));
          }
          // if list contains our device as first item, use it as current
          if (otherUsers.isNotEmpty) {
            _updateCurrentLocation(otherUsers.first.location);
          }
        } else if (data is Map) {
          final double lat = double.parse(data['latitude'].toString());
          final double lng = double.parse(data['longitude'].toString());
          final LatLng newLocation = LatLng(lat, lng);
          _updateCurrentLocation(newLocation);
        }
      } else {
        // fallback to GPS if enabled
        if (useGpsFallback) await _useDeviceGpsOnce();
      }

      try {
        mapController.move(currentLocation, 16);
      } catch (_) {}

    } catch (e) {
      debugPrint("Map error: $e");
    }
  }

  void _clearSpiderfy() {
    _spiderTimer?.cancel();
    if (_spiders.isNotEmpty) {
      setState(() {
        _spiders.clear();
      });
    }
  }

  void _spiderfy(int index, _Cluster cluster) {
    _spiderTimer?.cancel();
    final int n = math.min(cluster.count, 12);
    final double maxRadius = math.min(80.0, 12.0 + cluster.count * 8.0); // meters
    final List<_Spider> list = [];
    for (int i = 0; i < n; i++) {
      final angle = (2 * math.pi * i) / n;
      final user = cluster.members[i % cluster.members.length];
      list.add(_Spider(center: cluster.center, angle: angle, radius: maxRadius, user: user));
    }

    setState(() {
      _spiders[index] = list;
    });

    _spiderController?.forward(from: 0);

    _spiderTimer = Timer(const Duration(seconds: 8), () {
      _spiderController?.reverse();
      Future.delayed(const Duration(milliseconds: 300), () {
        setState(() => _spiders.clear());
      });
    });
  }

  LatLng _offsetLatLng(LatLng from, double meters, double angleRad) {
    final dx = meters * math.cos(angleRad); // east
    final dy = meters * math.sin(angleRad); // north
    const metersPerDegLat = 111320.0;
    final latRad = from.latitude * math.pi / 180.0;
    final deltaLat = dy / metersPerDegLat;
    final deltaLng = dx / (metersPerDegLat * math.cos(latRad));
    return LatLng(from.latitude + deltaLat, from.longitude + deltaLng);
  }

  @override
  void dispose() {
    timer?.cancel();
    _moveController?.dispose();
    _spiderController?.dispose();
    super.dispose();
  }

  Future<void> _useDeviceGpsOnce() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        return;
      }

        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.best));
      final LatLng deviceLoc = LatLng(pos.latitude, pos.longitude);
      _updateCurrentLocation(deviceLoc);
    } catch (e) {
      debugPrint('GPS fallback error: $e');
    }
  }

  void _updateCurrentLocation(LatLng newLocation) {
    final prev = currentLocation;
    // start smooth animation between prev and new
    _animateMarker(prev, newLocation);

    setState(() {
      pathPoints.add(newLocation);
      currentLocation = newLocation;
    });
  }

  void _animateMarker(LatLng from, LatLng to) {
    // cancel previous
    _moveController?.stop();
    _animFrom = from;
    _animTo = to;

    _moveAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _moveController!, curve: Curves.easeInOut),
    )..addListener(() {
        final t = _moveAnimation!.value;
        final lat = _lerpDouble(_animFrom!.latitude, _animTo!.latitude, t);
        final lng = _lerpDouble(_animFrom!.longitude, _animTo!.longitude, t);
        setState(() {
          currentLocation = LatLng(lat, lng);
        });
      });

    _moveController?.forward(from: 0);
  }

  double _lerpDouble(double a, double b, double t) => a + (b - a) * t;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Tracking"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('GPS fallback'),
                Switch(
                  value: useGpsFallback,
                  onChanged: (v) => setState(() => useGpsFallback = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: currentLocation,
                initialZoom: 16,
                onTap: (_, __) => _clearSpiderfy(),
              ),
              children: [

                // 🌍 MAP TILES
                TileLayer(
                  urlTemplate:
                      "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName: "com.silent.sos",
                ),

                // build markers with simple clustering
                MarkerLayer(
                  markers: _buildAllMarkers(),
                ),

                // 🛣️ PATH DRAWING
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: pathPoints,
                      strokeWidth: 4,
                      color: Colors.blue,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildAllMarkers() {
    final List<Marker> markers = [];

    // current user marker (red)
    markers.add(Marker(
      point: currentLocation,
      width: 80,
      height: 80,
      child: const Icon(
        Icons.location_on,
        color: Colors.red,
        size: 40,
      ),
    ));

    // cluster other users
    final Distance distance = Distance();
    final List<_Cluster> clusters = [];

    for (final u in otherUsers) {
      bool placed = false;
      for (final c in clusters) {
        final d = distance.distance(c.center, u.location);
        if (d <= clusterRadiusMeters) {
          c.add(u);
          placed = true;
          break;
        }
      }
      if (!placed) clusters.add(_Cluster.fromUser(u));
    }

    for (int idx = 0; idx < clusters.length; idx++) {
      final c = clusters[idx];
      if (c.count == 1) {
        final u = c.members.first;
        markers.add(Marker(
          point: c.center,
          width: 48,
          height: 48,
          child: Column(
            children: [
              CircleAvatar(
                backgroundColor: Colors.green.shade700,
                radius: 14,
                backgroundImage: u.avatarUrl != null ? NetworkImage(u.avatarUrl!) : null,
                child: u.avatarUrl == null
                    ? Text(u._initials(), style: const TextStyle(fontSize: 10, color: Colors.white))
                    : null,
              ),
            ],
          ),
        ));
      } else {
        markers.add(Marker(
          point: c.center,
          width: 56,
          height: 56,
          child: GestureDetector(
            onTap: () => _spiderfy(idx, c),
            child: CircleAvatar(
              backgroundColor: Colors.orange,
              child: Text(c.count > 99 ? '99+' : c.count.toString()),
            ),
          ),
        ));
      }
    }

    // include spiderfy markers (animated expansion)
    final anim = _spiderAnimation?.value ?? 1.0;
    _spiders.forEach((idx, list) {
      for (final sp in list) {
        final pos = _offsetLatLng(sp.center, sp.radius * anim, sp.angle);
        markers.add(Marker(
          point: pos,
          width: 56,
          height: 56,
          child: GestureDetector(
            onTap: () => mapController.move(pos, mapController.camera.zoom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.green.shade600,
                  backgroundImage: sp.user.avatarUrl != null ? NetworkImage(sp.user.avatarUrl!) : null,
                  child: sp.user.avatarUrl == null
                      ? Text(sp.user._initials(), style: const TextStyle(fontSize: 10, color: Colors.white))
                      : null,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(sp.user.label ?? '', style: const TextStyle(color: Colors.white, fontSize: 10)),
                )
              ],
            ),
          ),
        ));
      }
    });

    return markers;
  }

}

class _Cluster {
  LatLng center;
  final List<_User> members = [];

  int get count => members.length;

  _Cluster.fromUser(_User u) : center = u.location {
    members.add(u);
  }

  void add(_User u) {
    // simple average to move center
    final oldCenter = center;
    final c = members.length;
    center = LatLng((oldCenter.latitude * c + u.location.latitude) / (c + 1),
        (oldCenter.longitude * c + u.location.longitude) / (c + 1));
    members.add(u);
  }
}

class _User {
  final LatLng location;
  final String? label;
  final String? avatarUrl;

  _User({required this.location, this.label, this.avatarUrl});

  String _initials() {
    if (label == null || label!.isEmpty) return 'U';
    final parts = label!.split(' ');
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

class _Spider {
  final LatLng center;
  final double angle;
  final double radius;
  final _User user;

  _Spider({required this.center, required this.angle, required this.radius, required this.user});
}
