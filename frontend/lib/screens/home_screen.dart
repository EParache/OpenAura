import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/settings_service.dart';
import '../widgets/aura_sidebar.dart';
import 'gallery_screen.dart';
import 'albums_screen.dart';
import 'scan_screen.dart';

class HomeScreen extends StatefulWidget {
  final ApiService api;
  final SettingsService settings;

  const HomeScreen({super.key, required this.api, required this.settings});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late ApiService _api;
  late List<Widget> _screens;
  bool _scanning = false;
  int _refreshKey = 0;
  String _searchQuery = '';
  String _hostname = 'HOST NAME';
  String _username = 'USER PC NAME';

  @override
  void initState() {
    super.initState();
    _api = widget.api;
    _buildScreens();
    _detectHostInfo();
  }

  void _detectHostInfo() async {
    try {
      final info = await _api.getHostInfo();
      if (!mounted) return;
      setState(() {
        _hostname = (info['hostname'] as String?) ?? 'HOST NAME';
        _username = (info['username'] as String?) ?? 'USER PC NAME';
      });
    } catch (e) {
      debugPrint('Error detectando host info: $e');
    }
  }

  void _buildScreens() {
    _screens = [
      GalleryScreen(key: ValueKey('gallery_$_refreshKey'), api: _api, initialQuery: _searchQuery),
      AlbumsScreen(key: ValueKey('albums_$_refreshKey'), api: _api),
    ];
  }

  void _rebuildWithUrl(String url) {
    widget.settings.updateUrl(url);
    setState(() {
      _api = ApiService(baseUrl: url);
      _buildScreens();
    });
  }

  Future<void> _rescan() async {
    setState(() => _scanning = true);
    try {
      final result = await _api.rescan();
      if (!mounted) return;

      final added = result['added'] ?? 0;
      final removed = result['removed'] ?? 0;
      final parts = <String>[];
      if (added > 0) parts.add('$added nuevo(s)');
      if (removed > 0) parts.add('$removed eliminado(s)');
      final msg = parts.isEmpty ? 'Sin cambios' : parts.join(', ');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
        ),
      );

      _refreshKey++;
      _buildScreens();
      setState(() => _scanning = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _scanning = false);
    }
  }

  void _onSidebarChanged(int index) {
    setState(() => _selectedIndex = index);
  }

  void _onScanTap() {
    _openScanDialog(context);
  }

  void _onSettingsTap() {
    _openSettings(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Row(
        children: [
          AuraSidebar(
            selectedIndex: _selectedIndex,
            onChanged: _onSidebarChanged,
            onRescan: _rescan,
            onScan: _onScanTap,
            onSettings: _onSettingsTap,
          ),
          Expanded(
            child: Column(
              children: [
                _Header(
                  hostname: _hostname,
                  username: _username,
                  scanning: _scanning,
                  searchQuery: _searchQuery,
                  onSearchChanged: (q) {
                    setState(() => _searchQuery = q);
                    _buildScreens();
                  },
                ),
                const Divider(height: 1),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: child,
                      );
                    },
                    child: _screens[_selectedIndex],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openSettings(BuildContext context) {
    final controller = TextEditingController(text: widget.settings.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.settings_outlined, size: 22),
            SizedBox(width: 10),
            Text('Configuracion'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'URL de la API',
                hintText: 'http://192.168.100.6:8000',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.link, size: 20),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'La IP se detecta automaticamente. Variable: AURA_API_URL',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty && url != widget.settings.baseUrl) {
                _rebuildWithUrl(url);
              }
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Conectar'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  void _openScanDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => ScanDialog(api: _api),
    ).then((_) {
      if (!mounted) return;
      _refreshKey++;
      _buildScreens();
      setState(() {});
    });
  }
}

class _Header extends StatefulWidget {
  final String hostname;
  final String username;
  final bool scanning;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;

  const _Header({
    required this.hostname,
    required this.username,
    required this.scanning,
    required this.searchQuery,
    required this.onSearchChanged,
  });

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  late TextEditingController _searchController;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant _Header oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery.isEmpty && _searchController.text.isNotEmpty) {
      _searchController.clear();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Text(
              'OPEN AURA',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleLarge?.color,
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              width: _showSearch ? 220 : 0,
              child: _showSearch
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Buscar...',
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  widget.onSearchChanged('');
                                },
                              )
                            : null,
                      ),
                      style: const TextStyle(fontSize: 13),
                      onChanged: widget.onSearchChanged,
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                _showSearch ? Icons.search_off_rounded : Icons.search_rounded,
                size: 22,
              ),
              tooltip: 'Buscar',
              onPressed: () => setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  widget.onSearchChanged('');
                }
              }),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              color: const Color(0xFF777777),
            ),
            const SizedBox(width: 6),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  widget.hostname,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
                Text(
                  widget.username,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFD81B60), Color(0xFFAD1457)],
                ),
                borderRadius: BorderRadius.circular(19),
              ),
              child: const Icon(
                Icons.person_rounded,
                size: 22,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
