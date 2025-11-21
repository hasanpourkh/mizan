// lib/src/pages/placeholder_page.dart
// صفحهٔ ساده placeholder برای مسیرهایی که فعلاً محتوای کامل ندارند.
// این صفحه عنوان میگیرد و یک متن توضیحی نمایش میدهد.
// کامنت فارسی مختصر قرار دارد.

import 'package:flutter/material.dart';

class PlaceholderPage extends StatelessWidget {
  final String title;
  const PlaceholderPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Text('صفحهٔ "$title" در حال ساخت است.',
            style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}
