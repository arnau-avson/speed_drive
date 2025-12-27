import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class GlobalRoutesPage extends StatefulWidget {
  const GlobalRoutesPage({super.key});

  @override
  State<GlobalRoutesPage> createState() => _GlobalRoutesPageState();
}

class _GlobalRoutesPageState extends State<GlobalRoutesPage> {
  LatLng? _currentUserPosition;

  @override
  void initState() {
    super.initState();
    _getCurrentUserLocation();
  }

  Future<void> _getCurrentUserLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      setState(() {
        _currentUserPosition = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      print('Error obteniendo ubicación: $e');
    }
  }

  // Datos de ejemplo de rutas de usuarios
  final List<UserRoute> _userRoutes = [
    UserRoute(
      userName: 'Carlos Martínez',
      userAvatar: 'CM',
      routeName: 'Ruta Costera Matinal',
      distance: 18.5,
      duration: '1:15:30',
      avgSpeed: 14.7,
      maxSpeed: 32.5,
      difficulty: 'Media',
      startPoint: LatLng(41.3851, 2.1734), // Barcelona
      routePoints: [
        LatLng(41.3851, 2.1734),
        LatLng(41.3900, 2.1800),
        LatLng(41.3950, 2.1850),
        LatLng(41.4000, 2.1900),
        LatLng(41.4050, 2.1950),
      ],
      likes: 45,
      date: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    UserRoute(
      userName: 'Ana López',
      userAvatar: 'AL',
      routeName: 'Circuito Urbano Centro',
      distance: 12.3,
      duration: '52:15',
      avgSpeed: 14.1,
      maxSpeed: 28.0,
      difficulty: 'Fácil',
      startPoint: LatLng(41.3900, 2.1600),
      routePoints: [
        LatLng(41.3900, 2.1600),
        LatLng(41.3920, 2.1650),
        LatLng(41.3940, 2.1700),
        LatLng(41.3960, 2.1750),
        LatLng(41.3980, 2.1700),
      ],
      likes: 32,
      date: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    UserRoute(
      userName: 'Miguel Fernández',
      userAvatar: 'MF',
      routeName: 'Desafío Montaña',
      distance: 35.7,
      duration: '2:45:00',
      avgSpeed: 12.9,
      maxSpeed: 48.3,
      difficulty: 'Difícil',
      startPoint: LatLng(41.4200, 2.1500),
      routePoints: [
        LatLng(41.4200, 2.1500),
        LatLng(41.4300, 2.1550),
        LatLng(41.4400, 2.1600),
        LatLng(41.4500, 2.1650),
        LatLng(41.4600, 2.1700),
      ],
      likes: 89,
      date: DateTime.now().subtract(const Duration(days: 1)),
    ),
    UserRoute(
      userName: 'Laura Sánchez',
      userAvatar: 'LS',
      routeName: 'Paseo Nocturno',
      distance: 8.9,
      duration: '38:20',
      avgSpeed: 13.9,
      maxSpeed: 25.5,
      difficulty: 'Fácil',
      startPoint: LatLng(41.3750, 2.1650),
      routePoints: [
        LatLng(41.3750, 2.1650),
        LatLng(41.3780, 2.1680),
        LatLng(41.3810, 2.1710),
        LatLng(41.3840, 2.1740),
        LatLng(41.3870, 2.1770),
      ],
      likes: 28,
      date: DateTime.now().subtract(const Duration(hours: 12)),
    ),
  ];

  double _calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
          point1.latitude,
          point1.longitude,
          point2.latitude,
          point2.longitude,
        ) /
        1000; // Convertir a km
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Rutas Globales',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,

      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar rutas o usuarios...',
                  prefixIcon: const Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
          // Lista de rutas
          Expanded(
            child: _currentUserPosition == null
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _userRoutes.length,
                    itemBuilder: (context, index) {
                      final route = _userRoutes[index];
                      final distanceFromUser = _calculateDistance(
                        _currentUserPosition!,
                        route.startPoint,
                      );
                      return _buildRouteCard(route, distanceFromUser);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard(UserRoute route, double distanceFromUser) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado con info del usuario
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar del usuario
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.blue,
                  child: Text(
                    route.userAvatar,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Nombre y tiempo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getTimeAgo(route.date),
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                // Likes
                Row(
                  children: [
                    const Icon(Icons.thumb_up, color: Colors.blue, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      '${route.likes}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Mapa interactivo de la ruta
          Container(
            height: 200,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: route.startPoint,
                  initialZoom: 13.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.speedcar',
                  ),
                  // Línea de la ruta
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: route.routePoints,
                        strokeWidth: 4.0,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                  // Marcador de inicio
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: route.routePoints.first,
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Icon(
                            Icons.flag,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      // Marcador de fin
                      Marker(
                        point: route.routePoints.last,
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Icon(
                            Icons.flag_circle,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Información de la ruta
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nombre de la ruta y distancia desde tu ubicación
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        route.routeName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _getDifficultyColor(route.difficulty),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        route.difficulty,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Distancia desde tu ubicación
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 4),
                    Text(
                      'A ${distanceFromUser.toStringAsFixed(1)} km del inicio de la ruta',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Estadísticas
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat(
                      Icons.straighten,
                      '${route.distance} km',
                      'Distancia',
                    ),
                    _buildStat(Icons.timer, route.duration, 'Duración'),
                    _buildStat(
                      Icons.speed,
                      '${route.avgSpeed} km/h',
                      'Vel. Media',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Botones de acción
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _showRouteDetails(route, distanceFromUser);
                        },
                        icon: const Icon(Icons.info_outline, size: 18),
                        label: const Text('Detalles'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: const BorderSide(color: Colors.blue),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.blue[700]),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'Fácil':
        return Colors.green;
      case 'Media':
        return Colors.orange;
      case 'Difícil':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getTimeAgo(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inHours < 1) {
      return 'Hace ${difference.inMinutes} minutos';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours} horas';
    } else {
      return 'Hace ${difference.inDays} días';
    }
  }

  void _showRouteDetails(UserRoute route, double distanceFromUser) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.blue,
                    child: Text(
                      route.userAvatar,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          route.userName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _getTimeAgo(route.date),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                route.routeName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, size: 18, color: Colors.blue[700]),
                  const SizedBox(width: 4),
                  Text(
                    'A ${distanceFromUser.toStringAsFixed(1)} km del inicio',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Mapa más grande
              Container(
                height: 250,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: route.startPoint,
                      initialZoom: 12.5,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.speedcar',
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: route.routePoints,
                            strokeWidth: 5.0,
                            color: Colors.blue,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: route.routePoints.first,
                            width: 50,
                            height: 50,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                              child: const Icon(
                                Icons.flag,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                          Marker(
                            point: route.routePoints.last,
                            width: 50,
                            height: 50,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                              child: const Icon(
                                Icons.flag_circle,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildDetailRow(
                'Distancia total',
                '${route.distance} km',
                Icons.straighten,
              ),
              _buildDetailRow('Duración', route.duration, Icons.timer),
              _buildDetailRow(
                'Velocidad promedio',
                '${route.avgSpeed} km/h',
                Icons.speed,
              ),
              _buildDetailRow(
                'Velocidad máxima',
                '${route.maxSpeed} km/h',
                Icons.flash_on,
              ),
              _buildDetailRow('Dificultad', route.difficulty, Icons.terrain),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _startRoute(route);
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Iniciar esta Ruta'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Colors.blue),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _startRoute(UserRoute route) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Iniciando ruta: ${route.routeName}'),
        action: SnackBarAction(label: 'Ver', onPressed: () {}),
      ),
    );
  }
}

// Modelo de datos para rutas de usuarios
class UserRoute {
  final String userName;
  final String userAvatar;
  final String routeName;
  final double distance;
  final String duration;
  final double avgSpeed;
  final double maxSpeed;
  final String difficulty;
  final LatLng startPoint;
  final List<LatLng> routePoints;
  final int likes;
  final DateTime date;

  UserRoute({
    required this.userName,
    required this.userAvatar,
    required this.routeName,
    required this.distance,
    required this.duration,
    required this.avgSpeed,
    required this.maxSpeed,
    required this.difficulty,
    required this.startPoint,
    required this.routePoints,
    required this.likes,
    required this.date,
  });
}
