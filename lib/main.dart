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
import 'components/main/recent_destinations.dart';
import 'components/main/map_picker.dart';
import 'dart:async';

class RouteOption {
  final String id;
  final String name;
  final double distance; // en km
  final double duration; // en minutos
  final List<LatLng> points;
  final bool hasToll;
  final double estimatedCost;
  final String difficulty;
  final String description;

  RouteOption({
    required this.id,
    required this.name,
    required this.distance,
    required this.duration,
    required this.points,
    required this.hasToll,
    this.estimatedCost = 0.0,
    this.difficulty = 'Media',
    this.description = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'distance': distance,
      'duration': duration,
      'hasToll': hasToll,
      'estimatedCost': estimatedCost,
      'difficulty': difficulty,
      'description': description,
    };
  }

  factory RouteOption.fromMap(Map<String, dynamic> map, List<LatLng> points) {
    return RouteOption(
      id: map['id'] ?? UniqueKey().toString(),
      name: map['name'] ?? 'Ruta',
      distance: (map['distance'] ?? 0).toDouble(),
      duration: (map['duration'] ?? 0).toDouble(),
      points: points,
      hasToll: map['hasToll'] ?? false,
      estimatedCost: (map['estimatedCost'] ?? 0).toDouble(),
      difficulty: map['difficulty'] ?? 'Media',
      description: map['description'] ?? '',
    );
  }
}

class RecentDestination {
  final String name;
  final double latitude;
  final double longitude;
  double? distanceFromCurrent;
  final String? address;

  RecentDestination({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.distanceFromCurrent,
    this.address,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
    };
  }

