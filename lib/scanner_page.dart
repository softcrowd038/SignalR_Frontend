// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:color_identifier/main.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'scanner_overlay.dart';
import 'package:image/image.dart' as img;

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<StatefulWidget> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  CameraController? _cameraController;
  bool _isProcessing = false;
  String? _colorBarUrl;
  String? storedImageUrl;
  List<dynamic>? _colors;
  double? _area;
  String? shape;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_cameraController == null) {
      _initializeCameras();
    }
  }

  Future<void> _initializeCameras() async {
    if (cameras!.isNotEmpty) {
      _cameraController = CameraController(
        cameras![0],
        ResolutionPreset.high,
      );
      await _cameraController?.initialize();
      if (!mounted) return;
      setState(() {});
    } else {
      debugPrint('No cameras available');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _captureAndUpload() async {
    if (_isProcessing || !_cameraController!.value.isInitialized) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final XFile imageFile = await _cameraController!.takePicture();

      final imageBytes = await File(imageFile.path).readAsBytes();
      final originalImage = img.decodeImage(imageBytes);

      if (originalImage == null) {
        throw Exception('Failed to decode image');
      }

      final containerWidth = MediaQuery.of(context).size.width * 0.8;
      final containerHeight = MediaQuery.of(context).size.height * 0.4;

      final cropWidth = (originalImage.width * containerWidth) /
          MediaQuery.of(context).size.width;
      final cropHeight = (originalImage.height * containerHeight) /
          MediaQuery.of(context).size.height;

      final startX = (originalImage.width - cropWidth) ~/ 2;
      final startY = (originalImage.height - cropHeight) ~/ 2;

      final croppedImage = img.copyCrop(
        originalImage,
        x: startX,
        y: startY,
        width: cropWidth.toInt(),
        height: cropHeight.toInt(),
      );

      final croppedFilePath =
          '${(await getTemporaryDirectory()).path}/cropped_image.jpg';
      final croppedFile = File(croppedFilePath)
        ..writeAsBytesSync(img.encodeJpg(croppedImage));

      final uri = Uri.parse("http://192.168.1.4:5000/upload");
      final request = http.MultipartRequest("POST", uri);
      request.files
          .add(await http.MultipartFile.fromPath('file', croppedFile.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final jsonResponse = jsonDecode(responseBody);

        setState(() {
          _colorBarUrl = jsonResponse['color_bar_url'];
          _colors = jsonResponse['colors'];
          _area = jsonResponse['total_area_cm2'];
          storedImageUrl = jsonResponse['contour_image_url'];
          shape = jsonResponse['shape'];
        });
        _showColorsDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to analyze image.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showColorsDialog() {
    if (_colors == null || _colors!.isEmpty) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Color Analysis'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.height * 0.30,
                  height: MediaQuery.of(context).size.height * 0.30,
                  child:
                      Image.network('http://192.168.1.4:5000$storedImageUrl'),
                ),
                Column(
                  children: _colors!.map((colorInfo) {
                    return Row(
                      children: [
                        Container(
                          width: MediaQuery.of(context).size.height * 0.050,
                          height: MediaQuery.of(context).size.height * 0.050,
                          color: Color(
                            int.parse(
                                colorInfo['color'].replaceFirst('#', '0xff')),
                          ),
                        ),
                        SizedBox(
                            width:
                                MediaQuery.of(context).size.height * 0.01600),
                        Expanded(
                          child: Text(
                            '${colorInfo['color']} ( ${colorInfo['proportion']}% )',
                            style: TextStyle(
                                fontSize: MediaQuery.of(context).size.height *
                                    0.01600),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.0100),
                Text(
                  'shape: $shape',
                  style: TextStyle(
                      fontSize: MediaQuery.of(context).size.height * 0.01600),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.0100),
                Text(
                  'Area: $_area sq.cm',
                  style: TextStyle(
                      fontSize: MediaQuery.of(context).size.height * 0.01600),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.0100),
                Image.network(
                  "http://192.168.1.4:5000$_colorBarUrl",
                  height: MediaQuery.of(context).size.height * 0.100,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(
          child: CircularProgressIndicator(
        color: Colors.blue,
      ));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SIGNALR',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue,
      ),
      body: SizedBox(
        height: MediaQuery.of(context).size.height * 0.90,
        width: MediaQuery.of(context).size.width,
        child: Stack(
          children: [
            Padding(
              padding:
                  EdgeInsets.all(MediaQuery.of(context).size.height * 0.015),
              child: Align(
                alignment: Alignment.center,
                child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: CameraPreview(_cameraController!)),
              ),
            ),
            const Positioned.fill(
              child: ScannerOverlay(),
            ),
            Positioned(
              bottom: MediaQuery.of(context).size.width * 0.030,
              left: MediaQuery.of(context).size.width * 0.420,
              child: GestureDetector(
                  onTap: _isProcessing ? null : _captureAndUpload,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(
                        MediaQuery.of(context).size.height * 0.90,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(
                        MediaQuery.of(context).size.height * 0.025,
                      ),
                      child: !_isProcessing
                          ? Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: MediaQuery.of(context).size.height * 0.035,
                            )
                          : const CircularProgressIndicator(
                              color: Colors.white,
                            ),
                    ),
                  )),
            ),
          ],
        ),
      ),
    );
  }
}
