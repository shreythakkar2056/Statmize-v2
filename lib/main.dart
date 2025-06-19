import 'package:flutter/material.dart';
import 'package:app/core/theme.dart';
import 'package:app/screens/home_screen.dart';
import 'package:app/screens/login_screen.dart';
import 'package:app/screens/settings_page.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _isLoggedIn = false; // Simulated login state

  @override
  void initState() {
    super.initState();
    _requestStoragePermission();
  }

  Future<void> _requestStoragePermission() async {
    await Permission.storage.request();
  }

  void _toggleTheme(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  void _onLoginSkipped() {
    setState(() {
      _isLoggedIn = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Statmize',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: _isLoggedIn
          ? HomeScreen(
              themeMode: _themeMode,
              onThemeModeChanged: _toggleTheme,
            )
          : LoginScreenWithSkip(onSkip: _onLoginSkipped),
    );
  }
}

// Wrapper to handle skip callback
class LoginScreenWithSkip extends StatelessWidget {
  final VoidCallback onSkip;
  const LoginScreenWithSkip({super.key, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return LoginScreen(onSkip: onSkip);
  }
}