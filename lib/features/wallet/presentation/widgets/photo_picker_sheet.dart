import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:solfare/core/util/app_log.dart';

/// Photo library grid that pops the chosen image back as a [File].
///
/// Exists because image_picker asks the PHPicker item provider for image data
/// and gives up when the asset only lives in iCloud — the failure users see as
/// "Cannot load representation of type public.jpeg". photo_manager goes
/// through PHImageManager with network access allowed, so the same photo
/// downloads instead of failing, and [PMProgressHandler] reports how far along
/// that download is.
class PhotoPickerSheet extends StatefulWidget {
  const PhotoPickerSheet({super.key});

  @override
  State<PhotoPickerSheet> createState() => _PhotoPickerSheetState();
}

class _PhotoPickerSheetState extends State<PhotoPickerSheet> {
  static const _pageSize = 90;
  static const _columns = 3;

  final _scrollController = ScrollController();
  final List<AssetEntity> _assets = [];

  AssetPathEntity? _album;
  PermissionState? _permission;
  int _page = 0;
  bool _loading = true;
  bool _hasMore = true;

  // Non-null while an asset is being fetched, which on iCloud-only photos can
  // take long enough that the grid needs to say something.
  AssetEntity? _downloading;
  double _downloadProgress = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!mounted) return;
    setState(() => _permission = permission);

    if (!permission.hasAccess) {
      setState(() => _loading = false);
      return;
    }

    // onlyAll collapses every album into the single "Recent" collection, which
    // is what a background picker wants — no album browser.
    final albums = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: RequestType.image,
    );
    if (!mounted) return;

    if (albums.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    _album = albums.first;
    await _loadPage();
  }

  Future<void> _loadPage() async {
    final album = _album;
    if (album == null) return;

    final batch = await album.getAssetListPaged(page: _page, size: _pageSize);
    if (!mounted) return;

    setState(() {
      _assets.addAll(batch);
      _page++;
      _hasMore = batch.length == _pageSize;
      _loading = false;
    });
  }

  void _onScroll() {
    if (_loading || !_hasMore) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 600) {
      _loading = true;
      _loadPage();
    }
  }

  Future<void> _select(AssetEntity asset) async {
    if (_downloading != null) return;
    setState(() {
      _downloading = asset;
      _downloadProgress = 0;
    });

    // PMProgressHandler asserts on anything but iOS/macOS, and only Apple
    // platforms have an iCloud fetch to report on in the first place.
    final handler = (Platform.isIOS || Platform.isMacOS) ? PMProgressHandler() : null;
    final subscription = handler?.stream.listen((state) {
      if (mounted) setState(() => _downloadProgress = state.progress);
    });

    try {
      // isOrigin false returns the transcoded JPEG rather than the HEIC
      // original, which is both smaller and what Image.file can render.
      final file = await asset.loadFile(isOrigin: false, progressHandler: handler);
      if (!mounted) return;

      if (file == null) {
        setState(() => _downloading = null);
        _showError('Could not load that photo. Try another one.');
        return;
      }
      Navigator.of(context).pop(file);
    } catch (e) {
      debugLog('[PhotoPicker] load failed: $e');
      if (!mounted) return;
      setState(() => _downloading = null);
      _showError('Could not load that photo. Try another one.');
    } finally {
      subscription?.cancel();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'FKGrotesk', fontSize: 12)),
        backgroundColor: const Color(0xFF1C1F26),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF0E1014),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        children: [
          const Text(
            'Choose a photo',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontFamily: 'FKGrotesk',
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          // iOS 14+ can grant access to a hand-picked subset. Without a way
          // back into that sheet the user is stuck with whatever they chose.
          if (_permission == PermissionState.limited)
            TextButton(
              onPressed: () async {
                await PhotoManager.presentLimited();
                if (!mounted) return;
                setState(() {
                  _assets.clear();
                  _page = 0;
                  _hasMore = true;
                  _loading = true;
                });
                _init();
              },
              child: const Text(
                'Manage',
                style: TextStyle(color: Colors.yellow, fontSize: 12, fontFamily: 'FKGrotesk'),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _assets.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.yellow, strokeWidth: 2),
      );
    }

    final permission = _permission;
    if (permission != null && !permission.hasAccess) {
      return _buildMessage(
        'Solfare needs access to your photos to set a custom background.',
        actionLabel: 'Open Settings',
        onAction: PhotoManager.openSetting,
      );
    }

    if (_assets.isEmpty) {
      return _buildMessage('No photos found on this device.');
    }

    return Stack(
      children: [
        GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _columns,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: _assets.length,
          itemBuilder: (context, index) {
            final asset = _assets[index];
            return _Thumbnail(
              asset: asset,
              onTap: () => _select(asset),
            );
          },
        ),
        if (_downloading != null) _buildDownloadOverlay(),
      ],
    );
  }

  Widget _buildDownloadOverlay() {
    // A local photo resolves instantly and this flashes; an iCloud one sits
    // here for seconds, which is the whole reason for the progress readout.
    final percent = (_downloadProgress * 100).clamp(0, 100).toStringAsFixed(0);
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.7),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.yellow, strokeWidth: 2),
            const SizedBox(height: 16),
            Text(
              _downloadProgress > 0
                  ? 'Downloading from iCloud  $percent%'
                  : 'Loading photo',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'FKGrotesk'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(String message, {String? actionLabel, VoidCallback? onAction}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 12, fontFamily: 'FKGrotesk', height: 1.5),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: onAction,
                child: Text(
                  actionLabel,
                  style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One grid cell. Thumbnails are decoded per tile and held by the element so
/// a rebuild during scrolling doesn't re-request bytes from the platform.
class _Thumbnail extends StatefulWidget {
  final AssetEntity asset;
  final VoidCallback onTap;

  const _Thumbnail({required this.asset, required this.onTap});

  @override
  State<_Thumbnail> createState() => _ThumbnailState();
}

class _ThumbnailState extends State<_Thumbnail> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bytes = await widget.asset.thumbnailDataWithSize(
      const ThumbnailSize.square(300),
      quality: 80,
    );
    if (mounted) setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        color: const Color(0xFF1C1F26),
        child: bytes == null
            ? null
            : Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
      ),
    );
  }
}
