import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'global_routes_page.dart';
import 'package:provider/provider.dart';
import 'user_profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecentDestination {
  final String name;
  final double latitude;
  final double longitude;
  double? distanceFromCurrent;

  RecentDestination({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.distanceFromCurrent,
  });

  Map<String, dynamic> toMap() {
    return {'name': name, 'latitude': latitude, 'longitude': longitude};
  }

  factory RecentDestination.fromMap(Map<String, dynamic> map) {
    return RecentDestination(
      name: map['name'],
      latitude: map['latitude'],
      longitude: map['longitude'],
    );
  }
}

class RouteCalculatorPage extends StatefulWidget {
  const RouteCalculatorPage({super.key});

  @override
  State<RouteCalculatorPage> createState() => _RouteCalculatorPageState();
}

class _RouteCalculatorPageState extends State<RouteCalculatorPage> {
  final _formKey = GlobalKey<FormState>();
  final _destinationController = TextEditingController();
  final _editDestinationController = TextEditingController();
  final MapController _mapController = MapController();
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isLoading = false;
  bool _isLoadingLocation = true;
  bool _isPlaying = false;
  bool _showRecentDestinations = false;
  Map<String, dynamic>? _result;
  List<LatLng>? _routePoints;
  String? _error;
  Position? _currentPosition;
  String? _currentLocationName;

  List<RecentDestination> _recentDestinations = [];
  RecentDestination? _destinationToEdit;

