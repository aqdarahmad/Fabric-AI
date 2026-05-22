import 'dart:convert';
import 'package:http/http.dart' as http;
import '../screens/models/fabric_item.dart'; // مسار الاستيراد للموديل

class FabricApiService {
  // 1. وظيفة فحص العيوب (Roboflow)
  static Future<Map<String, dynamic>> runDefectDetection({
    required String base64Image,
    required double confidenceThreshold,
  }) async {
    String apiKey = "udRjLbfGnQ8wnXINPPCB";
    String modelName = "garment-defects-o1agi";
    String version = "1";

    String url =
        "https://detect.roboflow.com/$modelName/$version?api_key=$apiKey&confidence=${confidenceThreshold.toInt()}";

    var response = await http
        .post(
          Uri.parse(url),
          headers: {"Content-Type": "application/x-www-form-urlencoded"},
          body: base64Image,
        )
        .timeout(const Duration(seconds: 25));

    if (response.statusCode == 200) {
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
        double conf = pred['confidence'] as double;

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
        'imgWidth': imgWidth,
        'imgHeight': imgHeight,
      };
    } else {
      throw Exception('Roboflow Server Error: ${response.statusCode}');
    }
  }

  // 2. وظيفة فحص نوع القماش (Gemini)
  static Future<String> runFabricTypeDetection({
    required String base64Image,
  }) async {
    String geminiApiKey = "AIzaSyAt8Bq3J0X3sLJY_WepKknypAS1Kbi8xfQ";

    if (geminiApiKey == "AIzaSyAt8Bq3J0X3sLJY_WepKknypAS1Kbi8xfQ" ||
        geminiApiKey == "AIzaSyAn7BDCUQJvmi4F7FLBhvl8aLQBmoyhYvo") {
      throw Exception(
        "لم يتم تغيير مفتاح الـ API. يرجى إنشاء مفتاح خاص بك من موقع Google AI Studio ووضعه في الكود لكي يعمل الفحص بنجاح.",
      );
    }

    String url =
        "https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=$geminiApiKey";

    String prompt =
        "Analyze this image and identify the fabric type. Choose ONLY ONE from this list: Cotton, Polyester, Silk, Wool, Linen, Denim, Leather, Knitwear. Return ONLY the fabric name without any extra text or punctuation.";

    var response = await http
        .post(
          Uri.parse(url),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "contents": [
              {
                "parts": [
                  {"text": prompt},
                  {
                    "inlineData": {
                      "mimeType": "image/jpeg",
                      "data": base64Image,
                    },
                  },
                ],
              },
            ],
            "generationConfig": {"temperature": 0.2},
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      var jsonResponse = jsonDecode(response.body);

      try {
        String bestMatch =
            jsonResponse['candidates'][0]['content']['parts'][0]['text']
                .toString()
                .trim()
                .toUpperCase();
        return bestMatch;
      } catch (e) {
        throw Exception('Failed to parse Gemini response.');
      }
    } else {
      String detailedError = response.body;
      try {
        var decodedError = jsonDecode(response.body);
        if (decodedError['error'] != null &&
            decodedError['error']['message'] != null) {
          detailedError = decodedError['error']['message'];
        }
      } catch (_) {}

      throw Exception('Gemini Error (${response.statusCode}): $detailedError');
    }
  }
}
