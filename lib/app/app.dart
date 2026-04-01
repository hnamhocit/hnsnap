import 'package:flutter/material.dart';
import 'package:hnsnap/app/router/app_router.dart';
import 'package:hnsnap/app/theme/app_theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'hnsnap',
      themeMode: ThemeMode.dark,
      theme: lightTheme,
      darkTheme: darkTheme,
      routerConfig: router,
    );
  }
}
