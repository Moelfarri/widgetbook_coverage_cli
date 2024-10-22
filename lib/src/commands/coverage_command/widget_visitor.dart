part of 'coverage_command.dart';

class WidgetVisitor extends GeneralizingAstVisitor<void> {
  WidgetVisitor(this.logger);

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
