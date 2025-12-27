import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'components/bottom_navigation_bar.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Speed Car',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? _currentPosition;
  String? _errorMessage;
  bool _isLoading = true;
  bool _hasGpsSignal = false;
  final MapController _mapController = MapController();
  Timer? _gpsCheckTimer;
  DateTime? _startTime;
  double _totalDistance = 0.0;
  LatLng? _lastPosition;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _getCurrentLocation(); // Primera carga
    _startGpsCheckTimer(); // Iniciar actualizaciones en segundo plano
  }

  @override
  void dispose() {
    _gpsCheckTimer?.cancel();
    super.dispose();
  }

  void _startGpsCheckTimer() {
    _gpsCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _updateLocationInBackground();
    });
  }

  // Actualización en segundo plano (sin mostrar loading)
  Future<void> _updateLocationInBackground() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _hasGpsSignal = false;
          _errorMessage = 'GPS desactivado';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _hasGpsSignal = false;
          _errorMessage = 'Permiso denegado';
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );

      // Calcular distancia si hay posición anterior
      if (_lastPosition != null) {
        double distanceInMeters = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        _totalDistance += distanceInMeters / 1000; // Convertir a km
      }

      setState(() {
        _lastPosition = _currentPosition;
        _currentPosition = LatLng(position.latitude, position.longitude);
        _hasGpsSignal = true;
        _errorMessage = null;
        _isLoading = false;
      });

      // Mover el mapa suavemente a la nueva posición
      if (_mapController.camera.zoom >= 14) {
        _mapController.move(_currentPosition!, _mapController.camera.zoom);
      }

      print(
        '📍 Ubicación actualizada: ${position.latitude}, ${position.longitude}',
      );
    } catch (e) {
      setState(() {
        _hasGpsSignal = false;
        if (_currentPosition == null) {
          _errorMessage = 'Error al obtener GPS';
          _isLoading = false;
        }
      });
      print('⚠️ Error en actualización: $e');
    }
  }

  // Primera carga (con loading)
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage =
              'El servicio de ubicación está deshabilitado.\nPor favor, actívalo en la configuración del dispositivo.';
          _isLoading = false;
          _hasGpsSignal = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage =
                'Permiso de ubicación denegado.\nPor favor, acepta el permiso para continuar.';
            _isLoading = false;
            _hasGpsSignal = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage =
              'Permiso de ubicación denegado permanentemente.\nHabilítalo manualmente en la configuración de la app.';
          _isLoading = false;
          _hasGpsSignal = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _lastPosition = _currentPosition;
        _isLoading = false;
        _hasGpsSignal = true;
      });

      print(
        '✅ Ubicación inicial obtenida: ${position.latitude}, ${position.longitude}',
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al obtener la ubicación:\n${e.toString()}';
        _isLoading = false;
        _hasGpsSignal = false;
      });
      print('❌ Error: $e');
    }
  }

  void _centerOnLocation() {
    if (_currentPosition != null) {
      _mapController.move(_currentPosition!, 16.0);
    }
  }

  String _getElapsedTime() {
    if (_startTime == null) return '00:00';
    Duration elapsed = DateTime.now().difference(_startTime!);
    int minutes = elapsed.inMinutes;
    int seconds = elapsed.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  void _navigateToUserProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UserProfilePage(),
      ),
    );
  }

  void _navigateToGlobalRoutes() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const GlobalRoutesPage(),
      ),
    );
  }

  void _onPlayPressed() {
    print('Play button pressed');
  }

  Widget _buildBody() {
    // Solo mostrar loading en la primera carga
    if (_isLoading && _currentPosition == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(strokeWidth: 3),
            const SizedBox(height: 20),
            const Text(
              'Obteniendo tu ubicación...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            Text(
              'Esto puede tardar unos segundos',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null && _currentPosition == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off, size: 80, color: Colors.red[300]),
              const SizedBox(height: 24),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _getCurrentLocation,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () async {
                  await Geolocator.openLocationSettings();
                },
                icon: const Icon(Icons.settings),
                label: const Text('Abrir Configuración'),
              ),
            ],
          ),
        ),
      );
    }

    // Mapa con ubicación
    return Stack(
      children: [
        // Mapa en el fondo
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentPosition ?? LatLng(0, 0), // Fallback si _currentPosition es null
            initialZoom: 16.0,
            minZoom: 3.0,
            maxZoom: 18.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.speedcar',
              maxZoom: 19,
            ),
          ],
        ),
        // Indicador de señal GPS centrado horizontalmente en la parte superior
        Positioned(
          top: 40,
          left: MediaQuery.of(context).size.width * 0.1, // 10% de margen a cada lado
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8, // 80% del ancho de la pantalla
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _hasGpsSignal ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _hasGpsSignal ? 'Señal GPS activa' : 'Sin señal GPS',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Menú inferior flotante
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CustomBottomNavigationBar(
              onProfilePressed: _navigateToUserProfile,
              onRoutesPressed: _navigateToGlobalRoutes,
              onPlayPressed: _onPlayPressed,
              onCenterPressed: _centerOnLocation,
              selectedIndex: 0, // Cambiar según sea necesario
            ),
          ),
        ),
      ],
    );
  }
}

class UserProfilePage extends StatelessWidget {
  const UserProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil de Usuario'),
      ),
      body: Center(
        child: Text(
          'Aquí va la información del usuario',
          style: TextStyle(fontSize: 18, color: Colors.grey[800]),
        ),
      ),
    );
  }
}

class GlobalRoutesPage extends StatelessWidget {
  const GlobalRoutesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rutas Globales'),
      ),
      body: Center(
        child: Text(
          'Aquí van las rutas globales',
          style: TextStyle(fontSize: 18, color: Colors.grey[800]),
        ),
      ),
    );
  }
}
