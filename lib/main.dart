import 'package:flutter/material.dart';
import 'package:instant_messaging_app/screens/chat_detail_screen.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hello World',
      home: const ChatDetailScreen(),
    );
  }
}
