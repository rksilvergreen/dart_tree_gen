import '../schema/schema_info.dart';

/// Extension to capitalize strings.
extension StringExtensions on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}

/// Generates TreeObject class code from a SchemaInfo.
class TreeObjectClassGenerator {
  final SchemaInfo schema;

  TreeObjectClassGenerator(this.schema);

  /// Gets the proper way to access a property in code expressions.
  /// Always use 'this.' prefix to avoid conflicts with local variables.
  static String _propertyAccess(String propertyName) {
    return 'this.$propertyName';
  }

  /// Escapes property names for use in string literals.
  /// Properties starting with $ need the $ escaped as \$
  static String _escapePropertyName(String propertyName) {
    if (propertyName.startsWith(r'$')) {
      return r'\$' + propertyName.substring(1);
    }
    return propertyName;
  }

  /// Formats a list of property names for use in const list literals in generated code.
  static String _formatPropertyNamesList(List<String> names) {
    return names
        .map((k) {
          final escaped = _escapePropertyName(k);
          return '\'$escaped\'';
        })
        .join(', ');
  }

  /// Generates the complete TreeObject class code.
  String generate() {
    // Check if this is a union schema
    if (schema.isUnion) {
      return _generateUnion();
    }

    final buffer = StringBuffer();

    // Class declaration
    buffer.writeln('/// Generated TreeObject class for ${schema.title}');
    buffer.write('class ${schema.title}Object');
    if (schema.isUnion && schema.unionInfo!.typeParameters.isNotEmpty) {
      buffer.write('<');
      buffer.write(schema.unionInfo!.typeParameters.map((t) => '$t extends TreeObject').join(', '));
      buffer.write('>');
    }
    buffer.writeln(' extends TreeObject {');

    // Generate fields
    _generateFields(buffer);

    buffer.writeln();

    // Generate constructor
    _generateConstructor(buffer);

    buffer.writeln();

    // Generate serialization methods
    _generateToJson(buffer);
    buffer.writeln();
    _generateToYaml(buffer);
    buffer.writeln();
    _generateFromJson(buffer);
    buffer.writeln();
    _generateFromYaml(buffer);

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

  /// Generates a concrete union class.
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
    buffer.writeln('/// Generated union class for ${schema.title}');
    buffer.write('class ${schema.title}Object');
    if (typeParams.isNotEmpty) {
      buffer.write('<');
      buffer.write(typeParams.map((t) => '$t extends TreeObject').join(', '));
      buffer.write('>');
    }
    buffer.writeln(' {');

    // Generate nullable fields for concrete types
    for (final type in types) {
      final constructorName = _getConstructorName(type);
      final dartType = _getUnionDartType(type);
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
      final dartType = _getUnionDartType(type);
      buffer.writeln('  /// Creates a ${schema.title} with a $dartType value.');
      buffer.write('  ${schema.title}Object.$constructorName($dartType $constructorName)');
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
      buffer.writeln('  /// Creates a ${schema.title} with a $typeParam value.');
      buffer.write('  ${schema.title}Object.$fieldName($typeParam $fieldName)');
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
      final dartType = _getUnionDartType(type);
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
      final dartType = _getUnionDartType(type);
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

    // Generate toJson
    buffer.writeln('  String toJson() {');
    for (final type in types) {
      final constructorName = _getConstructorName(type);
      buffer.writeln('    if (_$constructorName != null) return _$constructorName.toJson();');
    }
    for (final typeParam in typeParams) {
      final fieldName = _typeParamToFieldName(typeParam);
      buffer.writeln('    if (_$fieldName != null) return _$fieldName.toJson();');
    }
    buffer.writeln('    throw StateError(\'Union has no value set\');');
    buffer.writeln('  }');
    buffer.writeln();

    // Generate toYaml
    buffer.writeln('  String toYaml() {');
    for (final type in types) {
      final constructorName = _getConstructorName(type);
      buffer.writeln('    if (_$constructorName != null) return _$constructorName.toYaml();');
    }
    for (final typeParam in typeParams) {
      final fieldName = _typeParamToFieldName(typeParam);
      buffer.writeln('    if (_$fieldName != null) return _$fieldName.toYaml();');
    }
    buffer.writeln('    throw StateError(\'Union has no value set\');');
    buffer.writeln('  }');
    buffer.writeln();

    // Generate fromJson
    buffer.writeln('  /// Attempts to decode from JSON by trying each type in order.');
    buffer.write('  static ${schema.title}Object');
    if (typeParams.isNotEmpty) {
      buffer.write('<');
      buffer.write(typeParams.join(', '));
      buffer.write('>');
    }
    buffer.write(' fromJson');
    if (typeParams.isNotEmpty) {
      buffer.write('<');
      buffer.write(typeParams.map((t) => '$t extends TreeObject').join(', '));
      buffer.write('>');
    }
    buffer.write('(String json');
    if (typeParams.isNotEmpty) {
      for (final typeParam in typeParams) {
        buffer.write(', TextParser<$typeParam> textParser_$typeParam');
      }
    }
    buffer.writeln(') {');

    int attemptIndex = 0;
    // Try concrete types
    for (final type in types) {
      final constructorName = _getConstructorName(type);
      final dartType = _getUnionDartType(type);

      if (attemptIndex > 0) buffer.writeln('    } catch (_) {');
      buffer.writeln('    try {');
      buffer.writeln('      return ${schema.title}Object.$constructorName($dartType.fromJson(json));');
      attemptIndex++;
    }

    // Try type parameters
    for (final typeParam in typeParams) {
      final fieldName = _typeParamToFieldName(typeParam);

      if (attemptIndex > 0) buffer.writeln('    } catch (_) {');
      buffer.writeln('    try {');
      buffer.writeln('      return ${schema.title}Object.$fieldName(textParser_$typeParam(json));');
      attemptIndex++;
    }

    buffer.writeln('    } catch (e) {');
    buffer.writeln('      throw FormatException(\'Could not decode ${schema.title}Object from JSON: \$e\');');
    buffer.writeln('    }');
    for (int i = 1; i < totalTypes; i++) {
      buffer.writeln('    }');
    }
    buffer.writeln('  }');
    buffer.writeln();

    // Generate fromYaml
    buffer.writeln('  /// Attempts to decode from YAML by trying each type in order.');
    buffer.write('  static ${schema.title}Object');
    if (typeParams.isNotEmpty) {
      buffer.write('<');
      buffer.write(typeParams.join(', '));
      buffer.write('>');
    }
    buffer.write(' fromYaml');
    if (typeParams.isNotEmpty) {
      buffer.write('<');
      buffer.write(typeParams.map((t) => '$t extends TreeObject').join(', '));
      buffer.write('>');
    }
    buffer.write('(String yaml');
    if (typeParams.isNotEmpty) {
      for (final typeParam in typeParams) {
        buffer.write(', TextParser<$typeParam> textParser_$typeParam');
      }
    }
    buffer.writeln(') {');

    attemptIndex = 0;
    // Try concrete types
    for (final type in types) {
      final constructorName = _getConstructorName(type);
      final dartType = _getUnionDartType(type);

      if (attemptIndex > 0) buffer.writeln('    } catch (_) {');
      buffer.writeln('    try {');
      buffer.writeln('      return ${schema.title}Object.$constructorName($dartType.fromYaml(yaml));');
      attemptIndex++;
    }

    // Try type parameters
    for (final typeParam in typeParams) {
      final fieldName = _typeParamToFieldName(typeParam);

      if (attemptIndex > 0) buffer.writeln('    } catch (_) {');
      buffer.writeln('    try {');
      buffer.writeln('      return ${schema.title}Object.$fieldName(textParser_$typeParam(yaml));');
      attemptIndex++;
    }

    buffer.writeln('    } catch (e) {');
    buffer.writeln('      throw FormatException(\'Could not decode ${schema.title}Object from YAML: \$e\');');
    buffer.writeln('    }');
    for (int i = 1; i < totalTypes; i++) {
      buffer.writeln('    }');
    }
    buffer.writeln('  }');
    buffer.writeln();

    // Generate toString
    buffer.write('  String toString() => \'${schema.title}Object(');
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

    // Generate operator==
    buffer.writeln('  bool operator ==(Object other) =>');
    buffer.writeln('      identical(this, other) ||');
    buffer.write('      other is ${schema.title}Object');
    if (typeParams.isNotEmpty) {
      buffer.write('<');
      buffer.write(typeParams.join(', '));
      buffer.write('>');
    }
    buffer.write(' &&');

    // Compare all fields
    for (int i = 0; i < types.length; i++) {
      final constructorName = _getConstructorName(types[i]);
      buffer.writeln();
      buffer.write('      _$constructorName == other._$constructorName');
      if (i < types.length - 1 || typeParams.isNotEmpty) buffer.write(' &&');
    }

    for (int i = 0; i < typeParamsList.length; i++) {
      final fieldName = _typeParamToFieldName(typeParamsList[i]);
      buffer.writeln();
      buffer.write('      _$fieldName == other._$fieldName');
      if (i < typeParamsList.length - 1) buffer.write(' &&');
    }
    buffer.writeln(';');
    buffer.writeln();

    // Generate hashCode
    buffer.write('  int get hashCode => Object.hash(');
    final allFields = [
      ...types.map((t) => '_${_getConstructorName(t)}'),
      ...typeParams.map((tp) => '_${_typeParamToFieldName(tp)}'),
    ];
    buffer.write(allFields.join(', '));
    buffer.writeln(');');

    buffer.writeln('}');

    return buffer.toString();
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

  /// Gets the Dart type name for a union member.
  String _getUnionDartType(SchemaInfo type) {
    if (type.title == 'String') return 'StringValue';
    if (type.title == 'Integer') return 'IntValue';
    if (type.title == 'Number') return 'DoubleValue';
    if (type.title == 'Boolean') return 'BoolValue';
    return '${type.title}Object';
  }

  /// Generates field declarations.
  void _generateFields(StringBuffer buffer) {
    for (final property in schema.properties.values) {
      final dartType = _getDartType(property);
      final nullMark = property.nullable ? '?' : '';
      buffer.writeln('  final $dartType$nullMark ${property.name};');
    }
  }

  /// Generates the constructor.
  void _generateConstructor(StringBuffer buffer) {
    buffer.writeln('  ${schema.title}Object({');

    // Constructor parameters
    for (final property in schema.properties.values) {
      final prefix = property.nullable ? '' : 'required ';
      buffer.writeln('    ${prefix}this.${property.name},');
    }

    buffer.writeln('  });');
  }

  /// Generates toJson method.
  void _generateToJson(StringBuffer buffer) {
    buffer.writeln('  @override');
    buffer.writeln('  String toJson() {');

    final properties = schema.properties.values.toList();

    // Optimize for single non-nullable property
    if (properties.length == 1 && !properties[0].nullable) {
      final property = properties[0];
      final propAccess = _propertyAccess(property.name);
      final escapedName = _escapePropertyName(property.name);
      buffer.write('    return \'{"');
      buffer.write(escapedName);
      buffer.write('": \' + ');
      buffer.write(propAccess);
      buffer.writeln('.toJson() + \'}\';');
      buffer.writeln('  }');
      return;
    }

    // Check if we have at least one required property
    final hasRequiredProperty = properties.any((p) => !p.nullable);
    final firstRequiredIndex = properties.indexWhere((p) => !p.nullable);

    // General case with multiple or nullable properties
    buffer.writeln('    final buffer = StringBuffer();');
    buffer.writeln('    buffer.write(\'{\');');

    // Only need index tracking if we have nullable properties before the first required one
    final needsIndex = firstRequiredIndex > 0 || !hasRequiredProperty;
    if (needsIndex) {
      buffer.writeln('    int index = 0;');
    }

    for (int i = 0; i < properties.length; i++) {
      final property = properties[i];
      final propAccess = _propertyAccess(property.name);
      final escapedName = _escapePropertyName(property.name);
      final isAfterRequired = hasRequiredProperty && i > firstRequiredIndex;

      if (property.nullable) {
        buffer.writeln('    if ($propAccess != null) {');
        if (isAfterRequired) {
          // We know at least one property has been written (the required one)
          buffer.writeln('      buffer.write(\', \');');
        } else if (needsIndex) {
          buffer.writeln('      if (index > 0) buffer.write(\', \');');
          buffer.writeln('      index++;');
        } else {
          buffer.writeln('      buffer.write(\', \');');
        }
        buffer.write('      buffer.write(\'');
        buffer.write('"');
        buffer.write(escapedName);
        buffer.writeln('": \');');
        buffer.writeln('      buffer.write($propAccess!.toJson());');
        buffer.writeln('    }');
      } else {
        // Required property
        if (i > 0) {
          if (needsIndex && i <= firstRequiredIndex) {
            buffer.writeln('    if (index > 0) buffer.write(\', \');');
          } else {
            buffer.writeln('    buffer.write(\', \');');
          }
        }
        buffer.write('    buffer.write(\'');
        buffer.write('"');
        buffer.write(escapedName);
        buffer.writeln('": \');');
        buffer.writeln('    buffer.write($propAccess.toJson());');
        if (needsIndex && i <= firstRequiredIndex) {
          buffer.writeln('    index++;');
        }
      }
    }

    buffer.writeln('    buffer.write(\'}\');');
    buffer.writeln('    return buffer.toString();');
    buffer.writeln('  }');
  }

  /// Generates toYaml method.
  void _generateToYaml(StringBuffer buffer) {
    buffer.writeln('  @override');
    buffer.writeln('  String toYaml() {');

    final properties = schema.properties.values.toList();

    // Optimize for single non-nullable property
    if (properties.length == 1 && !properties[0].nullable) {
      final property = properties[0];
      final propAccess = _propertyAccess(property.name);
      final escapedName = _escapePropertyName(property.name);
      buffer.write('    return \'');
      buffer.write(escapedName);
      buffer.write(': \' + ');
      buffer.write(propAccess);
      buffer.writeln('.toYaml();');
      buffer.writeln('  }');
      return;
    }

    // Check if we have at least one required property
    final hasRequiredProperty = properties.any((p) => !p.nullable);
    final firstRequiredIndex = properties.indexWhere((p) => !p.nullable);

    // General case with multiple or nullable properties
    buffer.writeln('    final buffer = StringBuffer();');

    // Only need index tracking if we have nullable properties before the first required one
    final needsIndex = firstRequiredIndex > 0 || !hasRequiredProperty;
    if (needsIndex) {
      buffer.writeln('    int index = 0;');
    }

    for (int i = 0; i < properties.length; i++) {
      final property = properties[i];
      final propAccess = _propertyAccess(property.name);
      final escapedName = _escapePropertyName(property.name);
      final isAfterRequired = hasRequiredProperty && i > firstRequiredIndex;

      if (property.nullable) {
        buffer.writeln('    if ($propAccess != null) {');
        if (isAfterRequired) {
          // We know at least one property has been written (the required one)
          buffer.writeln('      buffer.writeln();');
        } else if (needsIndex) {
          buffer.writeln('      if (index > 0) buffer.writeln();');
          buffer.writeln('      index++;');
        } else {
          buffer.writeln('      buffer.writeln();');
        }
        buffer.write('      buffer.write(\'');
        buffer.write(escapedName);
        buffer.writeln(': \');');
        buffer.writeln('      buffer.write($propAccess!.toYaml());');
        buffer.writeln('    }');
      } else {
        // Required property
        if (i > 0) {
          if (needsIndex && i <= firstRequiredIndex) {
            buffer.writeln('    if (index > 0) buffer.writeln();');
          } else {
            buffer.writeln('    buffer.writeln();');
          }
        }
        buffer.write('    buffer.write(\'');
        buffer.write(escapedName);
        buffer.writeln(': \');');
        buffer.writeln('    buffer.write($propAccess.toYaml());');
        if (needsIndex && i <= firstRequiredIndex) {
          buffer.writeln('    index++;');
        }
      }
    }

    buffer.writeln('    return buffer.toString();');
    buffer.writeln('  }');
  }

  /// Generates fromJson factory.
  void _generateFromJson(StringBuffer buffer) {
    final typeParams = schema.isUnion ? schema.unionInfo!.typeParameters : <String>{};
    buffer.write('  static ${schema.title}Object');
    if (typeParams.isNotEmpty) {
      buffer.write('<');
      buffer.write(typeParams.join(', '));
      buffer.write('>');
    }
    buffer.write(' fromJson');
    if (typeParams.isNotEmpty) {
      buffer.write('<');
      buffer.write(typeParams.map((t) => '$t extends TreeObject').join(', '));
      buffer.write('>');
    }
    buffer.write('(String json');
    if (typeParams.isNotEmpty) {
      for (final typeParam in typeParams) {
        buffer.write(', TextParser<$typeParam> textParser_$typeParam');
      }
    }
    buffer.writeln(') {');
    buffer.writeln('    final map = extractJsonObjectFields(json);');
    buffer.writeln('    return \$checkedCreate(');
    buffer.writeln('      \'${schema.title}Object\',');
    buffer.writeln('      map,');
    buffer.writeln('      (\$checkedConvert) {');

    // Generate $checkKeys call if we have validation constraints
    final hasAllowed = schema.allowed != null && schema.allowed!.isNotEmpty;
    final hasRequired = schema.required.isNotEmpty;
    final hasNullable = schema.nullable != null && schema.nullable!.isNotEmpty;

    if (hasAllowed || hasRequired || hasNullable) {
      buffer.writeln('        \$checkKeys(');
      buffer.writeln('          map,');

      if (hasAllowed) {
        buffer.writeln('          allowedKeys: const [${_formatPropertyNamesList(schema.allowed!)}],');
      }

      if (hasRequired) {
        buffer.writeln('          requiredKeys: const [${_formatPropertyNamesList(schema.required)}],');
      }

      if (hasNullable) {
        // disallowNullValues should be properties that are NOT in the nullable list
        final disallowNull = schema.properties.keys.where((key) => !schema.nullable!.contains(key)).toList();
        if (disallowNull.isNotEmpty) {
          buffer.writeln('          disallowNullValues: const [${_formatPropertyNamesList(disallowNull)}],');
        }
      }

      buffer.writeln('        );');
    }

    // Generate the object construction
    buffer.write('        final val = ${schema.title}Object');
    if (typeParams.isNotEmpty) {
      buffer.write('<');
      buffer.write(typeParams.join(', '));
      buffer.write('>');
    }
    buffer.writeln('(');

    for (final property in schema.properties.values) {
      final decoder = _getCheckedConvertCall(property, isJson: true);
      buffer.writeln('          ${property.name}: $decoder,');
    }

    buffer.writeln('        );');
    buffer.writeln('        return val;');
    buffer.writeln('      },');
    buffer.writeln('    );');
    buffer.writeln('  }');
  }

  /// Generates fromYaml factory.
  void _generateFromYaml(StringBuffer buffer) {
    final typeParams = schema.isUnion ? schema.unionInfo!.typeParameters : <String>{};
    buffer.write('  static ${schema.title}Object');
    if (typeParams.isNotEmpty) {
      buffer.write('<');
      buffer.write(typeParams.join(', '));
      buffer.write('>');
    }
    buffer.write(' fromYaml');
    if (typeParams.isNotEmpty) {
      buffer.write('<');
      buffer.write(typeParams.map((t) => '$t extends TreeObject').join(', '));
      buffer.write('>');
    }
    buffer.write('(String yaml');
    if (typeParams.isNotEmpty) {
      for (final typeParam in typeParams) {
        buffer.write(', TextParser<$typeParam> textParser_$typeParam');
      }
    }
    buffer.writeln(') {');
    buffer.writeln('    final map = extractYamlMappingFields(yaml);');
    buffer.writeln('    return \$checkedCreate(');
    buffer.writeln('      \'${schema.title}Object\',');
    buffer.writeln('      map,');
    buffer.writeln('      (\$checkedConvert) {');

    // Generate $checkKeys call if we have validation constraints
    final hasAllowed = schema.allowed != null && schema.allowed!.isNotEmpty;
    final hasRequired = schema.required.isNotEmpty;
    final hasNullable = schema.nullable != null && schema.nullable!.isNotEmpty;

    if (hasAllowed || hasRequired || hasNullable) {
      buffer.writeln('        \$checkKeys(');
      buffer.writeln('          map,');

      if (hasAllowed) {
        buffer.writeln('          allowedKeys: const [${_formatPropertyNamesList(schema.allowed!)}],');
      }

      if (hasRequired) {
        buffer.writeln('          requiredKeys: const [${_formatPropertyNamesList(schema.required)}],');
      }

      if (hasNullable) {
        // disallowNullValues should be properties that are NOT in the nullable list
        final disallowNull = schema.properties.keys.where((key) => !schema.nullable!.contains(key)).toList();
        if (disallowNull.isNotEmpty) {
          buffer.writeln('          disallowNullValues: const [${_formatPropertyNamesList(disallowNull)}],');
        }
      }

      buffer.writeln('        );');
    }

    // Generate the object construction
    buffer.write('        final val = ${schema.title}Object');
    if (typeParams.isNotEmpty) {
      buffer.write('<');
      buffer.write(typeParams.join(', '));
      buffer.write('>');
    }
    buffer.writeln('(');

    for (final property in schema.properties.values) {
      final decoder = _getCheckedConvertCall(property, isJson: false);
      buffer.writeln('          ${property.name}: $decoder,');
    }

    buffer.writeln('        );');
    buffer.writeln('        return val;');
    buffer.writeln('      },');
    buffer.writeln('    );');
    buffer.writeln('  }');
  }

  /// Gets the checked convert call for a property.
  String _getCheckedConvertCall(PropertyInfo property, {required bool isJson}) {
    final convertLogic = isJson ? _getFromJsonConvertLogic(property) : _getFromYamlConvertLogic(property);

    final escapedName = _escapePropertyName(property.name);
    return '\$checkedConvert(\'$escapedName\', (v) => $convertLogic)';
  }

  /// Gets the conversion logic for fromJson (used inside $checkedConvert).
  String _getFromJsonConvertLogic(PropertyInfo property) {
    if (property.nullable) {
      return 'v == null ? null : ${_getFromJsonValueConversion(property, 'v')}';
    }
    return _getFromJsonValueConversion(property, 'v');
  }

  /// Gets the conversion logic for fromYaml (used inside $checkedConvert).
  String _getFromYamlConvertLogic(PropertyInfo property) {
    if (property.nullable) {
      return 'v == null ? null : ${_getFromYamlValueConversion(property, 'v')}';
    }
    return _getFromYamlValueConversion(property, 'v');
  }

  /// Gets the value conversion for JSON.
  String _getFromJsonValueConversion(PropertyInfo property, String varName) {
    switch (property.type) {
      case SchemaType.string:
        return 'StringValue.fromJson($varName as String)';
      case SchemaType.integer:
        return 'IntValue.fromJson($varName as String)';
      case SchemaType.number:
        return 'DoubleValue.fromJson($varName as String)';
      case SchemaType.boolean:
        return 'BoolValue.fromJson($varName as String)';
      case SchemaType.object:
        final baseType = '${property.referencedSchema!.title}Object';
        if (property.typeArguments != null && property.typeArguments!.isNotEmpty) {
          final typeArgs = property.typeArguments!.values.map((argProp) => _getDartType(argProp)).join(', ');
          final deserializerArgs = property.typeArguments!.values
              .map((argProp) => _getDeserializerLambda(argProp, isJson: true))
              .join(', ');
          return '$baseType.fromJson<$typeArgs>($varName as String, $deserializerArgs)';
        }
        return '$baseType.fromJson($varName as String)';
      case SchemaType.array:
        if (property.referencedSchema != null) {
          final listClass = _getListClassName(property.referencedSchema!.title, property.uniqueItems);
          return '$listClass.fromJson($varName as String)';
        }
        return 'ListObject(extractJsonArrayElements($varName as String).map((item) => TreeObject.fromJson(item)).toList())';
      case SchemaType.union:
        if (property.referencedSchema != null) {
          final unionSchema = property.referencedSchema!;
          return '${unionSchema.title}Object.fromJson($varName as String)';
        }
        return 'StringOrIntObject.fromJson($varName as String)';
    }
  }

  /// Gets the value conversion for YAML.
  String _getFromYamlValueConversion(PropertyInfo property, String varName) {
    switch (property.type) {
      case SchemaType.string:
        return 'StringValue.fromYaml($varName as String)';
      case SchemaType.integer:
        return 'IntValue.fromYaml($varName as String)';
      case SchemaType.number:
        return 'DoubleValue.fromYaml($varName as String)';
      case SchemaType.boolean:
        return 'BoolValue.fromYaml($varName as String)';
      case SchemaType.object:
        final baseType = '${property.referencedSchema!.title}Object';
        if (property.typeArguments != null && property.typeArguments!.isNotEmpty) {
          final typeArgs = property.typeArguments!.values.map((argProp) => _getDartType(argProp)).join(', ');
          final deserializerArgs = property.typeArguments!.values
              .map((argProp) => _getDeserializerLambda(argProp, isJson: false))
              .join(', ');
          return '$baseType.fromYaml<$typeArgs>($varName as String, $deserializerArgs)';
        }
        return '$baseType.fromYaml($varName as String)';
      case SchemaType.array:
        if (property.referencedSchema != null) {
          final listClass = _getListClassName(property.referencedSchema!.title, property.uniqueItems);
          return '$listClass.fromYaml($varName as String)';
        }
        return 'ListObject(extractYamlSequenceElements($varName as String).map((item) => TreeObject.fromYaml(item)).toList())';
      case SchemaType.union:
        if (property.referencedSchema != null) {
          final unionSchema = property.referencedSchema!;
          return '${unionSchema.title}Object.fromYaml($varName as String)';
        }
        return 'StringOrIntObject.fromYaml($varName as String)';
    }
  }

  /// Returns list class name by item schema (e.g. ReferencesListObject for Reference).
  String _getListClassName(String itemSchemaTitle, bool uniqueItems) {
    final plural = '${itemSchemaTitle}s';
    return uniqueItems ? '${plural}SetObject' : '${plural}ListObject';
  }

  /// Returns a deserializer lambda for a type argument (used when passing to union fromJson/fromYaml).
  String _getDeserializerLambda(PropertyInfo argProp, {required bool isJson}) {
    if (argProp.type == SchemaType.array && argProp.referencedSchema != null) {
      final listClass = _getListClassName(argProp.referencedSchema!.title, argProp.uniqueItems);
      final fromMethod = isJson ? 'fromJson' : 'fromYaml';
      return '(String s) => $listClass.$fromMethod(s)';
    }
    final concreteType = _getDartType(argProp);
    final fromMethod = isJson ? 'fromJson' : 'fromYaml';
    return '(String s) => $concreteType.$fromMethod(s)';
  }

  /// Gets the Dart type name for a property.
  String _getDartType(PropertyInfo property) {
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
        if (property.typeArguments != null && property.typeArguments!.isNotEmpty) {
          final typeArgs = property.typeArguments!.values.map((argProp) => _getDartType(argProp)).join(', ');
          return '$baseType<$typeArgs>';
        }
        return baseType;
      case SchemaType.array:
        if (property.referencedSchema != null) {
          return _getListClassName(property.referencedSchema!.title, property.uniqueItems);
        }
        return property.uniqueItems ? 'SetObject<TreeObject>' : 'ListObject<TreeObject>';
      case SchemaType.union:
        // Use the referenced schema's generated union type
        if (property.referencedSchema != null) {
          return '${property.referencedSchema!.title}Object';
        }
        return 'UnionObject2<TreeObject, TreeObject>';
    }
  }
}
