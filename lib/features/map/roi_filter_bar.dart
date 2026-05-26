import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database.dart';

class RoiFilterBar extends ConsumerWidget {
  final String? selectedRoiId;
  final ValueChanged<String?> onChanged;

  const RoiFilterBar({
    super.key,
    required this.selectedRoiId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);

    return FutureBuilder(
      future: db.getAllRois(),
      builder: (context, snapshot) {
        final rois = snapshot.data ?? [];

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // 「全部」按鈕
              FilterChip(
                label: const Text('全部'),
                selected: selectedRoiId == null,
                onSelected: (_) => onChanged(null),
              ),
              const SizedBox(width: 8),
              ...rois.map((roi) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(roi.name),
                      selected: selectedRoiId == roi.id,
                      onSelected: (_) => onChanged(roi.id),
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }
}