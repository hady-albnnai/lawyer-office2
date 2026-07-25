import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/permission_catalog.dart';

import '../providers/auth_providers.dart';
import '../screens/agenda/agenda_screen.dart';
import '../screens/cases/case_detail_screen.dart';
import '../screens/cases/cases_screen.dart';
import '../screens/cases/create_case_wizard.dart';
import '../screens/work_center/daily_work_center_screen.dart';
import '../screens/documents/documents_screen.dart';
import '../screens/documents/document_viewer.dart';
import '../screens/files/files_screen.dart';
import '../screens/finance/finance_screen.dart';
import '../screens/legal_library/legal_library_screen.dart';
import '../screens/main_layout_screen.dart';
import '../screens/onboarding/first_run_setup_screen.dart';
import '../screens/persons/person_detail_screen.dart';
import '../screens/persons/persons_screen.dart';
import '../screens/poa/poa_detail_screen.dart';
import '../screens/poa/poa_list_screen.dart';
import '../screens/search_reports/search_reports_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/work_orders/work_orders_screen.dart';
import '../screens/companies/companies_list_screen.dart';
import '../screens/companies/company_detail_screen.dart';
import '../screens/companies/create_company_wizard.dart';
import '../screens/contracts/contracts_list_screen.dart';
import '../screens/contracts/contract_detail_screen.dart';
import '../screens/contracts/create_contract_screen.dart';
import '../screens/admin_procedures/procedures_list_screen.dart';
import '../screens/admin_procedures/procedure_detail_screen.dart';
import '../screens/admin_procedures/create_procedure_screen.dart';
import '../screens/tasks/daily_tasks_screen.dart';
import '../screens/templates/legal_templates_screen.dart';
import '../screens/reports/legal_printing_screen.dart';
import '../screens/archive/archive_screen.dart';
import '../screens/archive_intake/archive_intake_screen.dart';
import '../screens/auth/login_screen.dart';
import '../widgets/archive_context_banner.dart';


final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (!auth.initialized || auth.isLoading && loc == '/splash') return null;
      if (!auth.initialized) return '/splash';
      if (!auth.hasOwner) return loc == '/setup' ? null : '/setup';
      if (!auth.isAuthenticated) {
        if (loc == '/login') return null;
        return '/login';
      }
      if (loc == '/splash' || loc == '/login' || loc == '/setup' || loc == '/') return '/today';
      final denied = _requiredPermissionForLocation(loc);
      if (denied != null && !(auth.user?.permissions.contains(denied) ?? false)) return '/no-access';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', name: 'splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', name: 'login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/setup',
        name: 'setup',
        builder: (_, __) => const FirstRunSetupScreen(),
      ),
      GoRoute(path: '/no-access', name: 'no-access', builder: (_, __) => const _NoAccessScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShellScreen(child: child),
        routes: [
          GoRoute(path: '/today', name: 'today', builder: (_, __) => const DailyWorkCenterScreen()),
          GoRoute(path: '/agenda', name: 'agenda', builder: (_, __) => const AgendaScreen()),
          GoRoute(path: '/new-work', redirect: (_, __) => '/today'),
          GoRoute(path: '/files', name: 'files', builder: (_, state) => FilesScreen(initialStatus: state.uri.queryParameters['status'])),
          GoRoute(path: '/persons', name: 'persons', builder: (_, __) => const PersonsScreen()),
          GoRoute(path: '/poa', name: 'poa', builder: (_, state) => PoaListScreen(archiveContext: ArchiveEntryContext.fromQuery(state.uri.queryParameters))),
          GoRoute(path: '/work-orders', name: 'work-orders', builder: (_, __) => const WorkOrdersScreen()),
          GoRoute(path: '/finance', name: 'finance', builder: (_, __) => const FinanceScreen()),
          GoRoute(path: '/documents', name: 'documents', builder: (_, __) => const DocumentsScreen()),
          GoRoute(path: '/documents/:documentId', name: 'document-viewer', builder: (_, state) => DocumentViewerScreen(documentId: state.pathParameters['documentId'] ?? '')),
          GoRoute(path: '/legal-library', name: 'legal-library', builder: (_, __) => const LegalLibraryScreen()),
          GoRoute(path: '/search-reports', name: 'search-reports', builder: (_, __) => const SearchReportsScreen()),
          GoRoute(path: '/settings', name: 'settings', builder: (_, __) => const SettingsScreen()),
          GoRoute(path: '/templates', name: 'legal-templates', builder: (_, __) => const LegalTemplatesScreen()),
          
          GoRoute(path: '/cases', name: 'cases', builder: (_, __) => const CasesScreen()),
          // New discovered routes:
          GoRoute(path: '/companies', name: 'companies', builder: (_, __) => const CompaniesListScreen()),
          GoRoute(path: '/contracts', name: 'contracts', builder: (_, __) => const ContractsListScreen()),
          GoRoute(path: '/procedures', name: 'procedures', builder: (_, __) => const ProceduresListScreen()),
          GoRoute(path: '/tasks', name: 'tasks', builder: (_, __) => const DailyTasksScreen()),
          GoRoute(path: '/printing', name: 'printing', builder: (_, __) => const LegalPrintingScreen()),
          GoRoute(path: '/archive-intake', name: 'archive-intake', builder: (_, __) => const ArchiveIntakeScreen()),
          GoRoute(path: '/archive', name: 'archive', builder: (_, __) => const ArchiveScreen()),

          // Detail Routes inside ShellRoute
          GoRoute(path: '/persons/:personId', name: 'person-detail', builder: (_, state) => PersonDetailScreen(personId: state.pathParameters['personId'] ?? '')),
          GoRoute(path: '/poa/:agencyId', name: 'poa-detail', builder: (_, state) => PoaDetailScreen(agencyId: state.pathParameters['agencyId'] ?? '')),
          GoRoute(path: '/cases/create', name: 'case-create', builder: (_, state) => CreateCaseWizard(archiveContext: ArchiveEntryContext.fromQuery(state.uri.queryParameters))),
          GoRoute(path: '/cases/:caseId', name: 'case-detail', builder: (_, state) { final caseId = int.tryParse(state.pathParameters['caseId'] ?? '0') ?? 0; return CaseDetailScreen(caseId: caseId); }),
          GoRoute(path: '/companies/create', name: 'company-create', builder: (_, state) => CreateCompanyWizard(archiveContext: ArchiveEntryContext.fromQuery(state.uri.queryParameters))),
          GoRoute(path: '/companies/:companyId', name: 'company-detail', builder: (_, state) { final id = int.tryParse(state.pathParameters['companyId'] ?? '0') ?? 0; return CompanyDetailScreen(companyId: id); }),
          GoRoute(path: '/contracts/templates', redirect: (_, __) => '/templates'),
          GoRoute(path: '/contracts/create', name: 'contract-create', builder: (_, state) => CreateContractScreen(archiveContext: ArchiveEntryContext.fromQuery(state.uri.queryParameters))),
          GoRoute(path: '/contracts/:contractId', name: 'contract-detail', builder: (_, state) { final id = int.tryParse(state.pathParameters['contractId'] ?? '0') ?? 0; return ContractDetailScreen(contractId: id); }),
          GoRoute(path: '/procedures/create', name: 'procedure-create', builder: (_, state) => CreateProcedureScreen(archiveContext: ArchiveEntryContext.fromQuery(state.uri.queryParameters))),
          GoRoute(path: '/procedures/:procedureId', name: 'procedure-detail', builder: (_, state) { final id = int.tryParse(state.pathParameters['procedureId'] ?? '0') ?? 0; return ProcedureDetailScreen(procedureId: id); }),

        ],
      ),
      // legacy root
      GoRoute(path: '/', redirect: (_, __) => '/today'),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('خطأ في الملاحة: ${state.error}')),
    ),
  );
});

