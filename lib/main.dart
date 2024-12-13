import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'scanner_page.dart';

List<CameraDescription>? cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Object Scanner',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ScannerPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
