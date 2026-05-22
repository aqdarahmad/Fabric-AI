import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:convert'; // أضف هذا السطر هنا

// استيراد الموديلات، القطع البرمجية، والخدمة
import 'models/fabric_item.dart';
import 'widgets/scan_mode_selector.dart';
import 'widgets/fabric_image_preview.dart';
import 'widgets/fabric_items_list.dart';
import '../services/fabric_api_service.dart'; // استدعاء ملف الخدمة الجديد

enum ScanMode { defect, fabricType }

class ResultPage extends StatefulWidget {
  const ResultPage({super.key});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  bool isLoading = false;
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  List predictionsList = [];
  double? imgWidth;
  double? imgHeight;

  bool _showBoundingBoxes = false;
  bool _isMistakeReported = false;

  ScanMode _currentMode = ScanMode.defect;

  List<FabricItem> fabricItems = [];
  Map<String, dynamic>? finalResultToReturn;

  final TextEditingController _nameController = TextEditingController();

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _currentMode == ScanMode.defect
                      ? 'Scan for Defects'
                      : 'Identify Fabric Type',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFFE91E63)),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _scanImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blue),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _scanImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<File?> _cropImage(String imagePath) async {
    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: imagePath,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Fabric',
          toolbarColor: const Color(0xFFE91E63),
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'Crop Fabric'),
      ],
    );
    if (croppedFile != null) return File(croppedFile.path);
    return null;
  }

  Future<void> _scanImage(ImageSource sourceOption) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: sourceOption,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (pickedFile == null) return;

      File? croppedImage = await _cropImage(pickedFile.path);
      if (croppedImage == null) return;

      setState(() {
        _selectedImage = croppedImage;
        isLoading = true;
        fabricItems.clear();
        predictionsList.clear();
        finalResultToReturn = null;
        _nameController.clear();
        _showBoundingBoxes = false;
        _isMistakeReported = false;
      });

      List<int> imageBytes = await _selectedImage!.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      // الاستدعاء الآن أصبح بسيطاً وموجهاً لملف الخدمة المستقل
      if (_currentMode == ScanMode.defect) {
        double userConfidence = Hive.box(
          'fabricBox',
        ).get('aiConfidence', defaultValue: 35.0);

        final result = await FabricApiService.runDefectDetection(
          base64Image: base64Image,
          confidenceThreshold: userConfidence,
        );

        setState(() {
          imgWidth = result['imgWidth'];
          imgHeight = result['imgHeight'];
          predictionsList = result['predictions'];
          fabricItems = List<FabricItem>.from(result['fabricItems']);

          if (predictionsList.isNotEmpty) {
            HapticFeedback.heavyImpact();
            finalResultToReturn = {
              'isDefective': true,
              'image': _selectedImage,
              'defects': result['defectNames'].toSet().toList().join(', '),
              'detailedDefects': result['detailedDefects'],
              'time': DateTime.now(),
              'isMistake': false,
              'mistakeNote': '',
            };

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '⚠️ Alert: Detected defects (${result['defectNames'].toSet().toList().join(', ')})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.redAccent,
                duration: const Duration(seconds: 4),
              ),
            );
          } else {
            _setPerfectFabric();
          }
        });
      } else {
        // فحص نوع القماش عن طريق خدمة Gemini
        final bestMatch = await FabricApiService.runFabricTypeDetection(
          base64Image: base64Image,
        );

        HapticFeedback.lightImpact();
        setState(() {
          fabricItems.add(
            FabricItem(
              name: "MATERIAL: $bestMatch",
              confidence: 0.99,
              isDefect: false,
            ),
          );

          finalResultToReturn = {
            'isDefective': false,
            'image': _selectedImage,
            'defects': "Type: $bestMatch",
            'detailedDefects': [
              {
                'name': 'Identified by Gemini as $bestMatch',
                'confidence': 0.99,
              },
            ],
            'time': DateTime.now(),
            'isMistake': false,
            'mistakeNote': '',
          };
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🧵 Fabric identified as: $bestMatch',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.blueAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      print("SCAN ERROR: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 10),
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _setPerfectFabric() {
    HapticFeedback.lightImpact();
    fabricItems.add(
      FabricItem(name: 'PERFECT FABRIC', confidence: 1.0, isDefect: false),
    );
    finalResultToReturn = {
      'isDefective': false,
      'image': _selectedImage,
      'defects': 'None',
      'detailedDefects': [],
      'time': DateTime.now(),
      'isMistake': false,
      'mistakeNote': '',
    };

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '✅ Success: Fabric is perfect! No defects found.',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _showReportMistakeDialog() {
    TextEditingController noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.report_problem, color: Colors.orange),
            SizedBox(width: 8),
            Text('Report AI Mistake', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Did the AI miss a defect or guess wrong? Please describe what it actually is.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                hintText: 'e.g., Missed a small hole',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              Navigator.pop(ctx);
              _submitMistake(noteController.text);
            },
            child: const Text(
              'Submit Flag',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _submitMistake(String note) {
    setState(() {
      _isMistakeReported = true;
      if (finalResultToReturn != null) {
        finalResultToReturn!['isMistake'] = true;
        finalResultToReturn!['mistakeNote'] = note.isNotEmpty
            ? note
            : 'User flagged an error';
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Thank you! This image is flagged.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _returnWithData() {
    if (finalResultToReturn != null) {
      finalResultToReturn!['fabricName'] = _nameController.text.isNotEmpty
          ? _nameController.text
          : 'Unknown Fabric';
    }
    Navigator.of(context).pop(finalResultToReturn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context, null),
        ),
        title: const Text(
          'Scan Fabric',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ScanModeSelector(
              currentMode: _currentMode,
              isLoading: isLoading,
              onModeChanged: (newMode) {
                setState(() => _currentMode = newMode);
              },
            ),
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentMode == ScanMode.defect
                        ? 'Defect Analysis'
                        : 'Material Analysis',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FabricImagePreview(
                    selectedImage: _selectedImage,
                    showBoundingBoxes: _showBoundingBoxes,
                    predictionsList: predictionsList,
                    imgWidth: imgWidth,
                    imgHeight: imgHeight,
                    currentMode: _currentMode,
                  ),
                  const SizedBox(height: 16),
                  if (finalResultToReturn != null &&
                      predictionsList.isNotEmpty &&
                      _currentMode == ScanMode.defect) ...[
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: () => setState(
                          () => _showBoundingBoxes = !_showBoundingBoxes,
                        ),
                        icon: Icon(
                          _showBoundingBoxes
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.blue,
                        ),
                        label: Text(
                          _showBoundingBoxes
                              ? 'Hide Defect Locations'
                              : 'Show Defect Locations',
                          style: const TextStyle(color: Colors.blue),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.blue),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (finalResultToReturn != null) ...[
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Enter Fabric Name / Roll ID',
                        prefixIcon: const Icon(
                          Icons.label,
                          color: Color(0xFFE91E63),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFE91E63),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isLoading ? null : _showImageSourceDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: finalResultToReturn == null
                                ? (_currentMode == ScanMode.defect
                                      ? const Color(0xFFE91E63)
                                      : Colors.blue)
                                : Colors.grey[300],
                            foregroundColor: finalResultToReturn == null
                                ? Colors.white
                                : Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: isLoading
                              ? const SizedBox()
                              : const Icon(Icons.camera_alt),
                          label: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  finalResultToReturn == null
                                      ? 'Scan Image'
                                      : 'Retake',
                                ),
                        ),
                      ),
                      if (finalResultToReturn != null) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _returnWithData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.save, color: Colors.white),
                            label: const Text(
                              'Save & View History',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (finalResultToReturn != null &&
                      !_isMistakeReported &&
                      _currentMode == ScanMode.defect) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _showReportMistakeDialog,
                        icon: const Icon(
                          Icons.report_problem_outlined,
                          color: Colors.orange,
                        ),
                        label: const Text(
                          'AI is wrong? Report Mistake',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Colors.orange,
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            FabricItemsList(
              fabricItems: fabricItems,
              currentMode: _currentMode,
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
