import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // সম্পূর্ণ অ্যাপের স্টেট ধরে রাখার জন্য ProviderScope ব্যবহার করা হয়েছে
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Global AI Train Tracker',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: const Color(0xFF0F2027),
      ),
      // অ্যাপ ওপেন হওয়ার সাথে সাথে লগইন পেজ শো করবে
      home: const LoginPage(),
    );
  }
}