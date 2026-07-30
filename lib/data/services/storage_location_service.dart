import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';

/// يحدّد أين تُخزَّن بيانات المكتب: قاعدة البيانات والمرفقات والنسخ.
///
/// المسار يُقرأ **قبل** فتح قاعدة البيانات، لذا يُحمَّل مرة واحدة في
/// بداية التشغيل ويُحتفظ به في متغيّر متزامن؛ لا يمكن انتظار Future
/// داخل `LazyDatabase` قبل معرفة مسار الملف.
class StorageLocationService {
  StorageLocationService._();

  static const String _prefsKey = 'custom_storage_root';

  /// المسار الفعّال الحالي. يُملأ في [initialize] قبل أي وصول للقاعدة.
  static String? _activeRoot;

  /// المسار الافتراضي (مجلد مستندات المستخدم) للعرض عند غياب تخصيص.
  static String? _defaultRoot;

  /// هل المسار مخصَّص من المستخدم أم الافتراضي؟
  static bool _isCustom = false;

  static bool get isCustomPath => _isCustom;

  /// جذر بيانات المكتب. يجب استدعاء [initialize] قبله.
  static String get activeRoot {
    final root = _activeRoot;
    if (root == null) {
      throw StateError(
        'StorageLocationService.initialize() لم تُستدعَ بعد. '
        'يجب تحديد مسار التخزين قبل فتح قاعدة البيانات.',
      );
    }
    return root;
  }

  static String get defaultRoot => _defaultRoot ?? '';

  /// تحميل المسار المحفوظ. تُستدعى مرة في main قبل runApp.
  static Future<void> initialize() async {
    final docs = await getApplicationDocumentsDirectory();
    _defaultRoot = p.join(docs.path, AppConstants.appDataDirectoryName);

    String? saved;
    try {
      final prefs = await SharedPreferences.getInstance();
      saved = prefs.getString(_prefsKey);
    } catch (e) {
      debugPrint('تعذّر قراءة مسار التخزين المحفوظ: $e');
    }

    if (saved != null && saved.trim().isNotEmpty) {
      final dir = Directory(saved);
      if (await dir.exists() || await _canCreate(dir)) {
        _activeRoot = saved;
        _isCustom = true;
      } else {
        // المسار المحفوظ لم يعد صالحاً (قرص خارجي مفصول مثلاً).
        // العودة للافتراضي أفضل من تعطّل التطبيق عند الإقلاع.
        debugPrint('مسار التخزين المحفوظ غير متاح: $saved — العودة للافتراضي');
        _activeRoot = _defaultRoot;
        _isCustom = false;
      }
    } else {
      _activeRoot = _defaultRoot;
      _isCustom = false;
    }

    await Directory(_activeRoot!).create(recursive: true);
  }

  static Future<bool> _canCreate(Directory dir) async {
    try {
      await dir.create(recursive: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// مسار ملف قاعدة البيانات.
  static String get databaseFile =>
      p.join(activeRoot, AppConstants.defaultDatabaseName);

  /// مجلد المرفقات المشفّرة.
  static String get filesDir =>
      p.join(activeRoot, AppConstants.filesDirectoryName);

  /// مجلد النسخ الاحتياطية.
  static String get backupsDir =>
      p.join(activeRoot, AppConstants.backupsDirectoryName);

  /// التحقق من صلاحية مجلد قبل اعتماده.
  ///
  /// يرجع رسالة الخطأ، أو null إن كان صالحاً.
  static Future<String?> validate(String path) async {
    if (path.trim().isEmpty) return 'المسار فارغ';

    final dir = Directory(path);
    try {
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      // اختبار كتابة فعلي: وجود المجلد لا يعني إمكانية الكتابة فيه
      // (مجلدات النظام أو أقراص للقراءة فقط).
      final probe = File(p.join(path, '.write_test_${DateTime.now().microsecondsSinceEpoch}'));
      await probe.writeAsString('ok');
      await probe.delete();
    } catch (e) {
      return 'لا يمكن الكتابة في هذا المجلد: $e';
    }

    // منع اختيار مجلد داخل المسار الحالي أو العكس: النقل سيقع على نفسه.
    final current = p.normalize(activeRoot);
    final target = p.normalize(path);
    if (target == current) return 'هذا هو المسار الحالي بالفعل';
    if (p.isWithin(current, target)) {
      return 'لا يمكن اختيار مجلد داخل مجلد البيانات الحالي';
    }
    if (p.isWithin(target, current)) {
      return 'لا يمكن اختيار مجلد يحتوي مجلد البيانات الحالي';
    }

    return null;
  }

  /// حفظ المسار الجديد. لا ينقل البيانات — النقل مسؤولية المستدعي.
  static Future<void> persist(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, path);
    _activeRoot = path;
    _isCustom = true;
  }

  /// العودة إلى المسار الافتراضي.
  static Future<void> resetToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    _activeRoot = _defaultRoot;
    _isCustom = false;
  }

  /// حساب الحجم الإجمالي لمجلد (بالبايت) لعرضه قبل النقل.
  static Future<int> folderSize(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return 0;
    var total = 0;
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {
            // ملف قيد الاستخدام أو محذوف أثناء المسح — يُتخطّى.
          }
        }
      }
    } catch (e) {
      debugPrint('تعذّر حساب حجم المجلد: $e');
    }
    return total;
  }

  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes بايت';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} كيلوبايت';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} ميجابايت';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} جيجابايت';
  }
}