  static const String _recentDestinationsKey = 'recent_destinations';
  static const int _maxRecentDestinations = 5;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _setCurrentLocationAsOrigin();
    _loadRecentDestinations();
  }

  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);

    await _requestNotificationPermission();
  }

  Future<void> _requestNotificationPermission() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }
  }

  Future<void> _showNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'route_channel_id',
      'Ruta Activa',
      channelDescription: 'Notificaciones durante la navegación de ruta',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);
    await _flutterLocalNotificationsPlugin.show(
      0,
      '🚗 Ruta en progreso',
      'La navegación está activa. Presiona para detener.',
      notificationDetails,
    );
  }

  Future<void> _cancelNotification() async {
    await _flutterLocalNotificationsPlugin.cancel(0);
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _editDestinationController.dispose();
    _cancelNotification();
    super.dispose();
  }

  // Guardar destinos recientes en SharedPreferences
  Future<void> _saveRecentDestinations() async {
    final prefs = await SharedPreferences.getInstance();
    final destinationsJson = _recentDestinations
        .map((dest) => json.encode(dest.toMap()))
        .toList();
    await prefs.setStringList(_recentDestinationsKey, destinationsJson);
  }

  // Cargar destinos recientes desde SharedPreferences
  Future<void> _loadRecentDestinations() async {
    final prefs = await SharedPreferences.getInstance();
    final destinationsJson = prefs.getStringList(_recentDestinationsKey) ?? [];

    final destinations = destinationsJson.map((jsonString) {
      final map = json.decode(jsonString) as Map<String, dynamic>;
      return RecentDestination.fromMap(map);
    }).toList();

    setState(() {
      _recentDestinations = destinations;
    });
  }

  // Añadir un nuevo destino a la lista de recientes
  Future<void> _addRecentDestination(
    String name,
    double lat,
    double lon,
  ) async {
    // Verificar si ya existe un destino con el mismo nombre o coordenadas
    final existingIndex = _recentDestinations.indexWhere(
      (dest) =>
          dest.name.toLowerCase() == name.toLowerCase() ||
          (dest.latitude == lat && dest.longitude == lon),
    );

    if (existingIndex != -1) {
      // Mover al principio si ya existe
      final existing = _recentDestinations.removeAt(existingIndex);
      _recentDestinations.insert(0, existing);
    } else {
      // Añadir nuevo destino al principio
      final newDestination = RecentDestination(
        name: name,
        latitude: lat,
        longitude: lon,
      );
      _recentDestinations.insert(0, newDestination);

      // Limitar el número de destinos recientes
      if (_recentDestinations.length > _maxRecentDestinations) {
        _recentDestinations = _recentDestinations.sublist(
          0,
          _maxRecentDestinations,
        );
      }
    }

    await _saveRecentDestinations();
    await _calculateDistancesForRecentDestinations();
  }

  // Eliminar un destino reciente
  Future<void> _removeRecentDestination(int index) async {
    setState(() {
      _recentDestinations.removeAt(index);
    });
    await _saveRecentDestinations();
  }

  // Renombrar un destino reciente
  Future<void> _renameRecentDestination(int index, String newName) async {
    if (newName.trim().isEmpty) return;

    setState(() {
      _recentDestinations[index] = RecentDestination(
        name: newName.trim(),
        latitude: _recentDestinations[index].latitude,
        longitude: _recentDestinations[index].longitude,
        distanceFromCurrent: _recentDestinations[index].distanceFromCurrent,
      );
    });
    await _saveRecentDestinations();
  }

  // Calcular distancias desde la ubicación actual para todos los destinos recientes
  Future<void> _calculateDistancesForRecentDestinations() async {
    if (_currentPosition == null) return;

    const Distance distance = Distance();

    for (int i = 0; i < _recentDestinations.length; i++) {
      final dest = _recentDestinations[i];
      final distanceInMeters = distance(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        LatLng(dest.latitude, dest.longitude),
      );

      _recentDestinations[i] = RecentDestination(
        name: dest.name,
        latitude: dest.latitude,
        longitude: dest.longitude,
        distanceFromCurrent: distanceInMeters / 1000, // Convertir a kilómetros
      );
    }

    setState(() {});
  }

  // Diálogo para editar nombre de destino
  void _showEditDestinationDialog(int index) {
    _editDestinationController.text = _recentDestinations[index].name;
    _destinationToEdit = _recentDestinations[index];

    showDialog(
      context: context,
      builder: (context) {
        final themeNotifier = Provider.of<ThemeNotifier>(context);
        return AlertDialog(
          backgroundColor: themeNotifier.isDarkMode
              ? Colors.grey.shade900
              : Colors.white,
          title: Text(
            'Editar nombre del destino',
            style: TextStyle(
              color: themeNotifier.isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          content: TextField(
            controller: _editDestinationController,
            decoration: InputDecoration(
              hintText: 'Nuevo nombre',
              hintStyle: TextStyle(color: Colors.grey.shade600),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
            style: TextStyle(
              color: themeNotifier.isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _renameRecentDestination(
                  index,
                  _editDestinationController.text,
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Guardar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // Widget para mostrar destinos recientes
  Widget _buildRecentDestinations() {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _showRecentDestinations ? 200 : 0,
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: themeNotifier.isDarkMode
                ? Colors.grey.shade900
                : Colors.grey.shade50,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Destinos recientes',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: themeNotifier.isDarkMode
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showRecentDestinations = false;
                      });
                    },
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_recentDestinations.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No hay destinos recientes',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ..._recentDestinations.asMap().entries.map((entry) {
                  final index = entry.key;
                  final destination = entry.value;
                  return GestureDetector(
                    onTap: () {
                      _destinationController.text = destination.name;
                      _calculateRouteFromDestination(destination);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: themeNotifier.isDarkMode
                            ? Colors.grey.shade800
                            : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: themeNotifier.isDarkMode
                              ? Colors.grey.shade700
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        destination.name,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: themeNotifier.isDarkMode
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () =>
                                          _showEditDestinationDialog(index),
                                      icon: Icon(
                                        Icons.edit,
                                        size: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    IconButton(
                                      onPressed: () =>
                                          _removeRecentDestination(index),
                                      icon: Icon(
                                        Icons.delete,
                                        size: 16,
                                        color: Colors.red.shade600,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                                if (destination.distanceFromCurrent != null)
                                  Text(
                                    '${destination.distanceFromCurrent!.toStringAsFixed(1)} km desde tu ubicación',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Future<String> _getLocationName(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'RouteCalculatorApp/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];

        // Intentar obtener la ubicación más específica disponible
        if (address['road'] != null) {
          return address['road'];
        } else if (address['suburb'] != null) {
          return address['suburb'];
        } else if (address['city'] != null) {
          return address['city'];
        } else if (address['town'] != null) {
          return address['town'];
        } else if (address['village'] != null) {
          return address['village'];
        } else if (address['state'] != null) {
          return address['state'];
        } else if (address['country'] != null) {
          return address['country'];
        }
      }
    } catch (e) {
      print('Error al obtener nombre de ubicación: $e');
    }
    return 'Tu ubicación actual';
  }

  Future<void> _setCurrentLocationAsOrigin() async {
    setState(() {
      _isLoadingLocation = true;
      _error = null;
    });

    try {
      print('Iniciando obtención de ubicación actual...');
      final position = await _getCurrentLocation();
      print(
        'Ubicación obtenida: Latitud ${position.latitude}, Longitud ${position.longitude}',
      );

      // Obtener el nombre de la ubicación
      final locationName = await _getLocationName(
        position.latitude,
        position.longitude,
      );

      setState(() {
        _currentPosition = position;
        _currentLocationName = locationName;
        _isLoadingLocation = false;
      });

      // Calcular distancias para destinos recientes
      await _calculateDistancesForRecentDestinations();
    } catch (e) {
      print('Error al obtener ubicación: $e');
      setState(() {
        _error = 'Error al obtener ubicación: $e';
        _isLoadingLocation = false;
      });
    }
  }

  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('El servicio de ubicación está deshabilitado.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Permiso de ubicación denegado.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permiso de ubicación denegado permanentemente.');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<Map<String, dynamic>> _getCoordinatesFromAddress(
    String address,
  ) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(address)}&format=json&addressdetails=1&limit=1',
    );

    final response = await http.get(
      url,
      headers: {'User-Agent': 'RouteCalculatorApp/1.0'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data != null && data.isNotEmpty) {
        final result = data[0];
        final lat = double.parse(result['lat']);
        final lon = double.parse(result['lon']);
        return {'lat': lat, 'lon': lon};
      } else {
        throw Exception('No se encontraron coordenadas para: $address');
      }
    } else {
      throw Exception('Error al buscar dirección');
    }
  }

  Future<void> _calculateRoute() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentPosition == null) {
      setState(() {
        _error = 'Esperando ubicación actual...';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _result = null;
      _routePoints = null;
    });

    try {
      final destination = await _getCoordinatesFromAddress(
        _destinationController.text,
      );

      // Guardar como destino reciente
      await _addRecentDestination(
        _destinationController.text,
        destination['lat'],
        destination['lon'],
      );

      final lat1 = _currentPosition!.latitude;
      final lon1 = _currentPosition!.longitude;
      final lat2 = destination['lat'];
      final lon2 = destination['lon'];

      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$lon1,$lat1;$lon2,$lat2?overview=full&geometries=geojson',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 'Ok' &&
            data['routes'] != null &&
            data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final durationSeconds = route['duration'] as num;
          final distanceMeters = route['distance'] as num;
          final geometry = route['geometry'];

          final hours = (durationSeconds / 3600).floor();
          final minutes = ((durationSeconds % 3600) / 60).floor();
          final distanceKm = distanceMeters / 1000;
          final avgSpeed = (distanceKm / (durationSeconds / 3600));

          final List<LatLng> points = [];
          if (geometry != null && geometry['coordinates'] != null) {
            for (var coord in geometry['coordinates']) {
              points.add(LatLng(coord[1], coord[0]));
            }
          }

          setState(() {
            _result = {
              'hours': hours,
              'minutes': minutes,
              'distance': distanceKm,
              'avgSpeed': avgSpeed,
            };
            _routePoints = points;
            _isLoading = false;
          });

          if (points.isNotEmpty) {
            _fitBounds(points);
          }
        } else {
          throw Exception(
            'No se pudo calcular la ruta: ${data['message'] ?? "Sin mensaje"}',
          );
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  // Nueva función para calcular ruta desde un destino reciente
  Future<void> _calculateRouteFromDestination(
    RecentDestination destination,
  ) async {
    if (_currentPosition == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _result = null;
      _routePoints = null;
      _showRecentDestinations = false;
    });

    try {
      final lat1 = _currentPosition!.latitude;
      final lon1 = _currentPosition!.longitude;
      final lat2 = destination.latitude;
      final lon2 = destination.longitude;

      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$lon1,$lat1;$lon2,$lat2?overview=full&geometries=geojson',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 'Ok' &&
            data['routes'] != null &&
            data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final durationSeconds = route['duration'] as num;
          final distanceMeters = route['distance'] as num;
          final geometry = route['geometry'];

          final hours = (durationSeconds / 3600).floor();
          final minutes = ((durationSeconds % 3600) / 60).floor();
          final distanceKm = distanceMeters / 1000;
          final avgSpeed = (distanceKm / (durationSeconds / 3600));

          final List<LatLng> points = [];
          if (geometry != null && geometry['coordinates'] != null) {
            for (var coord in geometry['coordinates']) {
              points.add(LatLng(coord[1], coord[0]));
            }
          }

          setState(() {
            _result = {
              'hours': hours,
              'minutes': minutes,
              'distance': distanceKm,
              'avgSpeed': avgSpeed,
            };
            _routePoints = points;
            _isLoading = false;
          });

          if (points.isNotEmpty) {
            _fitBounds(points);
          }
        } else {
          throw Exception(
            'No se pudo calcular la ruta: ${data['message'] ?? "Sin mensaje"}',
          );
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  void _fitBounds(List<LatLng> points) {
    if (points.isEmpty) return;

    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLon = points[0].longitude;
    double maxLon = points[0].longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLon) minLon = point.longitude;
      if (point.longitude > maxLon) maxLon = point.longitude;
    }

    final bounds = LatLngBounds(LatLng(minLat, minLon), LatLng(maxLat, maxLon));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return Scaffold(
      backgroundColor: themeNotifier.isDarkMode ? Colors.black : Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            if (_routePoints == null || _routePoints!.isEmpty)
              Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 60),

                            // Título principal
                            Text(
                              'Planifica tu viaje',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.5,
                                    color: themeNotifier.isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Calcula tiempo y distancia en segundos',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                            const SizedBox(height: 60),

                            // Punto de Origen con diseño mejorado
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: themeNotifier.isDarkMode
                                    ? Colors.grey.shade900
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: themeNotifier.isDarkMode
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade200,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.my_location,
                                          color: Colors.green,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'ORIGEN',
                                              style: TextStyle(
                                                fontSize: 11,
                                                letterSpacing: 1,
                                                color: Colors.grey.shade600,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            if (_isLoadingLocation)
                                              Row(
                                                children: [
                                                  SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                            Color
                                                          >(
                                                            themeNotifier
                                                                    .isDarkMode
                                                                ? Colors.white
                                                                : Colors.black,
                                                          ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                    'Obteniendo ubicación...',
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      color:
                                                          themeNotifier
                                                              .isDarkMode
                                                          ? Colors.white
                                                          : Colors.black,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            else if (_currentPosition != null)
                                              Text(
                                                _currentLocationName ??
                                                    'Tu ubicación actual',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                  color:
                                                      themeNotifier.isDarkMode
                                                      ? Colors.white
                                                      : Colors.black,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Punto de Destino con diseño mejorado
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: themeNotifier.isDarkMode
                                    ? Colors.grey.shade900
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: _showRecentDestinations
                                      ? Radius.zero
                                      : const Radius.circular(16),
                                  bottomRight: _showRecentDestinations
                                      ? Radius.zero
                                      : const Radius.circular(16),
                                ),
                                border: Border.all(
                                  color: themeNotifier.isDarkMode
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade200,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.location_on,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  'DESTINO',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    letterSpacing: 1,
                                                    color: Colors.grey.shade600,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                if (_recentDestinations
                                                    .isNotEmpty)
                                                  IconButton(
                                                    onPressed: () {
                                                      setState(() {
                                                        _showRecentDestinations =
                                                            !_showRecentDestinations;
                                                      });
                                                    },
                                                    icon: Icon(
                                                      _showRecentDestinations
                                                          ? Icons.arrow_drop_up
                                                          : Icons
                                                                .arrow_drop_down,
                                                      color:
                                                          Colors.grey.shade600,
                                                      size: 24,
                                                    ),
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _destinationController,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: themeNotifier.isDarkMode
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                    decoration: InputDecoration(
                                      hintText:
                                          'Ej: Madrid, Barcelona, París...',
                                      hintStyle: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade500,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Por favor, ingresa un destino';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),

                            // Mostrar destinos recientes
                            _buildRecentDestinations(),

                            const SizedBox(height: 32),

                            // Botón Calcular mejorado
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: (_isLoading || _isLoadingLocation)
                                    ? null
                                    : _calculateRoute,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: themeNotifier.isDarkMode
                                      ? Colors.white
                                      : Colors.black,
                                  foregroundColor: themeNotifier.isDarkMode
                                      ? Colors.black
                                      : Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  disabledBackgroundColor: Colors.grey.shade400,
                                ),
                                child: _isLoading
                                    ? SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: themeNotifier.isDarkMode
                                              ? Colors.black
                                              : Colors.white,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.route, size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Calcular ruta',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),

                            // Error mejorado
                            if (_error != null) ...[
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.red.shade700,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              )
            // Mapa ocupando toda la pantalla
            else
              Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _routePoints?.first ?? LatLng(0, 0),
                      initialZoom: 13,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: themeNotifier.isDarkMode
                            ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
                            : 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c', 'd'],
                        userAgentPackageName: 'com.routecalculator.app',
                        retinaMode: RetinaMode.isHighDensity(context),
                      ),
                      if (_routePoints != null && _routePoints!.isNotEmpty) ...[
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _routePoints!,
                              strokeWidth: 4.0,
                              color: Colors.blue,
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _routePoints!.first,
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.my_location,
                                color: Colors.green,
                                size: 40,
                              ),
                            ),
                            Marker(
                              point: _routePoints!.last,
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),

                  // Overlay con información en la parte superior
                  if (_result != null)
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: themeNotifier.isDarkMode
                              ? Colors.black.withOpacity(0.8)
                              : Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_result!['hours']}h ${_result!['minutes']}min',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: themeNotifier.isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                    Text(
                                      'Tiempo estimado',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),

                                // Botones de Play y Pause
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _isPlaying = !_isPlaying;
                                      if (_isPlaying) {
                                        _showNotification();
                                      } else {
                                        _cancelNotification();
                                      }
                                    });
                                  },
                                  icon: Icon(
                                    _isPlaying ? Icons.pause : Icons.play_arrow,
                                    color: themeNotifier.isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),

                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${_result!['distance'].toStringAsFixed(1)} km',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: themeNotifier.isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                    Text(
                                      '${_result!['avgSpeed'].toStringAsFixed(0)} km/h media',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

            // Botón flotante para salir del mapa
            if (_routePoints != null && _routePoints!.isNotEmpty)
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton(
                  onPressed: () {
                    print('Saliendo del mapa y volviendo a la vista principal');
                    setState(() {
                      _routePoints = null;
                      _result = null;
                      _isPlaying = false;
                      _cancelNotification();
                      _showRecentDestinations = false;
                    });
                  },
                  backgroundColor: themeNotifier.isDarkMode
                      ? Colors.white
                      : Colors.black,
                  child: Icon(
                    Icons.close,
                    color: themeNotifier.isDarkMode
                        ? Colors.black
                        : Colors.white,
                  ),
                ),
              ),

            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: themeNotifier.isDarkMode
                        ? Colors.white.withOpacity(0.2)
                        : Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 4.0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const GlobalRoutesPage(),
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.public,
                          color: themeNotifier.isDarkMode
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          Provider.of<ThemeNotifier>(
                            context,
                            listen: false,
                          ).toggleTheme();
                        },
                        icon: Icon(
                          themeNotifier.isDarkMode
                              ? Icons.dark_mode
                              : Icons.light_mode,
                          color: themeNotifier.isDarkMode
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const UserProfilePage(),
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.person,
                          color: themeNotifier.isDarkMode
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ThemeNotifier extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }
}

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeNotifier(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: themeNotifier.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const RouteCalculatorPage(),
    );
  }
}
