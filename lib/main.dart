import 'package:flutter/material.dart';
import 'package:ubiuas/mapScreen.dart'; // Reemplaza con tu implementación del mapa
import 'package:ubiuas/chatBot.dart'; // Asegúrate de que las rutas sean correctas
import 'package:geolocator/geolocator.dart'; // Importar Geolocator
import 'package:permission_handler/permission_handler.dart'; // Importar permission_handler

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mapa con Chatbot',
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          ChatBot(),
        ],
      ),
    );
  }
}
