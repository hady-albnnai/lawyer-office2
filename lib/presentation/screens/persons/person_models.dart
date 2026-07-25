/// نماذج واجهة المرحلة 6 للأشخاص والجهات والوكالات.
///
/// هذه النماذج تعرض سجل الأشخاص والوكالات بشكل مستقل وقابل للاختبار، مع
/// إمكانية ربطها لاحقاً بمستودعات Drift الحالية دون تغيير واجهات العرض.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_colors.dart';
import '../../providers/ui_data_providers.dart';

/// نوع سجل الشخص أو الجهة.
enum PersonDirectoryKind {
  natural,
  legal;

  String get displayName => const ['شخص طبيعي', 'شخص اعتباري / جهة'][index];

  IconData get icon => const [Icons.person, Icons.business][index];
}

/// دور السجل داخل المكتب.
enum PersonDirectoryRole {
  client,
  opponent,
  opponentLawyer,
  notary,
  barDelegate,
  teamMember,
  legalEntity,
  contractParty;

  String get displayName => const [
        'موكل',
        'خصم',
        'محامي خصم',
        'كاتب عدل',
        'مندوب نقابة',
        'فريق المكتب',
        'شركة / جهة اعتبارية',
        'طرف عقدي',
      ][index];

  Color get color => const [
        AppColors.success,
        AppColors.error,
        AppColors.warning,
        AppColors.info,
        AppColors.primaryNavy,
        AppColors.secondaryGold,
        AppColors.primaryNavy,
        AppColors.info,
      ][index];
}

/// جهة تنظيم الوكالة.
enum AgencySource {
  notary,
  barDelegate;

  String get displayName => const ['كاتب عدل', 'مندوب نقابة'][index];
}

/// نوع الوكالة.
enum AgencyType {
  general,
  special,
  sharia;

  /// التسمية المعتمدة في خطة القوائم المرجعية (البند 56).
  String get displayName => const ['سند توكيل عام', 'سند توكيل خاص', 'سند توكيل خاص شرعي'][index];
}

/// حدث زمني ضمن سجل شخص أو وكالة.
class DirectoryTimelineEvent {
  final String id;
  final String title;
  final String description;
  final String type;
  final DateTime date;
  final String createdBy;

  const DirectoryTimelineEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.date,
    this.createdBy = 'مكتب المحامي',
  });
}

/// سجل شخص أو جهة في المكتب.
class PersonDirectoryRecord {
  final String id;
  final PersonDirectoryKind kind;
  final String fullName;
  final String fatherName;
  final String motherName;
  final String nationalId;
  final String registryInfo;
  final String phone;
  final String whatsapp;
  final String email;
  final String address;
  final String city;
  final String profession;
  final String legalRepresentative;
  final String representativeCapacity;
  final String notes;
  final List<PersonDirectoryRole> roles;
  final List<String> agencyIds;
  final List<String> caseIds;
  final List<String> contractIds;
  final List<String> companyIds;
  final List<String> procedureIds;
  final List<String> documentIds;
  final double receivables;
  final double payables;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<DirectoryTimelineEvent> timeline;

  const PersonDirectoryRecord({
    required this.id,
    required this.kind,
    required this.fullName,
    this.fatherName = '',
    this.motherName = '',
    this.nationalId = '',
    this.registryInfo = '',
    this.phone = '',
    this.whatsapp = '',
    this.email = '',
    this.address = '',
    this.city = '',
    this.profession = '',
    this.legalRepresentative = '',
    this.representativeCapacity = '',
    this.notes = '',
    this.roles = const [],
    this.agencyIds = const [],
    this.caseIds = const [],
    this.contractIds = const [],
    this.companyIds = const [],
    this.procedureIds = const [],
    this.documentIds = const [],
    this.receivables = 0,
    this.payables = 0,
    required this.createdAt,
    required this.updatedAt,
    this.timeline = const [],
  });

  bool hasRole(PersonDirectoryRole role) => roles.contains(role);

  double get balance => receivables - payables;

