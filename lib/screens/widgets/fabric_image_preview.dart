import 'dart:io';
import 'package:flutter/material.dart';
import '../result_page.dart'; // الوصول إلى ScanMode

class FabricImagePreview extends StatelessWidget {
  final File? selectedImage;
  final bool showBoundingBoxes;
  final List predictionsList;
  final double? imgWidth;
  final double? imgHeight;
  final ScanMode currentMode;

  const FabricImagePreview({
    super.key,
    required this.selectedImage,
    required this.showBoundingBoxes,
    required this.predictionsList,
    required this.imgWidth,
    required this.imgHeight,
    required this.currentMode,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedImage == null) return const SizedBox();

    if (!showBoundingBoxes ||
        predictionsList.isEmpty ||
        imgWidth == null ||
        imgHeight == null ||
        currentMode == ScanMode.fabricType) {
      return Container(
        constraints: const BoxConstraints(maxHeight: 350),
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(selectedImage!, fit: BoxFit.contain),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        double maxWidth = constraints.maxWidth;
        double maxHeight = 350;

        double imgRatio = imgWidth! / imgHeight!;
        double containerRatio = maxWidth / maxHeight;

        double displayWidth, displayHeight;

        if (imgRatio > containerRatio) {
          displayWidth = maxWidth;
          displayHeight = maxWidth / imgRatio;
        } else {
          displayHeight = maxHeight;
          displayWidth = maxHeight * imgRatio;
        }

        double scaleX = displayWidth / imgWidth!;
        double scaleY = displayHeight / imgHeight!;

        List<Widget> boxes = predictionsList.map((pred) {
          double x = pred['x'].toDouble();
          double y = pred['y'].toDouble();
          double w = pred['width'].toDouble();
          double h = pred['height'].toDouble();

          double left = (x - w / 2) * scaleX;
          double top = (y - h / 2) * scaleY;

          return Positioned(
            left: left,
            top: top,
            width: w * scaleX,
            height: h * scaleY,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.redAccent, width: 2.5),
                borderRadius: BorderRadius.circular(4),
                color: Colors.redAccent.withOpacity(0.25),
              ),
              child: Align(
                alignment: Alignment.topLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(2),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                  child: Text(
                    '${pred['class']} ${(pred['confidence'] * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList();

        return Container(
          constraints: const BoxConstraints(maxHeight: 350),
          width: double.infinity,
          alignment: Alignment.center,
          child: SizedBox(
            width: displayWidth,
            height: displayHeight,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    selectedImage!,
                    width: displayWidth,
                    height: displayHeight,
                    fit: BoxFit.fill,
                  ),
                ),
                ...boxes,
              ],
            ),
          ),
        );
      },
    );
  }
}
