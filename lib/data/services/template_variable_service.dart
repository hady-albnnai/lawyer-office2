/// خدمة اكتشاف وملء متغيرات قوالب العقود
///
/// هذه الخدمة هي الأساس الذي سيبني عليه الذكاء الاصطناعي لاحقاً:
/// - تكتشف المتغيرات {{مثل_هذا}} في ملفات Word (.docx)
/// - تصنفها حسب نوعها (شخص، مبلغ، تاريخ، نص)
/// - تملأها تلقائياً من بيانات الأطراف
/// - تسجل كل تفاعل ليتعلم منه AI
///
/// آخر تحديث: 2026-08-06
library;

import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:drift/drift.dart';
import 'package:xml/xml.dart' as xml;
import '../database/database.dart';

/// متغير مكتشف في قالب عقد
class TemplateVariable {
  final String name;
  final String type; // person, money, date, text, property, number
  final bool autoFillFromParty;
  final int? partyOrder; // أي طرف يملأ هذا المتغير (1 = أول، 2 = ثاني)
  final String? suggestedValue;

  TemplateVariable({
    required this.name,
    required this.type,
    this.autoFillFromParty = false,
    this.partyOrder,
    this.suggestedValue,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    'autoFillFromParty': autoFillFromParty,
    'partyOrder': partyOrder,
  };
}

class TemplateVariableService {
  final AppDatabase db;
  TemplateVariableService(this.db);

  // ---------------------------------------------------------------------------
  // 1. اكتشاف المتغيرات في نص القالب
  // ---------------------------------------------------------------------------

  /// اكتشاف كل المتغيرات {{...}} في النص
  List<TemplateVariable> detectVariables(String templateText) {
    final regex = RegExp(r'\{\{([^}]+)\}\}');
    final matches = regex.allMatches(templateText);
    final seen = <String>{};
    final variables = <TemplateVariable>[];

    for (final match in matches) {
      final name = match.group(1)!.trim();
      if (seen.contains(name)) continue;
      seen.add(name);

      final type = _inferVariableType(name);
      final autoFill = _isPartyVariable(name);
      final partyOrder = _extractPartyOrder(name);

      variables.add(TemplateVariable(
        name: name,
        type: type,
        autoFillFromParty: autoFill,
        partyOrder: partyOrder,
      ));
    }

    return variables;
  }

  // ---------------------------------------------------------------------------
  // 1b. قراءة ملف Word (.docx) واستخراج المتغيرات
  // ---------------------------------------------------------------------------

  /// قراءة ملف .docx واستخراج كل المتغيرات {{...}} منه
  /// يُرجع قائمة المتغيرات المكتشفة أو قائمة فارغة إذا فشل القراءة
  Future<List<TemplateVariable>> detectVariablesFromDocx(File docxFile) async {
    try {
      final text = await _extractTextFromDocx(docxFile);
      if (text.isEmpty) return [];
      return detectVariables(text);
    } catch (e) {
      // في حالة الفشل — إرجاع قائمة فارغة (لا نرمي exception)
      return [];
    }
  }

  /// استخراج النص من ملف .docx
  /// .docx هو ملف ZIP يحتوي على word/document.xml
  Future<String> _extractTextFromDocx(File docxFile) async {
    final bytes = await docxFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // البحث عن word/document.xml
    final documentXml = archive.files.where((f) => f.name == 'word/document.xml').firstOrNull;
    if (documentXml == null) return '';

    final xmlContent = utf8.decode(documentXml.content as List<int>);
    final document = xml.XmlDocument.parse(xmlContent);

    // استخراج كل النصوص من عناصر <w:t>
    final textBuffer = StringBuffer();
    for (final element in document.findAllElements('w:t')) {
      textBuffer.write(element.innerText);
      textBuffer.write(' '); // مسافة بين العناصر
    }

    return textBuffer.toString();
  }

