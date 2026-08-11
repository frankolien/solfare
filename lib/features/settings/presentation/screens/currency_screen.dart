import 'package:flutter/material.dart';
import 'package:solfare/core/currency/currency.dart';
import 'package:solfare/core/currency/currency_store.dart';

class CurrencyScreen extends StatefulWidget {
  const CurrencyScreen({super.key});

  @override
  State<CurrencyScreen> createState() => _CurrencyScreenState();
}

class _CurrencyScreenState extends State<CurrencyScreen> {
  @override
  Widget build(BuildContext context) {
    final selected = CurrencyStore.instance.selected;

    return Scaffold(
      backgroundColor: const Color(0xFF0a0b12),
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: ListView.builder(
                itemCount: Currencies.all.length,
                itemBuilder: (context, i) {
                  final currency = Currencies.all[i];
                  final isSelected = currency.code == selected.code;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      await CurrencyStore.instance.select(currency);
                      if (mounted) setState(() {});
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Text(
                              currency.symbol,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontFamily: 'FKGrotesk',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currency.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontFamily: 'FKGrotesk',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currency.display,
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 10,
                                    fontFamily: 'FKGrotesk',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check,
                                color: Colors.yellow, size: 18),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
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
                'Currency',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontFamily: 'FKGrotesk',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
        ],
      ),
    );
  }
}
