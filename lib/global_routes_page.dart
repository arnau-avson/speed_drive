import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart'; // Para Clipboard
import 'main.dart'; // Import to access the theme mode

class GlobalRoutesPage extends StatefulWidget {
  const GlobalRoutesPage({super.key});

  @override
  State<GlobalRoutesPage> createState() => _GlobalRoutesPageState();
}

class _GlobalRoutesPageState extends State<GlobalRoutesPage> {
  int? _activeMapIndex;

  // Lista de usuarios que sigues (índices)
  final List<int> _followingUsers = [0, 2, 4, 7];

  // Lista de rutas para mostrar datos variados
  final List<Map<String, dynamic>> _routes = [
    {
      'name': 'Ruta costera',
      'description':
          'Una ruta espectacular siguiendo la línea de costa con vistas al mar. Perfecta para amaneceres.',
      'distance': 12,
      'duration': 75,
      'elevation': 120,
      'difficulty': 'Moderada',
      'date': '17 Diciembre 2024',
      'color': 0xFF4A90E2,
    },
    {
      'name': 'Montaña del norte',
      'description':
          'Desafío de montaña con pendientes pronunciadas y recompensas en la cima.',
      'distance': 18,
      'duration': 120,
      'elevation': 450,
      'difficulty': 'Difícil',
      'date': '15 Diciembre 2024',
      'color': 0xFFE24A90,
    },
    {
      'name': 'Parque central',
      'description':
          'Ruta tranquila por el parque principal de la ciudad, ideal para familias.',
      'distance': 5,
      'duration': 35,
      'elevation': 30,
      'difficulty': 'Fácil',
      'date': '18 Diciembre 2024',
      'color': 0xFF4AE2A9,
    },
    {
      'name': 'Circuito urbano',
      'description':
          'Recorrido por los puntos más emblemáticos del centro histórico.',
      'distance': 8,
      'duration': 50,
      'elevation': 65,
      'difficulty': 'Moderada',
      'date': '16 Diciembre 2024',
      'color': 0xFFE2A94A,
    },
    {
      'name': 'Sendero boscoso',
      'description':
          'Inmersión en la naturaleza con caminos entre árboles centenarios.',
      'distance': 10,
      'duration': 70,
      'elevation': 180,
      'difficulty': 'Moderada',
      'date': '14 Diciembre 2024',
      'color': 0xFF904AE2,
    },
  ];