  /// استبدال المتغيرات في ملف .docx وإرجاع ملف جديد
  /// يُنشئ نسخة من القالب مع استبدال {{المتغيرات}} بقيمها
  Future<File?> replaceVariablesInDocx(
    File sourceDocx,
    Map<String, String> variableValues,
    String outputPath,
  ) async {
    try {
      final bytes = await sourceDocx.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final newArchive = Archive();

      for (final file in archive.files) {
        if (file.name == 'word/document.xml') {
          var xmlContent = utf8.decode(file.content as List<int>);
          
          // استبدال كل متغير
          for (final entry in variableValues.entries) {
            xmlContent = xmlContent.replaceAll('{{${entry.key}}}', entry.value);
          }

          final newFile = ArchiveFile(
            file.name,
            utf8.encode(xmlContent).length,
            utf8.encode(xmlContent),
          );
          newArchive.addFile(newFile);
        } else {
          newArchive.addFile(file);
        }
      }

      final zipBytes = ZipEncoder().encode(newArchive);
      if (zipBytes == null) return null;

      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(zipBytes);
      return outputFile;
    } catch (e) {
      return null;
    }
  }

  /// استنتاج نوع المتغير من اسمه
  String _inferVariableType(String name) {
    final lower = name.toLowerCase();
    
    // متغيرات الأشخاص
    if (lower.contains('بائع') || lower.contains('مشتري') || 
        lower.contains('مؤجر') || lower.contains('مستأجر') ||
        lower.contains('مقاول') || lower.contains('عامل') ||
        lower.contains('طرف') || lower.contains('شريك') ||
        lower.contains('كفيل') || lower.contains('ضامن') ||
        lower.contains('اسم') || lower.contains('وكيل')) {
      return 'person';
    }
    
    // متغيرات مالية
    if (lower.contains('ثمن') || lower.contains('سعر') || 
        lower.contains('مبلغ') || lower.contains('قيمة') ||
        lower.contains('أجر') || lower.contains('بدل') ||
        lower.contains('رهن') || lower.contains('عربون')) {
      return 'money';
    }
    
    // متغيرات تاريخية
    if (lower.contains('تاريخ') || lower.contains('موعد') ||
        lower.contains('مدة') || lower.contains('يوم')) {
      return 'date';
    }
    
    // متغيرات عقارية
    if (lower.contains('عقار') || lower.contains('منطقة') ||
        lower.contains('سهم') || lower.contains('حص') ||
        lower.contains('رقم') && lower.contains('عقاري') ||
        lower.contains('عنوان') || lower.contains('موقع') ||
        lower.contains('محل') || lower.contains('مقر')) {
      return 'property';
    }
    
    // أرقام
    if (lower.contains('رقم') || lower.contains('عدد') ||
        lower.contains('سجل') || lower.contains('هوية')) {
      return 'number';
    }
    
    return 'text';
  }

  /// هل هذا المتغير يُملأ من بيانات طرف؟
  bool _isPartyVariable(String name) {
    final lower = name.toLowerCase();
    return lower.contains('بائع') || lower.contains('مشتري') ||
           lower.contains('مؤجر') || lower.contains('مستأجر') ||
           lower.contains('طرف') || lower.contains('شريك') ||
           lower.contains('كفيل') || lower.contains('ضامن');
  }

