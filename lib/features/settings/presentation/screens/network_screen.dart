import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:solfare/core/constant/network.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_event.dart';

class NetworkScreen extends StatefulWidget {
  const NetworkScreen({super.key});

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> {
  SolanaNetwork _selected = NetworkConstants.current;

  Future<void> _select(SolanaNetwork network) async {
    setState(() => _selected = network);
    await NetworkConstants.setNetwork(network);

    // Re-fetch balance on the new network
    if (mounted) {
      context.read<WalletBloc>().add(const LoadWalletAddressEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
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
                        'Network',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                ],
              ),
            ),

            // Network options
            ...SolanaNetwork.values.map((network) {
              final isSelected = _selected == network;
              return GestureDetector(
                onTap: () => _select(network),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          network.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFamily: 'FKGrotesk',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Colors.yellow,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, color: Colors.black, size: 14),
                        )
                      else
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey[700]!, width: 1.5),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
