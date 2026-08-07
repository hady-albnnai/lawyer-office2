import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../core/constants/app_constants.dart';
import '../../core/constants/court_catalog.dart';
import '../services/storage_location_service.dart';
import 'schema.dart';
import 'daos/case_dao.dart';
import 'daos/person_dao.dart';
import 'daos/task_dao.dart';
import 'daos/finance_dao.dart';
import 'daos/document_dao.dart';
import 'daos/lookup_dao.dart';
import 'daos/company_dao.dart';
import 'daos/contract_dao.dart';
import 'daos/admin_procedure_dao.dart';
import 'daos/legal_library_dao.dart';
import 'daos/settings_dao.dart';
import 'daos/work_order_dao.dart';

part 'database.g.dart';

/// قاعدة البيانات المحلية الموحدة لنظام إدارة مكتب المحاماة السوري (Drift + SQLite)
@DriftDatabase(
  tables: [
    // 1. النظام والإعدادات
    AppSettings, Security, ActivityLog, Backups, YearlySequences,
    // 2. الأشخاص والأدوار
    Persons, LegalEntities, PersonRoles, TeamMembers, OpponentLawyers, Notaries,
    // 3. الوكالات القضائية
    PowersOfAttorney, PoaParties, CasePoaLinks,
    // 4. الجداول المرجعية
    Courts, CaseSubjects, PartyRolesLookup, ContractTypesLookup, CompanyTypesLookup,
    // 5. الدعاوى والجلسات
    Cases, CaseParties, CasePhases, CaseSessions, CaseActions,
    // 6. الشركات
    Companies, CompanyPhases, CompanyManagement, CompanyPartners, CompanyDirectors,
    // 7. العقود
    Contracts, ContractParties, ContractReminders, ContractTemplates, ContractVersions,
    // 7b. جداول الذكاء الاصطناعي للعقود
    ContractTemplateVariables, ContractInstanceVariables, ContractTemplateUsageLog,
    // 8. الإجراءات الإدارية
    AdminProcedures, AdminSteps, AdminProcedureTypes,
    // 9. المهام والأعمال اليومية
    DailyTasks, TaskHistory,
    // 10. المستندات
    Documents, DocumentLinks,
    // 11. المالية الموحدة
    FeeAgreements, FeePayments, Expenses,
    // 12. النواقص والخط الزمني
    Deficiencies, TimelineEvents,
    // 13. المكتبة القانونية
    LegalLibraryItems, LegalLibraryLinks,
    // 14. أوامر العمل
    WorkOrders,
  ],
  daos: [
    CaseDao,
    PersonDao,
    TaskDao,
    FinanceDao,
    DocumentDao,
    LookupDao,
    CompanyDao,
    ContractDao,
    AdminProcedureDao,
    LegalLibraryDao,
    SettingsDao,
    WorkOrderDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openDatabase());

  /// للاختبارات: قاعدة ذاكرة اختيارية.
  AppDatabase.forTesting(super.e);

  /// الإصدار 4: استكمال الأعمدة التي أُضيفت للمخطط دون ترحيل مقابل.
  ///
  /// قاعدة إلزامية (انظر CONSTITUTION.md): أي عمود جديد يُضاف إلى
  /// schema.dart يجب أن يرافقه رفع هذا الرقم وإضافة m.addColumn في
  /// onUpgrade. عدم الالتزام يُنتج خطأ SQLite رقم 1 على القواعد القائمة.
  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _createCustomIndexes();
      await _seedDefaultLookups();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(legalLibraryItems);
        await m.createTable(legalLibraryLinks);
      }
      if (from < 3) {
        await m.createTable(workOrders);
      }
      if (from < 4) {
        await _migrateToV4(m);
      }
      if (from < 5) {
        await _migrateToV5(m);
      }
      if (from < 6) {
        await _migrateToV6(m);
      }
      if (from < 7) {
        await _migrateToV7(m);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
      await ensureAuthTables();
      await ensureOfficeFileTables();
      await ensureArchiveTables();
    },
  );


  /// ترحيل الإصدار 4 — إضافة الأعمدة الناقصة بشكل صريح.
  ///
  /// هذه الأعمدة أُضيفت إلى schema.dart بعد الإصدار الأول دون رفع
  /// schemaVersion، فبقيت مفقودة في قواعد المستخدمين القائمة بينما
  /// يولّدها Drift في عبارات INSERT => SQLite error 1 (no such column).
  ///
  /// كل addColumn محاطة بفحص وجود مسبق لأن بعض القواعد قد تكون حصلت
  /// على العمود عبر شبكة الأمان في beforeOpen قبل تطبيق هذا الترحيل.
  Future<void> _migrateToV4(Migrator m) async {
    // --- powers_of_attorney: حقول ملف الوكالة (البندان 3 و7) ---
    await _addColumnIfMissing(m, powersOfAttorney, 'category',
        () => powersOfAttorney.category);
    await _addColumnIfMissing(m, powersOfAttorney, 'sub_type',
        () => powersOfAttorney.subType);
    await _addColumnIfMissing(m, powersOfAttorney, 'registry_number',
        () => powersOfAttorney.registryNumber);
    await _addColumnIfMissing(m, powersOfAttorney, 'white_number',
        () => powersOfAttorney.whiteNumber);
    await _addColumnIfMissing(m, powersOfAttorney, 'delegate_name',
        () => powersOfAttorney.delegateName);
    await _addColumnIfMissing(m, powersOfAttorney, 'delegate_phone',
        () => powersOfAttorney.delegatePhone);
    await _addColumnIfMissing(m, powersOfAttorney, 'delegate_branch',
        () => powersOfAttorney.delegateBranch);
    await _addColumnIfMissing(m, powersOfAttorney, 'scope_text',
        () => powersOfAttorney.scopeText);
    await _addColumnIfMissing(m, powersOfAttorney, 'file_path',
        () => powersOfAttorney.filePath);
    await _addColumnIfMissing(m, powersOfAttorney, 'status',
        () => powersOfAttorney.status);
    await _addColumnIfMissing(m, powersOfAttorney, 'expiry_date',
        () => powersOfAttorney.expiryDate);
    await _addColumnIfMissing(m, powersOfAttorney, 'notary_id',
        () => powersOfAttorney.notaryId);
    await _addColumnIfMissing(m, powersOfAttorney, 'delegate_id',
        () => powersOfAttorney.delegateId);

    // --- work_orders: office_file_id من المرحلة السادسة لخارطة التنفيذ ---
    await _addColumnIfMissing(m, workOrders, 'office_file_id',
        () => workOrders.officeFileId);
  }

  /// ترحيل الإصدار 5 — إعادة هيكلة المحاكم: محافظة + رقم غرفة.
  ///
  /// كانت المحاكم تُخزَّن باسم مركّب يدمج المحافظة والدرجة والترتيب
  /// ("محكمة البداية المدنية الأولى بدمشق")، وهذا خلط بين ثلاثة مفاهيم:
  ///   - المحافظة: هوية المحكمة المكانية.
  ///   - الدرجة: شأن إجرائي تديره JudicialPhases (بداية ← استئناف ← نقض).
  ///   - الغرفة: رقم من 1 إلى 16 وقابل للزيادة.
  /// الترحيل يضيف عمود الغرفة، ثم يستخرج المحافظة من الأسماء القديمة.
  Future<void> _migrateToV5(Migrator m) async {
    // SQL مباشر لا m.addColumn: عمود chamber_number أُضيف إلى
    // schema.dart ولم يُعد توليد database.g.dart بعد، فلا يوجد
    // GeneratedColumn مقابل له. _ensureSqlColumn تعمل على مستوى
    // SQLite مباشرة فتنجح في الحالتين، وتتخطّى العمود إن كان موجوداً.
    await _ensureSqlColumn('courts', 'chamber_number', 'INTEGER');
    await normalizeCourtNames();
  }

  /// ترحيل الإصدار 6 — فصل «نوع المحكمة» عن «المحافظة».
  ///
  /// حتى الإصدار 5 كانت المحكمة تُعرَّف بالمحافظة وحدها، فكان جواب
  /// «أمام أي محكمة استُؤنفت الدعوى؟» هو «حمص» — وهذا اسم مدينة لا
  /// محكمة. الدرجة كانت تُحشر في `sub_type` كنص حر، ومنه استحال
  /// معرفة مسار الطعن التالي.
  ///
  /// الإصلاح: `court_kind` يحمل معرّفاً من `CourtCatalog` يجمع
  /// الدرجة والتخصص، و`chamber_number` يحمل الغرفة. المحافظة تبقى
  /// في `court_id`. المحكمة الكاملة = النوع + المحافظة + الغرفة.
  Future<void> _migrateToV6(Migrator m) async {
    await _addColumnIfMissing(m, courts, 'court_kind', () => courts.courtKind);

    await _addColumnIfMissing(m, cases, 'court_kind', () => cases.courtKind);
    await _addColumnIfMissing(
        m, cases, 'chamber_number', () => cases.chamberNumber);

    await _addColumnIfMissing(
        m, casePhases, 'court_kind', () => casePhases.courtKind);
    await _addColumnIfMissing(
        m, casePhases, 'chamber_number', () => casePhases.chamberNumber);

    await ensureCourtKindRows();
    await backfillCourtKinds();
  }

  /// حقن سجل لكل (نوع محكمة × محافظة) غير موجود.
  ///
  /// القواعد المرحَّلة من الإصدار 5 تحوي 14 سجلاً باسم محافظة وبلا
  /// نوع. تُترك كما هي حتى لا تنكسر الدعاوى المرتبطة بها عبر
  /// `court_id`، لكنها لا تظهر في قوائم الاختيار الجديدة لأنها
  /// تُفلتر بـ `court_kind`. هذه الدالة تضيف الصفوف الناقصة فقط،
  /// فتشغيلها مرة ثانية لا يُحدث تكراراً.
  Future<void> ensureCourtKindRows() async {
    final existing = await customSelect(
      'SELECT name, court_kind FROM courts WHERE court_kind IS NOT NULL',
    ).get();

    final present = existing
        .map((r) => '${r.data['court_kind']}|${r.data['name']}')
        .toSet();

    for (final kind in CourtCatalog.all) {
      for (final gov in kind.governorates) {
        if (present.contains('${kind.id}|$gov')) continue;
        await customStatement(
          'INSERT INTO courts (name, city, court_kind, is_active) '
          'VALUES (?, ?, ?, 1)',
          [gov, gov, kind.id],
        );
      }
    }
  }

  /// استنتاج نوع المحكمة للسجلات التي سبقت الإصدار 6.
  ///
  /// المصدر الوحيد المتاح هو النص الحر في `cases.sub_type` و
  /// `case_phases.phase_type` مع نوع الدعوى. الاستنتاج تقريبي بطبعه،
  /// ولذلك يقتصر على الحالات القاطعة ويترك المبهم فارغاً بدل تخمين
  /// درجة خاطئة تُظهر للمحامي مساراً لا وجود له.
  Future<void> backfillCourtKinds() async {
    final caseRows = await customSelect(
      'SELECT id, case_type, sub_type FROM cases '
      'WHERE court_kind IS NULL OR court_kind = ?',
      variables: [Variable.withString('')],
    ).get();

    for (final row in caseRows) {
      final kind = _inferCourtKind(
        degreeText: row.data['sub_type'] as String?,
        caseTypeText: row.data['case_type'] as String?,
      );
      if (kind == null) continue;
      await customStatement(
        'UPDATE cases SET court_kind = ? WHERE id = ?',
        [kind, row.data['id'] as int],
      );
    }

    final phaseRows = await customSelect(
      'SELECT p.id AS id, p.phase_type AS phase_type, c.case_type AS case_type '
      'FROM case_phases p LEFT JOIN cases c ON c.id = p.case_id '
      'WHERE p.court_kind IS NULL OR p.court_kind = ?',
      variables: [Variable.withString('')],
    ).get();

    for (final row in phaseRows) {
      final kind = _inferCourtKind(
        degreeText: row.data['phase_type'] as String?,
        caseTypeText: row.data['case_type'] as String?,
      );
      if (kind == null) continue;
      await customStatement(
        'UPDATE case_phases SET court_kind = ? WHERE id = ?',
        [kind, row.data['id'] as int],
      );
    }
  }

  /// مطابقة نص درجة قديم بمعرّف نوع محكمة.
  ///
  /// المنطق في `CourtCatalog.inferKindFromText` كي يبقى مصدراً
  /// واحداً يتقاسمه الترحيل وشاشة الأرشيف.
  String? _inferCourtKind({String? degreeText, String? caseTypeText}) =>
      CourtCatalog.inferKindFromText(
        degreeText: degreeText,
        caseTypeText: caseTypeText,
      );

  /// تحويل أسماء المحاكم القديمة إلى اسم المحافظة وحدها.
  ///
  /// تُنفَّذ مرة واحدة ضمن ترحيل v5 فقط، ولا تُستدعى في beforeOpen:
  /// تشغيلها في كل إقلاع يعيد كتابة أسماء قد يكون المستخدم أدخلها
  /// عمداً بصيغة مخصّصة.
  Future<void> normalizeCourtNames() async {
    final rows =
        await customSelect('SELECT id, name, city FROM courts').get();

    for (final row in rows) {
      final id = row.data['id'] as int;
      final name = (row.data['name'] as String?) ?? '';
      final city = row.data['city'] as String?;

      final resolved = _resolveGovernorate(name, city);
      if (resolved == null || resolved == name) continue;

      await customStatement(
        'UPDATE courts SET name = ?, city = ? WHERE id = ?',
        [resolved, resolved, id],
      );
    }
  }

  /// استخراج اسم المحافظة من تسمية محكمة قديمة.
  ///
  /// يعتمد على المطابقة النصية بعد تطبيع الهمزات والتاء المربوطة،
  /// ويعالج التسميات الشائعة الخاطئة مثل "حما" بدل "حماة".
  String? _resolveGovernorate(String rawName, String? city) {
    String normalize(String s) => s
        .replaceAll(RegExp(r'[\u064B-\u0652]'), '') // التشكيل
        .replaceAll(RegExp(r'[أإآا]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final haystack = normalize('$rawName ${city ?? ''}');

    // "حماة" تُكتب خطأً "حما"؛ تُفحص أولاً كي لا تلتقطها مطابقة أخرى.
    if (RegExp(r'\bحما\b').hasMatch(haystack) ||
        haystack.contains('حماه')) {
      return 'حماة';
    }

    // ريف دمشق قبل دمشق حتى لا تبتلعها المطابقة الأعم.
    if (haystack.contains('ريف دمشق')) return 'ريف دمشق';

    for (final gov in AppConstants.syrianGovernorates) {
      if (haystack.contains(normalize(gov))) return gov;
    }
    return null;
  }

  /// ترحيل الإصدار 7 — أعمدة العقود الجديدة + جداول AI.
  ///
  /// يُضيف أعمدة التصنيف القانوني وربط القالب بالعقود،
  /// وينشئ الجداول الثلاثة للذكاء الاصطناعي:
  ///   - contract_template_variables: متغيرات القوالب {{...}}
  ///   - contract_instance_variables: قيم المتغيرات لكل عقد
  ///   - contract_template_usage_log: سجل التفاعلات
  Future<void> _migrateToV7(Migrator m) async {
    // --- contracts: أعمدة جديدة ---
    await _ensureSqlColumn('contracts', 'legal_category', 'TEXT');
    await _ensureSqlColumn('contracts', 'legal_subcategory', 'TEXT');
    await _ensureSqlColumn('contracts', 'source_template_id', 'INTEGER');
    await _ensureSqlColumn('contracts', 'creation_method', 'TEXT');

    // --- contract_parties: عمود الصفة ---
    await _ensureSqlColumn('contract_parties', 'party_capacity', 'TEXT');

    // --- جداول AI الجديدة ---
    await customStatement('''
      CREATE TABLE IF NOT EXISTS contract_template_variables (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        template_id INTEGER NOT NULL REFERENCES contract_templates(id) ON DELETE CASCADE,
        variable_name TEXT NOT NULL,
        variable_type TEXT,
        auto_fill_from_party INTEGER NOT NULL DEFAULT 0,
        usage_count INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS contract_instance_variables (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contract_id INTEGER NOT NULL REFERENCES contracts(id) ON DELETE CASCADE,
        template_variable_id INTEGER REFERENCES contract_template_variables(id),
        variable_name TEXT NOT NULL,
        variable_value TEXT,
        fill_method TEXT NOT NULL DEFAULT 'manual',
        was_corrected INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS contract_template_usage_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        template_id INTEGER REFERENCES contract_templates(id),
        contract_id INTEGER REFERENCES contracts(id),
        event_type TEXT NOT NULL,
        event_data TEXT,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
      )
    ''');
  }

  /// إضافة عمود عبر Migrator مع تخطّيه إن كان موجوداً بالفعل.
  ///
  /// ضروري لأن شبكة الأمان (ensure*Columns) قد تكون أضافت العمود
  /// في تشغيل سابق، و ALTER TABLE ADD COLUMN يفشل على عمود مكرر.
  Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo table,
    String columnName,
    GeneratedColumn Function() column,
  ) async {
    final info =
        await customSelect('PRAGMA table_info(${table.actualTableName})').get();
    final exists = info.any((row) => row.data['name'] == columnName);
    if (!exists) {
      await m.addColumn(table, column());
    }
  }

  /// إنشاء جداول الأمان والصلاحيات وسجل المسؤولية عبر SQL مخصص.
  /// ملاحظة: هذه الجداول مستقلة عن منطق التشغيل الحالي، وتُفتح قبل استخدام AuthRepository.
  Future<void> ensureAuthTables() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS app_roles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        is_system_role INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS app_users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        full_name TEXT NOT NULL,
        username TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        role_id INTEGER NOT NULL REFERENCES app_roles(id),
        phone TEXT,
        email TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        is_owner INTEGER NOT NULL DEFAULT 0,
        last_login_at DATETIME,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS role_permissions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        role_id INTEGER NOT NULL REFERENCES app_roles(id) ON DELETE CASCADE,
        permission_key TEXT NOT NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(role_id, permission_key)
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS user_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER REFERENCES app_users(id),
        username_snapshot TEXT,
        user_full_name_snapshot TEXT,
        role_name_snapshot TEXT,
        login_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        logout_at DATETIME,
        last_active_at DATETIME,
        status TEXT NOT NULL DEFAULT 'active',
        device_name TEXT,
        app_version TEXT,
        failed_reason TEXT,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS audit_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER REFERENCES user_sessions(id),
        user_id INTEGER REFERENCES app_users(id),
        username_snapshot TEXT,
        user_full_name_snapshot TEXT,
        role_name_snapshot TEXT,
        action TEXT NOT NULL,
        category TEXT NOT NULL,
        entity_type TEXT,
        entity_id TEXT,
        entity_title TEXT,
        description TEXT,
        before_json TEXT,
        after_json TEXT,
        severity TEXT NOT NULL DEFAULT 'info',
        device_name TEXT,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
      );
    ''');
    await _ensureSqlColumn('app_roles', 'hierarchy_level', 'INTEGER NOT NULL DEFAULT 0');
    await customStatement("UPDATE app_roles SET name = 'مالك المكتب', hierarchy_level = 100 WHERE name = 'صاحب المكتب' AND NOT EXISTS (SELECT 1 FROM app_roles WHERE name = 'مالك المكتب');");
    await customStatement("UPDATE app_roles SET hierarchy_level = 100 WHERE name = 'مالك المكتب';");
    await customStatement("UPDATE app_roles SET hierarchy_level = 80 WHERE name = 'مدير المكتب';");
    await customStatement("UPDATE app_roles SET hierarchy_level = 60 WHERE name = 'محامي أستاذ';");
    await customStatement('CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_events(created_at);');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_events(user_id, created_at);');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_audit_category ON audit_events(category, action);');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_sessions_user ON user_sessions(user_id, login_at);');
  }


  /// إنشاء جداول ملف المكتب الموحد والترقيم حسب نوع الملف.
  /// ملاحظة تنفيذية: أبقينا هذه الجداول SQL-managed مؤقتاً حتى لا نكسر البناء في بيئة لا يتوفر فيها build_runner.
  /// يمكن نقلها لاحقاً إلى Drift-managed schema عند توفر توليد كامل واختبارات Windows.
  Future<void> ensureOfficeFileTables() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS office_file_sequences (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        year INTEGER NOT NULL,
        file_type TEXT NOT NULL,
        prefix TEXT NOT NULL,
        last_number INTEGER NOT NULL DEFAULT 0,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(year, file_type)
      );
    ''');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_office_file_sequences_year_type ON office_file_sequences(year, file_type);');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS office_files (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_number TEXT NOT NULL UNIQUE,
        file_type TEXT NOT NULL,
        file_year INTEGER NOT NULL,
        serial INTEGER NOT NULL,
        source TEXT NOT NULL DEFAULT 'new_work',
        status TEXT NOT NULL DEFAULT 'active',
        linked_entity_type INTEGER,
        linked_entity_id INTEGER,
        title TEXT,
        opened_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        opened_by_user_id INTEGER,
        opened_by_name_snapshot TEXT,
        closed_at DATETIME,
        closed_by_user_id INTEGER,
        closed_by_name_snapshot TEXT,
        closure_reason TEXT,
        closure_summary TEXT,
        has_pending_finance INTEGER NOT NULL DEFAULT 0,
        has_pending_paper_original INTEGER NOT NULL DEFAULT 0,
        has_post_closure_actions INTEGER NOT NULL DEFAULT 0,
        handover_document_id INTEGER,
        notes TEXT,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(file_type, file_year, serial)
      );
    ''');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_office_files_type_status ON office_files(file_type, status);');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_office_files_source ON office_files(source, status);');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_office_files_linked_entity ON office_files(linked_entity_type, linked_entity_id);');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_office_files_opened ON office_files(opened_at);');
  }


  /// إنشاء جداول مركز إدخال الأرشيف القديم عبر SQL مخصص مرحلياً.
  Future<void> ensureArchiveTables() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS archive_batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        source_type TEXT NOT NULL,
        source_path TEXT,
        status TEXT NOT NULL DEFAULT 'new',
        created_by_user_id INTEGER,
        created_by_name_snapshot TEXT,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        started_at DATETIME,
        completed_at DATETIME,
        total_files INTEGER NOT NULL DEFAULT 0,
        processed_files INTEGER NOT NULL DEFAULT 0,
        failed_files INTEGER NOT NULL DEFAULT 0,
        duplicate_files INTEGER NOT NULL DEFAULT 0,
        unclassified_files INTEGER NOT NULL DEFAULT 0,
        approved_files INTEGER NOT NULL DEFAULT 0,
        notes TEXT
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS archive_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        batch_id INTEGER NOT NULL REFERENCES archive_batches(id) ON DELETE CASCADE,
        original_file_name TEXT NOT NULL,
        source_path TEXT,
        stored_path TEXT,
        file_type TEXT,
        file_size INTEGER NOT NULL DEFAULT 0,
        sha256 TEXT,
        status TEXT NOT NULL DEFAULT 'imported',
        suggested_document_type TEXT,
        confirmed_document_type TEXT,
        suggested_entity_type INTEGER,
        suggested_entity_id INTEGER,
        confirmed_entity_type INTEGER,
        confirmed_entity_id INTEGER,
        ocr_status TEXT NOT NULL DEFAULT 'not_required',
        ocr_text_path TEXT,
        review_status TEXT NOT NULL DEFAULT 'needs_review',
        error_message TEXT,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
      );
    ''');
    await _ensureSqlColumn('archive_items', 'reviewed_by', 'TEXT');
    await _ensureSqlColumn('archive_items', 'reviewed_at', 'DATETIME');
    await _ensureSqlColumn('archive_items', 'review_note', 'TEXT');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS agency_delegates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        full_name TEXT NOT NULL,
        phone TEXT,
        bar_branch TEXT,
        notes TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
      );
    ''');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_agency_delegates_branch ON agency_delegates(bar_branch, is_active);');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS archive_reference_values (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        parent_value TEXT,
        value TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(category, parent_value, value)
      );
    ''');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_archive_reference_values_category ON archive_reference_values(category, parent_value, is_active);');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS document_paper_metadata (
        document_id INTEGER PRIMARY KEY REFERENCES documents(id) ON DELETE CASCADE,
        paper_original_saved INTEGER NOT NULL DEFAULT 0,
        paper_location TEXT,
        box TEXT,
        shelf TEXT,
        paper_folder TEXT,
        can_destroy_original INTEGER NOT NULL DEFAULT 0,
        reviewed_by TEXT,
        reviewed_at DATETIME,
        notes TEXT,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
      );
    ''');
    // حقول الأصل الورقي المطلوبة في المرحلة الثامنة من خارطة التنفيذ.
    await _ensureSqlColumn('document_paper_metadata', 'with_client', 'INTEGER NOT NULL DEFAULT 0');
    await _ensureSqlColumn('document_paper_metadata', 'court_exhibit', 'INTEGER NOT NULL DEFAULT 0');
    await _ensureSqlColumn('document_paper_metadata', 'digital_only', 'INTEGER NOT NULL DEFAULT 0');
    await _ensureSqlColumn('document_paper_metadata', 'handover_reference', 'TEXT');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_paper_metadata_location ON document_paper_metadata(paper_location, box, shelf);');
    await _backfillPaperMetadataFromDocumentNotes();
    await customStatement('CREATE INDEX IF NOT EXISTS idx_archive_batches_status ON archive_batches(status, created_at);');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_archive_items_batch ON archive_items(batch_id, status);');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_archive_items_hash ON archive_items(sha256);');
    await ensurePoaColumns();
    await ensureUpgradeTableColumns();
    await _ensureSqlColumn('courts', 'chamber_number', 'INTEGER');
  }

  /// استكمال أعمدة جدول الوكالات المضافة بعد الإصدار الأول من المخطط.
  ///
  /// قواعد البيانات التي أُنشئت قبل إضافة حقول "ملف الوكالة" (البندان 3 و7)
  /// تفتقر لهذه الأعمدة، بينما تولّد Drift عبارة INSERT تتضمنها كلها،
  /// فيفشل الإدخال بخطأ SQLite رقم 1 (logic error / no such column).
  /// التعريفات هنا مطابقة لما في schema.dart تماماً.
  Future<void> ensurePoaColumns() async {
    await _ensureSqlColumn(
        'powers_of_attorney', 'category', "TEXT NOT NULL DEFAULT 'judicial'");
    await _ensureSqlColumn('powers_of_attorney', 'sub_type', 'TEXT');
    await _ensureSqlColumn('powers_of_attorney', 'registry_number', 'TEXT');
    await _ensureSqlColumn('powers_of_attorney', 'white_number', 'TEXT');
    await _ensureSqlColumn('powers_of_attorney', 'delegate_name', 'TEXT');
    await _ensureSqlColumn('powers_of_attorney', 'delegate_phone', 'TEXT');
    await _ensureSqlColumn('powers_of_attorney', 'delegate_branch', 'TEXT');
    await _ensureSqlColumn('powers_of_attorney', 'scope_text', 'TEXT');
    await _ensureSqlColumn('powers_of_attorney', 'file_path', 'TEXT');
    await _ensureSqlColumn(
        'powers_of_attorney', 'status', "TEXT NOT NULL DEFAULT 'active'");
    await _ensureSqlColumn('powers_of_attorney', 'expiry_date', 'DATETIME');
    await _ensureSqlColumn('powers_of_attorney', 'notary_id', 'INTEGER');
    await _ensureSqlColumn('powers_of_attorney', 'delegate_id', 'INTEGER');
  }

  /// استكمال أعمدة الجداول المُنشأة عبر onUpgrade.
  ///
  /// الجداول التالية تُنشأ في onUpgrade (وليس createAll)، وأي عمود يُضاف
  /// إليها بعد ترقية المستخدم لا يصل إلى قاعدته لأن schemaVersion لم يتغيّر.
  /// النتيجة نفس عطل الوكالات: Drift يولّد INSERT بأعمدة غير موجودة
  /// فيفشل بخطأ SQLite رقم 1.
  ///
  /// التعريفات مطابقة لـ schema.dart. الأعمدة NOT NULL التي لها قيمة
  /// افتراضية تُضاف بنفس الافتراضي؛ أما NOT NULL بلا افتراضي فلا يمكن
  /// إضافتها لجدول يحوي صفوفاً، لذا تُستثنى (وهي موجودة أصلاً منذ الإنشاء).
  Future<void> ensureUpgradeTableColumns() async {
    // --- work_orders ---
    await _ensureSqlColumn('work_orders', 'office_file_id', 'INTEGER');
    await _ensureSqlColumn(
        'work_orders', 'linked_entity_type', 'INTEGER NOT NULL DEFAULT 0');
    await _ensureSqlColumn(
        'work_orders', 'linked_entity_id', 'INTEGER NOT NULL DEFAULT 0');
    await _ensureSqlColumn('work_orders', 'assigned_to_phone', 'TEXT');
    await _ensureSqlColumn(
        'work_orders', 'priority', "TEXT NOT NULL DEFAULT 'medium'");
    await _ensureSqlColumn(
        'work_orders', 'status', "TEXT NOT NULL DEFAULT 'draft'");
    await _ensureSqlColumn('work_orders', 'instructions', 'TEXT');
    await _ensureSqlColumn('work_orders', 'created_by', 'TEXT');
    await _ensureSqlColumn('work_orders', 'printed_at', 'DATETIME');
    await _ensureSqlColumn('work_orders', 'whatsapp_sent_at', 'DATETIME');
    await _ensureSqlColumn('work_orders', 'result_status', 'TEXT');
    await _ensureSqlColumn('work_orders', 'result_text', 'TEXT');
    await _ensureSqlColumn('work_orders', 'result_date', 'DATETIME');
    await _ensureSqlColumn('work_orders', 'next_date', 'DATETIME');
    await _ensureSqlColumn('work_orders', 'approved_at', 'DATETIME');

    // --- legal_library_items ---
    for (final c in const [
      'category', 'source', 'source_url', 'file_path', 'file_name',
      'extracted_text', 'tags', 'law_number', 'law_kind', 'last_amendment',
      'court', 'chamber', 'decision_number', 'base_number', 'principle',
      'journal_issue', 'page', 'notes', 'created_by',
    ]) {
      await _ensureSqlColumn('legal_library_items', c, 'TEXT');
    }
    await _ensureSqlColumn('legal_library_items', 'decision_date', 'DATETIME');
    await _ensureSqlColumn('legal_library_items', 'journal_year', 'INTEGER');
    await _ensureSqlColumn(
        'legal_library_items', 'year', 'INTEGER NOT NULL DEFAULT 0');
    await _ensureSqlColumn(
        'legal_library_items', 'is_favorite', 'INTEGER NOT NULL DEFAULT 0');
    await _ensureSqlColumn(
        'legal_library_items', 'is_principle', 'INTEGER NOT NULL DEFAULT 0');

    // --- legal_library_links ---
    await _ensureSqlColumn('legal_library_links', 'entity_title', 'TEXT');
    await _ensureSqlColumn('legal_library_links', 'note', 'TEXT');
  }

  Future<void> _ensureSqlColumn(String tableName, String columnName, String definition) async {
    final columns = await customSelect('PRAGMA table_info($tableName)').get();
    final exists = columns.any((row) => row.data['name'] == columnName);
    if (!exists) {
      await customStatement('ALTER TABLE $tableName ADD COLUMN $columnName $definition;');
    }
  }

  Future<void> _backfillPaperMetadataFromDocumentNotes() async {
    final rows = await customSelect('''
      SELECT d.id, d.notes
      FROM documents d
      LEFT JOIN document_paper_metadata m ON m.document_id = d.id
      WHERE m.document_id IS NULL
        AND d.notes IS NOT NULL
        AND d.notes LIKE '%الأصل الورقي محفوظ:%'
    ''').get();

    String? pick(String notes, String prefix) {
      for (final line in notes.split('\n')) {
        if (line.trim().startsWith(prefix)) {
          final value = line.replaceFirst(prefix, '').trim();
          return value.isEmpty ? null : value;
        }
      }
      return null;
    }

    for (final row in rows) {
      final id = row.data['id'] as int;
      final notes = row.data['notes'] as String? ?? '';
      final saved = (pick(notes, 'الأصل الورقي محفوظ:') ?? '').contains('نعم');
      final canDestroy = (pick(notes, 'يجوز إتلاف الأصل:') ?? '').contains('نعم');
      await customStatement('''
        INSERT OR IGNORE INTO document_paper_metadata(
          document_id, paper_original_saved, paper_location, box, shelf, paper_folder,
          can_destroy_original, reviewed_by, reviewed_at, notes, updated_at
        ) VALUES(?, ?, ?, ?, ?, ?, ?, ?, CASE WHEN ? IS NOT NULL THEN CURRENT_TIMESTAMP ELSE NULL END, ?, CURRENT_TIMESTAMP)
      ''', [
        id,
        saved ? 1 : 0,
        pick(notes, 'مكان الأصل:'),
        pick(notes, 'الصندوق:'),
        pick(notes, 'الرف:'),
        pick(notes, 'المجلد الورقي:'),
        canDestroy ? 1 : 0,
        pick(notes, 'راجع النسخة الرقمية:'),
        pick(notes, 'راجع النسخة الرقمية:'),
        notes,
      ]);
    }
  }

  /// مسح كل بيانات التشغيل/البيانات التجريبية مع الإبقاء على الإعدادات والقوائم المرجعية.
  /// يستخدم عند تسليم التطبيق لمكتب حقيقي يريد البدء من قاعدة نظيفة.
  Future<void> clearOperationalData() async {
    await transaction(() async {
      // حذف أوامر العمل عبر Drift أيضاً لضمان إشعار الشاشات المرتبطة بالـ Stream.
      await delete(workOrders).go();

      final tables = <String>[
        'archive_items',
        'archive_batches',
        'office_files',
        'office_file_sequences',
        'document_paper_metadata',
        'document_links',
        'documents',
        'fee_payments',
        'fee_agreements',
        'expenses',
        'work_orders',
        'legal_library_links',
        'legal_library_items',
        'daily_tasks',
        'task_history',
        'deficiencies',
        'timeline_events',
        'case_poa_links',
        'case_actions',
        'case_sessions',
        'case_phases',
        'case_parties',
        'cases',
        'company_directors',
        'company_partners',
        'company_management',
        'company_phases',
        'companies',
        'contract_versions',
        'contract_reminders',
        'contract_parties',
        'contracts',
        'contract_templates',
        'admin_steps',
        'admin_procedures',
        'poa_parties',
        'powers_of_attorney',
        'person_roles',
        'team_members',
        'legal_entities',
        'opponent_lawyers',
        'persons',
        'yearly_sequences',
        'activity_log',
      ];

      for (final table in tables) {
        await customStatement('DELETE FROM $table;');
      }

      final tableNames = tables.map((t) => "'$t'").join(',');
      await customStatement('DELETE FROM sqlite_sequence WHERE name IN ($tableNames);');
    });
  }

  /// إنشاء الفهارس السريعة للحقول الأكثر استخداماً في البحث والمتابعة اليومية
  Future<void> _createCustomIndexes() async {
    await customStatement('CREATE INDEX IF NOT EXISTS idx_persons_name ON persons(full_name);');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_persons_nat_id ON persons(national_id);');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_persons_phone ON persons(phone1);');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_cases_internal ON cases(internal_number);');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_cases_year_num ON cases(year, internal_number);');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_cases_next_session ON cases(next_session_date);');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_cases_status ON cases(status);');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_daily_tasks_date ON daily_tasks(task_date, status);');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_daily_tasks_assigned ON daily_tasks(assigned_to);');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_doc_links_entity ON document_links(entity_type, entity_id);');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_timeline_entity ON timeline_events(entity_type, entity_id, event_date);');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_deficiencies_entity ON deficiencies(entity_type, entity_id, status);');
  }

  /// حقن القوائم السورية الجاهزة الافتراضية عند أول تشغيل للمكتب
  Future<void> _seedDefaultLookups() async {
    await batch((b) {
      // المحاكم: سجل لكل (نوع محكمة × محافظة يجوز انعقادها فيها).
      //
      // كان السجل الواحد يحمل اسم محافظة مجرداً، فيختار المحامي
      // «حمص» ولا يُعرف أهي صلح أم استئناف. الآن يحمل السجل نوعه
      // في court_kind، وتبقى المحافظة في name و city.
      // محاكم النقض والقضاء الإداري تُحقن لدمشق وحدها لأن مقرها
      // القانوني هناك، فحقنها لكل محافظة يُنشئ محاكم لا وجود لها.
      b.insertAll(
        courts,
        [
          for (final kind in CourtCatalog.all)
            for (final gov in kind.governorates)
              CourtsCompanion.insert(
                name: gov,
                city: Value(gov),
                courtKind: Value(kind.id),
              ),
        ],
      );

      // مواضيع دعاوى جاهزة
      b.insertAll(caseSubjects, [
        CaseSubjectsCompanion.insert(name: 'مطالبة مالية', category: const Value('مدني')),
        CaseSubjectsCompanion.insert(name: 'تثبيت بيع عقار', category: const Value('مدني')),
        CaseSubjectsCompanion.insert(name: 'إخلاء مأجور', category: const Value('مدني')),
        CaseSubjectsCompanion.insert(name: 'تثبيت زواج ونسب', category: const Value('شرعي')),
        CaseSubjectsCompanion.insert(name: 'تثبيت طلاق ومخالعة رضائية', category: const Value('شرعي')),
        CaseSubjectsCompanion.insert(name: 'نفقة زوجية وأولاد', category: const Value('شرعي')),
        CaseSubjectsCompanion.insert(name: 'فسخ عقد تجاري ومطالبة بالعطل والضرر', category: const Value('تجاري')),
        CaseSubjectsCompanion.insert(name: 'إساءة أمانة', category: const Value('جزائي')),
        CaseSubjectsCompanion.insert(name: 'شيك بلا رصيد', category: const Value('جزائي')),
      ]);

      // صفات الأطراف
      b.insertAll(partyRolesLookup, [
        PartyRolesLookupCompanion.insert(roleName: 'مدعي', category: 'civil'),
        PartyRolesLookupCompanion.insert(roleName: 'مدعى عليه', category: 'civil'),
        PartyRolesLookupCompanion.insert(roleName: 'متدخل / شخص ثالث', category: 'civil'),
        PartyRolesLookupCompanion.insert(roleName: 'مستأنف', category: 'civil'),
        PartyRolesLookupCompanion.insert(roleName: 'مستأنف عليه', category: 'civil'),
        PartyRolesLookupCompanion.insert(roleName: 'طاعن', category: 'civil'),
        PartyRolesLookupCompanion.insert(roleName: 'مطعون ضده', category: 'civil'),
        PartyRolesLookupCompanion.insert(roleName: 'مدعي شخصي / شاكي', category: 'criminal'),
        PartyRolesLookupCompanion.insert(roleName: 'مشكو منه / متهم / ظنين', category: 'criminal'),
      ]);

      // مندوبو فروع النقابة وكتاب العدل الافتراضيون (سوريا)
      b.insertAll(notaries, [
        NotariesCompanion.insert(name: 'مندوب نقابة المحامين - فرع دمشق', branch: const Value('دمشق'), type: 'delegate'),
        NotariesCompanion.insert(name: 'مندوب نقابة المحامين - فرع ريف دمشق', branch: const Value('ريف دمشق'), type: 'delegate'),
        NotariesCompanion.insert(name: 'مندوب نقابة المحامين - فرع السويداء', branch: const Value('السويداء'), type: 'delegate'),
        NotariesCompanion.insert(name: 'مندوب نقابة المحامين - فرع درعا', branch: const Value('درعا'), type: 'delegate'),
        NotariesCompanion.insert(name: 'مندوب نقابة المحامين - فرع حمص', branch: const Value('حمص'), type: 'delegate'),
        NotariesCompanion.insert(name: 'مندوب نقابة المحامين - فرع حلب', branch: const Value('حلب'), type: 'delegate'),
        NotariesCompanion.insert(name: 'مندوب نقابة المحامين - فرع اللاذقية', branch: const Value('اللاذقية'), type: 'delegate'),
        NotariesCompanion.insert(name: 'دائرة الكاتب بالعدل الأول بدمشق', branch: const Value('دمشق'), type: 'public_notary'),
        NotariesCompanion.insert(name: 'دائرة الكاتب بالعدل الأول بالسويداء', branch: const Value('السويداء'), type: 'public_notary'),
      ]);
    });
  }
}

/// إنشاء الاتصال مع قاعدة البيانات المحلية في Isolate خلفي على Windows دون اعتماد OpenSSL خارجي
LazyDatabase _openDatabase() {
  return LazyDatabase(() async {
    // المسار قد يكون مخصَّصاً من المستخدم؛ StorageLocationService
    // تُهيَّأ في main قبل runApp فيكون الجذر جاهزاً هنا.
    final lawOfficeDir = Directory(StorageLocationService.activeRoot);
    if (!await lawOfficeDir.exists()) {
      await lawOfficeDir.create(recursive: true);
    }

    final file = File(StorageLocationService.databaseFile);

    return NativeDatabase.createInBackground(
      file,
      setup: (rawDb) {
        // فرض سلامة العلاقات الخارجية عند فتح قاعدة البيانات المحلية.
        rawDb.execute("PRAGMA foreign_keys = ON;");
        rawDb.execute("PRAGMA journal_mode=WAL;");
        rawDb.execute("PRAGMA synchronous=NORMAL;");
      },
    );
  });
}
