import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class RetrainingPoolPage extends StatefulWidget {
  const RetrainingPoolPage({super.key});

  @override
  State<RetrainingPoolPage> createState() => _RetrainingPoolPageState();
}

class _RetrainingPoolPageState extends State<RetrainingPoolPage> {
  List _flaggedMistakes = [];
  final _box = Hive.box('fabricBox');

  @override
  void initState() {
    super.initState();
    _loadMistakes();
  }

  // تحميل الأخطاء المخزنة في قاعدة البيانات المحلية Hive
  void _loadMistakes() {
    setState(() {
      _flaggedMistakes = _box.get('flaggedMistakes', defaultValue: []);
    });
  }

  // حذف خطأ معين من القائمة
  Future<void> _deleteMistake(int index) async {
    List tempList = List.from(_flaggedMistakes);
    tempList.removeAt(index);
    await _box.put('flaggedMistakes', tempList);
    _loadMistakes();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Record deleted successfully.")),
    );
  }

  // مسح السلة بالكامل بعد الاستخراج وإعادة التدريب
  Future<void> _clearAll() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear Retraining Pool"),
        content: const Text(
          "Are you sure you want to delete all flagged images? This cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _box.put('flaggedMistakes', []);
              Navigator.pop(ctx);
              _loadMistakes();
            },
            child: const Text(
              "Clear All",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
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
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Model Retraining Pool',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_flaggedMistakes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.red),
              onPressed: _clearAll,
              tooltip: "Clear All",
            ),
        ],
      ),
      body: _flaggedMistakes.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.assignment_turned_in,
                      size: 70,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Retraining Pool is Empty!",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Flagged incorrect AI predictions will show up here to help train future models.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _flaggedMistakes.length,
              itemBuilder: (context, index) {
                var item = _flaggedMistakes[index];
                File imgFile = File(item['imagePath'] ?? "");

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // عرض مصغر للصورة المخطوء فيها
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: imgFile.existsSync()
                                  ? Image.file(
                                      imgFile,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      width: 80,
                                      height: 80,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.broken_image),
                                    ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.warning,
                                        color: Colors.redAccent,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        "Wrong AI Prediction:",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item['aiVerdict'] ?? "Unknown",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    "Date: ${item['timestamp']?.toString().substring(0, 16) ?? ""}",
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.grey,
                              ),
                              onPressed: () => _deleteMistake(index),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: Colors.black12),
                        const SizedBox(height: 12),
                        // عرض الملاحظة الصحيحة باللغة العربية
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.comment,
                              color: Colors.blue,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "User Correction:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item['userCorrection'] ?? "No note provided.",
                            textAlign:
                                TextAlign.right, // توجيه النص لليمين للعربية
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
