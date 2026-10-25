import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'package:fabric_ai/screens/models/fabric_item.dart';
import 'package:fabric_ai/screens/widgets/scan_mode_selector.dart';
import 'package:fabric_ai/screens/widgets/fabric_image_preview.dart';
import 'package:fabric_ai/screens/widgets/fabric_items_list.dart';
import 'package:fabric_ai/services/fabric_api_service.dart';
import 'package:fabric_ai/screens/retraining_pool_page.dart';

enum ScanMode { defect, fabricType, authenticity }

class ResultPage extends StatefulWidget {
  const ResultPage({super.key});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  bool isLoading = false;
  Uint8List? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  List predictionsList = [];
  double? imgWidth;
  double? imgHeight;

  bool _showBoundingBoxes = false;
  bool _isMistakeReported = false;

  ScanMode _currentMode = ScanMode.defect;

  List<FabricItem> fabricItems = [];
  Map<String, dynamic>? finalResultToReturn;

  // متغيرات مخصصة لحفظ تفاصيل نوع القماش المطور
  Map<String, dynamic>? _fabricTypeDetails;

  // متغيرات مخصصة لحفظ تفاصيل فحص جودة وأصالة القماش
  String? _authenticityVerdict;
  String? _authenticityExplanation;
  int? _authenticityScore;
  List<String> _authenticityIndicators = [];

  final TextEditingController _nameController = TextEditingController();

  CameraController? _cameraController;
  bool _isLiveScanning = false;
  Timer? _liveScanTimer;

  @override
  void dispose() {
    _liveScanTimer?.cancel();
    _cameraController?.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _initLiveCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      _cameraController = CameraController(
        cameras[0],
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      print("Camera initialization error: $e");
    }
  }

  Future<void> _toggleLiveScan() async {
    if (_isLiveScanning) {
      _liveScanTimer?.cancel();
      await _cameraController?.dispose();
      setState(() {
        _isLiveScanning = false;
        _cameraController = null;
        predictionsList.clear();
        fabricItems.clear();
      });
    } else {
      setState(() => isLoading = true);
      await _initLiveCamera();

      if (_cameraController == null ||
          !_cameraController!.value.isInitialized) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not initialize camera preview.")),
        );
        return;
      }

      setState(() {
        _isLiveScanning = true;
        isLoading = false;
        _selectedImage = null;
        finalResultToReturn = null;
        fabricItems.clear();
        predictionsList.clear();
        _fabricTypeDetails = null;
        _authenticityVerdict = null;
        _authenticityExplanation = null;
        _authenticityScore = null;
        _authenticityIndicators.clear();
      });

      double userConfidence = Hive.box(
        'fabricBox',
      ).get('aiConfidence', defaultValue: 35.0);

