import 'package:flutter/material.dart';

import 'persons_list_screen.dart';

/// شاشة الأشخاص والجهات الرئيسية.
class PersonsScreen extends StatelessWidget {
  const PersonsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الأشخاص والجهات')),
      body: const PersonsListScreen(),
    );
  }
}
