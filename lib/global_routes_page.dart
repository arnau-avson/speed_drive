import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

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

  void _showRouteDetail(BuildContext context, int index, bool isDark) {
    final isFollowing = _followingUsers.contains(index);

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
            color: isDark ? Colors.black : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
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
                              colors: [
                                const Color(0xFF4A90E2),
                                const Color(0xFF5BA3F5),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4A90E2).withOpacity(0.3),
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
                                      color: const Color(0xFF4A90E2),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Siguiendo',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF4A90E2),
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.close_rounded,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Mapa grande
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                        height: 300,
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
                                  color: const Color(0xFF4A90E2),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Chips de información
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _InfoChip(
                          icon: Icons.calendar_today_rounded,
                          label: '17 Diciembre 2024',
                          isDark: isDark,
                          isLarge: true,
                        ),
                        _InfoChip(
                          icon: Icons.straighten_rounded,
                          label: '${(index + 1) * 5} kilómetros',
                          isDark: isDark,
                          isLarge: true,
                        ),
                        _InfoChip(
                          icon: Icons.schedule_rounded,
                          label: '${(index + 1) * 15} minutos',
                          isDark: isDark,
                          isLarge: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Título de descripción
                    Text(
                      'Descripción de la ruta',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Descripción completa
                    Text(
                      'Una increíble ruta por la ciudad descubriendo lugares únicos y paisajes espectaculares. Perfecta para disfrutar en cualquier momento del día.\n\nEsta ruta te llevará a través de los lugares más emblemáticos de la ciudad, pasando por parques, monumentos históricos y zonas con vistas panorámicas impresionantes. Es ideal tanto para ciclistas experimentados como para principiantes que buscan una experiencia memorable.\n\nNo olvides llevar agua, protector solar y tu cámara para capturar los mejores momentos de esta aventura única.',
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
                            value: 'Moderada',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 12),
                          _DetailRow(
                            icon: Icons.trending_up_rounded,
                            label: 'Elevación',
                            value: '${(index + 1) * 50}m',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 12),
                          _DetailRow(
                            icon: Icons.speed_rounded,
                            label: 'Velocidad media',
                            value: '${20 + index}km/h',
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
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
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Rutas Globales',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(
                        bottom: 3,
                      ), // Added margin bottom
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close_rounded,
                          color: Theme.of(context).iconTheme.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final isFollowing = _followingUsers.contains(index);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: GestureDetector(
                      onTap: () => _showRouteDetail(context, index, isDark),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1A1A1A)
                              : const Color(0xFFFAFAFA),
                          borderRadius: BorderRadius.circular(24.0),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.08)
                                : Colors.black.withOpacity(0.06),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withOpacity(0.4)
                                  : Colors.black.withOpacity(0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                      height: 140,
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
                                                color: const Color(0xFF4A90E2),
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
                                                      Colors.black.withOpacity(
                                                        0.3,
                                                      ),
                                                      Colors.black.withOpacity(
                                                        0.5,
                                                      ),
                                                    ]
                                                  : [
                                                      Colors.white.withOpacity(
                                                        0.3,
                                                      ),
                                                      Colors.white.withOpacity(
                                                        0.5,
                                                      ),
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
                                                    ? Colors.white.withOpacity(
                                                        0.15,
                                                      )
                                                    : Colors.black.withOpacity(
                                                        0.08,
                                                      ),
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
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.touch_app_rounded,
                                                    size: 16,
                                                    color: isDark
                                                        ? Colors.white
                                                              .withOpacity(0.9)
                                                        : Colors.black
                                                              .withOpacity(0.7),
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
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [
                                              const Color(0xFF4A90E2),
                                              const Color(0xFF5BA3F5),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF4A90E2,
                                              ).withOpacity(0.3),
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
                                                    color: const Color(
                                                      0xFF4A90E2,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Siguiendo',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: const Color(
                                                        0xFF4A90E2,
                                                      ),
                                                      letterSpacing: 0.3,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Una increíble ruta por la ciudad descubriendo lugares únicos y paisajes espectaculares. Perfecta para disfrutar en cualquier momento del día.',
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
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _InfoChip(
                                        icon: Icons.calendar_today_rounded,
                                        label: '17 Dic',
                                        isDark: isDark,
                                      ),
                                      _InfoChip(
                                        icon: Icons.straighten_rounded,
                                        label: '${(index + 1) * 5} km',
                                        isDark: isDark,
                                      ),
                                      _InfoChip(
                                        icon: Icons.schedule_rounded,
                                        label: '${(index + 1) * 15} min',
                                        isDark: isDark,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }, childCount: 10),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
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

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.isDark,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLarge ? 16 : 14,
        vertical: isLarge ? 11 : 9,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.1)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.15)
              : Colors.black.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: isLarge ? 17 : 15,
            color: isDark
                ? Colors.white.withOpacity(0.75)
                : Colors.black.withOpacity(0.65),
          ),
          SizedBox(width: isLarge ? 8 : 7),
          Text(
            label,
            style: TextStyle(
              fontSize: isLarge ? 14 : 13,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? Colors.white.withOpacity(0.8)
                  : Colors.black.withOpacity(0.7),
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

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF4A90E2)),
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
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }
}
