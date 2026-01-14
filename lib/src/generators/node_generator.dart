import 'package:code_builder/code_builder.dart';
import '../analyzers/tree_object_analyzer.dart';

/// Generates TreeNode classes from TreeObject definitions.
class NodeGenerator {
  final List<TreeObjectInfo> treeObjects;

  NodeGenerator(this.treeObjects);

  String generate() {
    final library = Library(
      (b) => b
        ..body.addAll([
          // Generate all node classes
          for (final obj in treeObjects) ...[
            _generateNodeClass(obj),
            // Generate collection nodes if needed
            for (final field in obj.treeChildFields)
              if (field.isList) _generateListNode(field) else if (field.isMap) _generateMapNode(field),
          ],
        ]),
    );

    final emitter = DartEmitter(useNullSafetySyntax: true);
    return library.accept(emitter).toString();
  }

  Class _generateNodeClass(TreeObjectInfo obj) {
    return Class(
      (b) => b
        ..name = obj.nodeClassName
        ..extend = refer('CollectionNode')
        ..docs.add('/// Generated node for ${obj.className}')
        ..constructors.add(
          Constructor(
            (b) => b
              ..optionalParameters.addAll([
                Parameter(
                  (p) => p
                    ..name = 'id'
                    ..named = true
                    ..toSuper = true,
                ),
                Parameter(
                  (p) => p
                    ..name = 'sourceRange'
                    ..named = true
                    ..toSuper = true,
                ),
                Parameter(
                  (p) => p
                    ..name = 'formatting'
                    ..named = true
                    ..toSuper = true,
                ),
              ]),
          ),
        )
         ..methods.addAll([
           // Generate getters for tree children
           for (final field in obj.treeChildFields)
             Method(
               (m) => m
                 ..name = field.name
                 ..type = MethodType.getter
                 ..returns = refer(field.nodeTypeNameWithNullability)
                 ..body = Code(
                   field.isNullable
                       ? "return \$children?['${field.name}'] as ${field.nodeTypeNameWithNullability};"
                       : "return \$children!['${field.name}']! as ${field.nodeTypeName};",
                 ),
             ),
           // Generate clone method
           Method(
             (m) => m
               ..name = 'clone'
               ..returns = refer(obj.nodeClassName)
               ..annotations.add(refer('override'))
               ..body = Code('return ${obj.nodeClassName}(id: id, sourceRange: sourceRange, formatting: formatting);'),
           ),
         ]),
    );
  }

  Class _generateListNode(FieldInfo field) {
    final elementType = _extractGenericType(field.typeName);
    final nodeType = '${elementType}Node';
    final listNodeName = field.nodeTypeName;

    return Class(
      (b) => b
        ..name = listNodeName
        ..extend = refer('ListTreeNode<$nodeType>')
        ..docs.add('/// Generated list node for ${field.name}')
        ..constructors.add(
          Constructor(
            (b) => b
              ..optionalParameters.addAll([
                Parameter(
                  (p) => p
                    ..name = 'id'
                    ..named = true
                    ..toSuper = true,
                ),
                Parameter(
                  (p) => p
                    ..name = 'sourceRange'
                    ..named = true
                    ..toSuper = true,
                ),
                Parameter(
                  (p) => p
                    ..name = 'formatting'
                    ..named = true
                    ..toSuper = true,
                ),
              ]),
          ),
        )
        ..methods.add(
          Method(
            (m) => m
              ..name = 'clone'
              ..returns = refer(listNodeName)
              ..annotations.add(refer('override'))
              ..body = Code('return $listNodeName(id: id, sourceRange: sourceRange, formatting: formatting);'),
          ),
        ),
    );
  }

  Class _generateMapNode(FieldInfo field) {
    final valueType = _extractMapValueType(field.typeName);
    final nodeType = '${valueType}Node';
    final mapNodeName = field.nodeTypeName;

    return Class(
      (b) => b
        ..name = mapNodeName
        ..extend = refer('MapTreeNode<$nodeType>')
        ..docs.add('/// Generated map node for ${field.name}')
        ..constructors.add(
          Constructor(
            (b) => b
              ..optionalParameters.addAll([
                Parameter(
                  (p) => p
                    ..name = 'id'
                    ..named = true
                    ..toSuper = true,
                ),
                Parameter(
                  (p) => p
                    ..name = 'sourceRange'
                    ..named = true
                    ..toSuper = true,
                ),
                Parameter(
                  (p) => p
                    ..name = 'formatting'
                    ..named = true
                    ..toSuper = true,
                ),
              ]),
          ),
        )
        ..methods.add(
          Method(
            (m) => m
              ..name = 'clone'
              ..returns = refer(mapNodeName)
              ..annotations.add(refer('override'))
              ..body = Code('return $mapNodeName(id: id, sourceRange: sourceRange, formatting: formatting);'),
          ),
        ),
    );
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
