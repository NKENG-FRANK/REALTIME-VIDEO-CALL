import 'package:flutter/material.dart';
import 'package:videocall/config/theme/app_colors.dart';

class CallList extends StatefulWidget {
  const CallList({Key? key}) : super(key: key);

  @override
  State<CallList> createState() => _CallListState();
}

class _CallListState extends State<CallList> {
  final TextEditingController _searchCtrl = TextEditingController();
  int _activeTab = 0; // 0: All, 1: Missed, 2: Incoming
  final List<Map<String, dynamic>> _calls = List.generate(8, (i) => {
        'name': 'Contact ${i + 1}',
        'time': '${i + 1}h ago',
        'missed': i % 3 == 0,
        'avatarColor': i % 2 == 0 ? Colors.purple : Colors.green,
      });

  @override
  Widget build(BuildContext context) {
    final filtered = _calls.where((c) => c['name']
        .toString()
        .toLowerCase()
        .contains(_searchCtrl.text.toLowerCase()))
        .toList();
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search box
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search calls...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          // Tabs
          Row(
            children: [
              _tabButton('All', 0),
              _tabButton('Missed', 1),
              _tabButton('Incoming', 2),
            ],
          ),
          const SizedBox(height: 24),
          // Call list
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, idx) {
                final call = filtered[idx];
                final isMissed = call['missed'] as bool;
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isMissed ? const Color(0xFFFFE8E8) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: isMissed ? const Color(0xFFFFB3B3) : Colors.transparent),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: call['avatarColor'] as Color,
                        child: Text(call['name'][0], style: const TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(call['name'], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primary)),
                            const SizedBox(height: 4),
                            Text(call['time'], style: const TextStyle(fontSize: 13, color: Colors.grey)),
                          ],
                        ),
                      ),
                      if (isMissed)
                        const Badge(
                          label: Text('Missed', style: TextStyle(color: Colors.white, fontSize: 11)),
                          backgroundColor: Color(0xFFDC143C),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final bool selected = _activeTab == index;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: selected ? AppColors.primary : Colors.transparent, width: 3)),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? AppColors.primary : Colors.grey,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
      ),
    );
  }
}
