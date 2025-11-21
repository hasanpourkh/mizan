// lib/src/pages/settings/update_page.dart
// صفحهٔ نمایش اطلاعات بروزرسانی و دانلود آن — route: /settings/update
// - نمایش نسخهٔ سرور، توضیحات، دکمهٔ دانلود و نمایش مسیر ذخیره‌شده.
// - از UpdateService استفاده میکند (core/update).
// - رفع ارور نوع nullable: در مواقعی که _downloadedPath کنترل شده است از '!' استفاده شده تا با نوع String سازگار باشد.
// کامنت فارسی مختصر برای هر بخش قرار دارد.

import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/update/update_service.dart';
import '../../core/update/update_model.dart';
import '../../core/notifications/notification_service.dart';

class UpdatePage extends StatefulWidget {
  const UpdatePage({super.key});

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  UpdateInfo? _info;
  bool _loading = true;
  bool _downloading = false;
  double _progress = 0.0;
  String? _downloadedPath;

  @override
  void initState() {
    super.initState();
    _check();
  }

  // بررسی بروزرسانی از سرور
  Future<void> _check() async {
    setState(() {
      _loading = true;
      _info = null;
      _downloadedPath = null;
    });
    try {
      final info = await UpdateService.fetchLatest();
      if (!mounted) return;
      setState(() {
        _info = info;
      });
    } catch (e) {
      NotificationService.showToast(context, 'خطا در بررسی آپدیت: $e',
          backgroundColor: Colors.orange);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // دانلود فایل آپدیت با نمایش پروگرس
  Future<void> _download() async {
    if (_info == null || _info!.url.isEmpty) {
      NotificationService.showToast(context, 'آدرس دانلود معتبر نیست',
          backgroundColor: Colors.orange);
      return;
    }
    setState(() {
      _downloading = true;
      _progress = 0.0;
      _downloadedPath = null;
    });
    try {
      final path =
          await UpdateService.downloadUpdate(_info!.url, onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      });
      if (path != null) {
        setState(() => _downloadedPath = path);
        NotificationService.showSuccess(
            context, 'دانلود کامل شد', 'فایل در:\n$path ذخیره شد');
      } else {
        NotificationService.showError(
            context, 'دانلود ناموفق', 'قادر به دانلود فایل نیست');
      }
    } catch (e) {
      NotificationService.showError(context, 'خطا', 'خطا در دانلود: $e');
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
          _progress = 0.0;
        });
      }
    }
  }

  Widget _buildInfo() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_info == null) {
      return const Center(child: Text('اطلاعاتی از سرور دریافت نشد'));
    }
    final published = _info!.publishedAt != null
        ? 'تاریخ: ${_info!.publishedAt!.toLocal()}'
        : '';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
            child: Text('نسخه روی سرور: ${_info!.version}',
                style: const TextStyle(fontWeight: FontWeight.w700))),
        if (_info!.mandatory)
          Chip(
              label: const Text('اجباری'),
              backgroundColor: Colors.red.shade100),
      ]),
      if (published.isNotEmpty)
        Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Text(published,
                style: const TextStyle(fontSize: 12, color: Colors.grey))),
      const SizedBox(height: 12),
      const Text('توضیحات تغییرات:',
          style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Expanded(
        child: SingleChildScrollView(
          child: SelectableText(
              _info!.notes.isNotEmpty ? _info!.notes : 'بدون توضیحات'),
        ),
      ),
      const SizedBox(height: 12),
      if (_downloading) ...[
        LinearProgressIndicator(value: _progress),
        const SizedBox(height: 8),
        Text('در حال دانلود: ${(_progress * 100).toStringAsFixed(0)}%'),
      ],
      if (!_downloading)
        Row(children: [
          Expanded(
              child: FilledButton.tonal(
                  onPressed: _download,
                  child: Text(
                      _downloadedPath == null ? 'دانلود' : 'دانلود مجدد'))),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: _check, child: const Text('بررسی دوباره')),
        ]),
      const SizedBox(height: 8),
      if (_downloadedPath != null)
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('فایل دانلود شده:'),
          SelectableText(_downloadedPath!),
          const SizedBox(height: 6),
          Row(children: [
            FilledButton.tonal(
                onPressed: () {
                  try {
                    // توجه: _downloadedPath در اینجا غیر-null است (شرط بالا)
                    if (Platform.isWindows) {
                      // نمایش در اکسپلورر و انتخاب فایل
                      Process.run('explorer', ['/select,', _downloadedPath!]);
                    } else if (Platform.isMacOS) {
                      // نمایش در Finder و انتخاب فایل
                      Process.run('open', ['-R', _downloadedPath!]);
                    } else if (Platform.isLinux) {
                      // باز کردن پوشه حاوی فایل در توزیع لینوکس
                      Process.run(
                          'xdg-open', [File(_downloadedPath!).parent.path]);
                    }
                  } catch (_) {}
                },
                child: const Text('نمایش در پوشه')),
          ]),
        ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بروزرسانی برنامه'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SizedBox(
          height: 420,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: _buildInfo(),
            ),
          ),
        ),
      ),
    );
  }
}
