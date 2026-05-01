import 'package:flutter/material.dart';
import '../models/media.dart';
import '../services/api_service.dart';

class MediaDetailScreen extends StatefulWidget {
  final Media media;
  final ApiService api;

  const MediaDetailScreen({super.key, required this.media, required this.api});

  @override
  State<MediaDetailScreen> createState() => _MediaDetailScreenState();
}

class _MediaDetailScreenState extends State<MediaDetailScreen>
    with SingleTickerProviderStateMixin {
  late TextEditingController _titleController;
  late TextEditingController _filenameController;
  late DateTime _selectedDate;
  late String _currentPath;
  late String _displayName;
  bool _saving = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _showFullImage = false;
  bool _panelExpanded = true;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.media.title ?? '');
    _filenameController = TextEditingController(text: widget.media.filename);
    _selectedDate = widget.media.createdAt;
    _currentPath = widget.media.path;
    _displayName = widget.media.displayName;

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _filenameController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1970),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
    );
    if (time == null || !mounted) return;

    setState(() {
      _selectedDate = DateTime(
        date.year, date.month, date.day, time.hour, time.minute,
      );
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final newTitle = _titleController.text.trim();
      final newFilename = _filenameController.text.trim();

      final updated = await widget.api.updateMedia(
        widget.media.id,
        title: newTitle.isNotEmpty ? newTitle : null,
        filename: newFilename.isNotEmpty &&
                newFilename != _currentPath.split('/').last
            ? newFilename
            : null,
        createdAt: _selectedDate,
      );
      if (!mounted) return;
      setState(() {
        _titleController.text = updated.title ?? '';
        _filenameController.text = updated.filename;
        _currentPath = updated.path;
        _displayName = updated.displayName;
        _selectedDate = updated.createdAt;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cambios guardados'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildPreviewArea()),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut,
                  width: _panelExpanded
                      ? MediaQuery.of(context).size.width * 0.27
                      : 0,
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.centerLeft,
                      maxWidth: MediaQuery.of(context).size.width * 0.27,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 250),
                        opacity: _panelExpanded ? 1.0 : 0.0,
                        child: _buildInfoPanel(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 22),
            tooltip: 'Volver',
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              _displayName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.media.format != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFD81B60).withAlpha(25),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                widget.media.format!.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD81B60),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          const SizedBox(width: 6),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => setState(() => _panelExpanded = !_panelExpanded),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  _panelExpanded
                      ? Icons.info_rounded
                      : Icons.info_outline_rounded,
                  size: 20,
                  color: const Color(0xFFD81B60),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewArea() {
    return GestureDetector(
      onTap: () => setState(() => _showFullImage = !_showFullImage),
      child: Container(
        color: const Color(0xFF1A1A1A),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: Hero(
                  tag: 'media_${widget.media.id}',
                  child: _buildMediaContent(),
                ),
              ),
              if (widget.media.type == 'video')
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(180),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 44,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
              if (!_showFullImage)
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(120),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Click para expandir',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaContent() {
    if (_showFullImage && widget.media.type == 'image') {
      return InteractiveViewer(
        maxScale: 5.0,
        child: Center(
          child: Image.network(
            widget.media.fileUrl(widget.api.baseUrl),
            fit: BoxFit.contain,
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: Colors.white70),
              );
            },
            errorBuilder: (ctx, err, stack) {
              return const Icon(Icons.broken_image, size: 80, color: Colors.white38);
            },
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        widget.media.type == 'video'
            ? (widget.media.thumbnailUrl(widget.api.baseUrl) ?? widget.media.fileUrl(widget.api.baseUrl))
            : widget.media.fileUrl(widget.api.baseUrl),
        fit: BoxFit.contain,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: CircularProgressIndicator(color: Colors.white70),
          );
        },
        errorBuilder: (ctx, err, stack) {
          if (widget.media.type == 'video') {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.movie, size: 80, color: Colors.white.withAlpha(60)),
                const SizedBox(height: 12),
                Text(
                  widget.media.displayName,
                  style: TextStyle(
                    color: Colors.white.withAlpha(100),
                    fontSize: 13,
                  ),
                ),
              ],
            );
          }
          return const Icon(Icons.broken_image, size: 80, color: Colors.white38);
        },
      ),
    );
  }

  Widget _buildInfoPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(
              controller: _titleController,
              label: 'Titulo',
              icon: Icons.title,
              hint: 'Sin titulo',
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _filenameController,
              label: 'Archivo',
              icon: Icons.insert_drive_file_outlined,
            ),
            const SizedBox(height: 12),
            _buildDatePicker(),
            const SizedBox(height: 20),
            _sectionTitle('Metadatos'),
            const SizedBox(height: 12),
            _metadataCard(),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save, size: 18),
                label: Text(
                  _saving ? 'Guardando...' : 'Guardar cambios',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.grey.shade500,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    String? hint,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, size: 19) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        isDense: true,
        filled: true,
        fillColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      style: const TextStyle(fontSize: 13),
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(9),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Fecha',
          prefixIcon: const Icon(Icons.calendar_today, size: 19),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
          isDense: true,
          filled: true,
          fillColor: Theme.of(context).scaffoldBackgroundColor,
          suffixIcon: const Icon(Icons.edit_calendar, size: 17, color: Color(0xFF999999)),
        ),
        child: Text(_formatDate(_selectedDate), style: const TextStyle(fontSize: 13)),
      ),
    );
  }

  Widget _metadataCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: Column(
        children: [
          _metaRow('Tipo', widget.media.type == 'image' ? 'Imagen' : 'Video', Icons.category_outlined),
          _metaDivider(),
          if (widget.media.width != null && widget.media.height != null) ...[
            _metaRow('Dimensiones', '${widget.media.width} x ${widget.media.height}', Icons.aspect_ratio),
            _metaDivider(),
          ],
          if (widget.media.format != null) ...[
            _metaRow('Formato', widget.media.format!.toUpperCase(), Icons.text_snippet_outlined),
            _metaDivider(),
          ],
          _metaRow('Ruta', _currentPath, Icons.folder_outlined, multiLine: true),
        ],
      ),
    );
  }

  Widget _metaRow(String label, String value, IconData icon,
      {bool multiLine = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        crossAxisAlignment: multiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 17, color: Colors.grey.shade400),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: multiLine ? 3 : 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaDivider() {
    return Divider(height: 1, color: Colors.grey.shade200);
  }
}
