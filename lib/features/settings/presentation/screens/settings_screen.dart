import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Settings',
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
