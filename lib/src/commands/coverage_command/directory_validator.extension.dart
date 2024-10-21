part of 'coverage_command.dart';

extension CoverageCommandDirectoryValidator on CoverageCommand {
  /* ------------------------------ Project name ------------------------------ */

  String get widgetContextProjectName {
    _widgetContextFlutterProjectName ??= File('$widgetContext/pubspec.yaml')
        .readAsStringSync()
        .split('\n')
        .firstWhere((line) => line.contains('name:'))
        .split(':')
        .last
        .trim();
    return _widgetContextFlutterProjectName!;
  }

  String get widgetbookContextProjectName {
    _widgetbookContextFlutterProjectName ??=
        File('$widgetbookContext/pubspec.yaml')
            .readAsStringSync()
            .split('\n')
            .firstWhere((line) => line.contains('name:'))
            .split(':')
            .last
            .trim();
    return _widgetbookContextFlutterProjectName!;
  }

  String get widgetbookTargetProjectName {
    _widgetbookTargetProjectName ??= File('$widgetbookTarget/pubspec.yaml')
        .readAsStringSync()
        .split('\n')
        .firstWhere((line) => line.contains('name:'))
        .split(':')
        .last
        .trim();
    return _widgetbookTargetProjectName!;
  }

  String get widgetTargetProjectName {
    _widgetTargetProjectName ??= File('$widgetTarget/pubspec.yaml')
        .readAsStringSync()
        .split('\n')
        .firstWhere((line) => line.contains('name:'))
        .split(':')
        .last
        .trim();
    return _widgetTargetProjectName!;
  }
  /* ------------------------------ Project name ------------------------------ */

  /// Checks if the [widgetContext] directory is a Flutter project root directory.
  /// By checking for the presence of a pubspec.yaml file
  /// and Flutter dependency in the pubspec.yaml file.
  bool _isFlutterProject() {
    final pubspecFile = File('$widgetContext/pubspec.yaml');

    // Check if pubspec.yaml exists
    if (!pubspecFile.existsSync()) {
      throw CliException(
        '''
        Cannot find a pubspec.yaml file, the coverage command can 
        only run from a Flutter project root directory.
        ''',
        ExitCode.usage.code,
      );
    }

    // Read the contents of pubspec.yaml
    final pubspecContent = pubspecFile.readAsStringSync();

    // Check for the presence of 'flutter' in the pubspec.yaml file
    if (!pubspecContent.contains('flutter:')) {
      throw CliException(
        '''
        Cannot find Flutter dependency in pubspec.yaml file, the coverage 
        command can only run from a Flutter project root directory.
        ''',
        ExitCode.usage.code,
      );
    }

    if (widgetContextProjectName != widgetTargetProjectName) {
      throw CliException(
        '''
        The widget_context and widget_target options should point to the
        same project, the widget_context project is $widgetContextProjectName
        and the widget_target project is $widgetTargetProjectName.
        ''',
        ExitCode.usage.code,
      );
    }

    return true;
  }

  /// Checks if the [widgetbookContext] directory is a valid widgetbook project.
  /// By checking for the presence of a pubspec.yaml file
  /// and widgetbook dependency in the pubspec.yaml file.
  /// If the [widgetbookContext] is different from the [widgetContext],
  /// it checks if the widgetbook project imports the flutter project in the
  /// [widgetContext] directory.
  bool _isValidWidgetbookProject() {
    final pubspecFile = File('$widgetbookContext/pubspec.yaml');

    // Check if pubspec.yaml exists
    if (!pubspecFile.existsSync()) {
      throw CliException(
        '''
        Cannot find a pubspec.yaml file, the coverage command can 
        only run from a Flutter project root directory.
        ''',
        ExitCode.usage.code,
      );
    }

    // Read the contents of pubspec.yaml
    final pubspecContent = pubspecFile.readAsStringSync();

    // Check for the presence of 'widgetbook' in the pubspec.yaml file
    if (!pubspecContent.contains('widgetbook:')) {
      throw CliException(
        '''
        Cannot find Widgetbook dependency in pubspec.yaml file, the coverage 
        command can only run from a Flutter project containing a widgetbook
        dependency. Specify the widgetbook_context option to a project
        containing a widgetbook dependency.
        ''',
        ExitCode.usage.code,
      );
    }

    // if widgetbook context is a different project, check if the widgetbook
    // project imports the flutter project
    if (widgetbookContext != widgetContext) {
      if (!pubspecContent.contains('$widgetContextProjectName:')) {
        throw CliException(
          '''
          The widgetbook project in $widgetbookContext does not depend on the
          Flutter project $widgetContextProjectName. widgetbook_context
          should point to the widgetbook project related to the Flutter project
          in widget_context $widgetContext. 
          ''',
          ExitCode.usage.code,
        );
      }
    }

    if (widgetbookContextProjectName != widgetbookTargetProjectName) {
      throw CliException(
        '''
        The widgetbook_context and widgetbook_target options should point to the
        same project, the widgetbook_context project is $widgetbookContextProjectName
        and the widgetbook_target project is $widgetbookTargetProjectName.
        ''',
        ExitCode.usage.code,
      );
    }

    return true;
  }

  /// Checks if the provided path is a valid directory.
  bool _isValidDirectory(String path) {
    final directory = Directory(path);

    if (path.isEmpty) {
      throw CliException(
        'Empty path argument is invalid.',
        ExitCode.usage.code,
      );
    }

    if (directory.statSync().type != FileSystemEntityType.directory) {
      throw CliException(
        '$path is not a directory.',
        ExitCode.ioError.code,
      );
    }

    if (!directory.existsSync()) {
      throw CliException(
        'Directory $path not found.',
        ExitCode.ioError.code,
      );
    }

    if (directory.listSync().isEmpty) {
      throw CliException(
        'Empty directory $path cannot be set as target for coverage.',
        ExitCode.ioError.code,
      );
    }

    return true;
  }
}
