import 'package:flutter/material.dart';
import '../models/media.dart';
import '../services/api_service.dart';
import '../widgets/shimmer_loading.dart';
import 'media_detail_screen.dart';

class GalleryScreen extends StatefulWidget {
  final ApiService api;
  const GalleryScreen({super.key, required this.api});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<Media> _media = [];
  bool _loading = true;
  String? _error;

  static const _meses = [
    '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    try {
      final media = await widget.api.getMedia(limit: 500);
      if (!mounted) return;
      setState(() { _media = media; _loading = false; _error = null; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  List<_MonthGroup> _buildGroups() {
    final map = <String, List<Media>>{};
    for (final m in _media) {
      final key = '${m.createdAt.year}-${m.createdAt.month.toString().padLeft(2, '0')}';
      map.putIfAbsent(key, () => []).add(m);
    }
    return map.entries.map((e) {
      final parts = e.key.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      return _MonthGroup(
        label: '${_meses[month]} $year',
        media: e.value,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SkeletonGallery();

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadMedia, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    if (_media.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No hay archivos multimedia',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('Usa el boton de escanear para indexar archivos'),
          ],
        ),
      );
    }

    final groups = _buildGroups();

    return RefreshIndicator(
      onRefresh: _loadMedia,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final group = groups[index];
          return _MonthSection(
            group: group,
            onTap: (media) => _openDetail(media),
          );
        },
      ),
    );
  }

  void _openDetail(Media media) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, __, ___) =>
            MediaDetailScreen(media: media, api: widget.api),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    ).then((_) => _loadMedia());
  }
}

class _MonthGroup {
  final String label;
  final List<Media> media;
  const _MonthGroup({required this.label, required this.media});
}

class _MonthSection extends StatelessWidget {
  final _MonthGroup group;
  final void Function(Media) onTap;

  const _MonthSection({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            group.label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF555555),
                ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: group.media.length,
          itemBuilder: (context, index) {
            final m = group.media[index];
            return _MediaTile(media: m, onTap: () => onTap(m));
          },
        ),
      ],
    );
  }
}

class _MediaTile extends StatefulWidget {
  final Media media;
  final VoidCallback onTap;

  const _MediaTile({required this.media, required this.onTap});

  @override
  State<_MediaTile> createState() => _MediaTileState();
}

class _MediaTileState extends State<_MediaTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'media_${widget.media.id}',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            transform: _hovered
                ? (Matrix4.identity()..translate(0, -3, 0)..scale(1.02))
                : Matrix4.identity(),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0E0)),
              boxShadow: _hovered
                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))]
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: _thumbnail(),
          ),
        ),
      ),
    );
  }

  Widget _thumbnail() {
    final thumb = widget.media.thumbnailPath;
    if (thumb != null && thumb.isNotEmpty) {
      return Image.network(
        thumb,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFF0F2F5),
      child: Center(
        child: widget.media.type == 'video'
            ? const Icon(Icons.videocam, size: 40, color: Color(0xFFBBBBBB))
            : const Icon(Icons.image, size: 40, color: Color(0xFFBBBBBB)),
      ),
    );
  }
}
