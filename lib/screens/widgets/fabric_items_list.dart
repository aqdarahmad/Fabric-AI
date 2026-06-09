import 'package:flutter/material.dart';
import '../models/fabric_item.dart'; // الوصول لـ FabricItem
import '../result_page.dart'; // الوصول لـ ScanMode

class FabricItemsList extends StatelessWidget {
  final List<FabricItem> fabricItems;
  final ScanMode currentMode;

  const FabricItemsList({
    super.key,
    required this.fabricItems,
    required this.currentMode,
  });

  @override
  Widget build(BuildContext context) {
    if (fabricItems.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20.0),
        child: Center(
          child: Text(
            "No scan results yet.\nPlease add an image.",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: fabricItems.length,
      itemBuilder: (context, index) {
        var item = fabricItems[index];

        Color iconColor;
        IconData iconType;
        String subtitleText;

        // 1. تخصيص الألوان والأيقونات بناءً على وضع الفحص المختار
        if (currentMode == ScanMode.fabricType) {
          iconColor = Colors.blue;
          iconType = Icons.info;
          subtitleText = 'Confidence: ${(item.confidence * 100).toInt()}%';
        } else if (currentMode == ScanMode.authenticity) {
          // اللون الأخضر للأصلي عالي الجودة، والبرتقالي للرديء والمقلد
          iconColor = item.isDefect ? Colors.orange : Colors.green;
          iconType = item.isDefect ? Icons.gpp_bad : Icons.verified_user;
          subtitleText = 'Fabric Quality Assessment';
        } else {
          // وضع كشف العيوب (الوردي)
          iconColor = item.isDefect ? Colors.red : Colors.green;
          iconType = item.isDefect ? Icons.warning : Icons.check_circle;
          subtitleText = 'Confidence: ${(item.confidence * 100).toInt()}%';
        }

        return Card(
          child: ListTile(
            leading: Icon(iconType, color: iconColor),
            title: Text(
              item.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(subtitleText),
          ),
        );
      },
    );
  }
}
