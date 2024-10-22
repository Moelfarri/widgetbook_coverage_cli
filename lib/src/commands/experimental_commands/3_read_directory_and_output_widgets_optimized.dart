// ignore_for_file: file_names, lines_longer_than_80_chars, prefer_const_constructors, unused_local_variable, omit_local_variable_types, prefer_final_locals
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:widgetbook_coverage_cli/src/error_handling/cli_exception.dart';

// - make a new command that looks cleaner
// - add widgetbook usecases part to it
// - add the flag ideas
// - remove the concurrency and batch stuff it does nothing really
// - see if you can load widgets and widgetbook usecases using isolates for performance

/// Flags:
/// context flag to specify what should be loaded into the analyzer context
///   - context should default to the root directory of the project that user is reading from
///   - checks widget directory and attempts to deduce the root directory from that for example
///     /lib/path/to/widgets => we should be in root
///     project_name/lib/path/to/widgets => we should be in project_name, etc
/// widget_directory flag to specify the directory to read the widgets from
/// widgetbook_path flag to specify the path to the widgetbook

//SOME OPTIMIZATION IDEAS:
// - Maybe write a bundler? Parse all the files into one big one and get the analyzer context once?
// - Use the simple analyzer parsing command vs the full analysis context collection depending on file?

/// The command here and the one in 2_read_directory_and_output_widgets_block_main_thread.dart
/// are similar in that they both read all the files in a directory and output the widgets.
/// The difference is that this command tries to optimize the process by:
/// - Loading the analyzer context once, into the root folder of the project and using the same context for all files
class ReadDirectoryAndOutputWidgetsOptimizedCommand extends Command<int> {
  ReadDirectoryAndOutputWidgetsOptimizedCommand({
    required Logger logger,
  }) : _logger = logger;

  @override
  String get description =>
      'A command that returns all widgets from a folder, including those in subfolders.';

  @override
  String get name => 'read_directory_and_output_widgets_optimized';

  final Logger _logger;

  // Assume that the analyzer context is loaded once and used for all files
  // and that the context is loaded into the root directory of the project
  final AnalysisContextCollection analyzerContextCollection =
      AnalysisContextCollection(
    includedPaths: [Directory.current.path],
  );

  @override
  Future<int> run() async {
    // Spawn a new isolate for time counting
    final receivePort = ReceivePort();
    final timeIsolate = await Isolate.spawn(
      _startStopwatchTimerInIsolate,
      receivePort.sendPort,
    );

    try {
      // get the folder path from the user argument
      final argResults = this.argResults;
      if (argResults == null || argResults.rest.isEmpty) {
        throw CliException(
          'Please provide a valid folder path.',
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
          timeIsolate.kill();
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

    // Process files in batches of size `concurrency`
    for (var i = 0; i < absoluteFilePaths.length; i += concurrency) {
      // Get the current batch of file paths
      final batch = absoluteFilePaths.skip(i).take(concurrency).toList();

      // Process the batch concurrently using Future.wait()
      final batchResults = await Future.wait(
        batch.map((filePath) async {
          final context = analyzerContextCollection.contextFor(filePath);
          return context.currentSession.getResolvedUnit(filePath);
        }),
      );

      // Yield the batch results as they becomes available
      for (final result in batchResults) {
        yield result;
      }
    }

    // Dispose the collection when finished with all file paths
    await analyzerContextCollection.dispose();
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

// isolate that starts a stopwatch so we cna see how long this command takes
// we run it in an isolate since the main thread is blocekd by the processing
// of many analyzer contexts
void _startStopwatchTimerInIsolate(SendPort sendPort) {
  final stopwatch = Stopwatch()..start();

  // Send elapsed time to main isolate periodically
  final timer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
    if (!timer.isActive) return;

    String elapsedTime =
        'Elapsed time: ${stopwatch.elapsed.inSeconds}.${(stopwatch.elapsedMilliseconds % 1000).toString().padLeft(3, '0')}s';

    stdout.write('\r $elapsedTime'.padRight(30));
  });
}
