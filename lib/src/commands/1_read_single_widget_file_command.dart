// ignore_for_file: file_names
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

class ReadSingleWidgetFileCommand extends Command<int> {
  ReadSingleWidgetFileCommand({
    required Logger logger,
  }) : _logger = logger;

  @override
  String get description =>
      'A command to return all the widgets in a specific dart file';

  @override
  String get name => 'read_single_widget_file';

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
    late final SomeResolvedUnitResult result;

    try {
      // analyze the file
      result = await _analyzeFile(File(filePath).absolute.path, _logger);
    } catch (e) {
      _logger.err('Error during analyzer parsing of dart file: $e');
      return ExitCode.ioError.code;
    }

    if (result is ResolvedUnitResult) {
      // Traverse the AST and find widget declarations
      final visitor = WidgetVisitor(_logger);
      result.unit.visitChildren(visitor);
    } else {
      _logger.err('Failed to analyze file: $filePath');
    }

    return ExitCode.success.code;
  }

  Future<SomeResolvedUnitResult> _analyzeFile(
    String filePath,
    Logger logger,
  ) async {
    final file = File(filePath);

    if (!file.existsSync()) {
      throw FileSystemException('File not found: $filePath');
    }

    // Create an AnalysisContextCollection for resolving Dart files
    // in the project
    final collection = AnalysisContextCollection(
      includedPaths: [filePath],
    );

    // Get the analysis context for the file
    final context = collection.contextFor(filePath);

    // Perform analysis on the file
    return context.currentSession.getResolvedUnit(filePath);
  }
}

class WidgetVisitor extends GeneralizingAstVisitor<void> {
  WidgetVisitor(this.logger);

  final Logger logger;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    // Start by getting the superclass name
    final superClass = node.extendsClause?.superclass;

    if (superClass != null && node.declaredElement != null) {
      // Check if the class is or extends a widget
      if (_isWidgetClass(node.declaredElement!)) {
        logger.info('Found widget: ${node.name}');
      }
    }

    super.visitClassDeclaration(node);
  }

  /// Recursively checks if the class extends a widget
  /// by traversing up the class hierarchy
  bool _isWidgetClass(ClassElement classElement) {
    final superType = classElement.supertype;

    // If there's no superclass, it's not a widget
    if (superType == null) return false;

    final superClassName = superType.element.name;

    // Check if this class directly extends StatelessWidget or StatefulWidget
    if (superClassName == 'StatelessWidget' ||
        superClassName == 'StatefulWidget' ||
        superClassName == 'Widget') {
      return true;
    }

    // If not, recursively check the superclass
    final interfaceElement = superType.element;
    if (interfaceElement is! ClassElement) {
      return false;
    }
    return _isWidgetClass(interfaceElement);
  }
}
