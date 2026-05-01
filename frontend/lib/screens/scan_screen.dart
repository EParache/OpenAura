import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ScanDialog extends StatefulWidget {
  final ApiService api;

  const ScanDialog({super.key, required this.api});

  @override
  State<ScanDialog> createState() => _ScanDialogState();
}

class _ScanDialogState extends State<ScanDialog> {
  final _pathController = TextEditingController();
  bool _scanning = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final path = _pathController.text.trim();
    if (path.isEmpty) return;

    setState(() {
      _scanning = true;
      _result = null;
      _error = null;
    });

    try {
      final result = await widget.api.scanDirectory(path);
      if (!mounted) return;
      setState(() {
        _result = result;
        _scanning = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _scanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.folder_open_rounded, size: 22, color: Color(0xFFD81B60)),
          SizedBox(width: 10),
          Text('Escanear carpeta'),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _pathController,
              decoration: InputDecoration(
                hintText: '/ruta/a/la/carpeta',
                labelText: 'Ruta de la carpeta',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.folder_outlined, size: 20),
              ),
              enabled: !_scanning,
              onSubmitted: (_) => _scan(),
            ),
            const SizedBox(height: 16),
            if (_scanning)
              const Column(
                children: [
                  SizedBox(height: 20),
                  CircularProgressIndicator(strokeWidth: 2.5),
                  SizedBox(height: 16),
                  Text(
                    'Escaneando archivos...',
                    style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
                  ),
                  SizedBox(height: 8),
                ],
              ),
            if (_result != null) _buildResult(),
            if (_error != null) _buildError(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _scanning ? null : () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
        FilledButton.icon(
          onPressed: _scanning ? null : _scan,
          icon: const Icon(Icons.search_rounded, size: 18),
          label: const Text('Escanear'),
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    final added = _result!['added'] ?? 0;
    final skipped = _result!['skipped'] ?? 0;
    final errors = _result!['errors'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded,
              color: Colors.green.shade600, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 13, color: Colors.green.shade800),
                children: [
                  TextSpan(
                    text: '$added',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' añadidos  '),
                  TextSpan(
                    text: '$skipped',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' saltados  '),
                  TextSpan(
                    text: '$errors',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' errores'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(fontSize: 13, color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }
}
