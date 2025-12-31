import 'package:flutter/material.dart';
import 'package:whatsapp_catalog/app/router/app_router.dart';
import 'package:whatsapp_catalog/app/theme/app_theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WhatsApp Katalog',
      theme: AppTheme.light(),
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}

