// lib/src/core/utils/image_utils.dart
// Utility برای ذخیره و تغییر اندازه تصاویر محصول بدون استفاده از پکیج خارجی.
// - از API داخلی Flutter (dart:ui) برای خواندن و resize تصویر استفاده می‌کند.
// - اگر تصویر کوچکتر یا مساوی maxSize باشد، فقط کپی میشود (بدون تبدیل).
// - اگر تصویر بزرگتر باشد، تصویر با نسبت حفظ‌شده به حداکثر maxSize بریده (scale) و به PNG تبدیل شده و ذخیره می‌شود.
// - بازگشتی: Map { 'path': String? , 'resized': bool, 'message': String? }
// - توجه: خروجی resize همیشه PNG خواهد بود (برای سازگاری با toByteData).
//
// توضیح فنی مختصر (فارسی):
// - برای خواندن اندازهٔ تصویر از decodeImageFromList استفاده می‌کنیم.
// - برای resize از instantiateImageCodec با targetWidth/targetHeight استفاده شده و سپس frame را به ByteData (PNG) تبدیل و ذخیره میکنیم.
// - این پیاده‌سازی نیازی به dependency خارجی ندارد و در محیط Flutter (موبایل/دسکتاپ) کار می‌کند.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:path/path.dart' as p;

/// Resize و ذخیره تصویر بدون پکیج خارجی
/// پارامترها:
/// - srcPath: مسیر فایل منبع
/// - destDir: پوشهٔ مقصد (ایجاد میشود در صورت عدم وجود)
/// - fileName: نام فایل خروجی (در صورت تبدیل به PNG پسوند به .png تغییر میکند)
/// - maxSize: حداکثر مقدار هر ضلع (پیشفرض 500)
/// بازگشت: Map { 'path': String? , 'resized': bool, 'message': String? }
Future<Map<String, dynamic>> resizeAndSave({
  required String srcPath,
  required String destDir,
  required String fileName,
  int maxSize = 500,
}) async {
  final srcFile = File(srcPath);
  if (!await srcFile.exists()) {
    return {'path': null, 'resized': false, 'message': 'فایل منبع یافت نشد'};
  }

  try {
    final bytes = await srcFile.readAsBytes();

    // ابتدا اندازهٔ اصلی تصویر را بدست می‌آوریم
    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(bytes, (ui.Image img) {
      completer.complete(img);
    });
    final ui.Image originalImage = await completer.future;
    final int width = originalImage.width;
    final int height = originalImage.height;

    // اطمینان از وجود پوشه مقصد
    final dir = Directory(destDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final ext = p.extension(fileName).toLowerCase();

    // اگر تصویر کوچکتر یا مساوی maxSize است: فقط کپی کن و همان پسوند را نگه دار
    if (width <= maxSize && height <= maxSize) {
      final destPath = p.join(destDir, fileName);
      await srcFile.copy(destPath);
      return {
        'path': destPath,
        'resized': false,
        'message':
            'تصویر کوچکتر یا برابر ${maxSize}px است؛ بدون تغییر اندازه کپی شد'
      };
    }

    // محاسبه ابعاد جدید (proportional) بطوریکه بیشترین ضلع == maxSize
    double ratio;
    if (width > height) {
      ratio = maxSize / width;
    } else {
      ratio = maxSize / height;
    }
    final int targetW = (width * ratio).round();
    final int targetH = (height * ratio).round();

    // استفاده از instantiateImageCodec برای resize (targetWidth/Height)
    final codec = await ui.instantiateImageCodec(bytes,
        targetWidth: targetW, targetHeight: targetH);
    final frame = await codec.getNextFrame();
    final ui.Image resizedImage = frame.image;

    // تبدیل به PNG bytes
    final byteData =
        await resizedImage.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      return {
        'path': null,
        'resized': false,
        'message': 'خطا در تولید بایت تصویر'
      };
    }
    final Uint8List pngBytes = byteData.buffer.asUint8List();

    // اگر نام فایل ورودی پسوندی غیر-png داشت، خروجی را با پسوند .png ذخیره کن
    String outFileName = fileName;
    final allowedPngExt = ['.png'];
    if (!allowedPngExt.contains(ext)) {
      final base = p.basenameWithoutExtension(fileName);
      outFileName = '$base.png';
    }

    final destPath = p.join(destDir, outFileName);
    final outFile = File(destPath);
    await outFile.writeAsBytes(pngBytes);

    return {'path': destPath, 'resized': true, 'message': null};
  } catch (e) {
    return {
      'path': null,
      'resized': false,
      'message': 'خطا در پردازش تصویر: $e'
    };
  }
}
