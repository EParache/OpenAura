import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/api_service.dart';
import 'services/settings_service.dart';

void main() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('=== FLUTTER ERROR ===');
    debugPrint(details.exceptionAsString());
    debugPrint(details.stack?.toString() ?? 'no stack');
  };

  runApp(
    const MaterialApp(
      home: _Bootstrap(),
      debugShowCheckedModeBanner: false,
    ),
  );
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  String _status = 'Detectando servidor...';
  String? _error;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      setState(() => _status = 'Buscando API...');
      final settings = await SettingsService.detect();
      debugPrint('API URL detectada: ${settings.baseUrl}');

      if (!mounted) return;

      setState(() => _status = 'Conectando a ${settings.baseUrl}...');
      final api = ApiService(baseUrl: settings.baseUrl);

      try {
        final info = await api.getHostInfo();
        debugPrint('Conectado a: $info');
      } catch (e) {
        debugPrint('Advertencia: no se pudo conectar al backend: $e');
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AuraApp(settings: settings),
        ),
      );
    } catch (e, stack) {
      debugPrint('Error de inicio: $e');
      debugPrint('Stack: $stack');
      if (mounted) {
        setState(() {
          _error = '$e';
          _status = 'Error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome, size: 48, color: Color(0xFFD81B60)),
                const SizedBox(height: 16),
                Text(
                  'OPEN AURA',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 24),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: SelectableText(
                      _error!,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _retrying
                        ? null
                        : () {
                            setState(() {
                              _error = null;
                              _retrying = true;
                              _status = 'Reintentando...';
                            });
                            _init().then((_) {
                              if (mounted) setState(() => _retrying = false);
                            });
                          },
                    icon: _retrying
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: Text(_retrying ? 'Reintentando...' : 'Reintentar'),
                  ),
                ] else ...[
                  const SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(height: 12),
                  Text(_status, style: const TextStyle(color: Color(0xFF888888))),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuraApp extends StatelessWidget {
  final SettingsService settings;
  const AuraApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AURA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD81B60),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Color(0xFF333333),
          titleTextStyle: TextStyle(
            color: Color(0xFF333333),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
        ),
      ),
      darkTheme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD81B60),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF2A2A3E),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF3A3A4E)),
          ),
        ),
      ),
      home: HomeScreen(
        api: ApiService(baseUrl: settings.baseUrl),
        settings: settings,
      ),
    );
  }
}
