import '../schema/schema_info.dart';

/// Generates standalone Tree file with objectToNode implementation.
class StandaloneTreeGenerator {
  final List<SchemaInfo> schemas;
  final String sourceBaseName;

  StandaloneTreeGenerator(this.schemas, this.sourceBaseName);

  /// Escapes property names for use in string literals.
  static String _escapePropertyName(String propertyName) {
    if (propertyName.startsWith(r'$')) {
      return r'\$' + propertyName.substring(1);
    }
    return propertyName;
  }

  /// Gets the constructor name for a union type.
  String _getConstructorName(SchemaInfo type) {
    if (type.title == 'String') return 'string';
    if (type.title == 'Integer') return 'integer';
    if (type.title == 'Number') return 'number';
    if (type.title == 'Boolean') return 'boolean';
    // Convert 'UserProfile' -> 'userProfile'
    final title = type.title;
    return title[0].toLowerCase() + title.substring(1);
  }

  /// Converts a type parameter name to camelCase for use as property/field name.
  /// E.g. "GORDON_BANKS" -> "gordonBanks", "U" -> "u".
  String _typeParamToCamelCase(String typeParam) {
    if (typeParam.isEmpty) return typeParam;
    final parts = typeParam.split('_');
    if (parts.length == 1) {
      return typeParam[0].toLowerCase() + typeParam.substring(1);
    }
    final result = StringBuffer();
    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (part.isEmpty) continue;
      if (i == 0) {
        result.write(part.toLowerCase());
      } else {
        result.write(part[0].toUpperCase());
        if (part.length > 1) result.write(part.substring(1).toLowerCase());
      }
    }
    return result.toString();
  }

  String generate() {
    final buffer = StringBuffer();

    // File header
    buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    buffer.writeln('// Generated from $sourceBaseName.dart');
    buffer.writeln();

    // Imports
    buffer.writeln("import 'package:dart_tree/dart_tree.dart';");

    // Import all TreeObject files
    for (final schema in schemas) {
      buffer.writeln("import '../objects/${_toSnakeCase(schema.title)}_object.dart';");
    }

    // Import all TreeNode files
    for (final schema in schemas) {
      buffer.writeln("import '../nodes/${_toSnakeCase(schema.title)}_node.dart';");
    }

    buffer.writeln();

    // Generate Tree class
    final className = _toPascalCase(sourceBaseName) + 'Tree';
    buffer.writeln('/// Generated Tree class for $sourceBaseName schemas.');
    buffer.writeln('class $className extends Tree {');
    buffer.writeln('  $className({required super.root});');
    buffer.writeln();
    buffer.writeln('  @override');
    buffer.writeln('  void fromObject(Object object) {');

    // Handle value objects
    buffer.writeln('    // Handle value objects');
    buffer.writeln('    if (object is StringValue) { StringValueNode.fromObject(this, null, \'/\', object); return; }');
    buffer.writeln('    if (object is IntValue) { IntValueNode.fromObject(this, null, \'/\', object); return; }');
    buffer.writeln('    if (object is DoubleValue) { DoubleValueNode.fromObject(this, null, \'/\', object); return; }');
    buffer.writeln('    if (object is BoolValue) { BoolValueNode.fromObject(this, null, \'/\', object); return; }');
    buffer.writeln('    if (object is NullValue) { NullValueNode.fromObject(this, null, \'/\', object); return; }');
    buffer.writeln();

    // Handle union objects - delegate to their concrete type
    buffer.writeln('    // Handle union objects - delegate to concrete type');
    for (final schema in schemas) {
      if (!schema.isUnion) continue;

      final unionInfo = schema.unionInfo!;
      buffer.writeln('    if (object is ${schema.title}Object) {');

      for (int i = 0; i < unionInfo.types.length; i++) {
        final type = unionInfo.types[i];
        final constructorName = _getConstructorName(type);
        final capitalizedName = constructorName[0].toUpperCase() + constructorName.substring(1);

        if (i == 0) {
          buffer.writeln('      if (object.is$capitalizedName) { fromObject(object.as$capitalizedName!); return; }');
        } else {
          buffer.writeln(
            '      else if (object.is$capitalizedName) { fromObject(object.as$capitalizedName!); return; }',
          );
        }
      }

      // Handle type parameters if any
      for (final typeParam in unionInfo.typeParameters) {
        final fieldName = _typeParamToCamelCase(typeParam);
        final capitalizedName = fieldName[0].toUpperCase() + fieldName.substring(1);
        buffer.writeln('      else if (object.is$capitalizedName) { fromObject(object.as$capitalizedName!); return; }');
      }

      buffer.writeln('      return;');
      buffer.writeln('    }');
      buffer.writeln();
    }

    // Handle generated objects
    buffer.writeln('    // Handle generated objects');
    for (final schema in schemas) {
      // Skip union schemas - they are handled by their underlying types
      if (schema.isUnion) continue;

      buffer.writeln('    if (object is ${schema.title}Object) {');
      buffer.writeln('      ${schema.title}Node.fromObject(this, null, \'/\', object);');
      buffer.writeln('      return;');
      buffer.writeln('    }');
      buffer.writeln();
    }

    buffer.writeln('  }');
    buffer.writeln('}');

    return buffer.toString();
  }

  String _getNodeTypeForEdge(PropertyInfo property) {
    switch (property.type) {
      case SchemaType.string:
        return 'StringValueNode';
      case SchemaType.integer:
        return 'IntValueNode';
      case SchemaType.number:
        return 'DoubleValueNode';
      case SchemaType.boolean:
        return 'BoolValueNode';
      case SchemaType.object:
        return '${property.referencedSchema!.title}Node';
      case SchemaType.array:
        return 'ListTreeNode';
      case SchemaType.union:
        return 'UnionNode2';
    }
  }

  String _toSnakeCase(String input) {
    return input
        .replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m.group(0)!.toLowerCase()}')
        .replaceFirst(RegExp(r'^_'), '');
  }

  String _toPascalCase(String input) {
    return input.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join('');
  }
}
