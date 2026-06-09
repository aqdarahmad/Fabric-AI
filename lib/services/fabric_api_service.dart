import 'dart:convert';
import 'package:http/http.dart' as http;
import '../screens/models/fabric_item.dart';

class FabricApiService {
  static const String _openaiApiKey = "";
  static Future<Map<String, dynamic>> runDefectDetection({
    required String base64Image,
    required double confidenceThreshold,
  }) async {
    String apiKey = "";
    String modelName = "fabric-defect-detection-lbvbi-1kwag";
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
    } else {
      throw Exception(
        'Roboflow API Error: ${response.statusCode}\n${response.body}',
      );
    }
  }

  static Future<String> runFabricTypeDetection({
    required String base64Image,
  }) async {
    if (_openaiApiKey.isEmpty || _openaiApiKey.startsWith("ضع_هنا")) {
      throw Exception(
        "لم يتم إدخال مفتاح الـ API الخاص بـ OpenAI في ملف الخدمة.",
      );
    }

    String url = "https://api.openai.com/v1/chat/completions";

    var response = await http
        .post(
          Uri.parse(url),
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $_openaiApiKey",
          },
          body: jsonEncode({
            "model": "gpt-4o-mini",
            "messages": [
              {
                "role": "user",
                "content": [
                  {
                    "type": "text",
                    "text":
                        "Analyze this image and identify the fabric type. Choose ONLY ONE from this list: Cotton, Polyester, Silk, Wool, Linen, Denim, Leather, Knitwear. Return ONLY the fabric name without any extra text or punctuation.",
                  },
                  {
                    "type": "image_url",
                    "image_url": {"url": "data:image/jpeg;base64,$base64Image"},
                  },
                ],
              },
            ],
            "max_tokens": 15,
            "temperature": 0.2,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      var jsonResponse = jsonDecode(response.body);
      try {
        String bestMatch = jsonResponse['choices'][0]['message']['content']
            .toString()
            .trim()
            .toUpperCase();
        return bestMatch;
      } catch (e) {
        throw Exception('Failed to parse OpenAI response.');
      }
    } else {
      throw Exception('OpenAI Error: ${response.statusCode}');
    }
  }

  // 3. وظيفة فحص "أصالة وجودة القماش" المبتكرة والمصممة لمشروع التخرج
  static Future<Map<String, String>> runFabricAuthenticityCheck({
    required String base64Image,
  }) async {
    // شرط فحص ذكي لمنع حدوث تعليق أو أخطاء مع مفتاحك الفعلي
    if (_openaiApiKey.isEmpty || _openaiApiKey.startsWith("ضع_هنا")) {
      throw Exception(
        "لم يتم إدخال مفتاح الـ API الخاص بـ OpenAI في ملف الخدمة.",
      );
    }

    String url = "https://api.openai.com/v1/chat/completions";

    // طلب تحليل دقيق لجودة حبكة النسيج وإرجاع النتيجة كـ JSON
    var response = await http
        .post(
          Uri.parse(url),
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $_openaiApiKey",
          },
          body: jsonEncode({
            "model": "gpt-4o-mini",
            "response_format": {
              "type": "json_object",
            }, // تفعيل نظام الـ JSON الصارم من OpenAI
            "messages": [
              {
                "role": "user",
                "content": [
                  {
                    "type": "text",
                    "text":
                        "You are an expert textile inspector. Analyze this close-up image of a fabric to determine if it is of high-quality/authentic origin (GENUINE / HIGH QUALITY) or a cheap/fake imitation (LOW QUALITY / COUNTERFEIT). Analyze the weave density, stitch consistency, thread quality, and texture. Your response must be in JSON format with exactly two keys: 'verdict' (either 'GENUINE / HIGH QUALITY' or 'LOW QUALITY / COUNTERFEIT') and 'explanation' (A concise, 2-line explanation in Arabic explaining your visual reasoning about why it is high or low quality).",
                  },
                  {
                    "type": "image_url",
                    "image_url": {"url": "data:image/jpeg;base64,$base64Image"},
                  },
                ],
              },
            ],
            "max_tokens": 150,
            "temperature": 0.3,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      var jsonResponse = jsonDecode(response.body);
      try {
        // فك تشفير نص الـ JSON الراجع من ChatGPT
        String rawContent = jsonResponse['choices'][0]['message']['content'];
        Map<String, dynamic> parsedJson = jsonDecode(rawContent);

        return {
          "verdict": parsedJson['verdict']?.toString() ?? "UNKNOWN",
          "explanation":
              parsedJson['explanation']?.toString() ?? "لا توجد تفاصيل متوفرة.",
        };
      } catch (e) {
        throw Exception('Failed to parse Authenticity JSON.');
      }
    } else {
      throw Exception('OpenAI Authenticity Error: ${response.statusCode}');
    }
  }
}