      _liveScanTimer = Timer.periodic(const Duration(milliseconds: 1500), (
        timer,
      ) async {
        if (_cameraController == null ||
            !_cameraController!.value.isInitialized ||
            !_isLiveScanning) {
          timer.cancel();
          return;
        }

        try {
          if (_cameraController!.value.isTakingPicture) return;

          final XFile file = await _cameraController!.takePicture();
          final bytes = await file.readAsBytes();
          final base64Image = base64Encode(bytes);

          final result = await FabricApiService.runDefectDetection(
            base64Image: base64Image,
            confidenceThreshold: userConfidence,
          );

          if (mounted && _isLiveScanning) {
            setState(() {
              predictionsList = result['predictions'];
              fabricItems = List<FabricItem>.from(result['fabricItems']);
              imgWidth = result['imgWidth'];
              imgHeight = result['imgHeight'];
            });
          }
        } catch (e) {
          print("Live frame capture error: $e");
        }
      });
    }
  }

  Future<void> _scanImageFromPi() async {
    String piIp = Hive.box(
      'fabricBox',
    ).get('piIp', defaultValue: '192.168.1.197');

    String captureUrl = "http://$piIp:5000/capture";
    String imageUrl =
        "http://$piIp:5000/image?time=${DateTime.now().millisecondsSinceEpoch}";

    setState(() {
      isLoading = true;
      fabricItems.clear();
      predictionsList.clear();
      finalResultToReturn = null;
      _nameController.clear();
      _showBoundingBoxes = false;
      _isMistakeReported = false;
      _fabricTypeDetails = null;
      _authenticityVerdict = null;
      _authenticityExplanation = null;
      _authenticityScore = null;
      _authenticityIndicators.clear();
    });

    try {
      final captureResponse = await http
          .get(Uri.parse(captureUrl))
          .timeout(const Duration(seconds: 15));
      if (captureResponse.statusCode == 200) {
        var data = jsonDecode(captureResponse.body);
        if (data['status'] == 'success') {
          final imgResponse = await http
              .get(Uri.parse(imageUrl))
              .timeout(const Duration(seconds: 15));
          if (imgResponse.statusCode == 200) {
            setState(() {
              _selectedImage = imgResponse.bodyBytes;
            });

            String base64Image = base64Encode(imgResponse.bodyBytes);

            await _processFabricAnalysis(base64Image);
          } else {
            throw Exception("Failed to download captured image from Pi.");
          }
        } else {
          throw Exception("Pi Camera Capture failed: ${data['message']}");
        }
      } else {
        throw Exception("Could not communicate with Pi Server.");
      }
    } catch (e) {
      print("Pi Capture Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error capturing from Pi: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  // دالة موحدة لمعالجة تحليل المنسوجات بناءً على النمط النشط
  Future<void> _processFabricAnalysis(String base64Image) async {
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
        } else {
          _setPerfectFabric();
        }
      });
    } else if (_currentMode == ScanMode.fabricType) {
      final typeData = await FabricApiService.runFabricTypeDetection(
        base64Image: base64Image,
      );
      HapticFeedback.lightImpact();
      setState(() {
        _fabricTypeDetails = typeData;
        String mainType = typeData['fabric_type'] ?? 'Unknown';

        fabricItems.add(
          FabricItem(
            name: "نوع القماش: $mainType",
            confidence: 0.99,
            isDefect: false,
          ),
        );

        finalResultToReturn = {
          'isDefective': false,
          'image': _selectedImage,
          'defects': "النوع: $mainType",
          'detailedDefects': [
            {'name': 'التحليل الذكي للقماش: $mainType', 'confidence': 0.99},
          ],
          'time': DateTime.now(),
          'isMistake': false,
          'mistakeNote': '',
        };
      });
    } else if (_currentMode == ScanMode.authenticity) {
      final result = await FabricApiService.runFabricAuthenticityCheck(
        base64Image: base64Image,
      );
      HapticFeedback.lightImpact();

      setState(() {
        _authenticityVerdict = result['verdict'] ?? "UNKNOWN";
        _authenticityExplanation = result['explanation'] ?? "لا تتوفر تفاصيل.";
        _authenticityScore = result['quality_score'] != null
            ? int.tryParse(result['quality_score'].toString()) ?? 75
            : 75;
        _authenticityIndicators = List<String>.from(result['indicators'] ?? []);

        bool isLowQuality =
            _authenticityVerdict!.contains("LOW QUALITY") ||
            _authenticityVerdict!.contains("COUNTERFEIT");

        fabricItems.add(
          FabricItem(
            name: "التقييم البصري: $_authenticityVerdict",
            confidence: (_authenticityScore ?? 100) / 100.0,
            isDefect: isLowQuality,
          ),
        );

        finalResultToReturn = {
          'isDefective': isLowQuality,
          'image': _selectedImage,
          'defects': "الجودة: $_authenticityVerdict",
          'detailedDefects': [
            {
              'name': _authenticityVerdict!,
              'confidence': (_authenticityScore ?? 100) / 100.0,
            },
          ],
          'time': DateTime.now(),
          'isMistake': false,
          'mistakeNote': '',
        };
      });
    }
  }

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
                      : (_currentMode == ScanMode.fabricType
                            ? 'Identify Fabric Type'
                            : 'Check Quality & Authenticity'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFFE91E63)),
                title: const Text('Local Phone Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _scanImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blue),
                title: const Text('Local Phone Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _scanImage(ImageSource.gallery);
                },
              ),
              if (!kIsWeb)
                ListTile(
                  leading: const Icon(Icons.videocam, color: Colors.green),
                  title: const Text('Raspberry Pi Camera (Hardware)'),
                  onTap: () {
                    Navigator.pop(context);
                    _scanImageFromPi();
                  },
                ),
            ],
          ),
        );
      },
    );
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

      final Uint8List pickedBytes = await pickedFile.readAsBytes();

      setState(() {
        _selectedImage = pickedBytes;
        isLoading = true;
        fabricItems.clear();
        predictionsList.clear();
        finalResultToReturn = null;
        _nameController.clear();
        _showBoundingBoxes = false;
        _isMistakeReported = false;
        _fabricTypeDetails = null;
        _authenticityVerdict = null;
        _authenticityExplanation = null;
        _authenticityScore = null;
        _authenticityIndicators.clear();
      });

      String base64Image = base64Encode(pickedBytes);

      await _processFabricAnalysis(base64Image);
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

  Future<void> _submitMistake(String note) async {
    try {
      final box = Hive.box('fabricBox');
      List flaggedList = box.get('flaggedMistakes', defaultValue: []);

      flaggedList.add({
        'imageBytes': _selectedImage,
        'aiVerdict': finalResultToReturn?['defects'] ?? "Unknown",
        'userCorrection': note.isNotEmpty ? note : 'User flagged an error',
        'timestamp': DateTime.now().toString(),
      });

      await box.put('flaggedMistakes', flaggedList);

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
          content: Text('✅ Saved successfully to Retraining Pool!'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      print("Error saving mistake report: $e");
    }
  }

  void _returnWithData() {
    if (finalResultToReturn != null) {
      finalResultToReturn!['fabricName'] = _nameController.text.isNotEmpty
          ? _nameController.text
          : 'Unknown Fabric';
    }
    Navigator.of(context).pop(finalResultToReturn);
  }

  // ويدجت لبناء بطاقات تفصيلية عن نوع القماش بطريقة احترافية
  Widget _buildFabricTypeDetailsCard() {
    if (_fabricTypeDetails == null) return const SizedBox();

    String title = _fabricTypeDetails!['fabric_type'] ?? 'Unknown';
    String comp = _fabricTypeDetails!['composition'] ?? 'غير محدد';
    String txt = _fabricTypeDetails!['texture'] ?? 'غير محدد';
    List uses = _fabricTypeDetails!['best_uses'] ?? [];
    List care = _fabricTypeDetails!['care_instructions'] ?? [];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.texture, color: Colors.blue, size: 28),
              const SizedBox(width: 8),
              Text(
                "تحليل نوع النسيج: $title",
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: Colors.blueAccent),

          _buildInfoRow("التركيب المقدر:", comp, Icons.analytics),
          _buildInfoRow("الملمس المتوقع:", txt, Icons.touch_app),

          if (uses.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              "الاستخدامات المفضلة:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Wrap(
              spacing: 6,
              children: uses
                  .map(
                    (u) => Chip(
                      label: Text(
                        u.toString(),
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Colors.blue.shade100,
                      padding: EdgeInsets.zero,
                    ),
                  )
                  .toList(),
            ),
          ],

          if (care.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              "نصائح العناية والغسيل:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            ...care
                .map(
                  (c) => Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          c.toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.blueGrey),
          const SizedBox(width: 6),
          Text(
            "$label ",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  // جواز سفر الجودة - تصميم مقنع يعتمد على النقاط والمؤشرات
  Widget _buildAuthenticityPassportCard() {
    if (_authenticityVerdict == null) return const SizedBox();

    bool isPremium = _authenticityVerdict!.contains("PREMIUM");
    bool isStandard = _authenticityVerdict!.contains("STANDARD");
    Color themeColor = isPremium
        ? Colors
              .teal // تم التغيير إلى Teal ليعطي طابعاً فاخراً ومقنعاً للجودة العالية
        : (isStandard ? Colors.blue : Colors.orange.shade700);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeColor.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_user, color: themeColor, size: 28),
                  const SizedBox(width: 8),
                  const Text(
                    "تقرير مطابقة النسيج والجودة",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: themeColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${_authenticityScore ?? 75}%",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            _authenticityVerdict!,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: themeColor,
            ),
          ),
          const SizedBox(height: 8),

          // عرض تفصيلي للمؤشرات البصرية المكتشفة
          if (_authenticityIndicators.isNotEmpty) ...[
            const Text(
              "الملاحظات البصرية وعوامل التقييم:",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 4),
            ..._authenticityIndicators
                .map(
                  (ind) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(Icons.lens, size: 8, color: themeColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ind,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
            const SizedBox(height: 10),
          ],

          const Divider(height: 10),
          const SizedBox(height: 4),
          const Text(
            "التحليل البصري الدقيق:",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _authenticityExplanation!,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveCameraWithBoxes() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const SizedBox(
        height: 250,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        double maxWidth = constraints.maxWidth;
        double maxHeight = 350;

        double previewWidth = _cameraController!.value.previewSize!.height;
        double previewHeight = _cameraController!.value.previewSize!.width;

        double imgRatio = previewWidth / previewHeight;
        double containerRatio = maxWidth / maxHeight;

        double displayWidth, displayHeight;

        if (imgRatio > containerRatio) {
          displayWidth = maxWidth;
          displayHeight = maxWidth / imgRatio;
        } else {
          displayHeight = maxHeight;
          displayWidth = maxHeight * imgRatio;
        }

        double scaleX = displayWidth / (imgWidth ?? previewWidth);
        double scaleY = displayHeight / (imgHeight ?? previewHeight);

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
                  child: CameraPreview(_cameraController!),
                ),
                ...boxes,
              ],
            ),
          ),
        );
      },
    );
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
        actions: [
          IconButton(
            icon: const Icon(Icons.model_training, color: Colors.green),
            tooltip: "Model Retraining Pool",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RetrainingPoolPage(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ScanModeSelector(
              currentMode: _currentMode,
              isLoading: isLoading,
              onModeChanged: (newMode) {
                if (_isLiveScanning) _toggleLiveScan();
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
                        : (_currentMode == ScanMode.fabricType
                              ? 'Material Analysis'
                              : 'Authenticity & Quality Assessment'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _isLiveScanning
                      ? _buildLiveCameraWithBoxes()
                      : FabricImagePreview(
                          // التعديل هنا: إضافة الـ Key لإجبار الويدجت على عرض الصورة الجديدة دائماً عند تغير مسارها
                          key: ValueKey(_selectedImage?.length ?? 'no_image'),
                          selectedImage: _selectedImage,
                          showBoundingBoxes: _showBoundingBoxes,
                          predictionsList: predictionsList,
                          imgWidth: imgWidth,
                          imgHeight: imgHeight,
                          currentMode: _currentMode == ScanMode.defect
                              ? ScanMode.defect
                              : ScanMode.fabricType,
                        ),
                  const SizedBox(height: 16),

                  // عرض الموديل الثاني (نوع القماش المفصل)
                  if (_fabricTypeDetails != null &&
                      _currentMode == ScanMode.fabricType)
                    _buildFabricTypeDetailsCard(),

                  // عرض الموديل الثالث (أصالة وجودة القماش المطور)
                  if (_authenticityVerdict != null &&
                      _currentMode == ScanMode.authenticity)
                    _buildAuthenticityPassportCard(),

                  if (finalResultToReturn != null &&
                      predictionsList.isNotEmpty &&
                      _currentMode == ScanMode.defect &&
                      !_isLiveScanning) ...[
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
                      if (!_isLiveScanning)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isLoading
                                ? null
                                : _showImageSourceDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: finalResultToReturn == null
                                  ? (_currentMode == ScanMode.defect
                                        ? const Color(0xFFE91E63)
                                        : (_currentMode == ScanMode.fabricType
                                              ? Colors.blue
                                              : Colors.green))
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                          ),
                        ),

                      if (!_isLiveScanning &&
                          _currentMode == ScanMode.defect &&
                          finalResultToReturn == null)
                        const SizedBox(width: 10),

                      if (_currentMode == ScanMode.defect &&
                          finalResultToReturn == null)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isLoading ? null : _toggleLiveScan,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isLiveScanning
                                  ? Colors.red
                                  : Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: Icon(
                              _isLiveScanning ? Icons.stop : Icons.videocam,
                            ),
                            label: Text(
                              _isLiveScanning ? 'Stop Live' : 'Live Scan',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),

                      if (finalResultToReturn != null && !_isLiveScanning) ...[
                        const SizedBox(width: 10),
                        Expanded(
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
                              'Save & View',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (finalResultToReturn != null &&
                      !_isMistakeReported &&
                      _currentMode == ScanMode.defect &&
                      !_isLiveScanning) ...[
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
