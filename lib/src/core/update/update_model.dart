// lib/src/core/update/update_model.dart
// مدل سادهٔ اطلاعات بروزرسانی (UpdateInfo)
// کامنت فارسی مختصر: نگهداری نسخه، توضیحات، آدرس فایل دانلود و آیا اجباری هست یا نه.

class UpdateInfo {
  final String version; // رشته نسخه (مثلاً "1.0.1")
  final String
      notes; // متن تغییرات / changelog (می‌تواند HTML یا متن ساده باشد)
  final String url; // آدرس فایل قابل دانلود (مثلاً zip/exe/apk)
  final bool mandatory; // آیا این آپدیت اجباری است؟
  final int? size; // اندازه تقریبی بایت (اختیاری)
  final DateTime? publishedAt; // تاریخ انتشار (اختیاری)

  UpdateInfo({
    required this.version,
    required this.notes,
    required this.url,
    this.mandatory = false,
    this.size,
    this.publishedAt,
  });

  // ساخت از JSON بازگشتی از سرور
  factory UpdateInfo.fromJson(Map<String, dynamic> j) {
    DateTime? p;
    try {
      if (j.containsKey('published_at') && j['published_at'] != null) {
        p = DateTime.tryParse(j['published_at'].toString());
      }
    } catch (_) {
      p = null;
    }
    return UpdateInfo(
      version: j['version']?.toString() ?? '',
      notes: j['notes']?.toString() ?? '',
      url: j['url']?.toString() ?? '',
      mandatory: (j['mandatory'] == true || j['mandatory'] == 1),
      size: j['size'] is int
          ? j['size'] as int
          : (j['size'] != null ? int.tryParse(j['size'].toString()) : null),
      publishedAt: p,
    );
  }
}
