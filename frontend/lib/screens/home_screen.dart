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
      GalleryScreen(key: ValueKey('gallery_$_refreshKey'), api: _api),
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
            onMenuTap: _rescan,
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
                  onRescan: _rescan,
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

class _Header extends StatelessWidget {
  final String hostname;
  final String username;
  final bool scanning;
  final VoidCallback onRescan;

  const _Header({
    required this.hostname,
    required this.username,
    required this.scanning,
    required this.onRescan,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Row(
          children: [
            const Text(
              'OPEN AURA',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  hostname,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF555555),
                  ),
                ),
                Text(
                  username,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFFAAAAAA),
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
