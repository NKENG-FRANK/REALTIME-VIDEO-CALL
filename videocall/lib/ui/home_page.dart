import 'package:flutter/material.dart';
import 'package:videocall/ui/sidebar.dart';
import 'package:videocall/ui/call_list.dart';
import 'package:videocall/config/theme/app_colors.dart';
import 'package:videocall/ui/animated_background.dart';
import 'package:videocall/features/call/presentation/widgets/call_launcher_dialogs.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const AnimatedBackground(),
          const Positioned.fill(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Sidebar(),
                Expanded(child: _MainContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MainContent extends StatelessWidget {
  const _MainContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: const [
        _Header(),
        Expanded(child: CallList()),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _HeaderLeft(),
          _HeaderRight(),
        ],
      ),
    );
  }
}

class _HeaderLeft extends StatelessWidget {
  const _HeaderLeft({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Calls', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primary)),
        SizedBox(height: 4),
        Text('All your recent calls', style: TextStyle(fontSize: 13, color: Colors.grey)),
      ],
    );
  }
}

class _HeaderRight extends StatelessWidget {
  const _HeaderRight({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: () => showGroupCallLaunchDialog(context),
          icon: const Icon(Icons.groups_rounded, size: 16),
          label: const Text('Launch Group Call'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(width: 9),
        OutlinedButton.icon(
          onPressed: () => showOneToOneCallLaunchDialog(context),
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
          label: const Text('1-on-1 Call'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}
