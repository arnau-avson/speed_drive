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

class RouteCalculatorPage extends StatefulWidget {
  const RouteCalculatorPage({super.key});

  @override
  State<RouteCalculatorPage> createState() => _RouteCalculatorPageState();
}

class _RouteCalculatorPageState extends State<RouteCalculatorPage> {
  final _formKey = GlobalKey<FormState>();
  final _destinationController = TextEditingController();
  final MapController _mapController = MapController();
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isLoading = false;
  bool _isLoadingLocation = true;
  bool _isPlaying = false;
  Map<String, dynamic>? _result;
  List<LatLng>? _routePoints;
  String? _error;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _setCurrentLocationAsOrigin();
  }

  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Pedir permiso para notificaciones en Android 13+
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
    _cancelNotification();
    super.dispose();
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
      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });
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
              SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 32),
                      Text(
                        'Calculadora de Tiempo de Viaje',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w300,
                              letterSpacing: -0.5,
                            ),
                      ),
                      const SizedBox(height: 48),

                      Text(
                        'PUNTO DE ORIGEN',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 0.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_isLoadingLocation)
                        const Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text('Obteniendo ubicación actual...'),
                          ],
                        )
                      else if (_currentPosition != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.my_location, size: 16),
                                const SizedBox(width: 8),
                                const Text('Tu ubicación actual'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              'Lon: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 32),

                      // Punto de Destino
                      Text(
                        'PUNTO DE DESTINO',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 0.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _destinationController,
                        decoration: const InputDecoration(
                          labelText: 'Ciudad, dirección o lugar',
                          labelStyle: TextStyle(
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                          hintText: 'Ej: Madrid, Barcelona, Torre Eiffel...',
                          border: UnderlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingresa un destino';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),

                      // Botón Calcular
                      SizedBox(
                        width: double.infinity,
                        height: 48,
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
                            shape: const RoundedRectangleBorder(),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: themeNotifier.isDarkMode
                                        ? Colors.black
                                        : Colors.white,
                                  ),
                                )
                              : const Text(
                                  'CALCULAR RUTA',
                                  style: TextStyle(
                                    fontSize: 13,
                                    letterSpacing: 0.5,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                        ),
                      ),

                      // Error
                      if (_error != null) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
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