  PersonDirectoryRecord copyWith({
    String? fullName,
    PersonDirectoryKind? kind,
    String? fatherName,
    String? motherName,
    String? nationalId,
    String? registryInfo,
    String? phone,
    String? whatsapp,
    String? email,
    String? address,
    String? city,
    String? profession,
    String? legalRepresentative,
    String? representativeCapacity,
    String? notes,
    List<PersonDirectoryRole>? roles,
    List<String>? agencyIds,
    List<String>? caseIds,
    List<String>? contractIds,
    List<String>? companyIds,
    List<String>? procedureIds,
    List<String>? documentIds,
    double? receivables,
    double? payables,
    DateTime? updatedAt,
    List<DirectoryTimelineEvent>? timeline,
  }) {
    return PersonDirectoryRecord(
      id: id,
      kind: kind ?? this.kind,
      fullName: fullName ?? this.fullName,
      fatherName: fatherName ?? this.fatherName,
      motherName: motherName ?? this.motherName,
      nationalId: nationalId ?? this.nationalId,
      registryInfo: registryInfo ?? this.registryInfo,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      email: email ?? this.email,
      address: address ?? this.address,
      city: city ?? this.city,
      profession: profession ?? this.profession,
      legalRepresentative: legalRepresentative ?? this.legalRepresentative,
      representativeCapacity: representativeCapacity ?? this.representativeCapacity,
      notes: notes ?? this.notes,
      roles: roles ?? this.roles,
      agencyIds: agencyIds ?? this.agencyIds,
      caseIds: caseIds ?? this.caseIds,
      contractIds: contractIds ?? this.contractIds,
      companyIds: companyIds ?? this.companyIds,
      procedureIds: procedureIds ?? this.procedureIds,
      documentIds: documentIds ?? this.documentIds,
      receivables: receivables ?? this.receivables,
      payables: payables ?? this.payables,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      timeline: timeline ?? this.timeline,
    );
  }
}

/// وكالة قضائية أو قانونية.
class AgencyRecord {
  final String id;
  final String number;
  final AgencyType type;
  final AgencySource source;
  final String branch;
  final String principalPersonId;
  final String agentName;
  final DateTime issuedAt;
  final DateTime? expiresAt;
  final String scope;
  final String documentId;
  final String notes;
  final List<String> linkedCaseIds;
  final List<DirectoryTimelineEvent> timeline;

  const AgencyRecord({
    required this.id,
    required this.number,
    required this.type,
    required this.source,
    required this.branch,
    required this.principalPersonId,
    required this.agentName,
    required this.issuedAt,
    this.expiresAt,
    this.scope = '',
    this.documentId = '',
    this.notes = '',
    this.linkedCaseIds = const [],
    this.timeline = const [],
  });

  bool get hasDocument => documentId.isNotEmpty;

  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());

  AgencyRecord copyWith({
    String? number,
    AgencyType? type,
    AgencySource? source,
    String? branch,
    String? principalPersonId,
    String? agentName,
    DateTime? issuedAt,
    DateTime? expiresAt,
    String? scope,
    String? documentId,
    String? notes,
    List<String>? linkedCaseIds,
    List<DirectoryTimelineEvent>? timeline,
  }) {
    return AgencyRecord(
      id: id,
      number: number ?? this.number,
      type: type ?? this.type,
      source: source ?? this.source,
      branch: branch ?? this.branch,
      principalPersonId: principalPersonId ?? this.principalPersonId,
      agentName: agentName ?? this.agentName,
      issuedAt: issuedAt ?? this.issuedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      scope: scope ?? this.scope,
      documentId: documentId ?? this.documentId,
      notes: notes ?? this.notes,
      linkedCaseIds: linkedCaseIds ?? this.linkedCaseIds,
      timeline: timeline ?? this.timeline,
    );
  }
}

/// حالة دليل الأشخاص والوكالات.
class PersonsDirectoryState {
  final List<PersonDirectoryRecord> persons;
  final List<AgencyRecord> agencies;
  final String searchQuery;
  final PersonDirectoryRole? roleFilter;

  const PersonsDirectoryState({
    required this.persons,
    required this.agencies,
    this.searchQuery = '',
    this.roleFilter,
  });

