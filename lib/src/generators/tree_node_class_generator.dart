import '../schema/schema_info.dart';

/// Generates TreeNode class code from a SchemaInfo.
class TreeNodeClassGenerator {
  final SchemaInfo schema;

  TreeNodeClassGenerator(this.schema);

  /// Gets the proper way to access a property in code expressions.
  /// Always use 'this.' prefix to avoid conflicts with local variables.
  static String _propertyAccess(String propertyName) {
    return 'this.$propertyName';
  }

  /// Escapes property names for use in string literals.
  static String _escapePropertyName(String propertyName) {
    if (propertyName.startsWith(r'$')) {
      return r'\$' + propertyName.substring(1);
    }
    return propertyName;
  }

  /// Generates the complete TreeNode class code.
  String generate() {
    // Check if this is a union schema
    if (schema.isUnion) {
      return _generateUnion();
    }

    final buffer = StringBuffer();

    // Class declaration
    buffer.writeln('/// Generated TreeNode class for ${schema.title}');
    buffer.writeln('class ${schema.title}Node extends CollectionNode {');

    // Constructor
    buffer.writeln('  ${schema.title}Node({super.id});');
    buffer.writeln();

    // Generate getters
    _generateGetters(buffer);

    buffer.writeln();

    // Generate set methods for value types
    _generateSetters(buffer);

    buffer.writeln();

    // Generate set methods for object/array/union types
    _generateObjectSetters(buffer);

    buffer.writeln();

    // Generate toObject method
    _generateToObjectMethod(buffer);

    buffer.writeln();

    // Generate fromObject method
    _generateFromObjectMethod(buffer);

    buffer.writeln();

    // Generate clone method
    _generateCloneMethod(buffer);

    buffer.writeln('}');

    return buffer.toString();
  }

