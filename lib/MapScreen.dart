import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

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
  bool _isSearching = false;

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
    // Trigger location permission access and pan immediately on screen startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestLocationAccess();
    });
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
      
      setState(() {
        _pickupLatLng = userLatLng;
        _pickupController.text = "Lokasi Saya";
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(userLatLng, 16.0),
      );
      
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
      // Bias Google Places API to user location (radius 20km)
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(input)}'
        '&key=$_googleMapsApiKey'
        '&components=country:id'
        '&location=${userLocation.latitude},${userLocation.longitude}'
        '&radius=20000'
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

    // Pan map to chosen position
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(targetLatLng, 16.0),
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
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
            onMapCreated: (controller) {
              _mapController = controller;
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
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Create order via WebAPI and simulate booking search
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

    setState(() {
      _isSearching = true;
    });

    final chosen = _vehicleOptions.firstWhere((o) => o.id == _selectedVehicle);

    try {
      // Send real order details to Laravel WebAPI database
      final response = await http.post(
        Uri.parse('$_backendBaseUrl/customer/create-order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'customer_id': 1, // Default customer ID
          'origin': _pickupController.text,
          'destination': _destinationController.text,
          'price': chosen.price,
          'payment_type': 'cash',
          'service_type': _selectedVehicle,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // Success: simulate driver search
          Future.delayed(const Duration(seconds: 3), () {
            if (!mounted) return;
            setState(() {
              _isSearching = false;
            });

            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                title: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFF15803D), size: 28),
                    SizedBox(width: 8),
                    Text("Driver Ditemukan!"),
                  ],
                ),
                content: Text(
                  "Driver Anda sedang menuju ke lokasi penjemputan dengan ${chosen.name}.\n\nEstimasi waktu tiba: 3 Menit.",
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context); // Go back to Home
                    },
                    child: const Text("OK", style: TextStyle(color: Color(0xFFCC5900), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          });
          return;
        }
      }
      throw Exception("Server returned non-201 or success false");
    } catch (e) {
      print("Failed to place order via API: $e");
      // Fallback: search simulation
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() {
          _isSearching = false;
        });

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF15803D), size: 28),
                SizedBox(width: 8),
                Text("Driver Ditemukan! (Offline)"),
              ],
            ),
            content: Text(
              "Driver Anda sedang menuju ke lokasi penjemputan dengan ${chosen.name}.\n\nEstimasi waktu tiba: 3 Menit.",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text("OK", style: TextStyle(color: Color(0xFFCC5900), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      });
    }
  }
}
