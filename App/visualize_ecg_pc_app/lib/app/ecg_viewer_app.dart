import 'package:flutter/material.dart';

import '../features/ecg_viewer/pages/ecg_viewer_page.dart';

class EcgViewerApp extends StatelessWidget {
  const EcgViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AD8232 ECG Paper Viewer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xffb3261e),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xfff8f6f2),
        useMaterial3: true,
      ),
      home: const EcgViewerPage(),
    );
  }
}
