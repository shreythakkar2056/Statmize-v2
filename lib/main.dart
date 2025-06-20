import 'package:flutter/material.dart';
import 'package:app/core/theme.dart';
import 'package:app/screens/home_screen.dart';
import 'package:app/screens/login_screen.dart';
import 'package:app/screens/splash_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const supabaseUrl = 'https://xtkghfibtnfwoprppvuf.supabase.co';
  const supabaseKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh0a2doZmlidG5md29wcnBwdnVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA0MjEzNDAsImV4cCI6MjA2NTk5NzM0MH0.ElSLqKdEnNV7ApF3M3ci82k74HYNwIXDGFhNLpYszCc';
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
  );
  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
  }

  void _toggleTheme(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  void _onLoginSkipped() {
    // This can be repurposed or removed if skipping is no longer a feature.
    // For now, Supabase handles auth state.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Statmize',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: StreamBuilder<AuthState>(
        stream: supabase.auth.onAuthStateChange,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashPage();
          }

          if (snapshot.hasData && snapshot.data?.session != null) {
            return HomeScreen(
              themeMode: _themeMode,
              onThemeModeChanged: _toggleTheme,
            );
          }

          return LoginScreen(onSkip: _onLoginSkipped);
        },
      ),
    );
  }
}