  factory RecentDestination.fromMap(Map<String, dynamic> map) {
    return RecentDestination(
      name: map['name'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      address: map['address'],
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
  String? _error;
  Position? _currentPosition;
  String? _currentLocationName;

  List<RecentDestination> _recentDestinations = [];
  RecentDestination? _destinationToEdit;

  List<RouteOption> _routeOptions = [];
  RouteOption? _selectedRoute;
  bool _showRouteOptions = false;

  static const String _recentDestinationsKey = 'recent_destinations';
  static const int _maxRecentDestinations = 5;

  // Variables para el cronómetro
  bool _isStopwatchRunning = false;
  Duration _elapsedTime = Duration.zero;
  Timer? _stopwatchTimer;
  DateTime? _stopwatchStartTime;

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
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (notificationResponse) {
        // Manejar clic en notificación
        if (notificationResponse.payload == 'start_stopwatch') {
          _startStopwatchFromNotification();
        } else if (notificationResponse.payload == 'stop_stopwatch') {
          _stopStopwatchFromNotification();
        }
      },
    );

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

  Future<void> _showRouteNotification() async {
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

  Future<void> _cancelRouteNotification() async {
    await _flutterLocalNotificationsPlugin.cancel(0);
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _editDestinationController.dispose();
    _cancelRouteNotification();
    _stopStopwatch();
    super.dispose();
  }

  Future<void> _saveRecentDestinations() async {
    final prefs = await SharedPreferences.getInstance();
    final destinationsJson = _recentDestinations
        .map((dest) => json.encode(dest.toMap()))
        .toList();
    await prefs.setStringList(_recentDestinationsKey, destinationsJson);
  }

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

  Future<void> _addRecentDestination(
    String name,
    double lat,
    double lon,
  ) async {
    final existingIndex = _recentDestinations.indexWhere(
      (dest) =>
          dest.name.toLowerCase() == name.toLowerCase() ||
          (dest.latitude == lat && dest.longitude == lon),
    );

    if (existingIndex != -1) {
      final existing = _recentDestinations.removeAt(existingIndex);
      _recentDestinations.insert(0, existing);
    } else {
      final newDestination = RecentDestination(
        name: name,
        latitude: lat,
        longitude: lon,
      );
      _recentDestinations.insert(0, newDestination);

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

  Future<void> _removeRecentDestination(int index) async {
    setState(() {
      _recentDestinations.removeAt(index);
    });
    await _saveRecentDestinations();
  }

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
        distanceFromCurrent: distanceInMeters / 1000,
      );
    }

    setState(() {});
  }

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

  Widget _buildRecentDestinations() {
    return RecentDestinations(
      showRecentDestinations: _showRecentDestinations,
      recentDestinations: _recentDestinations,
      onRemove: (index) {
        if (index == -1) {
          setState(() {
            _showRecentDestinations = false;
          });
        } else {
          _removeRecentDestination(index);
        }
      },
      onRename: (index, name) => _showEditDestinationDialog(index),
      onSelect: (destination) {
        _destinationController.text = destination.name;
        _calculateRouteFromDestination(destination);
      },
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

      final locationName = await _getLocationName(
        position.latitude,
        position.longitude,
      );

      setState(() {
        _currentPosition = position;
        _currentLocationName = locationName;
        _isLoadingLocation = false;
      });

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

  Future<List<RouteOption>> _getMultipleRoutes(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$lon1,$lat1;$lon2,$lat2?overview=full&geometries=geojson&alternatives=3',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 'Ok' &&
            data['routes'] != null &&
            data['routes'].isNotEmpty) {
          final List<RouteOption> routes = [];

          for (int i = 0; i < data['routes'].length; i++) {
            final route = data['routes'][i];
            final durationSeconds = route['duration'] as num;
            final distanceMeters = route['distance'] as num;
            final geometry = route['geometry'];

            final List<LatLng> points = [];
            if (geometry != null && geometry['coordinates'] != null) {
              for (var coord in geometry['coordinates']) {
                points.add(LatLng(coord[1], coord[0]));
              }
            }

            final distanceKm = distanceMeters / 1000;
            final durationMinutes = (durationSeconds / 60).roundToDouble();

            final hasToll = i == 0 ? false : (i % 2 == 0);
            final estimatedCost = hasToll
                ? (distanceKm * 0.05).roundToDouble()
                : 0.0;

            final routeName = _generateRouteName(
              i,
              distanceKm,
              durationMinutes,
              hasToll,
            );

            final routeOption = RouteOption(
              id: 'route_$i',
              name: routeName,
              distance: distanceKm,
              duration: durationMinutes,
              points: points,
              hasToll: hasToll,
              estimatedCost: estimatedCost,
              difficulty: i == 0 ? 'Fácil' : (i == 1 ? 'Media' : 'Difícil'),
              description: hasToll
                  ? 'Ruta con peaje - Coste estimado: ${estimatedCost.toStringAsFixed(2)}€'
                  : 'Ruta sin peaje',
            );

            routes.add(routeOption);
          }

          return routes;
        } else {
          throw Exception('No se pudo calcular las rutas');
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('Error al obtener rutas múltiples: $e');
      rethrow;
    }
  }

  String _generateRouteName(
    int index,
    double distance,
    double duration,
    bool hasToll,
  ) {
    final List<String> routeTypes = [
      'Más rápida',
      'Más corta',
      'Escénica',
      'Equilibrada',
    ];
    final List<String> descriptors = [
      'Directa',
      'Alternativa',
      'Panorámica',
      'Económica',
    ];

    final type = index < routeTypes.length
        ? routeTypes[index]
        : 'Alternativa ${index + 1}';
    final descriptor = index < descriptors.length
        ? descriptors[index]
        : 'Ruta ${index + 1}';
    final tollIndicator = hasToll ? ' (con peaje)' : ' (sin peaje)';

    return '$type - $descriptor$tollIndicator';
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
      _routeOptions.clear();
      _selectedRoute = null;
      _showRouteOptions = false;
    });

    try {
      final destination = await _getCoordinatesFromAddress(
        _destinationController.text,
      );

      await _addRecentDestination(
        _destinationController.text,
        destination['lat'],
        destination['lon'],
      );

      final routes = await _getMultipleRoutes(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        destination['lat'],
        destination['lon'],
      );

      setState(() {
        _routeOptions = routes;
        _isLoading = false;
        _showRouteOptions = true;

        if (routes.isNotEmpty) {
          _selectedRoute = routes[0];
          if (routes[0].points.isNotEmpty) {
            _fitBounds(routes[0].points);
          }
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _calculateRouteFromDestination(
    RecentDestination destination,
  ) async {
    if (_currentPosition == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _routeOptions.clear();
      _selectedRoute = null;
      _showRouteOptions = false;
      _showRecentDestinations = false;
    });

    try {
      final routes = await _getMultipleRoutes(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        destination.latitude,
        destination.longitude,
      );

      setState(() {
        _routeOptions = routes;
        _isLoading = false;
        _showRouteOptions = true;

        if (routes.isNotEmpty) {
          _selectedRoute = routes[0];
          if (routes[0].points.isNotEmpty) {
            _fitBounds(routes[0].points);
          }
        }
      });
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

  Widget _buildRouteOptionCard(RouteOption route, bool isSelected) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRoute = route;
          _fitBounds(route.points);
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: themeNotifier.isDarkMode
              ? isSelected
                    ? Colors.blue.withOpacity(0.2)
                    : Colors.grey.shade900
              : isSelected
              ? Colors.blue.withOpacity(0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.blue
                : themeNotifier.isDarkMode
                ? Colors.grey.shade800
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            color: isSelected ? Colors.blue : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              route.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: themeNotifier.isDarkMode
                                    ? Colors.white
                                    : Colors.black,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        route.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: themeNotifier.isDarkMode
                              ? Colors.white.withOpacity(0.7)
                              : Colors.black.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                if (route.hasToll)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.attach_money,
                          size: 12,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${route.estimatedCost.toStringAsFixed(2)}€',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoItem(
                  Icons.schedule,
                  '${route.duration.toStringAsFixed(0)} min',
                  themeNotifier,
                ),
                _buildInfoItem(
                  Icons.straighten,
                  '${route.distance.toStringAsFixed(1)} km',
                  themeNotifier,
                ),
                _buildInfoItem(Icons.terrain, route.difficulty, themeNotifier),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(
    IconData icon,
    String text,
    ThemeNotifier themeNotifier,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: themeNotifier.isDarkMode
              ? Colors.white.withOpacity(0.6)
              : Colors.black.withOpacity(0.5),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: themeNotifier.isDarkMode
                ? Colors.white.withOpacity(0.7)
                : Colors.black.withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // FUNCIONES PARA EL CRONÓMETRO
  void _startStopwatch() {
    if (_isStopwatchRunning) return;

    setState(() {
      _isStopwatchRunning = true;
      _stopwatchStartTime = DateTime.now().subtract(_elapsedTime);
    });

    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedTime = DateTime.now().difference(_stopwatchStartTime!);
      });
    });

    // Mostrar notificación para poder detener el cronómetro desde fuera de la app
    const androidDetails = AndroidNotificationDetails(
      'stopwatch_channel',
      'Cronómetro',
      channelDescription: 'Cronómetro en segundo plano',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: false,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    _flutterLocalNotificationsPlugin.show(
      1,
      '⏱️ Cronómetro en marcha',
      'Pulsa para detener',
      notificationDetails,
      payload: 'stop_stopwatch',
    );
  }

  void _stopStopwatch() {
    if (!_isStopwatchRunning) return;

    _stopwatchTimer?.cancel();
    _stopwatchTimer = null;

    setState(() {
      _isStopwatchRunning = false;
    });

    // Cancelar la notificación
    _flutterLocalNotificationsPlugin.cancel(1);

    // Mostrar notificación de tiempo final
    const androidDetails = AndroidNotificationDetails(
      'stopwatch_channel',
      'Cronómetro',
      channelDescription: 'Cronómetro en segundo plano',
      importance: Importance.high,
      priority: Priority.high,
      autoCancel: true,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    final hours = _elapsedTime.inHours;
    final minutes = _elapsedTime.inMinutes.remainder(60);
    final seconds = _elapsedTime.inSeconds.remainder(60);

    _flutterLocalNotificationsPlugin.show(
      2,
      '⏱️ Cronómetro detenido',
      'Tiempo: ${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
      notificationDetails,
    );
  }

  void _resetStopwatch() {
    _stopStopwatch();
    setState(() {
      _elapsedTime = Duration.zero;
    });
  }

  void _startStopwatchFromNotification() {
    if (!_isStopwatchRunning) {
      _startStopwatch();
    }
  }

  void _stopStopwatchFromNotification() {
    if (_isStopwatchRunning) {
      _stopStopwatch();
    }
  }

  Widget _buildStopwatchDisplay() {
    final hours = _elapsedTime.inHours;
    final minutes = _elapsedTime.inMinutes.remainder(60);
    final seconds = _elapsedTime.inSeconds.remainder(60);

    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return Positioned(
      top: _selectedRoute != null ? 180 : 100,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cronómetro',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: themeNotifier.isDarkMode
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isStopwatchRunning ? 'En marcha' : 'Detenido',
                          style: TextStyle(
                            fontSize: 13,
                            color: themeNotifier.isDarkMode
                                ? Colors.white.withOpacity(0.7)
                                : Colors.black.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.timer,
                    color: _isStopwatchRunning ? Colors.green : Colors.grey,
                    size: 30,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: themeNotifier.isDarkMode
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton(
                    onPressed: _isStopwatchRunning ? null : _startStopwatch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      disabledBackgroundColor: Colors.green.withOpacity(0.3),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow, size: 20),
                        SizedBox(width: 8),
                        Text('Iniciar'),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _isStopwatchRunning ? _stopStopwatch : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      disabledBackgroundColor: Colors.red.withOpacity(0.3),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.stop, size: 20),
                        SizedBox(width: 8),
                        Text('Detener'),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _resetStopwatch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.replay, size: 20),
                        SizedBox(width: 8),
                        Text('Reiniciar'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStartStopwatchButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          if (_isStopwatchRunning) {
            _stopStopwatch();
          } else {
            _startStopwatch();
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: _isStopwatchRunning ? Colors.red : Colors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_isStopwatchRunning ? Icons.stop : Icons.play_arrow, size: 20),
            const SizedBox(width: 8),
            Text(
              _isStopwatchRunning ? 'Detener Cronómetro' : 'Iniciar Cronómetro',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return Scaffold(
      backgroundColor: themeNotifier.isDarkMode ? Colors.black : Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            if (_routeOptions.isEmpty || !_showRouteOptions)
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
                            const SizedBox(height: 60),

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
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
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
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'Por favor, ingresa un destino';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.map),
                                        onPressed: () async {
                                          final LatLng?
                                          pickedLocation = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => MapPicker(
                                                onLocationPicked:
                                                    (location, address) {
                                                      _destinationController
                                                              .text =
                                                          address;
                                                    },
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            _buildRecentDestinations(),

                            const SizedBox(height: 32),

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
                                            'Calcular rutas',
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

                            const SizedBox(height: 16),
                            _buildStartStopwatchButton(),

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
            else
              Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter:
                          _selectedRoute?.points.first ?? LatLng(0, 0),
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
                      if (_selectedRoute != null &&
                          _selectedRoute!.points.isNotEmpty) ...[
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _selectedRoute!.points,
                              strokeWidth: 4.0,
                              color: Colors.blue,
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _selectedRoute!.points.first,
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.my_location,
                                color: Colors.green,
                                size: 40,
                              ),
                            ),
                            Marker(
                              point: _selectedRoute!.points.last,
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

                  // Overlay con información de la ruta seleccionada
                  if (_selectedRoute != null && !_showRouteOptions)
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
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedRoute!.name,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: themeNotifier.isDarkMode
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _selectedRoute!.description,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: themeNotifier.isDarkMode
                                              ? Colors.white.withOpacity(0.7)
                                              : Colors.black.withOpacity(0.6),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _showRouteOptions = true;
                                    });
                                  },
                                  icon: Icon(
                                    Icons.swap_horiz,
                                    color: themeNotifier.isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildRouteInfo(
                                  Icons.schedule,
                                  '${_selectedRoute!.duration.toStringAsFixed(0)} min',
                                  themeNotifier,
                                ),
                                _buildRouteInfo(
                                  Icons.straighten,
                                  '${_selectedRoute!.distance.toStringAsFixed(1)} km',
                                  themeNotifier,
                                ),
                                _buildRouteInfo(
                                  Icons.terrain,
                                  _selectedRoute!.difficulty,
                                  themeNotifier,
                                ),
                                if (_selectedRoute!.hasToll)
                                  _buildRouteInfo(
                                    Icons.attach_money,
                                    '${_selectedRoute!.estimatedCost.toStringAsFixed(2)}€',
                                    themeNotifier,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _isPlaying = !_isPlaying;
                                      if (_isPlaying) {
                                        _showRouteNotification();
                                      } else {
                                        _cancelRouteNotification();
                                      }
                                    });
                                  },
                                  icon: Icon(
                                    _isPlaying ? Icons.pause : Icons.play_arrow,
                                    color: Colors.blue,
                                    size: 30,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

            // Panel de selección de rutas
            if (_showRouteOptions && _routeOptions.isNotEmpty)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: RouteOptionsPanel(
                  routeOptions: _routeOptions,
                  selectedRoute: _selectedRoute,
                  isDarkMode: themeNotifier.isDarkMode,
                  onRouteSelected: (route) {
                    setState(() {
                      _selectedRoute = route;
                      _fitBounds(route.points);
                    });
                  },
                  onConfirm: () {
                    setState(() {
                      _showRouteOptions = false;
                    });
                  },
                  onBack: () {
                    setState(() {
                      _showRouteOptions = false;
                    });
                  },
                ),
              ),

            // Botón flotante para salir del mapa
            if (_selectedRoute != null && !_showRouteOptions)
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton(
                  onPressed: () {
                    setState(() {
                      _routeOptions.clear();
                      _selectedRoute = null;
                      _showRouteOptions = false;
                      _isPlaying = false;
                      _cancelRouteNotification();
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

            // Botón para ver todas las rutas cuando hay una seleccionada
            if (_selectedRoute != null && !_showRouteOptions)
              Positioned(
                bottom: 80,
                right: 16,
                child: FloatingActionButton(
                  onPressed: () {
                    setState(() {
                      _showRouteOptions = true;
                    });
                  },
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.compare_arrows, color: Colors.white),
                ),
              ),

            // MOSTRAR EL CRONÓMETRO SI ESTÁ EN MARCHA
            if (_isStopwatchRunning) _buildStopwatchDisplay(),

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

  Widget _buildRouteInfo(
    IconData icon,
    String text,
    ThemeNotifier themeNotifier,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: themeNotifier.isDarkMode
              ? Colors.white.withOpacity(0.8)
              : Colors.black.withOpacity(0.7),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: themeNotifier.isDarkMode
                ? Colors.white.withOpacity(0.8)
                : Colors.black.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}

class RouteOptionsPanel extends StatelessWidget {
  final List<RouteOption> routeOptions;
  final RouteOption? selectedRoute;
  final bool isDarkMode;
  final Function(RouteOption) onRouteSelected;
  final VoidCallback onConfirm;
  final VoidCallback onBack;

  const RouteOptionsPanel({
    Key? key,
    required this.routeOptions,
    required this.selectedRoute,
    required this.isDarkMode,
    required this.onRouteSelected,
    required this.onConfirm,
    required this.onBack,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 350,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade900 : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                onPressed: onBack,
              ),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.3)
                      : Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Selecciona una ruta',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              Text(
                '${routeOptions.length} opciones',
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.6)
                      : Colors.black.withOpacity(0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Toca una ruta para verla en el mapa',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.5)
                  : Colors.black.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: routeOptions.length,
              itemBuilder: (context, index) {
                final route = routeOptions[index];
                return GestureDetector(
                  onTap: () => onRouteSelected(route),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? selectedRoute?.id == route.id
                                ? Colors.blue.withOpacity(0.2)
                                : Colors.grey.shade900
                          : selectedRoute?.id == route.id
                          ? Colors.blue.withOpacity(0.1)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selectedRoute?.id == route.id
                            ? Colors.blue
                            : isDarkMode
                            ? Colors.grey.shade800
                            : Colors.grey.shade300,
                        width: selectedRoute?.id == route.id ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    route.name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    route.description,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDarkMode
                                          ? Colors.white.withOpacity(0.6)
                                          : Colors.black.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (route.hasToll)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Peaje',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildInfoItem(
                              Icons.schedule,
                              '${route.duration.toStringAsFixed(0)} min',
                              isDarkMode,
                            ),
                            _buildInfoItem(
                              Icons.straighten,
                              '${route.distance.toStringAsFixed(1)} km',
                              isDarkMode,
                            ),
                            _buildInfoItem(
                              Icons.terrain,
                              route.difficulty,
                              isDarkMode,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Confirmar ruta seleccionada',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text, bool isDarkMode) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isDarkMode
              ? Colors.white.withOpacity(0.6)
              : Colors.black.withOpacity(0.5),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: isDarkMode
                ? Colors.white.withOpacity(0.7)
                : Colors.black.withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