String? _requiredPermissionForLocation(String loc) {
  if (loc.startsWith('/archive-intake')) return PermissionKeys.archiveIntakeView;
  if (loc.startsWith('/templates') || loc.startsWith('/contracts/templates')) return PermissionKeys.templatesView;
  if (loc.startsWith('/settings')) return PermissionKeys.settingsView;
  if (loc.startsWith('/finance')) return PermissionKeys.financeView;
  if (loc.startsWith('/work-orders')) return PermissionKeys.workOrdersView;
  if (loc.startsWith('/documents/') && loc != '/documents') return PermissionKeys.documentsOpen;
  if (loc.startsWith('/documents')) return PermissionKeys.documentsView;
  if (loc.startsWith('/legal-library')) return PermissionKeys.libraryView;
  if (loc.startsWith('/search-reports')) return PermissionKeys.searchView;
  if (loc.startsWith('/poa')) return PermissionKeys.poaView;
  if (loc.startsWith('/persons')) return PermissionKeys.personsView;
  if (loc.startsWith('/cases/create')) return PermissionKeys.casesCreateNew;
  if (loc.startsWith('/cases')) return PermissionKeys.casesView;
  if (loc.startsWith('/companies/create')) return PermissionKeys.companiesCreate;
  if (loc.startsWith('/companies')) return PermissionKeys.companiesView;
  if (loc.startsWith('/contracts/create')) return PermissionKeys.contractsCreate;
  if (loc.startsWith('/contracts')) return PermissionKeys.contractsView;
  if (loc.startsWith('/procedures/create')) return PermissionKeys.proceduresCreate;
  if (loc.startsWith('/procedures')) return PermissionKeys.proceduresView;
  if (loc.startsWith('/printing')) return PermissionKeys.reportsView;
  return null;
}

class _NoAccessScreen extends StatelessWidget {
  const _NoAccessScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('ليس لديك صلاحية الوصول إلى هذه الصفحة'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => context.go('/today'), child: const Text('العودة للوحة اليوم')),
          ],
        ),
      ),
    );
  }
}