  /// استخراج رقم الطرف من اسم المتغير
  int? _extractPartyOrder(String name) {
    if (name.contains('أول') || name.contains('1') || 
        name.contains('بائع') || name.contains('مؤجر') ||
        name.contains('مقاول') || name.contains('صاحب العمل')) {
      return 1;
    }
    if (name.contains('ثاني') || name.contains('2') ||
        name.contains('مشتري') || name.contains('مستأجر') ||
        name.contains('عامل')) {
      return 2;
    }
    if (name.contains('ثالث') || name.contains('3') ||
        name.contains('كفيل') || name.contains('ضامن')) {
      return 3;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 2. ملء المتغيرات من بيانات الأطراف
  // ---------------------------------------------------------------------------

  /// ملء المتغيرات تلقائياً من بيانات العقد والأطراف
  Map<String, String> autoFillVariables(
    List<TemplateVariable> variables,
    List<ContractParty> parties,
    List<PersonEntity> persons,
    Contract contract,
  ) {
    final filled = <String, String>{};

    for (final variable in variables) {
      if (variable.autoFillFromParty && variable.partyOrder != null) {
        // ابحث عن الطرف المناسب
        final party = parties.where((p) => p.partyOrder == variable.partyOrder).firstOrNull;
        if (party != null) {
          final person = persons.where((p) => p.id == party.personId).firstOrNull;
          if (person != null) {
            filled[variable.name] = person.fullName;
          }
        }
      } else if (variable.type == 'date' && variable.name.contains('تاريخ')) {
        // التاريخ الافتراضي = اليوم
        filled[variable.name] = DateTime.now().toString().substring(0, 10);
      } else if (variable.type == 'property' && variable.name.contains('مكان')) {
        filled[variable.name] = contract.location ?? '';
      }
    }

    return filled;
  }

  // ---------------------------------------------------------------------------
  // 3. استبدال المتغيرات في النص
  // ---------------------------------------------------------------------------

  /// استبدال المتغيرات {{...}} بقيمها في النص
  String replaceVariables(String templateText, Map<String, String> values) {
    var result = templateText;
    for (final entry in values.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value);
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // 4. حفظ المتغيرات والاكتشافات (AI Learning Data)
  // ---------------------------------------------------------------------------

  /// حفظ المتغيرات المكتشفة لقالب معين
  Future<void> saveTemplateVariables(
    int templateId,
    List<TemplateVariable> variables,
  ) async {
    // حذف المتغيرات القديمة
    await (db.delete(db.contractTemplateVariables)
          ..where((t) => t.templateId.equals(templateId)))
        .go();

    // إدخال المتغيرات الجديدة
    for (final variable in variables) {
      await db.into(db.contractTemplateVariables).insert(
        ContractTemplateVariablesCompanion.insert(
          templateId: templateId,
          variableName: variable.name,
          variableType: Value(variable.type),
          autoFillFromParty: Value(variable.autoFillFromParty),
        ),
      );
    }
  }

  /// حفظ قيم المتغيرات لنسخة عقد معينة
  Future<void> saveInstanceVariables(
    int contractId,
    Map<String, String> values,
    Map<String, String> fillMethods, // variable_name -> fill_method
  ) async {
    for (final entry in values.entries) {
      await db.into(db.contractInstanceVariables).insert(
        ContractInstanceVariablesCompanion.insert(
          contractId: contractId,
          variableName: entry.key,
          variableValue: Value(entry.value),
          fillMethod: Value(fillMethods[entry.key] ?? 'manual'),
        ),
      );
    }
  }

  /// تسجيل حدث استخدام القالب (AI Learning)
  Future<void> logTemplateUsage({
    required int? templateId,
    required int? contractId,
    required String eventType,
    Map<String, dynamic>? eventData,
  }) async {
    await db.into(db.contractTemplateUsageLog).insert(
      ContractTemplateUsageLogCompanion.insert(
        templateId: Value(templateId),
        contractId: Value(contractId),
        eventType: eventType,
        eventData: Value(eventData != null ? jsonEncode(eventData) : null),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. إحصائيات للاستخدام المستقبلي (AI Training Data)
  // ---------------------------------------------------------------------------

  /// جلب أكثر القوالب استخداماً لنوع عقد معين
  Future<List<ContractTemplate>> getMostUsedTemplates(String contractType) async {
    // هذا سيُستخدم لاحقاً لترتيب القوالب حسب الشعبية
    return (db.select(db.contractTemplates)
          ..where((t) => t.contractType.equals(contractType))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(10))
        .get();
  }

  /// جلب أنماط الملء الشائعة لمتغير معين
  /// (AI سيتعلم: عندما يكون المتغير "الثمن" وعقد "بيع عقار" → القيمة عادة رقم كبير)
  Future<List<ContractInstanceVariable>> getVariablePatterns(
    String variableName,
    String contractType,
  ) async {
    return (db.select(db.contractInstanceVariables)
          ..where((t) => t.variableName.equals(variableName))
          ..limit(50))
        .get();
  }
}