  List<PersonDirectoryRecord> get filteredPersons {
    final query = searchQuery.trim().toLowerCase();
    return persons.where((person) {
      final roleOk = roleFilter == null || person.roles.contains(roleFilter);
      final queryOk = query.isEmpty ||
          person.fullName.toLowerCase().contains(query) ||
          person.nationalId.toLowerCase().contains(query) ||
          person.phone.toLowerCase().contains(query) ||
          person.whatsapp.toLowerCase().contains(query) ||
          person.city.toLowerCase().contains(query);
      return roleOk && queryOk;
    }).toList();
  }

  PersonDirectoryRecord? personById(String id) {
    return persons.where((person) => person.id == id).firstOrNull;
  }

  AgencyRecord? agencyById(String id) {
    return agencies.where((agency) => agency.id == id).firstOrNull;
  }

  PersonsDirectoryState copyWith({
    List<PersonDirectoryRecord>? persons,
    List<AgencyRecord>? agencies,
    String? searchQuery,
    PersonDirectoryRole? roleFilter,
    bool clearRoleFilter = false,
  }) {
    return PersonsDirectoryState(
      persons: persons ?? this.persons,
      agencies: agencies ?? this.agencies,
      searchQuery: searchQuery ?? this.searchQuery,
      roleFilter: clearRoleFilter ? null : roleFilter ?? this.roleFilter,
    );
  }
}

final personsDirectoryProvider = StateNotifierProvider<PersonsDirectoryNotifier, PersonsDirectoryState>((ref) {
  final notifier = PersonsDirectoryNotifier();
  ref.listen<AsyncValue<PersonsDirectoryState>>(uiPersonsDirectoryProvider, (prev, next) {
    next.whenData(notifier.hydrateFromDb);
  });
  // kick load
  ref.watch(uiPersonsDirectoryProvider);
  return notifier;
});

class PersonsDirectoryNotifier extends StateNotifier<PersonsDirectoryState> {
  PersonsDirectoryNotifier() : super(const PersonsDirectoryState(persons: [], agencies: []));

  /// نسخة ببيانات تجريبية، للاختبارات فقط.
  /// التطبيق الفعلي يبدأ فارغاً ويُغذّى من قاعدة البيانات عبر [hydrateFromDb].
  @visibleForTesting
  PersonsDirectoryNotifier.withDemoSeed() : super(_seedState());

  void hydrateFromDb(PersonsDirectoryState dbState) {
    if (state.roleFilter == null) {
      state = dbState.copyWith(searchQuery: state.searchQuery, clearRoleFilter: true);
    } else {
      state = dbState.copyWith(searchQuery: state.searchQuery, roleFilter: state.roleFilter);
    }
  }

