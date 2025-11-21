// lib/src/pages/core/db/app_database.dart
// این فایل یک re-export محلی برای مسیرهای قدیمیِ pages/core/... است
// توضیح خیلی خیلی کوتاه (فارسی):
// بعضی فایل‌ها در کد پروژه از مسیر pages/core/db/app_database.dart import می‌کنند.
// برای جلوگیری از تداخل و ambiguous exports این stub را طوری تنظیم کردیم
// که مستقیم به database_facade.dart ارجاع دهد (منبع واحد).
// اگر می‌خواهی همه importها مستقیماً app_database.dart را صدا بزنند، اطلاع بده تا همان را هماهنگ کنم.

export '../../../core/db/database_facade.dart';
