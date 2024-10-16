// ignore_for_file: file_names, lines_longer_than_80_chars, prefer_const_constructors
import 'dart:async';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:widgetbook_coverage_cli/src/error_handling/cli_exception.dart';

class ReadDirectoryAndOutputWidgetsCommand extends Command<int> {
  ReadDirectoryAndOutputWidgetsCommand({
    required Logger logger,
  }) : _logger = logger;

  @override
  String get description =>
      'A command that returns all widgets from a folder, including those in subfolders.';

  @override
  String get name => 'read_directory_and_output_widgets';

  final Logger _logger;
  @override
  Future<int> run() async {
    try {
      // get the folder path from the user argument
      final argResults = this.argResults;
      if (argResults == null || argResults.rest.isEmpty) {
        throw CliException(
          'Please provide a Dart file path.',
          ExitCode.usage.code,
        );
      }
      final folderPath = argResults.rest.first;

      // get all the absolute file paths in the directory
      final dartFiles = await _getAbsoluteFilePaths(folderPath);

      // Traverse the AST and find the name of Widget declarations as the stream
      // is generating the resolved unit results
      final visitor = _WidgetVisitor(_logger);
      _createAnalyzerContextStream(dartFiles, concurrency: 10).listen(
        (result) {
          if (result is ResolvedUnitResult) {
            result.unit.visitChildren(visitor);
          }
        },
      ).onDone(
        () {
          _logger.info(
            'Found ${visitor.widgets.length} Widgets, here is the list: ${visitor.widgets}',
          );
        },
      );

      return ExitCode.success.code;
    } on CliException catch (e) {
      _logger.err(
        e.message,
      );
      return e.exitCode;
    } catch (e) {
      _logger.err(
        e.toString(),
      );
      return -1;
    }
  }

  /* --------------------------------- Comment -------------------------------- */
  // Maybe all the private functions should be dependency injected instead?
  /* --------------------------------- Comment -------------------------------- */

  // gets all the absolute file paths in a directory Path
  Future<List<String>> _getAbsoluteFilePaths(String directoryPath) async {
    final directory = Directory(directoryPath);

    // Check if the provided path is a directory
    if (directory.statSync().type != FileSystemEntityType.directory) {
      throw CliException(
        '$directoryPath is not a directory.',
        ExitCode.ioError.code,
      );
    }

    // Check if the directory exists
    if (!directory.existsSync()) {
      throw CliException(
        'Directory $directoryPath not found.',
        ExitCode.ioError.code,
      );
    }

    // Check if the directory is empty
    if (directory.listSync().isEmpty) {
      throw CliException(
        'Directory $directoryPath is empty. Please check the path or add files to continue.',
        ExitCode.ioError.code,
      );
    }

    // Get the list of dart files
    /* --------------------------------- Comment -------------------------------- */
    // Sidebar: Could lazy load this by only returning the iterable
    // and then loading the file when needed how ever this would require the
    // analyzer context to be created for each file which is a worse
    // trade off in this case. I'd rather we use more memory and get
    // the results faster.
    /* --------------------------------- Comment -------------------------------- */
    final dartFiles = directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.absolute.path)
        .toList();

    // Check if no Dart files are found
    if (dartFiles.isEmpty) {
      throw CliException(
        'No Dart files found in the directory $directoryPath.',
        ExitCode.ioError.code,
      );
    }

    return dartFiles;
  }

  /* --------------------------------- Comment -------------------------------- */
  // I have thought about a few things i wanted to try out firstly:
  //
  // - can we concurrently analyze the files?
  // The short answer would probably be no, because as the list of files grows
  // if we call Future.wait on all the files, the analyzer would have to
  // read all the files into memory and then analyze them concurrently which
  // would be a lot of memory usage. And somehow there might be a limit
  // to the number of files we can analyze concurrently.
  //
  // We could read the files in batches and analyze them concurrently but
  // we would still have to keep the AST nodes in memory until we are done
  //
  // Maybe we can analyze the files one by one

  // - So in the scenario the user presents us with 5000 files we would
  // have to keep all the AST nodes in memory until the analysis context

  // - So maybe the safest is to have a stream of the resolved unit results
  // and then we can process either one by one or in batches. Maybe batch
  // processing could be a user flag?
  //
  // Things to try:
  // - Maybe use an isolate to analyze the files concurrently?

  /* --------------------------------- Comment -------------------------------- */

  /// A generator function that creates one analyzer context
  /// for each file and yields the resolved unit result

  Stream<SomeResolvedUnitResult> _createAnalyzerContextStream(
    /// Assumes that the files given are valid Dart files.
    List<String> absoluteFilePaths, {
    /// Number of files to process concurrently
    int concurrency = 5,
  }) async* {
    if (absoluteFilePaths.isEmpty) {
      throw CliException(
        'Empty list of files provided to analyzer context.',
        ExitCode.ioError.code,
      );
    }

    // Create an AnalysisContextCollection for resolving Dart files
    final collection = AnalysisContextCollection(
      includedPaths: absoluteFilePaths,
    );

    // Process files in batches of size `concurrency`
    for (var i = 0; i < absoluteFilePaths.length; i += concurrency) {
      // Get the current batch of file paths
      final batch = absoluteFilePaths.skip(i).take(concurrency).toList();

      // Process the batch concurrently using Future.wait()
      final batchResults = await Future.wait(
        batch.map((filePath) async {
          final context = collection.contextFor(filePath);
          return context.currentSession.getResolvedUnit(filePath);
        }),
      );

      // Yield the batch results as they becomes available
      for (final result in batchResults) {
        yield result;
      }
    }

    // Dispose the collection when finished with all file paths
    await collection.dispose();
  }
}

class _WidgetVisitor extends GeneralizingAstVisitor<void> {
  _WidgetVisitor(this.logger);

  final Logger logger;

  final List<String> widgets = <String>[];

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    // Start by getting the superclass name
    final superClass = node.extendsClause?.superclass;

    if (superClass != null && node.declaredElement != null) {
      // Check if the class is or extends a widget
      if (_isWidgetClass(node.declaredElement!)) {
        // logger.info('Found widget: ${node.name}');
        widgets.add(node.name.toString());
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
