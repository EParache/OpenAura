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
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  String _query = '';
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  static const _pageSize = 100;

  static const _meses = [
    '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  @override
  void initState() {
    super.initState();
    _loadMedia();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadMedia() async {
    setState(() { _loading = true; _error = null; });
    try {
      final media = await widget.api.getMedia(
        limit: _pageSize,
        query: _query.isNotEmpty ? _query : null,
      );
      if (!mounted) return;
      setState(() {
        _media = media;
        _loading = false;
        _hasMore = media.length >= _pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final more = await widget.api.getMedia(
        skip: _media.length,
        limit: _pageSize,
        query: _query.isNotEmpty ? _query : null,
      );
      if (!mounted) return;
      setState(() {
        _media.addAll(more);
        _loadingMore = false;
        _hasMore = more.length >= _pageSize;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  void _search(String value) {
    _query = value;
    _media = [];
    _hasMore = true;
    _loadMedia();
  }

  List<_MonthGroup> _buildGroups() {
    final map = <String, List<Media>>{};
    for (final m in _media) {
      final key =
          '${m.createdAt.year}-${m.createdAt.month.toString().padLeft(2, '0')}';
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
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar archivos...',
          prefixIcon:
              const Icon(Icons.search_rounded, size: 20, color: Color(0xFF999999)),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _search('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          isDense: true,
          filled: true,
          fillColor: Theme.of(context).scaffoldBackgroundColor,
        ),
        style: const TextStyle(fontSize: 14),
        onChanged: (v) => _search(v),
      ),
    );
  }

  Widget _buildContent() {
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
            ElevatedButton(
                onPressed: _loadMedia, child: const Text('Reintentar')),
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
            Text(
              _query.isNotEmpty ? 'Sin resultados' : 'No hay archivos multimedia',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (_query.isEmpty) ...[
              const SizedBox(height: 8),
              const Text('Usa el boton de escanear para indexar archivos'),
            ],
          ],
        ),
      );
    }

    final groups = _buildGroups();

    return RefreshIndicator(
      onRefresh: _loadMedia,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          for (final group in groups) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  group.label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final m = group.media[index];
                    return _MediaTile(
                      media: m,
                      baseUrl: widget.api.baseUrl,
                      onTap: () => _openDetail(m, group.media, index),
                    );
                  },
                  childCount: group.media.length,
                ),
              ),
            ),
          ],
          if (_loadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
        ],
      ),
    );
  }

  void _openDetail(Media media, List<Media> group, int index) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, __, ___) => MediaDetailScreen(
          media: media,
          api: widget.api,
          allMedia: group,
          currentIndex: index,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    ).then((result) {
      if (result == true) _loadMedia();
    });
  }
}

class _MonthGroup {
  final String label;
  final List<Media> media;
  const _MonthGroup({required this.label, required this.media});
}

class _MediaTile extends StatefulWidget {
  final Media media;
  final String baseUrl;
  final VoidCallback onTap;

  const _MediaTile({
    required this.media,
    required this.baseUrl,
    required this.onTap,
  });

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
                ? (Matrix4.translationValues(0, -3, 0)..scale(1.02))
                : Matrix4.identity(),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hovered
                    ? Theme.of(context).colorScheme.primary.withAlpha(40)
                    : Colors.grey.shade300,
              ),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ]
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
    final thumb = widget.media.thumbnailUrl(widget.baseUrl);
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
