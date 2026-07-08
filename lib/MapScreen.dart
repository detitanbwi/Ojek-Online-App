import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MapScreen extends StatefulWidget {
  final String initialVehicleType; // 'motor' or 'mobil'

  const MapScreen({Key? key, required this.initialVehicleType}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _VehicleOption {
  final String id;
  final String name;
  final String description;
  final String image;
  int price;

  _VehicleOption({
    required this.id,
    required this.name,
    required this.description,
    required this.image,
    required this.price,
  });
}

class _MapScreenState extends State<MapScreen> {
  late String _selectedVehicle; // e.g. 'wiro_ride'
  GoogleMapController? _mapController;
  
  final TextEditingController _pickupController = TextEditingController(text: "Lokasi Saya");
  final TextEditingController _destinationController = TextEditingController(text: "");

  // Default camera position: Jakarta Center
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(-6.2088, 106.8456),
    zoom: 15.0,
  );

  LatLng? _pickupLatLng = const LatLng(-6.2088, 106.8456);
  LatLng? _destinationLatLng;
  double? _distanceKm;
  bool _isSearching = false;
  String _sheetState = 'booking'; // 'booking', 'searching', 'countdown', 'matched'
  int _countdownSeconds = 15;
  Timer? _countdownTimer;
  Timer? _searchSimulationTimer;
  int? _currentOrderId;

  // Matched Driver Details
  String _matchedDriverName = '';
  String _matchedDriverVehicle = '';
  String _matchedDriverPlate = '';
  int _selectedVehiclePrice = 0;
  String _paymentType = 'cash'; // 'cash' or 'qris'

  // Route polyline state
  List<LatLng> _fullRoutePoints = [];
  List<LatLng> _animatedRoutePoints = [];
  Timer? _polylineAnimTimer;

  // Places Autocomplete API Suggestions list
  List<dynamic> _suggestions = [];
  String _activeSearchField = ''; // 'pickup' or 'destination'

  // The Google Maps API Key
  final String _googleMapsApiKey = "AIzaSyCSZMQgc-PQz23FPaxiMCM1CQ-HYTdxMAI";
  final String _backendBaseUrl = "https://ojek.wirodev.com/api";

  // Vehicle choices list (Limited to WiroRide and WiroCar with updated asset paths)
  final List<_VehicleOption> _vehicleOptions = [
    _VehicleOption(
      id: 'wiro_ride',
      name: 'WiroRide',
      description: 'Ojek Motor Cepat (3-5 mnt)',
      image: 'assets/images/wiro_ride.png',
      price: 8000, // Default fallback price
    ),
    _VehicleOption(
      id: 'wiro_car',
      name: 'WiroCar',
      description: 'Mobil Nyaman AC (5-8 mnt)',
      image: 'assets/images/wiro_car.png',
      price: 25000, // Default fallback price
    ),
  ];

  // Local fallback mock database for instant offline suggestions if key fails
  final List<Map<String, dynamic>> _mockPlaces = [
    {
      "description": "Grand Indonesia Mall, Menteng, Jakarta Pusat",
      "lat": -6.1953,
      "lng": 106.8229
    },
    {
      "description": "Sarinah Department Store, Thamrin, Jakarta Pusat",
      "lat": -6.1873,
      "lng": 106.8239
    },
    {
      "description": "Sudirman Central Business District (SCBD), Kebayoran Baru",
      "lat": -6.2244,
      "lng": 106.8098
    },
    {
      "description": "Monumen Nasional (Monas), Gambir, Jakarta Pusat",
      "lat": -6.1754,
      "lng": 106.8272
    },
    {
      "description": "Stasiun Gambir, Jakarta Pusat",
      "lat": -6.1766,
      "lng": 106.8307
    },
    {
      "description": "Bandara Internasional Soekarno-Hatta (CGK), Tangerang",
      "lat": -6.1256,
      "lng": 106.6558
    },
    {
      "description": "Pondok Indah Mall (PIM), Kebayoran Lama, Jakarta Selatan",
      "lat": -6.2655,
      "lng": 106.7828
    },
    {
      "description": "Mall Taman Anggrek, Grogol Petamburan, Jakarta Barat",
      "lat": -6.1785,
      "lng": 106.7922
    },
    {
      "description": "Universitas Jember (UNEJ), Krajan Timur, Jember",
      "lat": -8.1634,
      "lng": 113.7162
    },
    {
      "description": "Bebek Galak 88, Sumbersari, Jember",
      "lat": -8.1712,
      "lng": 113.7222
    },
    {
      "description": "Alun-Alun Jember, Patrang, Jember",
      "lat": -8.1685,
      "lng": 113.7022
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedVehicle = widget.initialVehicleType == 'motor' ? 'wiro_ride' : 'wiro_car';
    _checkAndRestoreActiveOrder();
    // Trigger location permission access and pan immediately on screen startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestLocationAccess();
    });
  }

  void _checkAndRestoreActiveOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final activeId = prefs.getInt('active_order_id');
    if (activeId != null) {
      final oLat = prefs.getDouble('active_order_origin_lat');
      final oLng = prefs.getDouble('active_order_origin_lng');
      if (oLat != null && oLng != null) {
        _pickupLatLng = LatLng(oLat, oLng);
      }
      final dLat = prefs.getDouble('active_order_destination_lat');
      final dLng = prefs.getDouble('active_order_destination_lng');
      if (dLat != null && dLng != null) {
        _destinationLatLng = LatLng(dLat, dLng);
      }

      setState(() {
        _currentOrderId = activeId;
        final status = prefs.getString('active_order_status') ?? 'booking';
        _sheetState = status == 'accepted' ? 'matched' : status;
        _pickupController.text = prefs.getString('active_order_origin') ?? 'Lokasi Saya';
        _destinationController.text = prefs.getString('active_order_destination') ?? '';
        _selectedVehiclePrice = prefs.getInt('active_order_price') ?? 0;
        _distanceKm = prefs.getDouble('active_order_distance');
        _paymentType = prefs.getString('active_order_payment_type') ?? 'cash';
        _matchedDriverName = prefs.getString('active_order_driver_name') ?? '';
        _matchedDriverVehicle = prefs.getString('active_order_driver_vehicle') ?? '';
        _matchedDriverPlate = prefs.getString('active_order_driver_plate') ?? '';
        
        if (_sheetState == 'searching') {
          _searchSimulationTimer = Timer(const Duration(seconds: 4), () {
            if (!mounted) return;
            _startCountdown();
          });
        } else if (_sheetState == 'countdown') {
          _startCountdown();
        }
      });

      if (_pickupLatLng != null && _destinationLatLng != null) {
        _fetchRoutePolyline();
        Future.delayed(const Duration(milliseconds: 600), () {
          _fitBoundsForRoute();
        });
      }
    }
  }

  @override
  void dispose() {
    _polylineAnimTimer?.cancel();
    _countdownTimer?.cancel();
    _searchSimulationTimer?.cancel();
    _pickupController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  // Calculate distance on earth's surface using Haversine formula
  double _calculateHaversineDistance(LatLng p1, LatLng p2) {
    const double earthRadiusKm = 6371.0;
    
    double dLat = _degToRad(p2.latitude - p1.latitude);
    double dLng = _degToRad(p2.longitude - p1.longitude);
    
    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
               math.cos(_degToRad(p1.latitude)) * math.cos(_degToRad(p2.latitude)) *
               math.sin(dLng / 2) * math.sin(dLng / 2);
    
    double c = 2 * math.asin(math.sqrt(a));
    return earthRadiusKm * c;
  }

  double _degToRad(double deg) {
    return deg * (math.pi / 180.0);
  }

  // Request Location Access on Startup and pan immediately
  Future<void> _requestLocationAccess() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Layanan lokasi tidak aktif di perangkat Anda.")),
        );
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Akses lokasi ditolak.")),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Akses lokasi ditolak secara permanen di pengaturan.")),
        );
      }
      return;
    }

    // Get current coordinate and automatically pan to user location
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final userLatLng = LatLng(position.latitude, position.longitude);
      
      if (_currentOrderId != null) {
        // Just pan map to pickup coordinate if active order exists
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_pickupLatLng ?? userLatLng, 16.0),
        );
        return;
      }

      setState(() {
        _pickupLatLng = userLatLng;
        _pickupController.text = "Lokasi Saya";
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(userLatLng, 16.0),
      );

      // Reverse geocode to find actual address name for user location
      try {
        final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1';
        final response = await http.get(Uri.parse(url), headers: {
          'User-Agent': 'WirojekApp/1.0'
        });
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final displayName = data['display_name'] ?? "Lokasi Saya";
          setState(() {
            _pickupController.text = displayName;
          });
        }
      } catch (e) {
        print("Reverse geocode failed: $e");
      }
      
      // Calculate/fetch initial estimates if destination already filled
      _fetchFaresEstimate();
    } catch (e) {
      print("Failed to get current location: $e");
    }
  }

  // Fetch dynamic fares estimates from Laravel WebAPI based on distance
  Future<void> _fetchFaresEstimate() async {
    if (_pickupLatLng == null || _destinationLatLng == null) return;

    double distance = _calculateHaversineDistance(_pickupLatLng!, _destinationLatLng!);

    setState(() {
      _distanceKm = distance;
    });

    try {
      final response = await http.post(
        Uri.parse('$_backendBaseUrl/customer/estimate-fares'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'distance': distance}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List<dynamic> estimates = data['data'];
          setState(() {
            _vehicleOptions.clear();
            for (var est in estimates) {
              _vehicleOptions.add(_VehicleOption(
                id: est['id'],
                name: est['name'],
                description: est['description'],
                image: est['image'],
                price: est['price'],
              ));
            }
          });
          return;
        }
      }
    } catch (e) {
      print("Failed to fetch fares from server: $e");
    }

    // Fallback: local price estimation if API is unreachable
    setState(() {
      // WiroRide
      double wiroRidePrice = 8000;
      if (distance > 2.0) {
        wiroRidePrice += (distance - 2.0) * 2000;
      }
      wiroRidePrice = (wiroRidePrice / 1000).ceil() * 1000;

      // WiroCar
      double wiroCarPrice = 25000;
      if (distance > 2.0) {
        wiroCarPrice += (distance - 2.0) * 4000;
      }
      wiroCarPrice = (wiroCarPrice / 1000).ceil() * 1000;

      _vehicleOptions[0].price = wiroRidePrice.toInt();
      _vehicleOptions[1].price = wiroCarPrice.toInt();
    });
  }

  // Fetch autocomplete suggestions (Places API biased to user + local sorted by Haversine distance)
  Future<void> _fetchSuggestions(String input, String field) async {
    if (input.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _activeSearchField = '';
      });
      return;
    }

    setState(() {
      _activeSearchField = field;
    });

    final LatLng userLocation = _pickupLatLng ?? const LatLng(-6.2088, 106.8456);

    // Initialise results list with "Lokasi Saya" / "My Location" option at the very top
    List<dynamic> results = [];
    results.add({
      "description": "Lokasi Saya",
      "is_my_location": true,
      "lat": userLocation.latitude,
      "lng": userLocation.longitude,
    });

    try {
      // Bias Google Places API to user location (radius 15km, strict bounds)
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(input)}'
        '&key=$_googleMapsApiKey'
        '&components=country:id'
        '&location=${userLocation.latitude},${userLocation.longitude}'
        '&radius=15000'
        '&strictbounds=true'
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['predictions'] != null) {
          results.addAll(data['predictions']);
          setState(() {
            _suggestions = results;
          });
          return;
        }
      }
    } catch (e) {
      print("Google Places API error: $e");
    }

    // Fallback Mock suggestion engine sorted by Haversine distance from user location
    final lowercaseInput = input.toLowerCase();
    
    // Filter and map mock places
    List<Map<String, dynamic>> filteredMocks = _mockPlaces
        .where((place) => place['description'].toString().toLowerCase().contains(lowercaseInput))
        .toList();

    // Sort mock places based on Haversine distance (closest to user first)
    filteredMocks.sort((a, b) {
      LatLng locA = LatLng(a['lat'], a['lng']);
      LatLng locB = LatLng(b['lat'], b['lng']);
      double distA = _calculateHaversineDistance(userLocation, locA);
      double distB = _calculateHaversineDistance(userLocation, locB);
      return distA.compareTo(distB);
    });

    // Add sorted mocks to results list
    for (var mock in filteredMocks) {
      results.add({
        "description": mock['description'],
        "is_mock": true,
        "lat": mock['lat'],
        "lng": mock['lng']
      });
    }

    setState(() {
      _suggestions = results;
    });
  }

  // Select place from suggestion list
  Future<void> _selectSuggestion(dynamic suggestion) async {
    final String description = suggestion['description'];
    LatLng targetLatLng;

    if (suggestion['is_my_location'] == true || suggestion['is_mock'] == true) {
      targetLatLng = LatLng(suggestion['lat'], suggestion['lng']);
    } else {
      // Fetch coordinates via Place Details API for real Google predictions
      try {
        final placeId = suggestion['place_id'];
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=$placeId'
          '&key=$_googleMapsApiKey'
        );
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'OK' && data['result'] != null) {
            final loc = data['result']['geometry']['location'];
            targetLatLng = LatLng(loc['lat'], loc['lng']);
          } else {
            throw Exception("Failed to parse details");
          }
        } else {
          throw Exception("API HTTP error");
        }
      } catch (e) {
        print("Details fetch error: $e");
        // Fallback to center point
        targetLatLng = const LatLng(-6.2088, 106.8456);
      }
    }

    setState(() {
      if (_activeSearchField == 'pickup') {
        _pickupLatLng = targetLatLng;
        _pickupController.text = description;
      } else {
        _destinationLatLng = targetLatLng;
        _destinationController.text = description;
      }
      _suggestions = [];
      _activeSearchField = '';
    });

    // Fetch new fares estimate
    _fetchFaresEstimate();

    // If both points are set, fetch route polyline and fit bounds
    if (_pickupLatLng != null && _destinationLatLng != null) {
      await _fetchRoutePolyline();
      _fitBoundsForRoute();
    } else {
      // Pan map to chosen position
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(targetLatLng, 16.0),
      );
    }
  }

  // Fetch route from Google Directions API and animate polyline
  Future<void> _fetchRoutePolyline() async {
    if (_pickupLatLng == null || _destinationLatLng == null) return;

    // Cancel any existing animation
    _polylineAnimTimer?.cancel();
    setState(() {
      _fullRoutePoints = [];
      _animatedRoutePoints = [];
    });

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${_pickupLatLng!.latitude},${_pickupLatLng!.longitude}'
        '&destination=${_destinationLatLng!.latitude},${_destinationLatLng!.longitude}'
        '&mode=driving'
        '&key=$_googleMapsApiKey'
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['routes'] != null && data['routes'].isNotEmpty) {
          final encodedPolyline = data['routes'][0]['overview_polyline']['points'];
          final points = _decodePolyline(encodedPolyline);

          setState(() {
            _fullRoutePoints = points;
            _animatedRoutePoints = [];
          });

          // Animate polyline point by point
          _animatePolyline();
          return;
        }
      }
    } catch (e) {
      print('Directions API error: $e');
    }

    // Fallback: draw a straight line if Directions API fails
    setState(() {
      _fullRoutePoints = [_pickupLatLng!, _destinationLatLng!];
      _animatedRoutePoints = [];
    });
    _animatePolyline();
  }

  // Animate polyline drawing from A to B
  void _animatePolyline() {
    _polylineAnimTimer?.cancel();
    if (_fullRoutePoints.isEmpty) return;

    int pointIndex = 0;
    // Calculate interval: finish animation in ~1.2 seconds
    final int intervalMs = (_fullRoutePoints.length > 1)
        ? (1200 ~/ _fullRoutePoints.length).clamp(5, 50)
        : 20;

    _polylineAnimTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (pointIndex >= _fullRoutePoints.length) {
        timer.cancel();
        return;
      }
      setState(() {
        _animatedRoutePoints.add(_fullRoutePoints[pointIndex]);
      });
      pointIndex++;
    });
  }

  // Decode Google encoded polyline string to list of LatLng
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  // Fit map camera to show both pickup and destination with padding
  void _fitBoundsForRoute() {
    if (_pickupLatLng == null || _destinationLatLng == null || _mapController == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        math.min(_pickupLatLng!.latitude, _destinationLatLng!.latitude),
        math.min(_pickupLatLng!.longitude, _destinationLatLng!.longitude),
      ),
      northeast: LatLng(
        math.max(_pickupLatLng!.latitude, _destinationLatLng!.latitude),
        math.max(_pickupLatLng!.longitude, _destinationLatLng!.longitude),
      ),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80), // 80px padding
    );
  }

  // Reactive markers builder
  Set<Marker> _getMarkers() {
    final Set<Marker> markers = {};
    if (_pickupLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickupLatLng!,
          infoWindow: InfoWindow(title: 'Titik Jemput', snippet: _pickupController.text),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ),
      );
    }
    if (_destinationLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destinationLatLng!,
          infoWindow: InfoWindow(title: 'Titik Tujuan', snippet: _destinationController.text),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }
    return markers;
  }

  String _formatRupiah(int amount) {
    return 'Rp ' + amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Fullscreen Google Map
          GoogleMap(
            initialCameraPosition: _initialPosition,
            markers: _getMarkers(),
            polylines: _animatedRoutePoints.length >= 2
                ? {
                    Polyline(
                      polylineId: const PolylineId('route'),
                      points: _animatedRoutePoints,
                      color: const Color(0xFFCC5900),
                      width: 5,
                      patterns: [],
                    ),
                  }
                : {},
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
            onMapCreated: (controller) {
              _mapController = controller;
              if (_pickupLatLng != null && _destinationLatLng != null) {
                Future.delayed(const Duration(milliseconds: 150), () {
                  _fitBoundsForRoute();
                });
              }
            },
          ),

          // Floating Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Icon(
                  Icons.arrow_back,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
          ),

          // Right-Side Map Tool Floating Action Button (Only My Location symbol remaining)
          Positioned(
            right: 16,
            bottom: MediaQuery.of(context).size.height * 0.40,
            child: FloatingActionButton(
              heroTag: null,
              onPressed: _requestLocationAccess,
              tooltip: "Dapatkan Lokasi Saya",
              mini: false,
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              foregroundColor: const Color(0xFF002B93),
              child: const Icon(Icons.my_location, size: 24),
            ),
          ),

          // Draggable Scrollable Sheet for Booking Detail Inputs & Options
          DraggableScrollableSheet(
            initialChildSize: 0.38,
            minChildSize: 0.38,
            maxChildSize: 0.85,
            snap: true,
            snapSizes: const [0.38, 0.85],
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 16,
                      offset: const Offset(0, -6),
                    )
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  children: [
                    // Drag Handle
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_sheetState == 'booking') ...[
                      // Pickup & Destination Input Fields
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.circle, color: Color(0xFFCC5900), size: 16),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _pickupController,
                                    onChanged: (val) => _fetchSuggestions(val, 'pickup'),
                                    decoration: const InputDecoration(
                                      hintText: "Cari lokasi jemput...",
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24, thickness: 1),
                            Row(
                              children: [
                                const Icon(Icons.location_on, color: Color(0xFF002B93), size: 18),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _destinationController,
                                    onChanged: (val) => _fetchSuggestions(val, 'destination'),
                                    decoration: const InputDecoration(
                                      hintText: "Masukkan lokasi tujuan...",
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Auto-suggestion suggestions overlay list
                      if (_suggestions.isNotEmpty)
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.grey[50]!,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : Colors.grey[200]!,
                            ),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.all(8),
                            itemCount: _suggestions.length,
                            separatorBuilder: (context, index) => const Divider(height: 8),
                            itemBuilder: (context, index) {
                              final suggestion = _suggestions[index];
                              final text = suggestion['description'];
                              return ListTile(
                                leading: Icon(
                                  suggestion['is_my_location'] == true 
                                      ? Icons.my_location 
                                      : Icons.location_on_outlined, 
                                  color: suggestion['is_my_location'] == true ? Colors.blue : Colors.grey,
                                ),
                                title: Text(
                                  text,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: suggestion['is_my_location'] == true ? FontWeight.bold : FontWeight.normal,
                                    color: suggestion['is_my_location'] == true 
                                        ? Colors.blue 
                                        : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                  ),
                                ),
                                dense: true,
                                onTap: () => _selectSuggestion(suggestion),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Vehicle Selection List (Scrollable list downwards - 2 choices only: WiroRide & WiroCar)
                      ..._vehicleOptions.map((option) {
                        final isSelected = _selectedVehicle == option.id;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedVehicle = option.id;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF15803D).withOpacity(0.08)
                                  : (isDark ? const Color(0xFF1E293B) : Colors.white),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF15803D)
                                    : (isDark ? const Color(0xFF334155) : Colors.grey[200]!),
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Image
                                Image.asset(
                                  option.image,
                                  width: 60,
                                  height: 45,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(width: 16),
                                // Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        option.name,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        option.description,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? Colors.grey[400] : Colors.black54,
                                        ),
                                      ),
                                      if (_distanceKm != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 3),
                                          child: Row(
                                            children: [
                                              Icon(Icons.route, size: 13, color: isDark ? Colors.grey[50] : Colors.grey[600]),
                                              const SizedBox(width: 4),
                                              Text(
                                                '~${_distanceKm!.toStringAsFixed(1)} km',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // Price
                                Text(
                                  _formatRupiah(option.price),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFCC5900), // Orange identity
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),

                      const SizedBox(height: 16),

                      // Confirm Booking Action Button
                      ElevatedButton(
                        onPressed: _isSearching ? null : _placeOrder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFCC5900), // Orange identity
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                        ),
                        child: _isSearching
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                "Pesan Sekarang",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ] else if (_sheetState == 'searching') ...[
                      const SizedBox(height: 16),
                      Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 80,
                              height: 80,
                              child: CircularProgressIndicator(
                                strokeWidth: 5,
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFCC5900)),
                                backgroundColor: const Color(0xFFCC5900).withOpacity(0.15),
                              ),
                            ),
                            Icon(
                              _selectedVehicle == 'wiro_ride' ? Icons.motorcycle : Icons.directions_car,
                              size: 32,
                              color: const Color(0xFFCC5900),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "Mencari Driver Terdekat...",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold, 
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Mengirimkan tawaran perjalanan Anda ke driver di sekitar lokasi penjemputan.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13, 
                          color: isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _cancelOrder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          "Batalkan Pesanan",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ] else if (_sheetState == 'countdown') ...[
                      const SizedBox(height: 16),
                      Text(
                        "Menunggu Konfirmasi Driver...",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold, 
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Tawaran masuk ke hp driver. Menunggu respon konfirmasi...",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13, 
                          color: isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: _countdownSeconds / 15.0,
                          minHeight: 10,
                          backgroundColor: isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFE2E8F0),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Sisa waktu konfirmasi: $_countdownSeconds detik",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF64748B), 
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _cancelOrder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          "Batalkan Pesanan",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ] else if (_sheetState == 'matched') ...[
                      const SizedBox(height: 16),
                      // Alamat Jemput & Tujuan Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.circle, color: Color(0xFFCC5900), size: 14),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _pickupController.text,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white70 : const Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16, thickness: 1),
                            Row(
                              children: [
                                const Icon(Icons.location_on, color: Color(0xFF002B93), size: 16),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _destinationController.text,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white70 : const Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Driver Info Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: const Color(0xFFCC5900).withOpacity(0.2),
                              child: const Icon(Icons.person, color: Color(0xFFCC5900), size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _matchedDriverName,
                                    style: TextStyle(
                                      color: isDark ? Colors.white : const Color(0xFF0F172A), 
                                      fontSize: 16, 
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _matchedDriverVehicle,
                                    style: TextStyle(
                                      color: isDark ? Colors.white.withOpacity(0.7) : const Color(0xFF475569), 
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _matchedDriverPlate,
                                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Price & Payment Method Row Card
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Total Tarif",
                                  style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 11),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatRupiah(_selectedVehiclePrice),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFCC5900),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "Metode Pembayaran",
                                  style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 11),
                                ),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () async {
                                    final nextType = _paymentType == 'qris' ? 'cash' : 'qris';
                                    setState(() {
                                      _paymentType = nextType;
                                    });
                                    final prefs = await SharedPreferences.getInstance();
                                    await prefs.setString('active_order_payment_type', nextType);
                                    
                                    // Update backend payment status
                                    if (_currentOrderId != null) {
                                      try {
                                        await http.post(
                                          Uri.parse('$_backendBaseUrl/driver/order/status'),
                                          headers: {'Content-Type': 'application/json'},
                                          body: jsonEncode({
                                            'order_id': _currentOrderId,
                                            'status': 'accepted',
                                            'payment_type': nextType,
                                          }),
                                        );
                                      } catch (e) {
                                        print("Error updating payment status on backend: $e");
                                      }
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _paymentType == 'qris' ? const Color(0xFF002B93) : const Color(0xFFCC5900),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _paymentType.toUpperCase(),
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.edit, color: Colors.white70, size: 11),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () async {
                          await _cancelOrder();
                          if (mounted) {
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                        ),
                        child: const SizedBox(
                          width: double.infinity,
                          child: Text(
                            "Batalkan Pesanan",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Create order via WebAPI and manage search states in bottom sheet
  Future<void> _placeOrder() async {
    if (_destinationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Silakan masukkan titik tujuan terlebih dahulu."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final chosen = _vehicleOptions.firstWhere((o) => o.id == _selectedVehicle);

    setState(() {
      _selectedVehiclePrice = chosen.price;
      _isSearching = true;
      _sheetState = 'searching';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final customerId = prefs.getInt('customer_id') ?? 1;

      String pickupAddress = _pickupController.text;
      if (pickupAddress == "Lokasi Saya" && _pickupLatLng != null) {
        try {
          final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=${_pickupLatLng!.latitude}&lon=${_pickupLatLng!.longitude}&zoom=18&addressdetails=1';
          final response = await http.get(Uri.parse(url), headers: {'User-Agent': 'WirojekApp/1.0'});
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            pickupAddress = data['display_name'] ?? "Lokasi Saya";
            setState(() {
              _pickupController.text = pickupAddress;
            });
          }
        } catch (e) {
          print("Reverse geocode before order failed: $e");
        }
      }

      // Send real order details to Laravel WebAPI database
      final response = await http.post(
        Uri.parse('$_backendBaseUrl/customer/create-order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'customer_id': customerId,
          'origin': pickupAddress,
          'destination': _destinationController.text,
          'price': chosen.price,
          'payment_type': _paymentType,
          'service_type': _selectedVehicle,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _currentOrderId = data['data']['id'];

          // Save active order details to SharedPreferences for HomeTab dashboard card
          await prefs.setInt('active_order_id', _currentOrderId!);
          await prefs.setString('active_order_origin', pickupAddress);
          await prefs.setString('active_order_destination', _destinationController.text);
          await prefs.setInt('active_order_price', chosen.price);
          await prefs.setString('active_order_status', 'searching');
          await prefs.setDouble('active_order_distance', _distanceKm ?? 0.0);
          await prefs.setString('active_order_payment_type', _paymentType);

          if (_pickupLatLng != null) {
            await prefs.setDouble('active_order_origin_lat', _pickupLatLng!.latitude);
            await prefs.setDouble('active_order_origin_lng', _pickupLatLng!.longitude);
          }
          if (_destinationLatLng != null) {
            await prefs.setDouble('active_order_destination_lat', _destinationLatLng!.latitude);
            await prefs.setDouble('active_order_destination_lng', _destinationLatLng!.longitude);
          }

          // Start search simulation timer (waiting for offer to reach a driver)
          _searchSimulationTimer = Timer(const Duration(seconds: 4), () {
            if (!mounted) return;
            _startCountdown();
          });
          return;
        }
      }
      throw Exception("Server returned non-201 or success false");
    } catch (e) {
      print("Failed to place order via API: $e");
      
      // Fallback search simulation
      _searchSimulationTimer = Timer(const Duration(seconds: 4), () {
        if (!mounted) return;
        _startCountdown();
      });
    }
  }

  void _startCountdown() {
    setState(() {
      _sheetState = 'countdown';
      _countdownSeconds = 15;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_countdownSeconds > 0) {
          _countdownSeconds--;
          // Simulate driver acceptance at second 10
          if (_countdownSeconds == 10) {
            timer.cancel();
            _simulateDriverAcceptance();
          }
        } else {
          timer.cancel();
          _simulateDriverAcceptance();
        }
      });
    });
  }

  void _simulateDriverAcceptance() async {
    _countdownTimer?.cancel();
    
    if (_currentOrderId != null) {
      try {
        await http.post(
          Uri.parse('$_backendBaseUrl/driver/order/status'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'order_id': _currentOrderId,
            'status': 'accepted',
            'payment_type': _paymentType,
          }),
        );
      } catch (e) {
        print("Failed to update status on simulation: $e");
      }
    }

    setState(() {
      _sheetState = 'matched';
      _isSearching = false;
      if (_selectedVehicle == 'wiro_ride') {
        _matchedDriverName = "Budi Santoso";
        _matchedDriverVehicle = "Honda Beat (Hitam)";
        _matchedDriverPlate = "DK 3829 SFG";
      } else {
        _matchedDriverName = "Andi Wijaya";
        _matchedDriverVehicle = "Toyota Avanza (Putih)";
        _matchedDriverPlate = "DK 1982 TXY";
      }
    });

    // Save matched driver info to SharedPreferences for HomeTab dashboard card
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_order_status', 'accepted');
    await prefs.setString('active_order_driver_name', _matchedDriverName);
    await prefs.setString('active_order_driver_vehicle', _matchedDriverVehicle);
    await prefs.setString('active_order_driver_plate', _matchedDriverPlate);
  }

  Future<void> _cancelOrder() async {
    _countdownTimer?.cancel();
    _searchSimulationTimer?.cancel();

    if (_currentOrderId != null) {
      try {
        await http.post(
          Uri.parse('$_backendBaseUrl/customer/orders/$_currentOrderId/cancel'),
        );
      } catch (e) {
        print("Failed to cancel order: $e");
      }
    }

    setState(() {
      _sheetState = 'booking';
      _isSearching = false;
      _currentOrderId = null;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_order_id');
    await prefs.remove('active_order_origin');
    await prefs.remove('active_order_destination');
    await prefs.remove('active_order_price');
    await prefs.remove('active_order_status');
    await prefs.remove('active_order_distance');
    await prefs.remove('active_order_payment_type');
    await prefs.remove('active_order_driver_name');
    await prefs.remove('active_order_driver_vehicle');
    await prefs.remove('active_order_driver_plate');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Pesanan berhasil dibatalkan."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}

