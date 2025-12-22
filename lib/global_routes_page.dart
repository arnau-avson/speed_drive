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

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final isDark = themeNotifier.isDarkMode;

    return Scaffold(
      backgroundColor: isDark
          ? Theme.of(context).scaffoldBackgroundColor
          : Theme.of(context).scaffoldBackgroundColor,
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
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: Theme.of(context).iconTheme.color,
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
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? Theme.of(context).cardColor
                            : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20.0),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.black.withOpacity(0.3)
                                : Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20.0),
                              topRight: Radius.circular(20.0),
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
                                    height: 180,
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
                                              strokeWidth: 5.0,
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
                                        color: (isDark ? Colors.black : Colors.white) .withOpacity(0.4),
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? Colors.white.withOpacity(
                                                      0.15,
                                                    )
                                                  : Colors.black.withOpacity(
                                                      0.05,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              'Toca para interactuar',
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.white70
                                                    : Colors.black54,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
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
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: const Color(
                                        0xFF4A90E2,
                                      ).withOpacity(0.15),
                                      child: Text(
                                        'U${index + 1}',
                                        style: const TextStyle(
                                          color: Color(0xFF4A90E2),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Usuario ${index + 1}',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF1A1A1A),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Descripción de la ruta ${index + 1}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.black54,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    _InfoChip(
                                      icon: Icons.calendar_today_rounded,
                                      label: '17 Dic',
                                      isDark: isDark,
                                    ),
                                    const SizedBox(width: 8),
                                    _InfoChip(
                                      icon: Icons.straighten_rounded,
                                      label: '${(index + 1) * 5} km',
                                      isDark: isDark,
                                    ),
                                    const SizedBox(width: 8),
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

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isDark ? Colors.white60 : Colors.black54),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
