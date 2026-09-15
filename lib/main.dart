// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/registration_sync_provider.dart';   // <<< NUOVO

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => AuthProvider(),
        ),
        ChangeNotifierProvider(                              // <<< NUOVO
          create: (context) => RegistrationSyncProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'Musica per Tutti',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: const Color(0xFF6C2BD9),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6C2BD9),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF6C2BD9),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}