  /// Converts a type parameter name to camelCase for use as property/field name.
  /// E.g. "GORDON_BANKS" -> "gordonBanks", "U" -> "u".
  String _typeParamToFieldName(String typeParam) {
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

  /// Generates a concrete union node class.
  String _generateUnion() {
    final unionInfo = schema.unionInfo!;
    final types = unionInfo.types;
    final typeParams = unionInfo.typeParameters;
    final totalTypes = types.length + typeParams.length;

    if (totalTypes < 2) {
      throw Exception('Union must have at least 2 total types, got $totalTypes');
    }

    final buffer = StringBuffer();

    // Class declaration with type parameters
    buffer.writeln('/// Generated union node class for ${schema.title}');
    buffer.write('class ${schema.title}Node');
    if (typeParams.isNotEmpty) {
      buffer.write('<');
      buffer.write(typeParams.map((t) => '$t extends TreeNode').join(', '));
      buffer.write('>');
    }
    buffer.writeln(' {');

    // Generate nullable fields for concrete types
    for (final type in types) {
      final constructorName = _getConstructorName(type);
      final dartType = _getUnionNodeDartType(type);
      buffer.writeln('  final $dartType? _$constructorName;');
    }

    // Generate nullable fields for type parameters
    for (final typeParam in typeParams) {
      final fieldName = _typeParamToFieldName(typeParam);
      buffer.writeln('  final $typeParam? _$fieldName;');
    }
    buffer.writeln();

    // Generate named constructors for concrete types
    for (final type in types) {
      final constructorName = _getConstructorName(type);
      final dartType = _getUnionNodeDartType(type);
      buffer.writeln('  /// Creates a ${schema.title} node with a $dartType value.');
      buffer.write('  ${schema.title}Node.$constructorName($dartType $constructorName)');
      buffer.write(' : _$constructorName = $constructorName');

      // Set other concrete type fields to null
      for (final otherType in types) {
        final otherName = _getConstructorName(otherType);
        if (otherName != constructorName) {
          buffer.write(', _$otherName = null');
        }
      }

      // Set type parameter fields to null
      for (final typeParam in typeParams) {
        final fieldName = _typeParamToFieldName(typeParam);
        buffer.write(', _$fieldName = null');
      }
      buffer.writeln(';');
      buffer.writeln();
    }

    // Generate named constructors for type parameters
    for (final typeParam in typeParams) {
      final fieldName = _typeParamToFieldName(typeParam);
      buffer.writeln('  /// Creates a ${schema.title} node with a $typeParam value.');
      buffer.write('  ${schema.title}Node.$fieldName($typeParam $fieldName)');
      buffer.write(' : _$fieldName = $fieldName');

      // Set concrete type fields to null
      for (final type in types) {
        final constructorName = _getConstructorName(type);
        buffer.write(', _$constructorName = null');
      }

      // Set other type parameter fields to null
      for (final otherTypeParam in typeParams) {
        final otherFieldName = _typeParamToFieldName(otherTypeParam);
        if (otherFieldName != fieldName) {
          buffer.write(', _$otherFieldName = null');
        }
      }
      buffer.writeln(';');
      buffer.writeln();
    }

    // Generate type checking getters for concrete types
    for (final type in types) {
      final constructorName = _getConstructorName(type);
      final dartType = _getUnionNodeDartType(type);
      final capitalizedName = constructorName[0].toUpperCase() + constructorName.substring(1);
      buffer.writeln('  /// Returns true if this union contains a $dartType.');
      buffer.writeln('  bool get is$capitalizedName => _$constructorName != null;');
      buffer.writeln();
    }

    // Generate type checking getters for type parameters
    for (final typeParam in typeParams) {
      final fieldName = _typeParamToFieldName(typeParam);
      final capitalizedName = fieldName[0].toUpperCase() + fieldName.substring(1);
      buffer.writeln('  /// Returns true if this union contains a $typeParam.');
      buffer.writeln('  bool get is$capitalizedName => _$fieldName != null;');
      buffer.writeln();
    }

    // Generate type casting getters for concrete types
    for (final type in types) {
      final constructorName = _getConstructorName(type);
      final dartType = _getUnionNodeDartType(type);
      final capitalizedName = constructorName[0].toUpperCase() + constructorName.substring(1);
      buffer.writeln('  /// Gets the value as $dartType, or null if it\'s not that type.');
      buffer.writeln('  $dartType? get as$capitalizedName => _$constructorName;');
      buffer.writeln();
    }

    // Generate type casting getters for type parameters
    for (final typeParam in typeParams) {
      final fieldName = _typeParamToFieldName(typeParam);
      final capitalizedName = fieldName[0].toUpperCase() + fieldName.substring(1);
      buffer.writeln('  /// Gets the value as $typeParam, or null if it\'s not that type.');
      buffer.writeln('  $typeParam? get as$capitalizedName => _$fieldName;');
      buffer.writeln();
    }

    // Generate clone method
    buffer.writeln('  ${schema.title}Node clone() {');

    // Check concrete types
    for (int i = 0; i < types.length; i++) {
      final type = types[i];
      final constructorName = _getConstructorName(type);

      if (i == 0) {
        buffer.writeln('    if (_$constructorName != null) {');
      } else {
        buffer.writeln('    } else if (_$constructorName != null) {');
      }
      buffer.writeln(
        '      return ${schema.title}Node.$constructorName(_$constructorName.clone() as ${_getUnionNodeDartType(type)});',
      );
    }

    // Check type parameters
    for (final typeParam in typeParams) {
      final fieldName = _typeParamToFieldName(typeParam);

      buffer.writeln('    } else if (_$fieldName != null) {');
      buffer.writeln('      return ${schema.title}Node.$fieldName(_$fieldName.clone() as $typeParam);');
    }

    buffer.writeln('    } else {');
    buffer.writeln('      throw StateError(\'Union has no value set\');');
    buffer.writeln('    }');
    buffer.writeln('  }');
    buffer.writeln();

    // Generate accept method
    buffer.writeln('  T accept<T>(TreeNodeVisitor<T> visitor) {');

    for (int i = 0; i < types.length; i++) {
      final constructorName = _getConstructorName(types[i]);

      if (i == 0) {
        buffer.writeln('    if (_$constructorName != null) return _$constructorName.accept(visitor);');
      } else {
        buffer.writeln('    else if (_$constructorName != null) return _$constructorName.accept(visitor);');
      }
    }

    for (final typeParam in typeParams) {
      final fieldName = _typeParamToFieldName(typeParam);
      buffer.writeln('    else if (_$fieldName != null) return _$fieldName.accept(visitor);');
    }

    buffer.writeln('    else throw StateError(\'Union has no value set\');');
    buffer.writeln('  }');
    buffer.writeln();

    // Generate toString
    buffer.write('  String toString() => \'${schema.title}Node(');
    for (int i = 0; i < types.length; i++) {
      final constructorName = _getConstructorName(types[i]);
      if (i > 0) buffer.write(', ');
      buffer.write('\$_$constructorName');
    }
    final typeParamsList = typeParams.toList();
    for (int i = 0; i < typeParamsList.length; i++) {
      final fieldName = _typeParamToFieldName(typeParamsList[i]);
      buffer.write(', \$_$fieldName');
    }
    buffer.writeln(')\';');
    buffer.writeln();

    // Generate toObject method
    _generateUnionToObject(buffer, types, typeParams);

    buffer.writeln();

    // Generate fromObject method
    _generateUnionFromObject(buffer, types, typeParams);

    buffer.writeln('}');

    return buffer.toString();
  }

  /// Generates toObject method for union nodes.
  void _generateUnionToObject(StringBuffer buffer, List<SchemaInfo> types, Set<String> typeParams) {
    buffer.writeln('  ${schema.title}Object toObject() {');

    // Check concrete types
    for (int i = 0; i < types.length; i++) {
      final type = types[i];
      final constructorName = _getConstructorName(type);
      final capitalizedName = constructorName[0].toUpperCase() + constructorName.substring(1);
      final objectType = _getUnionObjectType(type);

      if (i == 0) {
        buffer.writeln('    if (_$constructorName != null) {');
      } else {
        buffer.writeln('    } else if (_$constructorName != null) {');
      }
      buffer.writeln('      return ${schema.title}Object.$constructorName(_$constructorName.toObject());');
    }

    // Handle type parameters
    for (final typeParam in typeParams) {
      final fieldName = _typeParamToFieldName(typeParam);

      buffer.writeln('    } else if (_$fieldName != null) {');
      buffer.writeln('      return ${schema.title}Object.$fieldName(_$fieldName.toObject());');
    }

    buffer.writeln('    } else {');
    buffer.writeln('      throw StateError(\'Union has no value set\');');
    buffer.writeln('    }');
    buffer.writeln('  }');
  }

  /// Gets the object type for a union member.
  String _getUnionObjectType(SchemaInfo type) {
    if (type.title == 'String') return 'StringValue';
    if (type.title == 'Integer') return 'IntValue';
    if (type.title == 'Number') return 'DoubleValue';
    if (type.title == 'Boolean') return 'BoolValue';
    return '${type.title}Object';
  }

  /// Generates fromObject method for union nodes.
  void _generateUnionFromObject(StringBuffer buffer, List<SchemaInfo> types, Set<String> typeParams) {
    buffer.write('  static void fromObject');
    if (typeParams.isNotEmpty) {
      buffer.write('<');
      buffer.write(typeParams.map((t) => '$t extends TreeObject').join(', '));
      buffer.write('>');
    }
    buffer.write('(Tree tree, TreeNode? parent, String key, ${schema.title}Object');
    if (typeParams.isNotEmpty) {
      buffer.write('<');
      buffer.write(typeParams.join(', '));
      buffer.write('>');
    }
    buffer.write('? object');
    if (typeParams.isNotEmpty) {
      for (final typeParam in typeParams) {
        buffer.write(', ObjectParser<$typeParam> objectParser_$typeParam');
      }
    }
    buffer.writeln(') {');
    buffer.writeln('    if (object == null) return;');
    buffer.writeln();

    // Delegate to concrete type's fromObject - union nodes are never stored, only concrete types
    for (int i = 0; i < types.length; i++) {
      final type = types[i];
      final constructorName = _getConstructorName(type);
      final capitalizedName = constructorName[0].toUpperCase() + constructorName.substring(1);
      final nodeType = _getUnionNodeDartType(type);

      if (i == 0) {
        buffer.writeln('    if (object.is$capitalizedName) {');
      } else {
        buffer.writeln('    } else if (object.is$capitalizedName) {');
      }
      buffer.writeln('      $nodeType.fromObject(tree, parent, key, object.as$capitalizedName);');
    }

    // Handle type parameters - use objectParser passed by parent
    for (final typeParam in typeParams) {
      final fieldName = _typeParamToFieldName(typeParam);
      final capitalizedName = fieldName[0].toUpperCase() + fieldName.substring(1);

      buffer.writeln('    } else if (object.is$capitalizedName) {');
      buffer.writeln('      objectParser_$typeParam(tree, parent, key, object.as$capitalizedName!);');
    }

    buffer.writeln('    }');
    buffer.writeln('  }');
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

  /// Gets the Dart node type name for a union member.
  String _getUnionNodeDartType(SchemaInfo type) {
    if (type.title == 'String') return 'StringValueNode';
    if (type.title == 'Integer') return 'IntValueNode';
    if (type.title == 'Number') return 'DoubleValueNode';
    if (type.title == 'Boolean') return 'BoolValueNode';
    return '${type.title}Node';
  }

  /// Generates getter methods for all properties.
  void _generateGetters(StringBuffer buffer) {
    for (final property in schema.properties.values) {
      final nodeType = _getNodeType(property);
      final nullMark = property.nullable ? '?' : '';
      final escapedName = _escapePropertyName(property.name);

      // Special handling for union types (either directly or via object reference)
      if ((property.type == SchemaType.union || property.referencedSchema?.isUnion == true) &&
          property.referencedSchema != null) {
        _generateUnionGetter(buffer, property);
        continue;
      }

      // Regular getter
      final operator = property.nullable ? '?' : '!';
      buffer.writeln(
        '  $nodeType$nullMark get ${property.name} => '
        'this.\$children$operator[\'$escapedName\'] as $nodeType$nullMark;',
      );
    }
  }

  /// Generates a special getter for union type properties.
  void _generateUnionGetter(StringBuffer buffer, PropertyInfo property) {
    final unionSchema = property.referencedSchema!;
    final unionInfo = unionSchema.unionInfo!;
    final escapedName = _escapePropertyName(property.name);
    String unionNodeType = '${unionSchema.title}Node';
    if (property.typeArguments != null && property.typeArguments!.isNotEmpty) {
      final typeArgs = unionInfo.typeParameters
          .map((tp) => property.typeArguments![tp] != null ? _getNodeType(property.typeArguments![tp]!) : 'TreeNode')
          .join(', ');
      unionNodeType = '$unionNodeType<$typeArgs>';
    }
    final nullMark = property.nullable ? '?' : '';

    buffer.writeln('  $unionNodeType$nullMark get ${property.name} {');
    buffer.writeln('    final child = this.\$children?[\'$escapedName\'];');
    buffer.writeln('    return switch (child.runtimeType) {');

    // Add cases for each concrete union type
    for (final type in unionInfo.types) {
      final constructorName = _getConstructorName(type);
      final nodeType = _getUnionNodeType(type);
      buffer.writeln('      $nodeType => $unionNodeType.$constructorName(child as $nodeType),');
    }

    // Handle type parameters - use concrete node types from typeArguments when available
    for (final typeParam in unionInfo.typeParameters) {
      final fieldName = _typeParamToFieldName(typeParam);
      final argProp = property.typeArguments?[typeParam];
      final nodeType = argProp != null ? _getNodeType(argProp) : 'TreeNode';
      buffer.writeln('      $nodeType => $unionNodeType.$fieldName(child as $nodeType),');
    }

    buffer.writeln('      _ => null,');
    buffer.writeln('    };');
    buffer.writeln('  }');
  }

  /// Gets the node type for a union member.
  String _getUnionNodeType(SchemaInfo type) {
    if (type.title == 'String') return 'StringValueNode';
    if (type.title == 'Integer') return 'IntValueNode';
    if (type.title == 'Number') return 'DoubleValueNode';
    if (type.title == 'Boolean') return 'BoolValueNode';
    return '${type.title}Node';
  }

  /// Generates setter methods for value type properties.
  void _generateSetters(StringBuffer buffer) {
    for (final property in schema.properties.values) {
      // Only generate setters for value types (primitives)
      if (!_isValueType(property.type)) continue;

      final objectType = _getObjectType(property);
      final nullMark = property.nullable ? '?' : '';
      final escapedName = _escapePropertyName(property.name);
      final capitalizedName = property.name[0].toUpperCase() + property.name.substring(1);

      buffer.writeln('  Tree? set$capitalizedName($objectType$nullMark value) {');
      buffer.writeln('    Tree? removedSubtree;');

      if (property.nullable) {
        buffer.writeln('    if (value == null) {');
        buffer.writeln('      // Remove node from tree');
        buffer.writeln('      final tree = this.\$tree;');
        buffer.writeln('      if (tree != null) {');
        buffer.writeln('        final oldNode = this.${property.name};');
        buffer.writeln('        if (oldNode != null) {');
        buffer.writeln('          removedSubtree = tree.removeSubtree(oldNode);');
        buffer.writeln('        }');
        buffer.writeln('      }');
        buffer.writeln('      return removedSubtree;');
        buffer.writeln('    }');
      }

      // Replace the node in the tree
      buffer.writeln('    final tree = this.\$tree;');
      buffer.writeln('    if (tree != null) {');
      buffer.writeln('      final oldNode = this.${property.name};');

      if (property.nullable) {
        buffer.writeln('      if (oldNode != null) {');
        buffer.writeln('        // Replace existing node');
        buffer.writeln('        final newSubtree = Tree(root: value);');
        buffer.writeln('        removedSubtree = tree.replaceSubtree(node: oldNode, newSubtree: newSubtree);');
        buffer.writeln('      } else {');
        buffer.writeln('        // Add new node (property was null before)');
        buffer.writeln('        final newSubtree = Tree(root: value);');
        buffer.writeln('        tree.addSubtree(parent: this, key: \'$escapedName\', subtree: newSubtree);');
        buffer.writeln('      }');
      } else {
        buffer.writeln('      final newSubtree = Tree(root: value);');
        buffer.writeln('      removedSubtree = tree.replaceSubtree(node: oldNode, newSubtree: newSubtree);');
      }

      buffer.writeln('    }');
      buffer.writeln('    return removedSubtree;');
      buffer.writeln('  }');
      buffer.writeln();
    }
  }

  /// Generates setter methods for non-value type properties (objects, arrays, unions).
  void _generateObjectSetters(StringBuffer buffer) {
    for (final property in schema.properties.values) {
      // Only generate setters for non-value types
      if (_isValueType(property.type)) continue;

      final objectType = _getObjectType(property);
      final nullMark = property.nullable ? '?' : '';
      final escapedName = _escapePropertyName(property.name);
      final nodeType = _getNodeType(property);
      final isUnion = property.type == SchemaType.union || property.referencedSchema?.isUnion == true;
      final capitalizedName = property.name[0].toUpperCase() + property.name.substring(1);

      buffer.writeln('  Tree? set$capitalizedName($objectType$nullMark value) {');
      buffer.writeln('    Tree? removedSubtree;');

      if (property.nullable) {
        buffer.writeln('    if (value == null) {');
        buffer.writeln('      // Remove node from tree');
        buffer.writeln('      final tree = this.\$tree;');
        buffer.writeln('      if (tree != null) {');
        // For union properties, get the underlying node from $children
        if (isUnion) {
          buffer.writeln('        final oldNode = this.\$children?[\'$escapedName\'] as TreeNode?;');
        } else {
          buffer.writeln('        final oldNode = this.${property.name};');
        }
        buffer.writeln('        if (oldNode != null) {');
        buffer.writeln('          removedSubtree = tree.removeSubtree(oldNode);');
        buffer.writeln('        }');
        buffer.writeln('      }');
        buffer.writeln('      return removedSubtree;');
        buffer.writeln('    }');
      }

      // Create subtree from object
      buffer.writeln('    final tree = this.\$tree;');
      buffer.writeln('    if (tree != null) {');
      // For union properties, get the underlying node from $children
      if (isUnion) {
        buffer.writeln('      final oldNode = this.\$children?[\'$escapedName\'] as TreeNode?;');
      } else {
        buffer.writeln('      final oldNode = this.${property.name};');
      }
      buffer.writeln('      final tempTree = Tree(root: value);');
      buffer.writeln('      final rootNode = tempTree.root;');
      buffer.writeln('      if (rootNode != null) {');
      buffer.writeln('        final subtree = tempTree.removeSubtree(rootNode);');

      if (property.nullable) {
        buffer.writeln('        if (oldNode != null) {');
        buffer.writeln('          // Replace existing node');
        buffer.writeln('          removedSubtree = tree.replaceSubtree(node: oldNode, newSubtree: subtree);');
        buffer.writeln('        } else {');
        buffer.writeln('          // Add new node (property was null before)');
        buffer.writeln('          tree.addSubtree(parent: this, key: \'$escapedName\', subtree: subtree);');
        buffer.writeln('        }');
      } else {
        buffer.writeln('        removedSubtree = tree.replaceSubtree(node: oldNode, newSubtree: subtree);');
      }

      buffer.writeln('      }');
      buffer.writeln('    }');
      buffer.writeln('    return removedSubtree;');
      buffer.writeln('  }');
      buffer.writeln();
    }
  }

  /// Generates the toObject method.
  void _generateToObjectMethod(StringBuffer buffer) {
    buffer.writeln('  ${schema.title}Object toObject() => ${schema.title}Object(');

    for (int i = 0; i < schema.properties.values.length; i++) {
      final property = schema.properties.values.elementAt(i);
      final propAccess = _propertyAccess(property.name);
      final toObjectCall = _getToObjectCall(property);

      if (i < schema.properties.values.length - 1) {
        buffer.writeln('    ${property.name}: $toObjectCall,');
      } else {
        buffer.writeln('    ${property.name}: $toObjectCall,');
      }
    }

    buffer.writeln('  );');
  }

  /// Gets the toObject conversion call for a property.
  String _getToObjectCall(PropertyInfo property) {
    final propAccess = _propertyAccess(property.name);

    switch (property.type) {
      case SchemaType.string:
      case SchemaType.integer:
      case SchemaType.number:
      case SchemaType.boolean:
        // Value nodes - call toObject() directly
        if (property.nullable) {
          return '$propAccess?.toObject()';
        }
        return '$propAccess.toObject()';
      case SchemaType.object:
        // Object nodes - call toObject()
        // All type arguments are now concrete types (type parameters are union-only)
        final isUnion = property.referencedSchema?.isUnion == true;
        final hasConcreteTypeArgs = property.typeArguments != null && property.typeArguments!.isNotEmpty;

        // Add cast if it's a union or has concrete type arguments
        if (isUnion || hasConcreteTypeArgs) {
          final objectType = _getObjectType(property);
          if (property.nullable) {
            return '$propAccess?.toObject() as $objectType?';
          }
          return '$propAccess.toObject() as $objectType';
        }

        // No cast for simple objects or objects with type parameter args
        if (property.nullable) {
          return '$propAccess?.toObject()';
        }
        return '$propAccess.toObject()';
      case SchemaType.array:
        // List nodes - map each element to object
        if (property.nullable) {
          return '$propAccess?.toObject()';
        }
        return '$propAccess.toObject()';
      case SchemaType.union:
        // Union nodes - call toObject()
        if (property.nullable) {
          return '$propAccess?.toObject()';
        }
        return '$propAccess.toObject()';
    }
  }

  /// Generates the fromObject static method.
  void _generateFromObjectMethod(StringBuffer buffer) {
    buffer.writeln(
      '  static void fromObject(Tree tree, TreeNode? parent, String key, ${schema.title}Object? object) {',
    );
    buffer.writeln('    if (object == null) return;');
    buffer.writeln();
    buffer.writeln('    final parentRecord = tree.nodes[parent?.id];');
    buffer.writeln('    final pointer = Pointer.build(parentRecord?.pointer, key);');
    buffer.writeln('    final node = ${schema.title}Node();');
    buffer.writeln('    tree.\$nodes[node.id] = TreeNodeRecord(node: node, pointer: pointer, parent: parent?.id);');
    buffer.writeln('    parentRecord?.children[Edge(${schema.title}Node, key)] = node.id;');
    buffer.writeln();

    // Call fromObject for each property
    for (final property in schema.properties.values) {
      final escapedName = _escapePropertyName(property.name);

      // For unions and objects, use the base node type without type arguments for fromObject call
      String nodeTypeForFromObject;
      if (property.type == SchemaType.object && property.referencedSchema != null) {
        nodeTypeForFromObject = '${property.referencedSchema!.title}Node';
      } else {
        nodeTypeForFromObject = _getNodeType(property);
      }

      final isUnionWithTypeArgs =
          property.referencedSchema?.isUnion == true &&
          property.referencedSchema!.unionInfo!.typeParameters.isNotEmpty &&
          property.typeArguments != null;

      if (isUnionWithTypeArgs) {
        final typeArgs = property.referencedSchema!.unionInfo!.typeParameters
            .map((tp) => _getObjectType(property.typeArguments![tp]!))
            .join(', ');
        final objectParserArgs = property.referencedSchema!.unionInfo!.typeParameters
            .map((tp) {
              final argProp = property.typeArguments![tp]!;
              final nodeType = _getNodeType(argProp);
              final objectType = _getObjectType(argProp);
              return '(Tree t, TreeNode? p, String k, $objectType o) => $nodeType.fromObject(t, p, k, o)';
            })
            .join(', ');
        buffer.writeln(
          '    $nodeTypeForFromObject.fromObject<$typeArgs>(tree, node, \'$escapedName\', object.${property.name}, $objectParserArgs);',
        );
      } else {
        buffer.writeln('    $nodeTypeForFromObject.fromObject(tree, node, \'$escapedName\', object.${property.name});');
      }
    }

    buffer.writeln('  }');
  }

  /// Generates the clone method.
  void _generateCloneMethod(StringBuffer buffer) {
    buffer.writeln('  @override');
    buffer.writeln('  ${schema.title}Node clone() => ${schema.title}Node(id: id);');
  }

  /// Gets the node type name for a property.
  String _getNodeType(PropertyInfo property) {
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
        final baseType = '${property.referencedSchema!.title}Node';
        if (property.typeArguments != null && property.typeArguments!.isNotEmpty) {
          final typeArgs = property.typeArguments!.values.map((argProp) => _getNodeType(argProp)).join(', ');
          return '$baseType<$typeArgs>';
        }
        return baseType;
      case SchemaType.array:
        if (property.referencedSchema != null) {
          final listClass = _getListClassName(property.referencedSchema!.title, property.uniqueItems);
          return listClass.replaceFirst('ListObject', 'ListNode').replaceFirst('SetObject', 'SetNode');
        }
        return property.uniqueItems ? 'SetTreeNode' : 'ListTreeNode';
      case SchemaType.union:
        // Use the referenced schema's generated union node type
        if (property.referencedSchema != null) {
          return '${property.referencedSchema!.title}Node';
        }
        return 'UnionNode2';
    }
  }

  /// Gets the object type for a property (for setter value creation).
  String _getObjectType(PropertyInfo property) {
    switch (property.type) {
      case SchemaType.string:
        return 'StringValue';
      case SchemaType.integer:
        return 'IntValue';
      case SchemaType.number:
        return 'DoubleValue';
      case SchemaType.boolean:
        return 'BoolValue';
      case SchemaType.object:
        final baseType = '${property.referencedSchema!.title}Object';
        // All type arguments are concrete types now (type parameters are union-only)
        if (property.typeArguments != null && property.typeArguments!.isNotEmpty) {
          final typeArgs = property.typeArguments!.values.map((argProp) => _getObjectType(argProp)).join(', ');
          return '$baseType<$typeArgs>';
        }
        return baseType;
      case SchemaType.array:
        if (property.referencedSchema != null) {
          return _getListClassName(property.referencedSchema!.title, property.uniqueItems);
        }
        return property.uniqueItems ? 'SetObject<TreeObject>' : 'ListObject<TreeObject>';
      case SchemaType.union:
        if (property.referencedSchema != null) {
          return '${property.referencedSchema!.title}Object';
        }
        return 'UnionObject2<TreeObject, TreeObject>';
    }
  }

  String _getListClassName(String itemSchemaTitle, bool uniqueItems) {
    final plural = '${itemSchemaTitle}s';
    return uniqueItems ? '${plural}SetObject' : '${plural}ListObject';
  }

  /// Gets the Dart value type (String, int, etc.) for a property.
  String _getDartValueType(PropertyInfo property) {
    switch (property.type) {
      case SchemaType.string:
        return 'String';
      case SchemaType.integer:
        return 'int';
      case SchemaType.number:
        return 'double';
      case SchemaType.boolean:
        return 'bool';
      default:
        return 'Object';
    }
  }

  /// Gets the ValueObject type name for a property.
  String _getValueObjectType(PropertyInfo property) {
    switch (property.type) {
      case SchemaType.string:
        return 'StringValue';
      case SchemaType.integer:
        return 'IntValue';
      case SchemaType.number:
        return 'DoubleValue';
      case SchemaType.boolean:
        return 'BoolValue';
      default:
        throw UnsupportedError('Not a value type: ${property.type}');
    }
  }

  /// Checks if a schema type is a value type (primitive).
  bool _isValueType(SchemaType type) {
    return type == SchemaType.string ||
        type == SchemaType.integer ||
        type == SchemaType.number ||
        type == SchemaType.boolean;
  }
}
