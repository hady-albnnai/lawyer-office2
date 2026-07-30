import '../database/database.dart';
import '../database/daos/lookup_dao.dart';

/// مستودع إدارة القوائم السورية الجاهزة والسجلات المرجعية (LookupRepository)
class LookupRepository {
  final LookupDao _lookupDao;

  LookupRepository(this._lookupDao);

  Stream<List<Court>> watchActiveCourts({String? type}) => _lookupDao.watchActiveCourts(type: type);
  Stream<List<Court>> watchCourtsOfKind(String kindId) => _lookupDao.watchCourtsOfKind(kindId);
  Future<Court?> findCourt({required String kindId, required String governorate}) =>
      _lookupDao.findCourt(kindId: kindId, governorate: governorate);
  Future<int> insertCourt(CourtsCompanion companion) => _lookupDao.insertCourt(companion);

  Stream<List<CaseSubject>> watchActiveCaseSubjects({String? category}) => _lookupDao.watchActiveCaseSubjects(category: category);
  Future<int> insertCaseSubject(CaseSubjectsCompanion companion) => _lookupDao.insertCaseSubject(companion);

  Stream<List<PartyRolesLookupData>> watchPartyRoles({required String category}) => _lookupDao.watchPartyRoles(category: category);
  Stream<List<ContractTypesLookupData>> watchContractTypes() => _lookupDao.watchContractTypes();
  Stream<List<CompanyTypesLookupData>> watchCompanyTypes({String? category}) => _lookupDao.watchCompanyTypes(category: category);
}
