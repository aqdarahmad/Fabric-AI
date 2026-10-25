class FabricItem {
  final String name; // اسم العيب المكتشف، أو نوع القماش، أو نتيجة فحص الجودة
  final double
  confidence; // نسبة ثقة الذكاء الاصطناعي في النتيجة (بين 0.0 و 1.0)
  final bool
  isDefect; // صحيح (true) في حال وجود عيب أو إذا كان القماش مقلداً ورديء الجودة

  FabricItem({
    required this.name,
    required this.confidence,
    required this.isDefect,
  });
}
