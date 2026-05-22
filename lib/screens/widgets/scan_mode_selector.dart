import 'package:flutter/material.dart';
import '../result_page.dart'; // الاستيراد النسبي للوصول إلى ScanMode

class ScanModeSelector extends StatelessWidget {
  final ScanMode currentMode;
  final bool isLoading;
  final ValueChanged<ScanMode> onModeChanged;

  const ScanModeSelector({
    super.key,
    required this.currentMode,
    required this.isLoading,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!isLoading) onModeChanged(ScanMode.defect);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: currentMode == ScanMode.defect
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: currentMode == ScanMode.defect
                      ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search,
                      size: 18,
                      color: currentMode == ScanMode.defect
                          ? const Color(0xFFE91E63)
                          : Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Detect Defects',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: currentMode == ScanMode.defect
                            ? const Color(0xFFE91E63)
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!isLoading) onModeChanged(ScanMode.fabricType);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: currentMode == ScanMode.fabricType
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: currentMode == ScanMode.fabricType
                      ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.category,
                      size: 18,
                      color: currentMode == ScanMode.fabricType
                          ? Colors.blue
                          : Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Fabric Type',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: currentMode == ScanMode.fabricType
                            ? Colors.blue
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
