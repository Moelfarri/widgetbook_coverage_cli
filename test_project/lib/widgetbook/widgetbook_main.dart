// ignore_for_file: depend_on_referenced_packages, implementation_imports, unused_import, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:accessibility_tools/accessibility_tools.dart';

//external imports
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:widgetbook/widgetbook.dart';
import 'widgetbook_main.directories.g.dart';

//DO NOT EXPORT AND USE ANY WIDGETS OR COMPONENTS FROM THIS
//OR ANY OTHER WIDGETBOOK LIBRARY. ONLY USED FOR
//FRONTEND DOCUMENTATION PURPOSES.

@widgetbook.App()
class WidgetbookApp extends StatefulWidget {
  const WidgetbookApp({super.key});

  @override
  State<WidgetbookApp> createState() => _WidgetbookAppState();
}

class _WidgetbookAppState extends State<WidgetbookApp> {
  GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      // gave better performance to inject a navigator for the app builder
      appBuilder: (context, directories) => Navigator(
        key: navigatorKey,
        onGenerateRoute: (route) => MaterialPageRoute(
          settings: route,
          builder: (context) => directories,
        ),
      ),
      directories: directories,
      addons: [
        TextScaleAddon(
          scales: [1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0],
        ),
        LocalizationAddon(
          locales: [
            const Locale('en', 'US'),
          ],
          localizationsDelegates: [
            DefaultWidgetsLocalizations.delegate,
            DefaultMaterialLocalizations.delegate,
          ],
        ),
        InspectorAddon(enabled: false),
        DeviceFrameAddon(
          initialDevice: Devices.android.mediumTablet,
          devices: [
            Devices.ios.iPadPro11Inches,
            Devices.android.mediumTablet,
            Devices.android.largeTablet,
          ],
        ),
        // AccessibilityAddon(),
        ZoomAddon(initialZoom: 1.0),
      ],
    );
  }
}

void main() {
  runApp(const WidgetbookApp());
}
