// import 'package:flutter/material.dart';

// class AppTheme {
//   static final ThemeData lightTheme = ThemeData(
//     brightness: Brightness.light,
//     scaffoldBackgroundColor: const Color(0xFFF5F5F5),
//     appBarTheme: const AppBarTheme(
//       backgroundColor: Colors.white,
//       iconTheme: IconThemeData(color: Color(0xFF0A0E25)),
//       titleTextStyle: TextStyle(color: Color(0xFF0A0E25), fontSize: 20),
//     ),
//     colorScheme: ColorScheme.light(
//       primary: const Color(0xFF0A0E25),
//       secondary: const Color(0xFF0A0E25),
//       onPrimary: Colors.white,
//       onSurface: Colors.black,
//     ),
//     iconTheme: const IconThemeData(color: Color(0xFF0A0E25)),
//     textTheme: const TextTheme(
//       bodyLarge: TextStyle(color: Colors.black),
//       bodyMedium: TextStyle(color: Colors.black87),
//     ),
//   );

//   static final ThemeData darkTheme = ThemeData(
//     brightness: Brightness.dark,
//     scaffoldBackgroundColor: const Color(0xFF0A0E25), // from logo
//     appBarTheme: const AppBarTheme(
//       backgroundColor: Color(0xFF0A0E25),
//       iconTheme: IconThemeData(color: Color(0xFFEFEDE6)),
//       titleTextStyle: TextStyle(color: Color(0xFFEFEDE6), fontSize: 20),
//     ),
//     colorScheme: ColorScheme.dark(
//       primary: const Color(0xFFEFEDE6),
//       secondary: const Color(0xFFEFEDE6),
//       onPrimary: Color(0xFF0A0E25),
//       onSurface: Color(0xFFEFEDE6),
//     ),
//     iconTheme: const IconThemeData(color: Color(0xFFEFEDE6)),
//     textTheme: const TextTheme(
//       bodyLarge: TextStyle(color: Color(0xFFEFEDE6)),
//       bodyMedium: TextStyle(color: Color(0xFFEFEDE6)),
//     ),
//   );
// }
import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      iconTheme: IconThemeData(color: Color(0xFF0A0E25)),
      titleTextStyle: TextStyle(color: Color(0xFF0A0E25), fontSize: 20),
    ),
    cardColor: Colors.white,
    colorScheme: ColorScheme.light(
      primary: const Color(0xFF0A0E25),
      secondary: const Color(0xFF00B2FF),
      onPrimary: Colors.white,
      onSurface: Colors.black,
    ),
    iconTheme: const IconThemeData(color: Color(0xFF0A0E25)),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
      bodyMedium: TextStyle(color: Colors.black87),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0F172A), // deep navy
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0F172A),
      iconTheme: IconThemeData(color: Color(0xFFEFEDE6)),
      titleTextStyle: TextStyle(color: Color(0xFFEFEDE6), fontSize: 20),
    ),
    cardColor: const Color(0xFF1E293B), // elegant dark card
    colorScheme: ColorScheme.dark(
      primary: const Color(0xFF00B2FF), // neon blue accent
      secondary: const Color(0xFF00FFAA), // electric green
      onPrimary: Color(0xFF0F172A),
      onSurface: Color(0xFFEFEDE6),
    ),
    iconTheme: const IconThemeData(color: Color(0xFF00FFAA)),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFFEFEDE6), fontWeight: FontWeight.w600),
      bodyMedium: TextStyle(color: Color(0xFFEFEDE6)),
    ),
  );
}

// This theme uses Rajdhani font for a modern, techy look
// and incorporates a neon blue accent for a futuristic feel.
// The dark theme features a deep navy background with electric green highlights,
// while the light theme maintains a clean, professional appearance with a touch of blue.
// The card color in dark mode is a subtle, elegant dark gray,
// providing a sleek contrast to the vibrant neon accents.  

//optional 