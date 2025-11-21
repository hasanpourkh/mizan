// lib/src/providers/onboarding_provider.dart
// Provider کامل برای ویـزارد Onboarding (ثبت تنظیمات اولیهٔ کسب‌وکار).
// - شامل فیلدها/گترها/ستترها برای همهٔ مقادیری که صفحات onboarding انتظار دارند.
// - متدهای کمکی: next(), back(), applyStep1(), saveProfile(), loadBusinessProfile()، و setError/clearError.
// - ذخیرهٔ نهایی با AppDatabase.saveBusinessProfile انجام میشود و تنظیمات کلی با ConfigManager.saveConfig.
// - تمام متدها با notifyListeners() هماهنگ شده‌اند.
// کامنت‌های فارسی مختصر برای هر بخش قرار دارد.

import 'package:flutter/material.dart';
import '../core/db/app_database.dart';
import '../core/config/config_manager.dart';

class OnboardingProvider extends ChangeNotifier {
  OnboardingProvider() {
    _initDefaults();
    // بارگذاری پروفایل موجود (اگر باشد)
    loadBusinessProfile();
  }

  // ========== مقداردهی اولیه و state داخلی ==========
  void _initDefaults() {
    _step = 1;
    _loading = false;
    _error = null;

    // مقادیر پیشفرض مرحله اول
    _language = 'fa';
    _businessNameStep1 = '';

    // مقادیر پیشفرض مرحله دوم (جزئیات)
    _businessName = '';
    _legalName = '';
    _activityArea = '';
    _nationalId = '';
    _economicCode = '';
    _registrationNumber = '';
    _country = '';
    _province = '';
    _city = '';
    _postalCode = '';
    _phone = '';
    _fax = '';
    _address = '';
    _website = '';
    _email = '';
    _businessType = '';

    // پیشفرض‌های مالی/تنظیمات (مرحله سوم)
    _vatRate = 0.0;
    _fiscalStart = '';
    _fiscalEnd = '';
    _fiscalTitle = '';
    _inventorySystem = false;
    _inventoryValuation = 'FIFO';
    _multiCurrency = false;
    _inventoryEnabled = false;
    _currency = 'IRR';
    _calendar = 'gregorian';
  }

  // وضعیت wizard
  int _step = 1;
  bool _loading = false;
  String? _error;

  // step1
  String _businessNameStep1 = '';
  String _language = 'fa';

  // step2 (business details)
  String _businessName = '';
  String _legalName = '';
  String _activityArea = '';
  String _nationalId = '';
  String _economicCode = '';
  String _registrationNumber = '';
  String _country = '';
  String _province = '';
  String _city = '';
  String _postalCode = '';
  String _phone = '';
  String _fax = '';
  String _address = '';
  String _website = '';
  String _email = '';
  String _businessType = '';

  // step3 (finance/settings)
  double _vatRate = 0.0;
  String _fiscalStart = '';
  String _fiscalEnd = '';
  String _fiscalTitle = '';
  bool _inventorySystem = false;
  String _inventoryValuation = 'FIFO';
  bool _multiCurrency = false;
  bool _inventoryEnabled = false;
  String _currency = 'IRR';
  String _calendar = 'gregorian';

  // ========== getters ==========
  int get step => _step;
  bool get loading => _loading;
  String? get error => _error;

  String get businessNameStep1 => _businessNameStep1;
  String get language => _language;

  String get businessName => _businessName;
  String get legalName => _legalName;
  String get activityArea => _activityArea;
  String get nationalId => _nationalId;
  String get economicCode => _economicCode;
  String get registrationNumber => _registrationNumber;
  String get country => _country;
  String get province => _province;
  String get city => _city;
  String get postalCode => _postalCode;
  String get phone => _phone;
  String get fax => _fax;
  String get address => _address;
  String get website => _website;
  String get email => _email;
  String get businessType => _businessType;

