import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Data for each background card option.
class _BackgroundOption {
  final String assetPath;
  final String name;
  final String description;

  const _BackgroundOption({
    required this.assetPath,
    required this.name,
    required this.description,
  });
}

class EditBackgroundScreen extends StatefulWidget {
  final String currentCard; // e.g. 'card_1.png' or an absolute file path
  final String walletId;

  const EditBackgroundScreen({
    super.key,
    required this.currentCard,
    required this.walletId,
  });

  @override
  State<EditBackgroundScreen> createState() => _EditBackgroundScreenState();
}

class _EditBackgroundScreenState extends State<EditBackgroundScreen> {
  static const _basePath = 'assets/assets/images/wallet_background';

  static const List<_BackgroundOption> _options = [
    _BackgroundOption(assetPath: 'card_1.png', name: 'Fortune Flow', description: 'Master the market tides and see your funds rise.'),
    _BackgroundOption(assetPath: 'card_2.png', name: 'Neon Pulse', description: 'Electric energy for your digital assets.'),
    _BackgroundOption(assetPath: 'card_3.png', name: 'Golden Hour', description: 'Warm tones for a bright portfolio.'),
    _BackgroundOption(assetPath: 'card_4.png', name: 'Pixel Art', description: 'Retro vibes for the modern collector.'),
    _BackgroundOption(assetPath: 'card_5.png', name: 'Urban Glow', description: 'City lights that never sleep.'),
    _BackgroundOption(assetPath: 'card_6.png', name: 'Sunset Blaze', description: 'Bold colors for bold moves.'),
    _BackgroundOption(assetPath: 'card_7.png', name: 'Cool Blue', description: 'Stay calm and stack sats.'),
    _BackgroundOption(assetPath: 'card_8.png', name: 'Silver Storm', description: 'Sleek and powerful aesthetics.'),
    _BackgroundOption(assetPath: 'card_9.png', name: 'Fire Walk', description: 'Walk through the flames of volatility.'),
    _BackgroundOption(assetPath: 'card_10.png', name: 'Ocean Deep', description: 'Dive into the depths of DeFi.'),
    _BackgroundOption(assetPath: 'card_11.png', name: 'Cyber Gold', description: 'Digital gold for the new age.'),
    _BackgroundOption(assetPath: 'card_12.png', name: 'Titan Rise', description: 'Rise above the rest.'),
  ];

  late String _selectedCard;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _selectedCard = widget.currentCard;
  }

  // Custom entries are stored as `custom:<filename>`. The sentinel lets us
  // tell them apart from the bundled `card_*.png` presets, and storing only
  // the filename (not the absolute path) keeps them valid even when the
  // iOS sandbox's documents-directory path changes between launches.
  static const _customPrefix = 'custom:';
  bool get _isCustomSelected => _selectedCard.startsWith(_customPrefix);
  String get _customFilename =>
      _selectedCard.substring(_customPrefix.length);

  int get _selectedIndex =>
      _options.indexWhere((o) => o.assetPath == _selectedCard);

  Future<void> _pickCustomImage() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked == null) return;

      // Copy into app documents so the file survives future picks from the
      // same transient cache location and is stable across app restarts.
      final docs = await getApplicationDocumentsDirectory();
      final ext = picked.path.split('.').last.toLowerCase();
      final filename =
          'wallet_bg_${widget.walletId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final dest = File('${docs.path}/$filename');
      await File(picked.path).copy(dest.path);

      // Best-effort cleanup of any prior custom file for this wallet.
      if (_isCustomSelected) {
        final old = File('${docs.path}/$_customFilename');
        if (await old.exists()) {
          try {
            await old.delete();
          } catch (_) {}
        }
      }

      if (mounted) setState(() => _selectedCard = '$_customPrefix$filename');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _apply() {
    Navigator.pop(context, _selectedCard);
  }

  Widget _buildPreview() {
    if (_isCustomSelected) {
      return FutureBuilder<Directory>(
        future: getApplicationDocumentsDirectory(),
        builder: (context, snap) {
          if (!snap.hasData) return Container(color: Colors.grey[900]);
          return Image.file(
            File('${snap.data!.path}/$_customFilename'),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: Colors.grey[900]),
          );
        },
      );
    }
    return Image.asset(
      '$_basePath/$_selectedCard',
      fit: BoxFit.cover,
      cacheWidth: 400,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => Container(color: Colors.grey[900]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedIndex >= 0 ? _options[_selectedIndex] : null;
    final previewName = _isCustomSelected
        ? 'Custom photo'
        : (selected?.name ?? _options[0].name);
    final previewDesc = _isCustomSelected
        ? 'Your own image, just for this wallet.'
        : (selected?.description ?? _options[0].description);

    return Scaffold(
      backgroundColor: const Color(0xFF0a0b12),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Edit background',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: AspectRatio(
                aspectRatio: 1.7,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _buildPreview(),
                ),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              previewName,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                previewDesc,
                style: TextStyle(color: Colors.grey[500], fontSize: 12, fontFamily: 'FKGrotesk'),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 24),

            // Grid: first cell is the upload tile, rest are presets.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.builder(
                  itemCount: _options.length + 1,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.6,
                  ),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _UploadTile(
                        picking: _picking,
                        selected: _isCustomSelected,
                        onTap: _pickCustomImage,
                        filename:
                            _isCustomSelected ? _customFilename : null,
                      );
                    }
                    final option = _options[index - 1];
                    final isSelected = option.assetPath == _selectedCard;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedCard = option.assetPath),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 2)
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(isSelected ? 8 : 10),
                          child: Image.asset(
                            '$_basePath/${option.assetPath}',
                            fit: BoxFit.cover,
                            cacheWidth: 200,
                            errorBuilder: (_, __, ___) => Container(color: Colors.grey[900]),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                  onPressed: _apply,
                  child: const Text(
                    'Apply',
                    style: TextStyle(color: Colors.black, fontSize: 13, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadTile extends StatelessWidget {
  final bool picking;
  final bool selected;
  final String? filename;
  final VoidCallback onTap;

  const _UploadTile({
    required this.picking,
    required this.selected,
    required this.onTap,
    this.filename,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: picking ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1F26),
          borderRadius: BorderRadius.circular(10),
          border: selected
              ? Border.all(color: Colors.white, width: 2)
              : Border.all(color: Colors.white12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(selected ? 8 : 10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (filename != null)
                FutureBuilder<Directory>(
                  future: getApplicationDocumentsDirectory(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return Container(color: const Color(0xFF1C1F26));
                    }
                    return Image.file(
                      File('${snap.data!.path}/$filename'),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: const Color(0xFF1C1F26)),
                    );
                  },
                ),
              Container(color: Colors.black.withValues(alpha: 0.35)),
              Center(
                child: picking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            filename == null ? Icons.add : Icons.refresh,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            filename == null ? 'Upload' : 'Change',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontFamily: 'FKGrotesk',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
