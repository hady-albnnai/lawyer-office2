import 'package:flutter/material.dart';

import 'persons_list_screen.dart';

/// شاشة الأشخاص والجهات الرئيسية.
class PersonsScreen extends StatelessWidget {
  /// دور ابتدائي للفلترة (من السايدبار: ?role=client, opponent, etc.)
  final String? initialRole;
  const PersonsScreen({super.key, this.initialRole});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الأشخاص والجهات')),
      body: PersonsListScreen(initialRole: initialRole),
    );
  }
}
