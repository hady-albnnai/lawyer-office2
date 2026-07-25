import 'package:flutter_test/flutter_test.dart';
import 'package:lawyer_office/presentation/screens/persons/person_models.dart';

void main() {
  test('PersonsDirectoryNotifier filters persons, adds agency, and links agencies to cases', () {
    final notifier = PersonsDirectoryNotifier.withDemoSeed();

    notifier.setSearchQuery('أحمد');
    expect(notifier.state.filteredPersons, isNotEmpty);

    notifier.setRoleFilter(PersonDirectoryRole.client);
    expect(
      notifier.state.filteredPersons.every((person) => person.roles.contains(PersonDirectoryRole.client)),
      isTrue,
    );

    final agencyBefore = notifier.agencyById('agency_1');
    expect(agencyBefore, isNotNull);
    expect(agencyBefore!.linkedCaseIds.contains('999'), isFalse);

    notifier.linkAgencyToCase('agency_1', '999');
    final agencyAfter = notifier.agencyById('agency_1');
    expect(agencyAfter!.linkedCaseIds.contains('999'), isTrue);
    expect(notifier.personById(agencyAfter.principalPersonId)!.caseIds.contains('999'), isTrue);

    final newAgency = AgencyRecord(
      id: 'agency_test',
      number: 'POA-TEST',
      type: AgencyType.special,
      source: AgencySource.notary,
      branch: 'دمشق',
      principalPersonId: 'person_1',
      agentName: 'الأستاذ هادي فيصل البني',
      issuedAt: DateTime(2026, 7, 10),
      documentId: 'doc_test',
    );

    notifier.addAgency(newAgency);
    expect(notifier.agencyById('agency_test'), isNotNull);
    expect(notifier.personById('person_1')!.agencyIds.contains('agency_test'), isTrue);
  });
}
