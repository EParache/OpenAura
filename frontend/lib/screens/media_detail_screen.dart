import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/media.dart';
import '../services/api_service.dart';

class MediaDetailScreen extends StatefulWidget {
  final Media media;
  final ApiService api;
  final List<Media>? allMedia;
  final int? currentIndex;

  const MediaDetailScreen({
    super.key,
    required this.media,
    required this.api,
    this.allMedia,
    this.currentIndex,
  });

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
  bool _deleting = false;
  bool _showFullImage = false;
  bool _panelExpanded = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  VideoPlayerController? _videoController;
  Timer? _videoTimeout;

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

    if (widget.media.type == 'video') {
      _initVideo();
    }
  }

  void _initVideo() {
    _videoTimeout?.cancel();
    _videoController?.dispose();
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(widget.media.fileUrl(widget.api.baseUrl)),
    );
    _videoController!.initialize().then((_) {
      if (mounted) setState(() {});
    }).catchError((e) {
      debugPrint('Error inicializando video: $e');
      _videoController?.dispose();
      _videoController = null;
      if (mounted) setState(() {});
    });

    _videoTimeout = Timer(const Duration(seconds: 10), () {
      if (mounted &&
          _videoController != null &&
          !_videoController!.value.isInitialized) {
        _videoController?.dispose();
        _videoController = null;
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _filenameController.dispose();
    _fadeController.dispose();
    _videoTimeout?.cancel();
    _videoController?.dispose();
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

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red, size: 22),
            SizedBox(width: 8),
            Text('Eliminar archivo'),
          ],
        ),
        content: Text('Estas seguro de eliminar "${_displayName}"?\n\n'
            'El archivo se borrara permanentemente del disco.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await widget.api.deleteMedia(widget.media.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${_displayName}" eliminado'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _goToPrev() {
    final list = widget.allMedia;
    final idx = widget.currentIndex;
    if (list == null || idx == null || idx <= 0) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) => MediaDetailScreen(
          media: list[idx - 1],
          api: widget.api,
          allMedia: list,
          currentIndex: idx - 1,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-0.3, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation, curve: Curves.easeOut,
            )),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
      ),
    );
  }

  void _goToNext() {
    final list = widget.allMedia;
    final idx = widget.currentIndex;
    if (list == null || idx == null || idx >= list.length - 1) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) => MediaDetailScreen(
          media: list[idx + 1],
          api: widget.api,
          allMedia: list,
          currentIndex: idx + 1,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.3, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation, curve: Curves.easeOut,
            )),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
      ),
    );
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

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error abriendo URL: $e');
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
                      child: IgnorePointer(
                        ignoring: !_panelExpanded,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                          opacity: _panelExpanded ? 1.0 : 0.0,
                          child: _buildInfoPanel(),
                        ),
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
      height: 48,
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
          if (widget.allMedia != null &&
              widget.currentIndex != null &&
              widget.currentIndex! > 0)
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, size: 24),
              tooltip: 'Anterior',
              onPressed: _goToPrev,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            ),
          if (widget.allMedia != null &&
              widget.currentIndex != null &&
              widget.currentIndex! < widget.allMedia!.length - 1)
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, size: 24),
              tooltip: 'Siguiente',
              onPressed: _goToNext,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
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
    if (widget.media.type == 'video') {
      return _buildVideoPreview();
    }

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

  Widget _buildVideoPreview() {
    final controller = _videoController;
    final hasError = controller != null &&
        controller.value.hasError &&
        !controller.value.isInitialized;

    if (controller == null || (!controller.value.isInitialized && !hasError)) {
      return Container(
        color: const Color(0xFF1A1A1A),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white70),
              SizedBox(height: 16),
              Text('Cargando video...',
                  style: TextStyle(color: Colors.white54, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    if (hasError) {
      final videoUrl = widget.media.fileUrl(widget.api.baseUrl);
      return Container(
        color: const Color(0xFF1A1A1A),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam, size: 64, color: Colors.white.withAlpha(80)),
              const SizedBox(height: 16),
              Text(
                widget.media.displayName,
                style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 15),
              ),
              const SizedBox(height: 8),
              Text(
                'El navegador no puede reproducir este formato',
                style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 12),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _initVideo(),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Reintentar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: Colors.white.withAlpha(40)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () {
                      // Abrir en el navegador directamente
                      _launchUrl(videoUrl);
                    },
                    icon: const Icon(Icons.open_in_browser, size: 16),
                    label: const Text('Abrir video'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD81B60),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          controller.value.isPlaying
              ? controller.pause()
              : controller.play();
        });
      },
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),
            if (!controller.value.isPlaying)
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
                    size: 48,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: _buildVideoControls(controller),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoControls(VideoPlayerController controller) {
    return Row(
      children: [
        IconButton(
          icon: Icon(
            controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
            size: 28,
          ),
          onPressed: () {
            setState(() {
              controller.value.isPlaying
                  ? controller.pause()
                  : controller.play();
            });
          },
        ),
        Expanded(
          child: VideoProgressIndicator(
            controller,
            allowScrubbing: true,
            colors: const VideoProgressColors(
              playedColor: Color(0xFFD81B60),
              bufferedColor: Colors.white24,
              backgroundColor: Colors.white12,
            ),
          ),
        ),
        Text(
          _formatDuration(controller.value.position),
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const Text(' / ', style: TextStyle(color: Colors.white38, fontSize: 12)),
        Text(
          _formatDuration(controller.value.duration),
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(
            controller.value.volume > 0 ? Icons.volume_up : Icons.volume_off,
            color: Colors.white70,
            size: 20,
          ),
          onPressed: () {
            setState(() {
              controller.setVolume(controller.value.volume > 0 ? 0.0 : 1.0);
            });
          },
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final min = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$min:$sec';
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
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton.icon(
                onPressed: _deleting || _saving ? null : _delete,
                icon: _deleting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.red,
                        ),
                      )
                    : const Icon(Icons.delete_outline, size: 17, color: Colors.red),
                label: Text(
                  _deleting ? 'Eliminando...' : 'Eliminar',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
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
