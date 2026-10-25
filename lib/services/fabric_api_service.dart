import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../screens/models/fabric_item.dart'; // مسار الاستيراد للموديل

/// كل طلبات الذكاء الاصطناعي تمر عبر سيرفر Fabric-AI (server/index.js)
/// حتى لا تظهر مفاتيح Roboflow و OpenAI داخل التطبيق أو المتصفح.
class FabricApiService {
  /// على الويب: نفس الدومين الذي يخدم التطبيق.
  /// على الموبايل: مرّر --dart-define=API_BASE_URL=https://your-app.onrender.com
  static const String _configuredBase = String.fromEnvironment('API_BASE_URL');

  static String get _baseUrl {
    if (_configuredBase.isNotEmpty) {
      return _configuredBase.replaceAll(RegExp(r'/+$'), '');
    }
    if (kIsWeb) return Uri.base.origin;
    throw Exception('API_BASE_URL is not configured for this build.');
  }

  static Future<http.Response> _post(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 40),
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/ai/$path'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      String detail = '';
      try {
        detail = jsonDecode(response.body)['error']?.toString() ?? '';
      } catch (_) {}
      throw Exception('Server error ${response.statusCode}: $detail');
    }
    return response;
  }

  // 1. فحص العيوب (Roboflow عبر السيرفر)
  static Future<Map<String, dynamic>> runDefectDetection({
    required String base64Image,
    required double confidenceThreshold,
  }) async {
    final response = await _post('defects', {
      'image': base64Image,
      'confidence': confidenceThreshold,
    }, timeout: const Duration(seconds: 30));

    var jsonResponse = jsonDecode(response.body);

    double? imgWidth;
    double? imgHeight;
    if (jsonResponse['image'] != null) {
      imgWidth = jsonResponse['image']['width']?.toDouble();
      imgHeight = jsonResponse['image']['height']?.toDouble();
    }

    List predictions = jsonResponse['predictions'] ?? [];
    List<FabricItem> fabricItems = [];
    List<String> defectNames = [];
    List<Map<String, dynamic>> detailedDefects = [];

    for (var pred in predictions) {
      String defName = pred['class'].toString().toUpperCase();
      double conf = (pred['confidence'] as num).toDouble();

      defectNames.add(defName);
      fabricItems.add(
        FabricItem(name: defName, confidence: conf, isDefect: true),
      );
      detailedDefects.add({'name': defName, 'confidence': conf});
    }

    return {
      'predictions': predictions,
      'fabricItems': fabricItems,
      'defectNames': defectNames,
      'detailedDefects': detailedDefects,
      'imgWidth': imgWidth ?? 768.0,
      'imgHeight': imgHeight ?? 512.0,
      'rawResponseBody': response.body,
    };
  }

  // 2. تحليل نوع القماش (OpenAI عبر السيرفر)
  static Future<Map<String, dynamic>> runFabricTypeDetection({
    required String base64Image,
  }) async {
    final response = await _post('fabric-type', {'image': base64Image});
    try {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } catch (e) {
      throw Exception('Failed to parse Fabric Type JSON.');
    }
  }

  // 3. فحص الجودة والأصالة (OpenAI عبر السيرفر)
  static Future<Map<String, dynamic>> runFabricAuthenticityCheck({
    required String base64Image,
  }) async {
    final response = await _post('authenticity', {'image': base64Image});
    try {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } catch (e) {
      throw Exception('Failed to parse Authenticity JSON.');
    }
  }
}