  // Función para copiar la ruta al portapapeles
  Future<void> _copyRouteToClipboard(BuildContext context, int index) async {
    final route = _routes[index % _routes.length];
    final routeText =
        '''
Ruta: ${route['name']}
Usuario: Usuario ${index + 1}
Distancia: ${route['distance']} km
Duración: ${route['duration']} min
Fecha: ${route['date']}
Dificultad: ${route['difficulty']}
Elevación: ${route['elevation']} m
''';

    await Clipboard.setData(ClipboardData(text: routeText));

    // Mostrar snackbar de confirmación
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ruta copiada al portapapeles'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showRouteDetail(BuildContext context, int index, bool isDark) {
    final routeIndex = index % _routes.length;
    final route = _routes[routeIndex];
    final isFollowing = _followingUsers.contains(index);
    final routeColor = Color(route['color']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? Color(0xFF121212) : Color(0xFFFAFAFA),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.3)
                      : Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Header con avatar y usuario
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [routeColor, routeColor.withOpacity(0.8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: routeColor.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.transparent,
                            child: Text(
                              'U${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Usuario ${index + 1}',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              if (isFollowing) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      size: 16,
                                      color: routeColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Siguiendo',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: routeColor,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Botón de copiar ruta en el header
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.black.withOpacity(0.05),
                          ),
                          child: IconButton(
                            onPressed: () =>
                                _copyRouteToClipboard(context, index),
                            icon: Icon(
                              Icons.copy_rounded,
                              color: isDark ? Colors.white : Colors.black,
                              size: 22,
                            ),
                            tooltip: 'Copiar ruta',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.black.withOpacity(0.05),
                          ),
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.close_rounded,
                              color: isDark ? Colors.white : Colors.black,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Título de la ruta
                    Text(
                      route['name'],
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Mapa grande
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        height: 300,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.black.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: FlutterMap(
                          options: MapOptions(
                            center: LatLng(51.505, -0.09),
                            zoom: 13.0,
                            interactiveFlags: InteractiveFlag.all,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: isDark
                                  ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
                                  : 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                              subdomains: ['a', 'b', 'c'],
                            ),
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: [
                                    LatLng(51.505, -0.09),
                                    LatLng(51.51, -0.1),
                                    LatLng(51.52, -0.12),
                                  ],
                                  strokeWidth: 5.0,
                                  color: routeColor,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Chips de información principal
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _InfoChip(
                            icon: Icons.calendar_today_rounded,
                            label: route['date'].split(' ')[0],
                            isDark: isDark,
                            color: routeColor,
                          ),
                          SizedBox(width: 8),
                          _InfoChip(
                            icon: Icons.straighten_rounded,
                            label: '${route['distance']} km',
                            isDark: isDark,
                            color: routeColor,
                          ),
                          SizedBox(width: 8),
                          _InfoChip(
                            icon: Icons.schedule_rounded,
                            label: '${route['duration']} min',
                            isDark: isDark,
                            color: routeColor,
                          ),
                          SizedBox(width: 8),
                          _InfoChip(
                            icon: Icons.terrain_rounded,
                            label: route['difficulty'],
                            isDark: isDark,
                            color: routeColor,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Título de descripción con botón de copiar
                    Row(
                      children: [
                        Text(
                          'Descripción',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const Spacer(),
                        // Botón pequeño para copiar
                        GestureDetector(
                          onTap: () => _copyRouteToClipboard(context, index),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: routeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: routeColor.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.copy_rounded,
                                  size: 16,
                                  color: routeColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Copiar ruta',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: routeColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Descripción completa
                    Text(
                      route['description'] +
                          '\n\nEsta ruta te llevará a través de los lugares más emblemáticos, pasando por parques, monumentos históricos y zonas con vistas panorámicas impresionantes. Es ideal tanto para ciclistas experimentados como para principiantes que buscan una experiencia memorable.\n\nNo olvides llevar agua, protector solar y tu cámara para capturar los mejores momentos de esta aventura única.',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark
                            ? Colors.white.withOpacity(0.75)
                            : Colors.black.withOpacity(0.7),
                        height: 1.6,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Estadísticas adicionales
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Detalles adicionales',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _DetailRow(
                            icon: Icons.terrain_rounded,
                            label: 'Dificultad',
                            value: route['difficulty'],
                            isDark: isDark,
                            color: routeColor,
                          ),
                          const SizedBox(height: 12),
                          _DetailRow(
                            icon: Icons.trending_up_rounded,
                            label: 'Elevación',
                            value: '${route['elevation']} m',
                            isDark: isDark,
                            color: routeColor,
                          ),
                          const SizedBox(height: 12),
                          _DetailRow(
                            icon: Icons.speed_rounded,
                            label: 'Velocidad media',
                            value: '${20 + index} km/h',
                            isDark: isDark,
                            color: routeColor,
                          ),
                          const SizedBox(height: 12),
                          _DetailRow(
                            icon: Icons.emoji_events_rounded,
                            label: 'Puntuación',
                            value: '${8.5 + (index % 3) * 0.5}/10',
                            isDark: isDark,
                            color: routeColor,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Botón de acción principal para copiar
                    Container(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () => _copyRouteToClipboard(context, index),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: routeColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                          shadowColor: routeColor.withOpacity(0.3),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.copy_rounded, size: 22),
                            const SizedBox(width: 10),
                            Text(
                              'Copiar ruta completa',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final isDark = themeNotifier.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? Color(0xFF0A0A0A) : Color(0xFFF5F5F5),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header con título y botón de cerrar
            SliverPadding(
              padding: const EdgeInsets.only(
                bottom: 16.0,
              ), // Ajusta este valor según necesites
              sliver: SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: true,
                floating: false,
                expandedHeight: 0, // Si no quieres que sea expandible
                titleSpacing: 0, // Ajusta el espaciado del título
                toolbarHeight: 60, // Altura fija para el AppBar
                leading: IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  'Rutas Globales',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            // Lista de rutas
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final routeIndex = index % _routes.length;
                    final route = _routes[routeIndex];
                    final isFollowing = _followingUsers.contains(index);
                    final routeColor = Color(route['color']);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: GestureDetector(
                        onTap: () => _showRouteDetail(context, index, isDark),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? Color(0xFF1A1A1A) : Colors.white,
                            borderRadius: BorderRadius.circular(24.0),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.black.withOpacity(0.08),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? Colors.black.withOpacity(0.4)
                                    : Colors.black.withOpacity(0.06),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Mapa con overlay interactivo
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(24.0),
                                  topRight: Radius.circular(24.0),
                                ),
                                child: Stack(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _activeMapIndex = index;
                                        });
                                      },
                                      child: SizedBox(
                                        height: 160,
                                        width: double.infinity,
                                        child: FlutterMap(
                                          options: MapOptions(
                                            center: LatLng(51.505, -0.09),
                                            zoom: 13.0,
                                            interactiveFlags:
                                                _activeMapIndex == index
                                                ? InteractiveFlag.all
                                                : InteractiveFlag.none,
                                          ),
                                          children: [
                                            TileLayer(
                                              urlTemplate: isDark
                                                  ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
                                                  : 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                              subdomains: ['a', 'b', 'c'],
                                            ),
                                            PolylineLayer(
                                              polylines: [
                                                Polyline(
                                                  points: [
                                                    LatLng(51.505, -0.09),
                                                    LatLng(51.51, -0.1),
                                                    LatLng(51.52, -0.12),
                                                  ],
                                                  strokeWidth: 4.5,
                                                  color: routeColor,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (_activeMapIndex != index)
                                      Positioned.fill(
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _activeMapIndex = index;
                                            });
                                          },
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: isDark
                                                    ? [
                                                        Colors.black
                                                            .withOpacity(0.3),
                                                        Colors.black
                                                            .withOpacity(0.6),
                                                      ]
                                                    : [
                                                        Colors.white
                                                            .withOpacity(0.2),
                                                        Colors.white
                                                            .withOpacity(0.4),
                                                      ],
                                              ),
                                            ),
                                            child: Center(
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 20,
                                                      vertical: 10,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? Colors.white
                                                            .withOpacity(0.15)
                                                      : Colors.black
                                                            .withOpacity(0.08),
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  border: Border.all(
                                                    color: isDark
                                                        ? Colors.white
                                                              .withOpacity(0.2)
                                                        : Colors.black
                                                              .withOpacity(0.1),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.touch_app_rounded,
                                                      size: 16,
                                                      color: isDark
                                                          ? Colors.white
                                                                .withOpacity(
                                                                  0.9,
                                                                )
                                                          : Colors.black
                                                                .withOpacity(
                                                                  0.7,
                                                                ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'Toca para interactuar',
                                                      style: TextStyle(
                                                        color: isDark
                                                            ? Colors.white
                                                                  .withOpacity(
                                                                    0.9,
                                                                  )
                                                            : Colors.black
                                                                  .withOpacity(
                                                                    0.7,
                                                                  ),
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        letterSpacing: 0.2,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              // Contenido de la tarjeta
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header con usuario y botón de copiar
                                    Row(
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              colors: [
                                                routeColor,
                                                routeColor.withOpacity(0.8),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: routeColor.withOpacity(
                                                  0.3,
                                                ),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: CircleAvatar(
                                            radius: 18,
                                            backgroundColor: Colors.transparent,
                                            child: Text(
                                              'U${index + 1}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Usuario ${index + 1}',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: isDark
                                                      ? Colors.white
                                                      : Colors.black,
                                                  letterSpacing: -0.3,
                                                ),
                                              ),
                                              if (isFollowing) ...[
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.check_circle,
                                                      size: 14,
                                                      color: routeColor,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Siguiendo',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: routeColor,
                                                        letterSpacing: 0.3,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        // Botón de copiar pequeño en tarjeta
                                        GestureDetector(
                                          onTap: () => _copyRouteToClipboard(
                                            context,
                                            index,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: routeColor.withOpacity(
                                                0.1,
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.copy_rounded,
                                              size: 16,
                                              color: routeColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Nombre de la ruta
                                    Text(
                                      route['name'],
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Descripción
                                    Text(
                                      route['description'],
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark
                                            ? Colors.white.withOpacity(0.7)
                                            : Colors.black.withOpacity(0.6),
                                        height: 1.4,
                                        letterSpacing: 0.1,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 14),

                                    // Chips de información
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _InfoChip(
                                          icon: Icons.calendar_today_rounded,
                                          label: route['date'].split(' ')[0],
                                          isDark: isDark,
                                          color: routeColor,
                                        ),
                                        _InfoChip(
                                          icon: Icons.straighten_rounded,
                                          label: '${route['distance']} km',
                                          isDark: isDark,
                                          color: routeColor,
                                        ),
                                        _InfoChip(
                                          icon: Icons.schedule_rounded,
                                          label: '${route['duration']} min',
                                          isDark: isDark,
                                          color: routeColor,
                                        ),
                                        _InfoChip(
                                          icon: Icons.terrain_rounded,
                                          label: route['difficulty'],
                                          isDark: isDark,
                                          color: routeColor,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Mensaje de distancia desde la ubicación del usuario
                                    Text(
                                      'Inicio de la ruta a ${route['distance']} km de tu ubicación',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDark
                                            ? Colors.white.withOpacity(0.7)
                                            : Colors.black.withOpacity(0.6),
                                        height: 1.4,
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _routes.length * 2,
                ), // Mostrar el doble de rutas para demostración
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final bool isLarge;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.isDark,
    this.isLarge = false,
    this.color = const Color(0xFF4A90E2),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLarge ? 16 : 12,
        vertical: isLarge ? 11 : 8,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isLarge ? 17 : 14, color: color),
          SizedBox(width: isLarge ? 8 : 6),
          Text(
            label,
            style: TextStyle(
              fontSize: isLarge ? 14 : 12,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final Color color;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    this.color = const Color(0xFF4A90E2),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? Colors.white.withOpacity(0.7)
                  : Colors.black.withOpacity(0.6),
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
