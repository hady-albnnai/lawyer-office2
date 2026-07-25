import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../persons/persons_list_screen.dart';
import '../poa/poa_list_screen.dart';
import '../cases/cases_screen.dart';
import '../companies/companies_list_screen.dart';
import '../contracts/contracts_list_screen.dart';
import '../admin_procedures/procedures_list_screen.dart';

/// شاشة الأرشيف العام لمكتب المحاماة السوري (ArchiveScreen)
/// تصنف كل المدخلات في 6 فئات رئيسية (الدعاوى، الإجراءات، الشركات، العقود، الموكلون، والوكالات)
class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppConstants.primaryNavy,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: AppConstants.accentGold,
            labelColor: AppConstants.accentGold,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            tabs: const [
              Tab(icon: Icon(Icons.gavel), text: 'الدعاوى القضائية'),
              Tab(icon: Icon(Icons.assignment), text: 'الإجراءات الإدارية'),
              Tab(icon: Icon(Icons.business), text: 'تأسيس الشركات'),
              Tab(icon: Icon(Icons.description), text: 'العقود والنماذج'),
              Tab(icon: Icon(Icons.people), text: 'الأشخاص والموكلون'),
              Tab(icon: Icon(Icons.verified_user), text: 'الوكالات القضائية'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              const CasesScreen(),
              const ProceduresListScreen(),
              const CompaniesListScreen(),
              const ContractsListScreen(),
              const PersonsListScreen(),
              const PoaListScreen(),
            ],
          ),
        ),
      ],
    );
  }
}