  double get vatRate => _vatRate;
  String get fiscalStart => _fiscalStart;
  String get fiscalEnd => _fiscalEnd;
  String get fiscalTitle => _fiscalTitle;
  bool get inventorySystem => _inventorySystem;
  String get inventoryValuation => _inventoryValuation;
  bool get multiCurrency => _multiCurrency;
  bool get inventoryEnabled => _inventoryEnabled;
  String get currency => _currency;
  String get calendar => _calendar;

  // ========== setters (همراه notifyListeners) ==========
  set step(int v) {
    if (v == _step) return;
    _step = v;
    notifyListeners();
  }

  set businessNameStep1(String v) {
    _businessNameStep1 = v;
    notifyListeners();
  }

  set language(String v) {
    _language = v;
    notifyListeners();
  }

  set businessName(String v) {
    _businessName = v;
    notifyListeners();
  }

  set legalName(String v) {
    _legalName = v;
    notifyListeners();
  }

  set activityArea(String v) {
    _activityArea = v;
    notifyListeners();
  }

  set nationalId(String v) {
    _nationalId = v;
    notifyListeners();
  }

  set economicCode(String v) {
    _economicCode = v;
    notifyListeners();
  }

  set registrationNumber(String v) {
    _registrationNumber = v;
    notifyListeners();
  }

  set country(String v) {
    _country = v;
    notifyListeners();
  }

  set province(String v) {
    _province = v;
    notifyListeners();
  }

  set city(String v) {
    _city = v;
    notifyListeners();
  }

  set postalCode(String v) {
    _postalCode = v;
    notifyListeners();
  }

  set phone(String v) {
    _phone = v;
    notifyListeners();
  }

  set fax(String v) {
    _fax = v;
    notifyListeners();
  }

  set address(String v) {
    _address = v;
    notifyListeners();
  }

  set website(String v) {
    _website = v;
    notifyListeners();
  }

  set email(String v) {
    _email = v;
    notifyListeners();
  }

  set businessType(String v) {
    _businessType = v;
    notifyListeners();
  }

  set vatRate(double v) {
    _vatRate = v;
    notifyListeners();
  }

  set fiscalStart(String v) {
    _fiscalStart = v;
    notifyListeners();
  }

  set fiscalEnd(String v) {
    _fiscalEnd = v;
    notifyListeners();
  }

  set fiscalTitle(String v) {
    _fiscalTitle = v;
    notifyListeners();
  }

  set inventorySystem(bool v) {
    _inventorySystem = v;
    notifyListeners();
  }

  set inventoryValuation(String v) {
    _inventoryValuation = v;
    notifyListeners();
  }

  set multiCurrency(bool v) {
    _multiCurrency = v;
    notifyListeners();
  }

  set inventoryEnabled(bool v) {
    _inventoryEnabled = v;
    notifyListeners();
  }

  set currency(String v) {
    _currency = v;
    notifyListeners();
  }

  set calendar(String v) {
    _calendar = v;
    notifyListeners();
  }

  // ========== navigation helpers ==========
  void next() {
    if (_step < 3) {
      _step++;
      notifyListeners();
    }
  }

  void back() {
    if (_step > 1) {
      _step--;
      notifyListeners();
    }
  }

  // applyStep1: اعتبارسنجی و انتقال businessNameStep1 به businessName (در صورت OK)
  bool applyStep1() {
    _error = null;
    final name = _businessNameStep1.trim();
    if (name.isEmpty) {
      _error = 'نام فروشگاه را وارد کنید';
      notifyListeners();
      return false;
    }
    _businessName = name;
    notifyListeners();
    return true;
  }

  // ========== error helpers ==========
  // متد عمومی برای ست کردن پیام خطا از بیرون (onboarding_wizard و صفحات)
  void setError(String? msg) {
    _error = msg;
    notifyListeners();
  }

  // پاکسازی خطا
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ========== persistence ==========
  // ذخیره پروفایل کسب‌وکار در DB و ذخیرهٔ تنظیمات مالی/فاکتور
  Future<bool> saveProfile() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final payload = <String, dynamic>{
        'business_name': _businessName,
        'legal_name': _legalName,
        'activity_area': _activityArea,
        'national_id': _nationalId,
        'economic_code': _economicCode,
        'registration_number': _registrationNumber,
        'country': _country,
        'province': _province,
        'city': _city,
        'postal_code': _postalCode,
        'phone': _phone,
        'fax': _fax,
        'address': _address,
        'website': _website,
        'email': _email,
        'business_type': _businessType,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      };

