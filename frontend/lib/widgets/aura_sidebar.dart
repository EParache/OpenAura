import 'package:flutter/material.dart';

class AuraSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final VoidCallback onMenuTap;
  final VoidCallback onRescan;
  final VoidCallback onScan;
  final VoidCallback onSettings;

  static const _accent = Color(0xFFD81B60);
  static const _inactiveIcon = Color(0xFF757575);

  const AuraSidebar({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
    required this.onMenuTap,
    required this.onRescan,
    required this.onScan,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FA),
        border: Border(right: BorderSide(color: Color(0xFFE0E0E0))),
      ),
      child: Column(
        children: [
          _MenuButton(onTap: onMenuTap),
          const SizedBox(height: 20),
          _NavIcon(
            icon: Icons.home_rounded,
            tooltip: 'Galeria',
            selected: selectedIndex == 0,
            onTap: () => onChanged(0),
          ),
          _NavIcon(
            icon: Icons.photo_album_rounded,
            tooltip: 'Albumes',
            selected: selectedIndex == 1,
            onTap: () => onChanged(1),
          ),
          const Spacer(),
          _GearMenu(
            onRescan: onRescan,
            onScan: onScan,
            onSettings: onSettings,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final VoidCallback onTap;
  const _MenuButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 70,
        color: const Color(0xFF4A4A4A),
        child: const Center(
          child: Icon(Icons.menu, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _GearMenu extends StatelessWidget {
  final VoidCallback onRescan;
  final VoidCallback onScan;
  final VoidCallback onSettings;

  const _GearMenu({
    required this.onRescan,
    required this.onScan,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (action) {
        switch (action) {
          case 'rescan':
            onRescan();
            break;
          case 'scan':
            onScan();
            break;
          case 'settings':
            onSettings();
            break;
        }
      },
      offset: const Offset(60, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'rescan',
          child: Row(
            children: [
              Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF666666)),
              SizedBox(width: 10),
              Text('Re-escanear', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'scan',
          child: Row(
            children: [
              Icon(Icons.folder_open_rounded, size: 20, color: Color(0xFF666666)),
              SizedBox(width: 10),
              Text('Escanear carpeta', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings_rounded, size: 20, color: Color(0xFF666666)),
              SizedBox(width: 10),
              Text('Configuracion', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ],
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.settings_rounded,
          size: 22,
          color: AuraSidebar._inactiveIcon,
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  const _NavIcon({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Tooltip(
        message: tooltip,
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 500),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: selected
                    ? [const BoxShadow(color: Color(0x0D000000), blurRadius: 4)]
                    : null,
              ),
              child: Icon(
                icon,
                size: 22,
                color: selected ? AuraSidebar._accent : AuraSidebar._inactiveIcon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
