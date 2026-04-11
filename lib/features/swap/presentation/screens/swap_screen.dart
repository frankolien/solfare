import 'package:flutter/material.dart';

class SwapScreen extends StatelessWidget {
  const SwapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Swap',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontFamily: 'FKGrotesk',
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
