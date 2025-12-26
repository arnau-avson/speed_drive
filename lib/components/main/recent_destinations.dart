import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../main.dart';

class RecentDestinations extends StatelessWidget {
  final bool showRecentDestinations;
  final List<RecentDestination> recentDestinations;
  final Function(int) onRemove;
  final Function(int, String) onRename;
  final Function(RecentDestination) onSelect;

  const RecentDestinations({
    Key? key,
    required this.showRecentDestinations,
    required this.recentDestinations,
    required this.onRemove,
    required this.onRename,
    required this.onSelect,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return Visibility(
      visible: showRecentDestinations,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: showRecentDestinations ? 200 : 0,
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
                        onRemove(-1); // Close action
                      },
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (recentDestinations.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No hay destinos recientes',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  ...recentDestinations.asMap().entries.map((entry) {
                    final index = entry.key;
                    final destination = entry.value;
                    return GestureDetector(
                      onTap: () => onSelect(destination),
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
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    destination.name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: themeNotifier.isDarkMode
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    destination.address ??
                                        'Dirección desconocida',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: themeNotifier.isDarkMode
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
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
      ),
    );
  }
}
