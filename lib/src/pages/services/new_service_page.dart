// lib/src/pages/services/new_service_page.dart
// فرم افزودن/ویرایش خدمت — از ServiceFormWidget برای بخش فرم استفاده میکند.
// - اگر param editing داده شود فرم در حالت ویرایش قرار میگیرد.
// - پس از ذخیره کاربر به لیست برمیگردد یا اگر از طریق push باز شده بسته میشود.

import 'package:flutter/material.dart';
import 'package:mizan/src/core/db/daos/services_dao.dart';
import '../../core/db/app_database.dart';
import '../../core/notifications/notification_service.dart';
import 'service_form_widget.dart';

class NewServicePage extends StatefulWidget {
  final Map<String, dynamic>? editing;
  const NewServicePage({super.key, this.editing});

  @override
  State<NewServicePage> createState() => _NewServicePageState();
}

class _NewServicePageState extends State<NewServicePage> {
  bool _saving = false;

  Future<void> _onSave(Map<String, dynamic> payload) async {
    setState(() => _saving = true);
    try {
      await AppDatabase.saveService(payload);
      NotificationService.showSuccess(context, 'ذخیره شد', 'خدمت ذخیره شد',
          onOk: () {
        Navigator.of(context).pop();
      });
    } catch (e) {
      NotificationService.showError(context, 'خطا', 'ذخیره انجام نشد: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing;
    return Scaffold(
      appBar:
          AppBar(title: Text(editing != null ? 'ویرایش خدمت' : 'خدمت جدید')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
            child: ServiceFormWidget(
                initial: editing, onSave: _onSave, saving: _saving)),
      ),
    );
  }
}