      // ذخیرهٔ پروفایل در جدول business
      await AppDatabase.saveBusinessProfile(payload);

      // ذخیرهٔ تنظیمات کلی در ConfigManager
      final cfg = <String, dynamic>{
        'vat_rate': _vatRate.toString(),
        'fiscal_start': _fiscalStart,
        'fiscal_end': _fiscalEnd,
        'fiscal_title': _fiscalTitle,
        'inventory_system': _inventorySystem ? '1' : '0',
        'inventory_valuation': _inventoryValuation,
        'multi_currency': _multiCurrency ? '1' : '0',
        'inventory_enabled': _inventoryEnabled ? '1' : '0',
        'currency': _currency,
        'calendar': _calendar,
        'invoice_prefix': 'INV',
      };
      await ConfigManager.saveConfig(cfg);

      // بارگذاری مجدد پروفایل برای همسانی state
      await loadBusinessProfile();

      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _loading = false;
      _error = 'خطا در ذخیره‌سازی اطلاعات: $e';
      notifyListeners();
      return false;
    }
  }

  // بارگذاری پروفایل کسب‌وکار از DB و پر کردن فیلدها (در صورتی که موجود باشد)
  Future<void> loadBusinessProfile() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final bp = await AppDatabase.getBusinessProfile();
      if (bp != null) {
        _businessName = bp['business_name']?.toString() ?? _businessName;
        _legalName = bp['legal_name']?.toString() ?? _legalName;
        _activityArea = bp['activity_area']?.toString() ?? _activityArea;
        _nationalId = bp['national_id']?.toString() ?? _nationalId;
        _economicCode = bp['economic_code']?.toString() ?? _economicCode;
        _registrationNumber =
            bp['registration_number']?.toString() ?? _registrationNumber;
        _country = bp['country']?.toString() ?? _country;
        _province = bp['province']?.toString() ?? _province;
        _city = bp['city']?.toString() ?? _city;
        _postalCode = bp['postal_code']?.toString() ?? _postalCode;
        _phone = bp['phone']?.toString() ?? _phone;
        _fax = bp['fax']?.toString() ?? _fax;
        _address = bp['address']?.toString() ?? _address;
        _website = bp['website']?.toString() ?? _website;
        _email = bp['email']?.toString() ?? _email;
        _businessType = bp['business_type']?.toString() ?? _businessType;
      }

      // بارگذاری برخی تنظیمات کلی از ConfigManager (در صورت وجود)
      try {
        final vat = await ConfigManager.get('vat_rate');
        if (vat != null) _vatRate = double.tryParse(vat) ?? _vatRate;
        final fs = await ConfigManager.get('fiscal_start');
        if (fs != null) _fiscalStart = fs;
        final fe = await ConfigManager.get('fiscal_end');
        if (fe != null) _fiscalEnd = fe;
        final ft = await ConfigManager.get('fiscal_title');
        if (ft != null) _fiscalTitle = ft;
        final invSys = await ConfigManager.get('inventory_system');
        if (invSys != null) _inventorySystem = (invSys == '1');
        final invVal = await ConfigManager.get('inventory_valuation');
        if (invVal != null) _inventoryValuation = invVal;
        final mc = await ConfigManager.get('multi_currency');
        if (mc != null) _multiCurrency = (mc == '1');
        final ie = await ConfigManager.get('inventory_enabled');
        if (ie != null) _inventoryEnabled = (ie == '1');
        final cur = await ConfigManager.get('currency');
        if (cur != null) _currency = cur;
        final cal = await ConfigManager.get('calendar');
        if (cal != null) _calendar = cal;
      } catch (_) {}
    } catch (e) {
      _error = 'خطا در خواندن پروفایل: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
