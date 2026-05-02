import 'package:flutter/material.dart';

class AuraSidebar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final VoidCallback onRescan;
  final VoidCallback onScan;
  final VoidCallback onRegenerate;
  final VoidCallback onSettings;

  static const _accent = Color(0xFFD81B60);
  static const _inactiveIcon = Color(0xFF888888);
  static const collapsedWidth = 80.0;
  static const expandedWidth = 210.0;

  const AuraSidebar({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
    required this.onRescan,
    required this.onScan,
    required this.onRegenerate,
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
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).dividerColor.withAlpha(80),
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          _Logo(expanded: _expanded, onTap: _toggle),
          const SizedBox(height: 32),
          Expanded(
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
                  onRegenerate: widget.onRegenerate,
                  onSettings: widget.onSettings,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;

  const _Logo({required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFD81B60), Color(0xFF880E4F)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? Theme.of(context).colorScheme.primary.withAlpha(15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: selected
                      ? AuraSidebar._accent
                      : AuraSidebar._inactiveIcon,
                ),
                if (expanded) ...[
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected
                          ? AuraSidebar._accent
                          : const Color(0xFF666666),
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
  final VoidCallback onRegenerate;
  final VoidCallback onSettings;

  const _GearMenu({
    required this.expanded,
    required this.onRescan,
    required this.onScan,
    required this.onRegenerate,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: PopupMenuButton<String>(
        onSelected: (action) {
          switch (action) {
            case 'rescan':
              onRescan();
              break;
            case 'scan':
              onScan();
              break;
            case 'regenerate':
              onRegenerate();
              break;
            case 'settings':
              onSettings();
              break;
          }
        },
        offset: Offset(expanded ? 200 : 70, 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: 'rescan',
            child: Row(children: [
              Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF666666)),
              SizedBox(width: 10),
              Text('Re-escanear', style: TextStyle(fontSize: 14)),
            ]),
          ),
          const PopupMenuItem(
            value: 'scan',
            child: Row(children: [
              Icon(Icons.folder_open_rounded, size: 20, color: Color(0xFF666666)),
              SizedBox(width: 10),
              Text('Escanear carpeta', style: TextStyle(fontSize: 14)),
            ]),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'regenerate',
            child: Row(children: [
              Icon(Icons.auto_fix_high_rounded, size: 20, color: Color(0xFF666666)),
              SizedBox(width: 10),
              Text('Regenerar miniaturas', style: TextStyle(fontSize: 14)),
            ]),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'settings',
            child: Row(children: [
              Icon(Icons.settings_rounded, size: 20, color: Color(0xFF666666)),
              SizedBox(width: 10),
              Text('Configuracion', style: TextStyle(fontSize: 14)),
            ]),
          ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.settings_rounded, size: 22, color: Color(0xFF888888)),
              if (expanded) ...[
                const SizedBox(width: 12),
                const Text('Ajustes',
                    style: TextStyle(fontSize: 13, color: Color(0xFF666666))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
