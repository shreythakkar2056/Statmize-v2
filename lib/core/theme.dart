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
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF121212),
      iconTheme: IconThemeData(color: Color(0xFFEFEDE6)),
      titleTextStyle: TextStyle(color: Color(0xFFEFEDE6), fontSize: 20),
    ),
    cardColor: const Color(0xFF282828),
    colorScheme: ColorScheme.dark(
      primary: const Color(0xFFEFEDE6),
      secondary: const Color(0xFFEFEDE6),
      onPrimary: Color(0xFF121212),
      onSurface: Color(0xFFEFEDE6),
    ),
    iconTheme: const IconThemeData(color: Color(0xFFEFEDE6)),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFFEFEDE6), fontWeight: FontWeight.w600),
      bodyMedium: TextStyle(color: Color(0xFFEFEDE6)),
    ),
  );
}