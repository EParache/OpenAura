import 'package:flutter/material.dart';

class AuraSidebar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final VoidCallback onRescan;
  final VoidCallback onScan;
  final VoidCallback onSettings;

  static const _accent = Color(0xFFD81B60);
  static const _inactiveIcon = Color(0xFF757575);
  static const collapsedWidth = 70.0;
  static const expandedWidth = 200.0;

  const AuraSidebar({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
    required this.onRescan,
    required this.onScan,
    required this.onSettings,
  });

  @override
  State<AuraSidebar> createState() => _AuraSidebarState();
}

class _AuraSidebarState extends State<AuraSidebar> {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      width: _expanded ? AuraSidebar.expandedWidth : AuraSidebar.collapsedWidth,
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FA),
        border: Border(right: BorderSide(color: Color(0xFFE0E0E0))),
      ),
      child: Column(
        children: [
          _MenuButton(expanded: _expanded, onTap: _toggle),
          const SizedBox(height: 16),
          Expanded(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: 1.0,
              child: Column(
                children: [
                  _NavItem(
                    icon: Icons.home_rounded,
                    label: 'Galeria',
                    selected: widget.selectedIndex == 0,
                    expanded: _expanded,
                    onTap: () => widget.onChanged(0),
                  ),
                  _NavItem(
                    icon: Icons.videocam_rounded,
                    label: 'Videos',
                    selected: widget.selectedIndex == 1,
                    expanded: _expanded,
                    onTap: () => widget.onChanged(1),
                  ),
                  _NavItem(
                    icon: Icons.photo_album_rounded,
                    label: 'Albumes',
                    selected: widget.selectedIndex == 2,
                    expanded: _expanded,
                    onTap: () => widget.onChanged(2),
                  ),
                  const Spacer(),
                  _GearMenu(
                    expanded: _expanded,
                    onRescan: widget.onRescan,
                    onScan: widget.onScan,
                    onSettings: widget.onSettings,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;

  const _MenuButton({required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        color: const Color(0xFF4A4A4A),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) {
              return RotationTransition(
                turns: animation,
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: Icon(
              expanded ? Icons.menu_open_rounded : Icons.menu_rounded,
              key: ValueKey(expanded),
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? 16 : 0,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: selected
                  ? [const BoxShadow(color: Color(0x0D000000), blurRadius: 4)]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    icon,
                    size: 24,
                    color: selected
                        ? AuraSidebar._accent
                        : AuraSidebar._inactiveIcon,
                  ),
                ),
                if (expanded) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        color: selected
                            ? AuraSidebar._accent
                            : const Color(0xFF555555),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GearMenu extends StatelessWidget {
  final bool expanded;
  final VoidCallback onRescan;
  final VoidCallback onScan;
  final VoidCallback onSettings;

  const _GearMenu({
    required this.expanded,
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
      offset: Offset(expanded ? 190 : 60, 0),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: expanded ? 16 : 0,
          vertical: 8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                Icons.settings_rounded,
                size: 24,
                color: AuraSidebar._inactiveIcon,
              ),
            ),
            if (expanded) ...[
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Ajustes',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF555555),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
