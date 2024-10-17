// ignore_for_file: file_names
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

class ReadSingleWidgetFileFasterCommand extends Command<int> {
  ReadSingleWidgetFileFasterCommand({
    required Logger logger,
  }) : _logger = logger;

  @override
  String get description =>
      'A command to return all the widgets in a specific dart file';

  @override
  String get name => 'read_single_widget_file_faster';

  final Logger _logger;
  @override
  Future<int> run() async {
    // get the file path from the arguments
    final argResults = this.argResults;
    if (argResults == null || argResults.rest.isEmpty) {
      _logger.err('Please provide a Dart file path.');
      return ExitCode.usage.code;
    }

    final filePath = argResults.rest.first;

    final result = parseFile(
      path: filePath,
      featureSet: FeatureSet.latestLanguageVersion(),
    );

    // Traverse the AST and find widget declarations
    final visitor = WidgetVisitor(_logger);
    result.unit.visitChildren(visitor);

    return ExitCode.success.code;
  }
}

class WidgetVisitor extends GeneralizingAstVisitor<void> {
  WidgetVisitor(this.logger);

  final Logger logger;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    // Start by getting the superclass name
    final superClass = node.extendsClause?.superclass;

    if (superClass != null) {
      final superClassName = superClass.toString();

      if (superClassName == 'StatelessWidget' ||
          superClassName == 'StatefulWidget' ||
          superClassName == 'Widget') {
        logger.info('Found widget: ${node.name}');
      }
    }

    super.visitClassDeclaration(node);
  }
}
