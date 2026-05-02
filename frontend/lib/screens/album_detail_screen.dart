import 'package:flutter/material.dart';
import '../models/album.dart';
import '../models/media.dart';
import '../services/api_service.dart';
import '../widgets/shimmer_loading.dart';
import 'media_detail_screen.dart';

class AlbumDetailScreen extends StatefulWidget {
  final ApiService api;
  final Album album;

  const AlbumDetailScreen({super.key, required this.api, required this.album});

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  late Album _album;
  List<Media> _allMedia = [];
  bool _loading = true;
  bool _addingMedia = false;

  @override
  void initState() {
    super.initState();
    _album = widget.album;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        widget.api.getAlbum(widget.album.id),
        widget.api.getMedia(),
      ]);
      if (!mounted) return;
      setState(() {
        _album = results[0] as Album;
        _allMedia = results[1] as List<Media>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _addMedia(Media media) async {
    try {
      final updated = await widget.api.addMediaToAlbum(_album.id, media.id);
      if (!mounted) return;
      setState(() {
        _album = updated;
        _addingMedia = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${media.displayName}" añadido a "${_album.name}"'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _removeMedia(Media media) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Quitar archivo'),
        content: Text('Quitar "${media.displayName}" del album?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final updated =
          await widget.api.removeMediaFromAlbum(_album.id, media.id);
      if (!mounted) return;
      setState(() => _album = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${media.displayName}" quitado del album'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final albumMediaIds = _album.media.map((m) => m.id).toSet();
    final availableMedia =
        _allMedia.where((m) => !albumMediaIds.contains(m.id)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_album.name),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (availableMedia.isNotEmpty)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: IconButton(
                key: ValueKey(_addingMedia),
                icon: Icon(
                  _addingMedia ? Icons.close_rounded : Icons.add_photo_alternate_rounded,
                  color: _addingMedia ? Colors.red.shade400 : null,
                ),
                tooltip: _addingMedia ? 'Cancelar' : 'Añadir archivos',
                onPressed: () =>
                    setState(() => _addingMedia = !_addingMedia),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const SkeletonAlbumGrid()
          : _album.media.isEmpty && !_addingMedia
              ? _buildEmptyState()
              : Column(
                  children: [
                    if (_addingMedia && availableMedia.isNotEmpty)
                      _buildAddBar(availableMedia),
                    Expanded(
                      child: _album.media.isNotEmpty
                          ? GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1,
                              ),
                              itemCount: _album.media.length,
                              itemBuilder: (context, index) {
                                final mediaItem = _album.media[index];
                                return _MediaInAlbumTile(
                                  media: mediaItem,
                                  baseUrl: widget.api.baseUrl,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        transitionDuration:
                                            const Duration(milliseconds: 300),
                                        reverseTransitionDuration:
                                            const Duration(milliseconds: 250),
                                        pageBuilder: (_, __, ___) =>
                                            MediaDetailScreen(
                                                media: mediaItem,
                                                api: widget.api,
                                                allMedia: _album.media,
                                                currentIndex: index,
                                            ),
                                        transitionsBuilder:
                                            (_, animation, __, child) {
                                          return FadeTransition(
                                              opacity: animation,
                                              child: child);
                                        },
                                      ),
                                    ).then((_) => _loadData());
                                  },
                                  onLongPress: () => _removeMedia(mediaItem),
                                );
                              },
                            )
                          : _buildEmptyState(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.photo_album_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Este album esta vacio',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          if (_allMedia.isNotEmpty)
            Text(
              'Usa el boton + para añadir archivos',
              style: TextStyle(color: Colors.grey.shade500),
            )
          else
            Text(
              'No hay archivos disponibles para añadir',
              style: TextStyle(color: Colors.grey.shade500),
            ),
        ],
      ),
    );
  }

  Widget _buildAddBar(List<Media> available) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      height: 130,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                Text(
                  'Añadir archivos al album',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${available.length} disponibles',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: available.length,
              itemBuilder: (context, index) {
                final m = available[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _addMedia(m),
                      child: SizedBox(
                        width: 82,
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: _thumbWidget(m, 70),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              m.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbWidget(Media m, double size) {
    final thumb = m.thumbnailUrl(widget.api.baseUrl);
    if (thumb != null && thumb.isNotEmpty) {
      return Image.network(
        thumb,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(size),
      );
    }
    return _placeholder(size);
  }

  Widget _placeholder(double size) {
    return Container(
      width: size,
      height: size,
      color: Theme.of(context).disabledColor.withAlpha(30),
      child: Icon(Icons.image, size: 28, color: Theme.of(context).disabledColor),
    );
  }
}

class _MediaInAlbumTile extends StatefulWidget {
  final Media media;
  final String baseUrl;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _MediaInAlbumTile({
    required this.media,
    required this.baseUrl,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_MediaInAlbumTile> createState() => _MediaInAlbumTileState();
}

class _MediaInAlbumTileState extends State<_MediaInAlbumTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: _hovered
              ? (Matrix4.translationValues(0, -3, 0)..scale(1.02))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered
                  ? const Color(0xFFD81B60).withAlpha(80)
                  : const Color(0xFFE0E0E0),
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: const Color(0xFFD81B60).withAlpha(25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _thumbnail(),
              if (_hovered)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(100),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.remove_circle_outline,
                      size: 16,
                      color: Colors.white70,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbnail() {
    final thumb = widget.media.thumbnailUrl(widget.baseUrl);
    if (thumb != null && thumb.isNotEmpty) {
      return Image.network(
        thumb,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      color: Theme.of(context).disabledColor.withAlpha(30),
      child: Center(
        child: widget.media.type == 'video'
            ? Icon(Icons.videocam, size: 40, color: Theme.of(context).disabledColor)
            : Icon(Icons.image, size: 40, color: Theme.of(context).disabledColor),
      ),
    );
  }
}
