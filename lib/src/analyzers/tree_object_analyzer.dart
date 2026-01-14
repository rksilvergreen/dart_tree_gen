import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:source_gen/source_gen.dart';
import 'package:dart_tree/dart_tree.dart' as dt;

/// Analyzes a library to find @treeObject and @GenerateTree annotated classes.
class TreeObjectAnalyzer {
  final LibraryReader library;
  
  TreeObjectAnalyzer(this.library);
  
  /// Finds all classes annotated with @treeObject.
  List<TreeObjectInfo> findTreeObjects() {
    final treeObjects = <TreeObjectInfo>[];
    
    // Use TypeChecker with the package URL and annotation name
    final treeObjectChecker = TypeChecker.fromUrl('package:dart_tree/src/annotations.dart#TreeObject');
    
    for (final element in library.allElements) {
      if (element is! ClassElement) continue;
      
      // Check for @treeObject annotation
      final annotation = treeObjectChecker.firstAnnotationOf(element);
      
      if (annotation != null) {
        treeObjects.add(_analyzeTreeObject(element));
      }
    }
    
    return treeObjects;
  }
  
  /// Finds the class annotated with @GenerateTree.
  GenerateTreeInfo? findGenerateTreeClass() {
    final generateTreeChecker = TypeChecker.fromUrl('package:dart_tree/src/annotations.dart#GenerateTree');
    
    for (final element in library.allElements) {
      if (element is! ClassElement) continue;
      
      final annotation = generateTreeChecker.firstAnnotationOf(element);
      
      if (annotation != null) {
        final className = element.name;
        if (className == null) continue;
        
        return GenerateTreeInfo(
          className: className,
          generatedClassName: annotation.getField('name')?.toStringValue() ??
              _deriveGeneratedTreeName(className),
        );
      }
    }
    
    return null;
  }
  
  TreeObjectInfo _analyzeTreeObject(ClassElement element) {
    final fields = <FieldInfo>[];
    final treeChildChecker = TypeChecker.fromUrl('package:dart_tree/src/annotations.dart#TreeChild');
    
    for (final field in element.fields) {
      if (field.isStatic || field.isSynthetic) continue;
      
      final fieldName = field.name;
      if (fieldName == null) continue;
      
      // Check if field is marked with @TreeChild
      final isTreeChild = treeChildChecker.hasAnnotationOf(field);
      
      // VALIDATION: @TreeChild must annotate TreeObject types
      if (isTreeChild && !_extendsTreeObject(field.type)) {
        throw InvalidGenerationSourceError(
          '@TreeChild() can only annotate properties that extend TreeObject. '
          'Field "$fieldName" of type "${field.type.getDisplayString(withNullability: true)}" '
          'does not extend TreeObject.',
          element: field,
        );
      }
      
      fields.add(FieldInfo(
        name: fieldName,
        type: field.type,
        isNullable: field.type.nullabilitySuffix == NullabilitySuffix.question,
        isTreeChild: isTreeChild,
        element: field,
      ));
    }
    
    final className = element.name;
    if (className == null) {
      throw InvalidGenerationSourceError(
        '@treeObject class must have a name',
        element: element,
      );
    }
    
    return TreeObjectInfo(
      className: className,
      fields: fields,
      element: element,
    );
  }
  
  bool _extendsTreeObject(DartType type) {
    final element = type.element;
    if (element is! ClassElement) return false;
    
    // Check if extends TreeObject
    return element.allSupertypes.any((supertype) =>
      supertype.getDisplayString(withNullability: false) == 'TreeObject');
  }
  
  String _deriveGeneratedTreeName(String baseName) {
    // Remove 'Base' suffix if present
    if (baseName.endsWith('Base')) {
      return baseName.substring(0, baseName.length - 4);
    }
    return '${baseName}Impl';
  }
}

/// Information about a @treeObject annotated class.
class TreeObjectInfo {
  final String className;
  final List<FieldInfo> fields;
  final ClassElement element;
  
  TreeObjectInfo({
    required this.className,
    required this.fields,
    required this.element,
  });
  
  String get nodeClassName => '${className}Node';
  
  List<FieldInfo> get treeChildFields =>
      fields.where((f) => f.isTreeChild).toList();
  
  List<FieldInfo> get scalarFields =>
      fields.where((f) => !f.isTreeChild).toList();
}

/// Information about a field in a TreeObject class.
class FieldInfo {
  final String name;
  final DartType type;
  final bool isNullable;
  final bool isTreeChild;
  final FieldElement element;
  
  FieldInfo({
    required this.name,
    required this.type,
    required this.isNullable,
    required this.isTreeChild,
    required this.element,
  });
  
  String get typeName => type.getDisplayString(withNullability: false);
  String get typeNameWithNullability => type.getDisplayString(withNullability: true);
  
  bool get isList => typeName.startsWith('List<');
  bool get isMap => typeName.startsWith('Map<');
  
  String get nodeTypeName {
    if (isList) {
      // List<Comment> -> CommentsListNode
      final elementType = _extractGenericType(typeName);
      return '${elementType}sListNode';
    } else if (isMap) {
      // Map<String, Setting> -> SettingsMapNode
      final valueType = _extractMapValueType(typeName);
      return '${valueType}sMapNode';
    } else {
      // Comment -> CommentNode
      return '${typeName}Node';
    }
  }
  
  String get nodeTypeNameWithNullability {
    return isNullable ? '$nodeTypeName?' : nodeTypeName;
  }
  
  String _extractGenericType(String typeStr) {
    final match = RegExp(r'List<(.+)>').firstMatch(typeStr);
    return match?.group(1) ?? 'Unknown';
  }
  
  String _extractMapValueType(String typeStr) {
    final match = RegExp(r'Map<.+,\s*(.+)>').firstMatch(typeStr);
    return match?.group(1) ?? 'Unknown';
  }
}

/// Information about a @GenerateTree annotated class.
class GenerateTreeInfo {
  final String className;
  final String generatedClassName;
  
  GenerateTreeInfo({
    required this.className,
    required this.generatedClassName,
  });
}