  static PersonsDirectoryState _seedState() {
    final now = DateTime(2026, 7, 10);
    final persons = [
      PersonDirectoryRecord(
        id: 'person_1',
        kind: PersonDirectoryKind.natural,
        fullName: 'أحمد محمد الخطيب',
        fatherName: 'محمد',
        motherName: 'فاطمة',
        nationalId: '01010010001',
        registryInfo: 'دمشق - الميدان / 456',
        phone: '0933000001',
        whatsapp: '0933000001',
        email: 'client1@example.com',
        address: 'دمشق - المزة',
        city: 'دمشق',
        profession: 'تاجر',
        notes: 'موكل رئيسي في ملف تعويض.',
        roles: const [PersonDirectoryRole.client],
        agencyIds: const ['agency_1'],
        caseIds: const ['1', '3'],
        contractIds: const ['contract_1'],
        documentIds: const ['doc_1', 'doc_3'],
        receivables: 5000000,
        payables: 250000,
        createdAt: now.subtract(const Duration(days: 25)),
        updatedAt: now.subtract(const Duration(days: 1)),
        timeline: [
          DirectoryTimelineEvent(
            id: 'person_1_created',
            title: 'فتح سجل موكل',
            description: 'تم إدخال بيانات الموكل وربط أول وكالة.',
            type: 'created',
            date: now.subtract(const Duration(days: 25)),
          ),
        ],
      ),
      PersonDirectoryRecord(
        id: 'person_2',
        kind: PersonDirectoryKind.natural,
        fullName: 'محمد أحمد السالم',
        fatherName: 'أحمد',
        nationalId: '01010010002',
        registryInfo: 'دمشق - الصالحية / 122',
        phone: '0944000002',
        whatsapp: '0944000002',
        address: 'دمشق - الصالحية',
        city: 'دمشق',
        profession: 'مقاول',
        roles: const [PersonDirectoryRole.opponent],
        caseIds: const ['1'],
        documentIds: const ['doc_2'],
        createdAt: now.subtract(const Duration(days: 18)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
      PersonDirectoryRecord(
        id: 'person_3',
        kind: PersonDirectoryKind.legal,
        fullName: 'شركة التطوير الحديث المحدودة المسؤولية',
        phone: '0112222222',
        email: 'info@modern-dev.example',
        address: 'دمشق - البحصة',
        city: 'دمشق',
        legalRepresentative: 'سامي عبد الله',
        representativeCapacity: 'مدير عام ومفوض بالتوقيع',
        roles: const [PersonDirectoryRole.legalEntity, PersonDirectoryRole.client, PersonDirectoryRole.contractParty],
        agencyIds: const ['agency_2'],
        caseIds: const ['2'],
        contractIds: const ['contract_2'],
        companyIds: const ['company_1'],
        documentIds: const ['doc_4', 'doc_5'],
        receivables: 2500000,
        payables: 125000,
        createdAt: now.subtract(const Duration(days: 35)),
        updatedAt: now.subtract(const Duration(days: 3)),
      ),
      PersonDirectoryRecord(
        id: 'person_4',
        kind: PersonDirectoryKind.natural,
        fullName: 'الأستاذ كريم ناصر',
        phone: '0955000004',
        address: 'دمشق - المالكي',
        city: 'دمشق',
        profession: 'محامي',
        roles: const [PersonDirectoryRole.opponentLawyer],
        createdAt: now.subtract(const Duration(days: 12)),
        updatedAt: now.subtract(const Duration(days: 4)),
      ),
      PersonDirectoryRecord(
        id: 'person_5',
        kind: PersonDirectoryKind.natural,
        fullName: 'دائرة الكاتب بالعدل الأول بدمشق',
        phone: '0113333333',
        address: 'دمشق - القصر العدلي',
        city: 'دمشق',
        roles: const [PersonDirectoryRole.notary],
        createdAt: now.subtract(const Duration(days: 60)),
        updatedAt: now.subtract(const Duration(days: 8)),
      ),
      PersonDirectoryRecord(
        id: 'person_6',
        kind: PersonDirectoryKind.natural,
        fullName: 'مندوب نقابة المحامين - فرع السويداء',
        phone: '0165555555',
        address: 'السويداء - فرع النقابة',
        city: 'السويداء',
        roles: const [PersonDirectoryRole.barDelegate],
        createdAt: now.subtract(const Duration(days: 60)),
        updatedAt: now.subtract(const Duration(days: 8)),
      ),
      PersonDirectoryRecord(
        id: 'person_7',
        kind: PersonDirectoryKind.natural,
        fullName: 'هادي فيصل البني',
        phone: '0999000000',
        whatsapp: '0999000000',
        address: 'مكتب المحامي',
        city: 'دمشق',
        profession: 'محامي أستاذ',
        roles: const [PersonDirectoryRole.teamMember],
        createdAt: now.subtract(const Duration(days: 90)),
        updatedAt: now,
      ),
    ];

    final agencies = [
      AgencyRecord(
        id: 'agency_1',
        number: 'POA-2026-001',
        type: AgencyType.general,
        source: AgencySource.barDelegate,
        branch: 'دمشق',
        principalPersonId: 'person_1',
        agentName: 'الأستاذ هادي فيصل البني',
        issuedAt: now.subtract(const Duration(days: 20)),
        expiresAt: now.add(const Duration(days: 345)),
        scope: 'وكالة قضائية عامة للمرافعة والمدافعة والمخاصمة.',
        documentId: 'doc_1',
        linkedCaseIds: const ['1'],
      ),
      AgencyRecord(
        id: 'agency_2',
        number: 'POA-2026-002',
        type: AgencyType.special,
        source: AgencySource.notary,
        branch: 'دمشق',
        principalPersonId: 'person_3',
        agentName: 'الأستاذ هادي فيصل البني',
        issuedAt: now.subtract(const Duration(days: 15)),
        scope: 'وكالة خاصة بملف الاستئناف التجاري.',
        documentId: 'doc_4',
        linkedCaseIds: const ['2'],
      ),
    ];

    return PersonsDirectoryState(persons: persons, agencies: agencies);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setRoleFilter(PersonDirectoryRole? role) {
    state = role == null ? state.copyWith(clearRoleFilter: true) : state.copyWith(roleFilter: role);
  }

  PersonDirectoryRecord? personById(String id) {
    return state.persons.where((person) => person.id == id).firstOrNull;
  }

  AgencyRecord? agencyById(String id) {
    return state.agencies.where((agency) => agency.id == id).firstOrNull;
  }

  List<AgencyRecord> agenciesForPerson(String personId) {
    return state.agencies.where((agency) => agency.principalPersonId == personId).toList();
  }

  void addPerson(PersonDirectoryRecord person) {
    state = state.copyWith(persons: [person, ...state.persons]);
  }

  void updatePerson(PersonDirectoryRecord updatedPerson) {
    state = state.copyWith(
      persons: state.persons
          .map((person) => person.id == updatedPerson.id ? updatedPerson : person)
          .toList(),
    );
  }

  void addAgency(AgencyRecord agency) {
    final event = DirectoryTimelineEvent(
      id: 'agency_created_${DateTime.now().microsecondsSinceEpoch}',
      title: 'إضافة وكالة',
      description: 'تمت إضافة الوكالة رقم ${agency.number}.',
      type: 'agency_created',
      date: DateTime.now(),
    );

    final updatedPersons = state.persons.map((person) {
      if (person.id != agency.principalPersonId || person.agencyIds.contains(agency.id)) {
        return person;
      }
      return person.copyWith(
        agencyIds: [...person.agencyIds, agency.id],
        updatedAt: event.date,
        timeline: [event, ...person.timeline],
      );
    }).toList();

    state = state.copyWith(
      agencies: [agency.copyWith(timeline: [event, ...agency.timeline]), ...state.agencies],
      persons: updatedPersons,
    );
  }

  void addTimelineEvent(String personId, DirectoryTimelineEvent event) {
    final updatedPersons = state.persons.map((person) {
      if (person.id != personId) {
        return person;
      }
      return person.copyWith(
        updatedAt: event.date,
        timeline: [event, ...person.timeline],
      );
    }).toList();
    state = state.copyWith(persons: updatedPersons);
  }

  void linkAgencyToCase(String agencyId, String caseId) {
    final event = DirectoryTimelineEvent(
      id: 'agency_link_${DateTime.now().microsecondsSinceEpoch}',
      title: 'ربط وكالة بدعوى',
      description: 'تم ربط الوكالة بالدعوى رقم $caseId.',
      type: 'agency_linked',
      date: DateTime.now(),
    );

    String? principalPersonId;
    final updatedAgencies = state.agencies.map((agency) {
      if (agency.id != agencyId || agency.linkedCaseIds.contains(caseId)) {
        return agency;
      }
      principalPersonId = agency.principalPersonId;
      return agency.copyWith(
        linkedCaseIds: [...agency.linkedCaseIds, caseId],
        timeline: [event, ...agency.timeline],
      );
    }).toList();

    final updatedPersons = state.persons.map((person) {
      if (person.id != principalPersonId || person.caseIds.contains(caseId)) {
        return person;
      }
      return person.copyWith(
        caseIds: [...person.caseIds, caseId],
        updatedAt: event.date,
        timeline: [event, ...person.timeline],
      );
    }).toList();

    state = state.copyWith(agencies: updatedAgencies, persons: updatedPersons);
  }
}

extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    for (final item in this) {
      return item;
    }
    return null;
  }
}
