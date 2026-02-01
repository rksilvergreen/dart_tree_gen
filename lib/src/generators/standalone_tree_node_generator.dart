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
    final classGenerator = TreeNodeClassGenerator(schema);

    // Import referenced nodes (including unions)
    final importedNodes = <String>{};

    // Import the object class for this node's fromObject method
    final importedObjects = <String>{schema.title};

    for (final property in schema.properties.values) {
      if (property.referencedSchema != null) {
        if (property.type == SchemaType.object ||
            property.type == SchemaType.union ||
            property.type == SchemaType.array) {
          importedNodes.add(property.referencedSchema!.title);
          // Also import the object class for setters
          importedObjects.add(property.referencedSchema!.title);
        }

        // If the referenced schema is a union, also import all its member types
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
      } else if (property.type == SchemaType.array) {
        // For array properties, import the list object class
        final className = _capitalize(property.name);
        importedObjects.add('${className}List');
      }
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

    buffer.writeln();

    buffer.write(classGenerator.generate());

    // Generate ListNode/MapNode classes that reference this schema
    _generateListMapNodes(buffer);

    return buffer.toString();
  }

  /// Generates ListNode classes that reference this schema as their item type.
  void _generateListMapNodes(StringBuffer buffer) {
    // Find all properties in all schemas that reference this schema as an array item
    for (final otherSchema in allSchemas) {
      for (final property in otherSchema.properties.values) {
        if (property.referencedSchema?.title == schema.title && property.type == SchemaType.array) {
          final className = '${_capitalize(property.name)}ListNode';
          final listObjectType = '${_capitalize(property.name)}ListObject';
          final itemNodeType = '${schema.title}Node';
          buffer.writeln();
          buffer.writeln('/// Generated ListNode for ${property.name}');
          buffer.writeln('class $className extends ListTreeNode<$itemNodeType> {');
          buffer.writeln('  $className({super.id});');
          buffer.writeln();
          buffer.writeln(
            '  $listObjectType toObject() => $listObjectType(this.map((node) => node.toObject()).toList());',
          );
          buffer.writeln();
          buffer.writeln(
            '  static void fromObject(Tree tree, TreeNode? parent, String key, $listObjectType? object) {',
          );
          buffer.writeln('    if (object == null) return;');
          buffer.writeln();
          buffer.writeln('    final parentRecord = tree.nodes[parent?.id];');
          buffer.writeln('    final pointer = Pointer.build(parentRecord?.pointer, key);');
          buffer.writeln('    final node = $className();');
          buffer.writeln(
            '    tree.\$nodes[node.id] = TreeNodeRecord(node: node, pointer: pointer, parent: parent?.id);',
          );
          buffer.writeln('    parentRecord?.children[Edge($className, key)] = node.id;');
          buffer.writeln();
          buffer.writeln('    for (int i = 0; i < object.length; i++) {');
          buffer.writeln('      $itemNodeType.fromObject(tree, node, i.toString(), object[i]);');
          buffer.writeln('    }');
          buffer.writeln('  }');
          buffer.writeln();
          buffer.writeln('  @override');
          buffer.writeln('  $className clone() => $className(id: id);');
          buffer.writeln('}');
        }
      }
    }
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
}
