import 'package:flutter/material.dart';

typedef NavigationCallback = void Function();

class CustomBottomNavigationBar extends StatelessWidget {
  final NavigationCallback onProfilePressed;
  final NavigationCallback onRoutesPressed;
  final NavigationCallback onPlayPressed;
  final NavigationCallback onCenterPressed;
  final int selectedIndex;

  const CustomBottomNavigationBar({
    Key? key,
    required this.onProfilePressed,
    required this.onRoutesPressed,
    required this.onPlayPressed,
    required this.onCenterPressed,
    this.selectedIndex = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Positioned(
      bottom: 20,
      left: screenWidth * 0.05, // 5% de margen en cada lado
      right: screenWidth * 0.05,
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
              spreadRadius: 2,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavButton(
                icon: Icons.person_outline,
                selectedIcon: Icons.person,
                label: 'Perfil',
                isSelected: selectedIndex == 0,
                onPressed: onProfilePressed,
              ),
              _buildNavButton(
                icon: Icons.map_outlined,
                selectedIcon: Icons.map,
                label: 'Rutas',
                isSelected: selectedIndex == 1,
                onPressed: onRoutesPressed,
              ),
              _buildCenterPlayButton(onPressed: onPlayPressed),
              _buildNavButton(
                icon: Icons.route_outlined,
                selectedIcon: Icons.route,
                label: 'Viajes',
                isSelected: selectedIndex == 3,
                onPressed: onPlayPressed,
              ),
              _buildNavButton(
                icon: Icons.my_location_outlined,
                selectedIcon: Icons.my_location,
                label: 'Ubicar',
                isSelected: selectedIndex == 4,
                onPressed: onCenterPressed,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              color: isSelected ? Colors.blue : Colors.grey[600],
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.blue : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterPlayButton({required VoidCallback onPressed}) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.blue, Colors.blueAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(30),
          child: const Center(
            child: Icon(Icons.directions_car, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }
}

// Widget auxiliar para mostrar el estado del tracking
class TrackingStatusBadge extends StatelessWidget {
  final bool isTracking;
  final String duration;
  final String distance;

  const TrackingStatusBadge({
    Key? key,
    required this.isTracking,
    required this.duration,
    required this.distance,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isTracking) return const SizedBox.shrink();

    return Positioned(
      top: 20,
      left: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green,
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
            const Text(
              'Grabando',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              duration,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
