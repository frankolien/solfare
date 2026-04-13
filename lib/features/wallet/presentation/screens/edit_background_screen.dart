import 'package:flutter/material.dart';

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
  final String currentCard; // e.g. 'card_1.png'

  const EditBackgroundScreen({super.key, required this.currentCard});

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

  @override
  void initState() {
    super.initState();
    _selectedCard = widget.currentCard;
  }

  int get _selectedIndex => _options.indexWhere((o) => o.assetPath == _selectedCard);

  void _apply() {
    Navigator.pop(context, _selectedCard);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedIndex >= 0 ? _options[_selectedIndex] : _options[0];

    return Scaffold(
      backgroundColor: const Color(0xFF0a0b12),
      body: SafeArea(
        child: Column(
          children: [
            // Header
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

            // Preview card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: AspectRatio(
                aspectRatio: 1.7,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    '$_basePath/$_selectedCard',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: Colors.grey[900]),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Name & description
            Text(
              selected.name,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              selected.description,
              style: TextStyle(color: Colors.grey[500], fontSize: 12, fontFamily: 'FKGrotesk'),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // Grid of thumbnails
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.builder(
                  itemCount: _options.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.6,
                  ),
                  itemBuilder: (context, index) {
                    final option = _options[index];
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
                            errorBuilder: (_, __, ___) => Container(color: Colors.grey[900]),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Apply button
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
