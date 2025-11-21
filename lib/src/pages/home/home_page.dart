// lib/src/pages/home/home_page.dart
// صفحه داشبورد (Home) — کارتها، آمار خلاصه، لیست عملیات اخیر و دکمههای تعاملی.
// اصلاحات: رنگ متنها وابسته به Theme شدند تا در حالت تیره خوانا باشند.
// کامنتهای فارسی برای هر بخش قرار دارد.

import 'package:flutter/material.dart';
import '../../core/notifications/notification_service.dart';
import 'package:intl/intl.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // نمونه دادههای آماری (در عمل اینها از DB یا API گرفته میشوند)
  Map<String, String> _stats() {
    final f = NumberFormat.decimalPattern('fa');
    return {
      'درخواستها (امروز)': f.format(12),
      'لایسنسهای فعال': f.format(24),
      'لایسنسهای منقضی': f.format(3),
      'فروش ماه': f.format(1250000),
    };
  }

  // لیست اقدامات اخیر نمونه
  List<Map<String, String>> _recent() {
    return [
      {'title': 'درخواست ثبتشدگان جدید', 'time': '۱۴۰۲/۰۸/۰۱'},
      {'title': 'لایسنس برای user@example.com فعال شد', 'time': '۱۴۰۲/۰۷/۳۰'},
      {'title': 'درخواست user2@example.com رد شد', 'time': '۱۴۰۲/۰۷/۲۸'},
    ];
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats();
    final recent = _recent();
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleLarge ??
        const TextStyle(fontSize: 28, fontWeight: FontWeight.bold);
    final subtitleStyle = theme.textTheme.bodyMedium ??
        const TextStyle(fontSize: 14, color: Colors.black54);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // سربرگ داشبورد
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('داشبورد', style: titleStyle.copyWith(fontSize: 28)),
                    const SizedBox(height: 6),
                    Text('خلاصهٔ وضعیت سیستم و عملیات اخیر',
                        style: subtitleStyle),
                  ],
                ),
              ),
              // دکمه اعلان نمونه
              FilledButton.tonal(
                onPressed: () {
                  NotificationService.showSuccess(
                      context, 'اطلاع', 'این یک اعلان نمونه موفق است');
                },
                child: const Text('نمایش اعلان نمونه'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () {
                  NotificationService.showToast(context, 'ذخیره انجام شد');
                },
                child: const Text('ذخیره'),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ردیف کارتهای آمار
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: stats.entries.map((e) {
              return _StatCard(title: e.key, value: e.value);
            }).toList(),
          ),

          const SizedBox(height: 20),

          // بخش عملیات اخیر و کارتهای سریع
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // لیست عملیات اخیر
              Expanded(
                flex: 2,
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('عملیات اخیر',
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontSize: 18)),
                        const SizedBox(height: 12),
                        ...recent.map((r) {
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(r['title'] ?? '',
                                style: theme.textTheme.bodyLarge),
                            subtitle: Text(r['time'] ?? '',
                                style: theme.textTheme.bodyMedium),
                            trailing: IconButton(
                              icon: Icon(Icons.open_in_new,
                                  color: theme.iconTheme.color),
                              onPressed: () {
                                NotificationService.showToast(
                                    context, 'نمایش جزئیات...');
                              },
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                              onPressed: () {
                                NotificationService.showToast(
                                    context, 'نمایش همه عملیات');
                              },
                              child: const Text('نمایش همه')),
                        )
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // ستون کناری کارتهای عملیاتی (سریع)
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    _ActionCard(
                        icon: Icons.person_add,
                        label: 'ثبت نام جدید',
                        color: Colors.teal,
                        onTap: () {
                          Navigator.of(context).pushNamed('/register');
                        }),
                    const SizedBox(height: 12),
                    _ActionCard(
                        icon: Icons.person,
                        label: 'پروفایل',
                        color: Colors.indigo,
                        onTap: () {
                          Navigator.of(context).pushNamed('/profile');
                        }),
                    const SizedBox(height: 12),
                    _ActionCard(
                        icon: Icons.settings,
                        label: 'تنظیمات',
                        color: Colors.orange,
                        onTap: () {
                          Navigator.of(context).pushNamed('/settings');
                        }),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 20),

          // بخش کمک / وضعیت سیستم
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 36, color: theme.iconTheme.color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'وضعیت سرویس لایسنس: سالم. (برای تست عملکرد تایید/رد درخواست، از پنل ادمین وردپرس استفاده کنید.)',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      NotificationService.showToast(
                          context, 'در حال بررسی وضعیت آنلاین...');
                    },
                    child: const Text('بررسی آنلاین'),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

// ویجت کارت آمار کوچک
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.bodyMedium?.copyWith(fontSize: 13) ??
        const TextStyle(fontSize: 13, color: Colors.black54);
    final valueStyle = theme.textTheme.titleLarge
            ?.copyWith(fontSize: 20, fontWeight: FontWeight.bold) ??
        const TextStyle(fontSize: 20, fontWeight: FontWeight.bold);

    return SizedBox(
      width: 230,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: titleStyle),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(value, style: valueStyle),
                  const Spacer(),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor:
                        theme.colorScheme.primary.withOpacity(0.15),
                    child: Icon(Icons.show_chart,
                        color: theme.colorScheme.primary),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ویجت کارت عملیاتی
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color,
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              Icon(Icons.arrow_forward_ios,
                  size: 14, color: theme.iconTheme.color ?? Colors.grey)
            ],
          ),
        ),
      ),
    );
  }
}
