// ignore_for_file: unused_element, camel_case_types

import 'package:app1/widgets/stateless_widget.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

//DO NOT EXPORT AND USE ANY WIDGETS OR COMPONENTS FROM THIS
//OR ANY OTHER WIDGETBOOK LIBRARY. ONLY USED FOR
//FRONTEND DOCUMENTATION PURPOSES.

@widgetbook.UseCase(
  name: "Default",
  type: Widget1,
)
Widget widget1DefaultUseCase(BuildContext context) {
  return const Center(
    child: Widget1(),
  );
}
