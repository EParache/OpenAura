import 'package:flutter/material.dart';
import '../models/album.dart';
import '../services/api_service.dart';
import '../widgets/shimmer_loading.dart';
import 'album_detail_screen.dart';

class AlbumsScreen extends StatefulWidget {
  final ApiService api;

  const AlbumsScreen({super.key, required this.api});

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  List<Album> _albums = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    try {
      final albums = await widget.api.getAlbums();
      if (!mounted) return;
      setState(() {
        _albums = albums;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _createAlbum() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nuevo album'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Nombre del album',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            prefixIcon: const Icon(Icons.photo_album_outlined, size: 20),
          ),
          autofocus: true,
          onSubmitted: (value) => Navigator.pop(ctx, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    if (name != null && name.trim().isNotEmpty) {
      try {
        await widget.api.createAlbum(name.trim());
        _loadAlbums();
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
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SkeletonAlbumGrid();

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _loadAlbums, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    return Stack(
      children: [
        if (_albums.isEmpty)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.photo_album_outlined, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No hay albumes',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Crea tu primer album con el boton +',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              ],
            ),
          )
        else
          RefreshIndicator(
            onRefresh: _loadAlbums,
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1,
              ),
              itemCount: _albums.length,
              itemBuilder: (context, index) {
                final album = _albums[index];
                return _AlbumTile(
                  album: album,
                  onTap: () => _openAlbum(album),
                  onDelete: () => _deleteAlbum(album),
                  onRename: () => _renameAlbum(album),
                );
              },
            ),
          ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: _createAlbum,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: const Color(0xFFD81B60),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }

  void _openAlbum(Album album) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, __, ___) =>
            AlbumDetailScreen(api: widget.api, album: album),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    ).then((_) => _loadAlbums());
  }

  void _deleteAlbum(Album album) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar album'),
        content: Text('Eliminar "${album.name}"?\nEsta accion no se puede deshacer.'),
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

    if (confirm == true) {
      try {
        await widget.api.deleteAlbum(album.id);
        _loadAlbums();
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
  }

  void _renameAlbum(Album album) async {
    final controller = TextEditingController(text: album.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Renombrar album'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Nuevo nombre',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            prefixIcon: const Icon(Icons.edit_outlined, size: 20),
          ),
          autofocus: true,
          onSubmitted: (value) => Navigator.pop(ctx, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Renombrar'),
          ),
        ],
      ),
    );

    if (newName != null && newName.trim().isNotEmpty && newName != album.name) {
      try {
        await widget.api.updateAlbum(album.id, newName.trim());
        _loadAlbums();
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
  }
}

class _AlbumTile extends StatefulWidget {
  final Album album;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  const _AlbumTile({
    required this.album,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
  });

  @override
  State<_AlbumTile> createState() => _AlbumTileState();
}

class _AlbumTileState extends State<_AlbumTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final firstThumb = widget.album.media.isNotEmpty
        ? widget.album.media.first.thumbnailPath
        : null;

    final albumColor = Colors.primaries[widget.album.id % Colors.primaries.length];

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          transform: _hovered
              ? (Matrix4.translationValues(0, -4, 0)..scale(1.02))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered ? albumColor.withAlpha(80) : const Color(0xFFE0E0E0),
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: albumColor.withAlpha(30),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    )
                  ]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Column(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildCover(firstThumb, albumColor),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.album.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.album.media.length} archivos',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Material(
                  color: Colors.white.withAlpha(200),
                  borderRadius: BorderRadius.circular(8),
                  child: PopupMenuButton<String>(
                    onSelected: (action) {
                      if (action == 'rename') widget.onRename();
                      if (action == 'delete') widget.onDelete();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(Icons.more_horiz,
                        size: 18, color: Colors.grey.shade600),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Renombrar'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Eliminar', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCover(String? firstThumb, Color albumColor) {
    if (firstThumb != null && firstThumb.isNotEmpty) {
      return Image.network(
        firstThumb,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholderCover(albumColor),
      );
    }
    return _placeholderCover(albumColor);
  }

  Widget _placeholderCover(Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withAlpha(50),
            color.withAlpha(25),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.photo_album_rounded,
          size: 48,
          color: color.withAlpha(100),
        ),
      ),
    );
  }
}
