import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';

/// نموذج بيانات إعدادات المكتب الأساسية
class OfficeSettingsModel {
  final String officeTitle;
  final String lawyerName;
  final String officeAddress;
  final String officePhone;

  const OfficeSettingsModel({
    required this.officeTitle,
    required this.lawyerName,
    required this.officeAddress,
    required this.officePhone,
  });

  OfficeSettingsModel copyWith({
    String? officeTitle,
    String? lawyerName,
    String? officeAddress,
    String? officePhone,
  }) {
    return OfficeSettingsModel(
      officeTitle: officeTitle ?? this.officeTitle,
      lawyerName: lawyerName ?? this.lawyerName,
      officeAddress: officeAddress ?? this.officeAddress,
      officePhone: officePhone ?? this.officePhone,
    );
  }
}

/// مزود حالة إعدادات المكتب (يدير تحميل وتحديث اسم المكتب واسم المحامي الأستاذ)
class OfficeSettingsNotifier extends StateNotifier<AsyncValue<OfficeSettingsModel>> {
  OfficeSettingsNotifier() : super(const AsyncValue.loading()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final title = prefs.getString(AppConstants.keyOfficeTitle) ?? AppConstants.defaultOfficeTitle;
      final lawyer = prefs.getString(AppConstants.keyLawyerName) ?? AppConstants.defaultLawyerName;
      final address = prefs.getString(AppConstants.keyOfficeAddress) ?? AppConstants.defaultAddress;
      final phone = prefs.getString(AppConstants.keyOfficePhone) ?? AppConstants.defaultPhone;

      state = AsyncValue.data(OfficeSettingsModel(
        officeTitle: title,
        lawyerName: lawyer,
        officeAddress: address,
        officePhone: phone,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateSettings({
    required String newTitle,
    required String newLawyerName,
    required String newAddress,
    required String newPhone,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyOfficeTitle, newTitle);
      await prefs.setString(AppConstants.keyLawyerName, newLawyerName);
      await prefs.setString(AppConstants.keyOfficeAddress, newAddress);
      await prefs.setString(AppConstants.keyOfficePhone, newPhone);

      state = AsyncValue.data(OfficeSettingsModel(
        officeTitle: newTitle,
        lawyerName: newLawyerName,
        officeAddress: newAddress,
        officePhone: newPhone,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final officeSettingsProvider = StateNotifierProvider<OfficeSettingsNotifier, AsyncValue<OfficeSettingsModel>>((ref) {
  return OfficeSettingsNotifier();
});
