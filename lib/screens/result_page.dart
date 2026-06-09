import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart'; // استيراد مطلوب لحفظ صورة الباي مؤقتاً
import 'package:http/http.dart'
    as http; // استيراد مطلوب للتواصل مع سيرفر الرازبري باي

import 'package:fabric_ai/screens/models/fabric_item.dart';
import 'package:fabric_ai/screens/widgets/scan_mode_selector.dart';
import 'package:fabric_ai/screens/widgets/fabric_image_preview.dart';
import 'package:fabric_ai/screens/widgets/fabric_items_list.dart';
import 'package:fabric_ai/services/fabric_api_service.dart';
import 'package:fabric_ai/screens/retraining_pool_page.dart'; // 👈 استدعاء صفحة الأخطاء الجديدة
import 'package:path_provider/path_provider.dart'; // تأكدي من وجودها لحفظ الصور

enum ScanMode { defect, fabricType, authenticity }

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

  String? _authenticityVerdict;
  String? _authenticityExplanation;

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
        _authenticityVerdict = null;
        _authenticityExplanation = null;
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
          final bytes = await File(file.path).readAsBytes();
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

  // 🎥 الدالة الهندسية المبتكرة لالتقاط الصورة وسحبها بالكامل من كاميرا الرازبري باي للتحليل
  Future<void> _scanImageFromPi() async {
    // 💡 رقم الـ IP الخاص بالرازبري باي (تأكدي من تعديله غداً ليتطابق مع الـ IP الذي يعطيكِ إياه تطبيق Fing عند ربطه بنقطة الاتصال Hotspot)
    String piIp = "abood.local";

    String captureUrl = "http://$piIp:5000/capture";
    String imageUrl = "http://$piIp:5000/image";

    setState(() {
      isLoading = true;
      fabricItems.clear();
      predictionsList.clear();
      finalResultToReturn = null;
      _nameController.clear();
      _showBoundingBoxes = false;
      _isMistakeReported = false;
      _authenticityVerdict = null;
      _authenticityExplanation = null;
    });

    try {
      // 1. إرسال أمر الالتقاط صامتاً للرازبري باي عبر الشبكة
      final captureResponse = await http
          .get(Uri.parse(captureUrl))
          .timeout(const Duration(seconds: 15));
      if (captureResponse.statusCode == 200) {
        var data = jsonDecode(captureResponse.body);
        if (data['status'] == 'success') {
          // 2. سحب الصورة وتحميل بايتات الملف فوراً للهاتف
          final imgResponse = await http
              .get(Uri.parse(imageUrl))
              .timeout(const Duration(seconds: 15));
          if (imgResponse.statusCode == 200) {
            // 3. حفظ بايتات الصورة كملف مؤقت داخل مساحة تخزين الهاتف ليعامل كصورة عادية
            final tempDir = await getTemporaryDirectory();
            final file = File('${tempDir.path}/pi_captured_fabric.jpg');
            await file.writeAsBytes(imgResponse.bodyBytes);

            setState(() {
              _selectedImage =
                  file; // وضع الصورة الملتقطة من الباي كصورة معتمدة للفحص
            });

            // 4. تشغيل خوارزميات الفحص والتحليل المختارة بالـ UI على صورة الرازبري باي الملتقطة
            List<int> imageBytes = await _selectedImage!.readAsBytes();
            String base64Image = base64Encode(imageBytes);

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
                    'defects': result['defectNames'].toSet().toList().join(
                      ', ',
                    ),
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
                      'name': 'Identified by ChatGPT as $bestMatch',
                      'confidence': 0.99,
                    },
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
              String verdict = result['verdict'] ?? "UNKNOWN";
              String explanation = result['explanation'] ?? "لا تتوفر تفاصيل.";

              setState(() {
                _authenticityVerdict = verdict;
                _authenticityExplanation = explanation;
                bool isFake =
                    verdict.contains("LOW QUALITY") ||
                    verdict.contains("COUNTERFEIT");

                fabricItems.add(
                  FabricItem(name: verdict, confidence: 0.99, isDefect: isFake),
                );
                finalResultToReturn = {
                  'isDefective': isFake,
                  'image': _selectedImage,
                  'defects': "Quality: $verdict",
                  'detailedDefects': [
                    {'name': verdict, 'confidence': 0.99},
                  ],
                  'time': DateTime.now(),
                  'isMistake': false,
                  'mistakeNote': '',
                };
              });
            }
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
              // 🎥 الخيار الثالث الذهبي والمبتكر لتشغيل كاميرا الرازبري باي من الهاتف مباشرة
              ListTile(
                leading: const Icon(Icons.videocam, color: Colors.green),
                title: const Text('Raspberry Pi Camera (Hardware)'),
                onTap: () {
                  Navigator.pop(context);
                  _scanImageFromPi(); // تشغيل دالة الاتصال بالباي وسحب الصورة
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
        _authenticityVerdict = null;
        _authenticityExplanation = null;
      });

      List<int> imageBytes = await _selectedImage!.readAsBytes();
      String base64Image = base64Encode(imageBytes);

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
      } else if (_currentMode == ScanMode.fabricType) {
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
                'name': 'Identified by ChatGPT as $bestMatch',
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
      } else if (_currentMode == ScanMode.authenticity) {
        final result = await FabricApiService.runFabricAuthenticityCheck(
          base64Image: base64Image,
        );

        HapticFeedback.lightImpact();
        String verdict = result['verdict'] ?? "UNKNOWN";
        String explanation = result['explanation'] ?? "لا تتوفر تفاصيل.";

        setState(() {
          _authenticityVerdict = verdict;
          _authenticityExplanation = explanation;

          bool isFake =
              verdict.contains("LOW QUALITY") ||
              verdict.contains("COUNTERFEIT");

          fabricItems.add(
            FabricItem(name: verdict, confidence: 0.99, isDefect: isFake),
          );

          finalResultToReturn = {
            'isDefective': isFake,
            'image': _selectedImage,
            'defects': "Quality: $verdict",
            'detailedDefects': [
              {'name': verdict, 'confidence': 0.99},
            ],
            'time': DateTime.now(),
            'isMistake': false,
            'mistakeNote': '',
          };
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🔒 Quality Scan Complete: $verdict',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.green,
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

  Future<void> _submitMistake(String note) async {
    try {
      // 1. حفظ الصورة بشكل دائم في مجلد التطبيق لكي لا تُمسح من الملفات المؤقتة
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = "flagged_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final savedImage = await _selectedImage!.copy('${appDir.path}/$fileName');

      // 2. فتح كرت الـ Hive وتخزين تفاصيل الخطأ بداخل قائمة الأخطاء المخصصة
      final box = Hive.box('fabricBox');
      List flaggedList = box.get('flaggedMistakes', defaultValue: []);

      flaggedList.add({
        'imagePath': savedImage.path,
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
    bool isFake =
        _authenticityVerdict != null &&
        (_authenticityVerdict!.contains("LOW QUALITY") ||
            _authenticityVerdict!.contains("COUNTERFEIT"));

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
        // 🟢 الزر الجديد المخصص في أعلى اليمين للانتقال الفوري لصفحة أخطاء الموديل وسلة إعادة التدريب
        actions: [
          IconButton(
            icon: const Icon(
              Icons.model_training,
              color: Colors.green,
            ), // أيقونة خضراء ذكية لتدريب الموديل
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
          const SizedBox(width: 8), // مسافة تباعد بسيطة
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

                  if (_authenticityVerdict != null &&
                      _authenticityExplanation != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isFake ? Colors.orange[50] : Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isFake ? Colors.orange : Colors.green,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isFake ? Icons.gpp_bad : Icons.verified,
                                color: isFake
                                    ? Colors.orange[800]
                                    : Colors.green[800],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _authenticityVerdict!,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isFake
                                      ? Colors.orange[900]
                                      : Colors.green[900],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(color: Colors.black12, height: 1),
                          const SizedBox(height: 10),
                          Text(
                            _authenticityExplanation!,
                            textAlign:
                                Navigator.of(context).widget is Directionality
                                ? TextAlign.right
                                : null,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

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
                      // 1. زر الفحص التقليدي أو إعادة الفحص (Retake) - مخفي أثناء البث الحي
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
                                        : 'Retake', // يظهر كـ Retake بعد التقاط الصورة
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                          ),
                        ),

                      // مسافة تباعد بين الأزرار تظهر فقط قبل التقاط الصورة في وضع العيوب
                      if (!_isLiveScanning &&
                          _currentMode == ScanMode.defect &&
                          finalResultToReturn == null)
                        const SizedBox(width: 10),

                      // 2. 🎥 زر البث الحي المباشر (يظهر فقط في وضع كشف العيوب Defects وقبل التقاط الصورة!)
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

                      // 3. أزرار الحفظ وعرض السجل بعد التقاط الصورة وفحصها بنجاح (تظهر متناسقة ومتساوية المساحة 50/50 مع زر Retake)
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
