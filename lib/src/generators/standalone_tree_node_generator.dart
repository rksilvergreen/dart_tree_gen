import '../schema/schema_info.dart';
import 'tree_node_class_generator.dart';

/// Generates standalone TreeNode files with imports.
class StandaloneTreeNodeGenerator {
  final SchemaInfo schema;
  final List<SchemaInfo> allSchemas;
  final String sourceBaseName;

  StandaloneTreeNodeGenerator(this.schema, this.allSchemas, this.sourceBaseName);

  String generate() {
    final buffer = StringBuffer();

    // File header
    buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    buffer.writeln('// Generated from $sourceBaseName.dart');
    buffer.writeln();

    // Imports
    buffer.writeln("import 'package:dart_tree/dart_tree.dart';");

    // Generate class using existing generator
    final treeClassName = _toPascalCase(sourceBaseName) + 'Tree';
    final classGenerator = TreeNodeClassGenerator(schema, treeClassName: treeClassName);

    // Import referenced nodes (including unions)
    final importedNodes = <String>{};

    // Import the object class for this node's fromObject method
    final importedObjects = <String>{schema.title};

    void collectFromProperty(PropertyInfo property) {
      if (property.referencedSchema != null) {
        if (property.type == SchemaType.object ||
            property.type == SchemaType.union ||
            property.type == SchemaType.array) {
          importedNodes.add(property.referencedSchema!.title);
          importedObjects.add(property.referencedSchema!.title);
        }
        if (property.referencedSchema!.isUnion) {
          for (final memberType in property.referencedSchema!.unionInfo!.types) {
            if (memberType.title != 'String' &&
                memberType.title != 'Integer' &&
                memberType.title != 'Number' &&
                memberType.title != 'Boolean') {
              importedNodes.add(memberType.title);
            }
          }
        }
        // Import type argument types (e.g. AdminObject, ReferencesListObject for BookObject<ReferencesListObject, AdminObject>)
        for (final argProp in property.typeArguments?.values ?? []) {
          if (argProp.type == SchemaType.object && argProp.referencedSchema != null) {
            importedObjects.add(argProp.referencedSchema!.title);
            importedNodes.add(argProp.referencedSchema!.title);
          } else if (argProp.type == SchemaType.array && argProp.referencedSchema != null) {
            // ReferencesListObject is in reference_object.dart
            importedObjects.add(argProp.referencedSchema!.title);
            importedNodes.add(argProp.referencedSchema!.title);
          }
        }
      }
    }

    for (final property in schema.properties.values) {
      collectFromProperty(property);
    }

    // For union schemas, import the types in the union
    if (schema.isUnion) {
      for (final type in schema.unionInfo!.types) {
        if (type.title != 'String' && type.title != 'Integer' && type.title != 'Number' && type.title != 'Boolean') {
          importedNodes.add(type.title);
        }
      }
    }

    for (final refTitle in importedNodes) {
      buffer.writeln("import '${_toSnakeCase(refTitle)}_node.dart';");
    }

    for (final refTitle in importedObjects) {
      buffer.writeln("import '../objects/${_toSnakeCase(refTitle)}_object.dart';");
    }

    // Import tree class for subtree creation in setters (only for schemas with properties)
    if (!schema.isUnion && schema.properties.isNotEmpty) {
      buffer.writeln("import '../trees/${_toSnakeCase(sourceBaseName)}_tree.dart';");
    }

    buffer.writeln();

    buffer.write(classGenerator.generate());

    // Generate ListNode/MapNode classes that reference this schema
    _generateListMapNodes(buffer);

    return buffer.toString();
  }

  /// Generates ListNode classes that reference this schema as their item type.
  /// Named by item schema (e.g. ReferencesListNode for Reference), not by property name.
  void _generateListMapNodes(StringBuffer buffer) {
    final generated = <String>{};
    void checkProperty(PropertyInfo property) {
      if (property.referencedSchema?.title == schema.title && property.type == SchemaType.array) {
        final listClassName = _getListClassName(schema.title, property.uniqueItems);
        final nodeClassName = listClassName.replaceFirst('ListObject', 'ListNode').replaceFirst('SetObject', 'SetNode');
        if (generated.add(nodeClassName)) {
          final itemNodeType = '${schema.title}Node';
          buffer.writeln();
          buffer.writeln('/// Generated ListNode for ${schema.title}');
          buffer.writeln('class $nodeClassName extends ListTreeNode<$itemNodeType> {');
          buffer.writeln('  $nodeClassName({super.id});');
          buffer.writeln();
          buffer.writeln(
            '  $listClassName toObject() => $listClassName(this.map((node) => node.toObject()).toList());',
          );
          buffer.writeln();
          buffer.writeln('  static void fromObject(Tree tree, TreeNode? parent, String key, $listClassName? object) {');
          buffer.writeln('    if (object == null) return;');
          buffer.writeln();
          buffer.writeln('    final parentRecord = tree.nodes[parent?.id];');
          buffer.writeln('    final pointer = Pointer.build(parentRecord?.pointer, key);');
          buffer.writeln('    final node = $nodeClassName();');
          buffer.writeln(
            '    tree.\$nodes[node.id] = TreeNodeRecord(node: node, pointer: pointer, parent: parent?.id);',
          );
          buffer.writeln('    parentRecord?.children[Edge($nodeClassName, key)] = node.id;');
          buffer.writeln();
          buffer.writeln('    for (int i = 0; i < object.length; i++) {');
          buffer.writeln('      $itemNodeType.fromObject(tree, node, i.toString(), object[i]);');
          buffer.writeln('    }');
          buffer.writeln('  }');
          buffer.writeln();
          buffer.writeln('  @override');
          buffer.writeln('  $nodeClassName clone() => $nodeClassName(id: id);');
          buffer.writeln('}');
        }
      }
      for (final arg in property.typeArguments?.values ?? []) {
        checkProperty(arg);
      }
    }

    for (final otherSchema in allSchemas) {
      for (final property in otherSchema.properties.values) {
        checkProperty(property);
      }
    }
  }

  String _getListClassName(String itemSchemaTitle, bool uniqueItems) {
    final plural = '${itemSchemaTitle}s';
    return uniqueItems ? '${plural}SetObject' : '${plural}ListObject';
  }

  String _capitalize(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1);
  }

  String _toSnakeCase(String input) {
    return input
        .replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m.group(0)!.toLowerCase()}')
        .replaceFirst(RegExp(r'^_'), '');
  }

  String _toPascalCase(String input) {
    return input.split('_').map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1)).join('');
  }
}
