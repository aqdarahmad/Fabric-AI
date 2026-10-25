import 'dart:convert';
import 'package:http/http.dart' as http;
import '../screens/models/fabric_item.dart'; // مسار الاستيراد للموديل

class FabricApiService {
  // مفتاح الـ API الفعلي الخاص بك لـ OpenAI ليعمل فحص نوع القماش وفحص الأصالة والجودة
   static String get _openaiApiKey =>
      dotenv.env['OPENAI_API_KEY'] ?? '';

  // 1. وظيفة فحص العيوب (Roboflow) - بقيت كما هي دون تغيير لضمان عملها المستقر
  static Future<Map<String, dynamic>> runDefectDetection({
    required String base64Image,
    required double confidenceThreshold,
  }) async {
    String apiKey = "udRjLbfGnQ8wnXINPPCB";
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

  // 2. الموديل الثاني المطور: تحليل تفصيلي لنوع القماش وخصائصه وإرجاع البيانات كـ JSON مفصل
  static Future<Map<String, dynamic>> runFabricTypeDetection({
    required String base64Image,
  }) async {
    if (_openaiApiKey.isEmpty || _openaiApiKey.startsWith("ضع_هنا")) {
      throw Exception("لم يتم إدخال مفتاح الـ API الخاص بـ OpenAI.");
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
            "response_format": {
              "type": "json_object",
            }, // تفعيل استجابة JSON الصارمة
            "messages": [
              {
                "role": "user",
                "content": [
                  {
                    "type": "image_url",
                    "image_url": {"url": "data:image/jpeg;base64,$base64Image"},
                  },
                  {
                    "type": "text",
                    "text":
                        "Analyze this image and identify the fabric. You must respond in JSON format with the following keys in Arabic:\n"
                        "- 'fabric_type': The main type (choose from: Cotton, Polyester, Silk, Wool, Linen, Denim, Leather, Knitwear, Mixed)\n"
                        "- 'composition': Estimated composition (e.g., '90% قطن، 10% بوليستر')\n"
                        "- 'texture': Short description of the expected texture/feel\n"
                        "- 'best_uses': List of 3 common garments or use cases for this fabric\n"
                        "- 'care_instructions': 2 key care or washing recommendations.",
                  },
                ],
              },
            ],
            "max_tokens": 300,
            "temperature": 0.3,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      var jsonResponse = jsonDecode(response.body);
      try {
        String rawContent = jsonResponse['choices'][0]['message']['content'];
        return jsonDecode(rawContent); // نرجع القاموس المنسق مباشرة
      } catch (e) {
        throw Exception('Failed to parse Fabric Type JSON.');
      }
    } else {
      throw Exception('OpenAI Error: ${response.statusCode}');
    }
  }

  // 3. الموديل الثالث المطور: فحص الجودة والمطابقة للأصلي مع مراعاة الصور الهيكلية للقطع الكاملة والصور المقربة للأقمشة
  static Future<Map<String, dynamic>> runFabricAuthenticityCheck({
    required String base64Image,
  }) async {
    if (_openaiApiKey.isEmpty || _openaiApiKey.startsWith("ضع_هنا")) {
      throw Exception("لم يتم إدخال مفتاح الـ API الخاص بـ OpenAI.");
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
            "response_format": {"type": "json_object"},
            "messages": [
              {
                "role": "user",
                "content": [
                  {
                    "type": "image_url",
                    "image_url": {"url": "data:image/jpeg;base64,$base64Image"},
                  },
                  {
                    "type": "text",
                    "text":
                        "You are an expert textile forensic inspector. Your job is to classify this image as 'PREMIUM / ORIGINAL QUALITY' or 'STANDARD / COMMERCIAL GRADE' or 'LOW QUALITY / SUSPECTED COUNTERFEIT'.\n\n"
                        "To prevent false positives and hallucinations, apply this strict inspection logic:\n\n"
                        "1. DETECT THE SCENE TYPE FIRST:\n"
                        "- Is it a CATALOG / STUDIO / MOCK-UP photo? (Characterized by a solid white, solid grey, or clean isolated background, with perfect digital rendering and studio lighting).\n"
                        "- Is it a REAL-WORLD photo? (Taken on a mobile phone, showing a background like a room, hand, hanger, shop, or human body in non-studio setting).\n"
                        "- Is it a MACRO/CLOSE-UP? (Extremely zoomed-in showing weave patterns).\n\n"
                        "2. APPLY THE CRITICAL DECISION RULES:\n"
                        "- RULE FOR CATALOG/STUDIO PHOTOS: If the image is a clean catalog/studio product shot with a solid white or grey background, you MUST automatically classify it as 'PREMIUM / ORIGINAL QUALITY' with a score between 95% and 100%. Do NOT hallucinate defects. The design curves, artistic gradients, and shadows of a digital render are NOT manufacturing flaws. They represent the official pristine brand standard.\n"
                        "- RULE FOR REAL-WORLD GARMENT PHOTOS: Analyze the physical sewing. Look for visible cheap-labor flaws: puckered/wrinkled seams, crooked or non-centered logos, asymmetrical collar cuts, or faded, blurry prints with visible ink bleeding. If these flaws are clearly visible in the real-world photo, classify as 'LOW QUALITY / SUSPECTED COUNTERFEIT'.\n"
                        "- RULE FOR MACRO PHOTOS: Evaluate weave density and yarn consistency.\n\n"
                        "Your response must be in JSON format with exactly these keys:\n"
                        "- 'verdict': One of the three categories mentioned above.\n"
                        "- 'quality_score': An integer from 30 to 100 representing the score.\n"
                        "- 'indicators': A list of exactly 3 visual observations in Arabic supporting your verdict (e.g., 'تصميم رسمي معتمد وخالٍ تماماً من عيوب التصنيع الهيكلية', 'تناسق كامل في الأبعاد والياقة والقصة الرقمية').\n"
                        "- 'explanation': A concise, professional 2-line explanation in Arabic describing your visual reasoning.",
                  },
                ],
              },
            ],
            "max_tokens": 400,
            "temperature":
                0.0, // صفر تماماً لفرض الالتزام الكامل بالقواعد ومنع الاجتهاد الخاطئ من الموديل
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      var jsonResponse = jsonDecode(response.body);
      try {
        String rawContent = jsonResponse['choices'][0]['message']['content'];
        return jsonDecode(rawContent);
      } catch (e) {
        throw Exception('Failed to parse Authenticity JSON.');
      }
    } else {
      throw Exception('OpenAI Authenticity Error: ${response.statusCode}');
    }
  }
}
