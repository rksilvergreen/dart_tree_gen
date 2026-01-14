import '../schema/schema_info.dart';
import '../validation/validation_code_generator.dart';

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
  final ValidationCodeGenerator validationGenerator;

  TreeObjectClassGenerator(this.schema)
      : validationGenerator = ValidationCodeGenerator();

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

  /// Generates the complete TreeObject class code.
  String generate() {
    // Check if this is a union schema
    if (schema.isUnion) {
      return _generateUnion();
    }

    final buffer = StringBuffer();

    // Class declaration
    buffer.writeln('/// Generated TreeObject class for ${schema.title}');
    buffer.writeln('class ${schema.title}Object extends TreeObject {');

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

  /// Generates a concrete union class.
  String _generateUnion() {
    final unionInfo = schema.unionInfo!;
    final types = unionInfo.types;
    final typeParams = unionInfo.typeParameters;
    final totalTypes = types.length + typeParams.length;
    
    if (totalTypes < 2 || totalTypes > 4) {
      throw Exception('Union must have 2-4 total types, got $totalTypes');
    }
    
    final buffer = StringBuffer();
    
    // Class declaration with type parameters
    buffer.writeln('/// Generated union class for ${schema.title}');
    buffer.write('class ${schema.title}Object');
    if (typeParams.isNotEmpty) {
      buffer.write('<');
      buffer.write(typeParams.keys.map((t) => '$t extends TreeObject').join(', '));
      buffer.write('>');
    }
    buffer.writeln(' extends TreeObject {');
    
    // Generate nullable fields for concrete types
    for (final type in types) {
      final constructorName = _getConstructorName(type);
      final dartType = _getUnionDartType(type);
      buffer.writeln('  final $dartType? _$constructorName;');
    }
    
    // Generate nullable fields for type parameters
    for (final entry in typeParams.entries) {
      final typeParam = entry.key;
      final fieldName = entry.value;
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
      for (final fieldName in typeParams.values) {
        buffer.write(', _$fieldName = null');
      }
      buffer.writeln(';');
      buffer.writeln();
    }
    
    // Generate named constructors for type parameters
    for (final entry in typeParams.entries) {
      final typeParam = entry.key;
      final fieldName = entry.value;
      buffer.writeln('  /// Creates a ${schema.title} with a $typeParam value.');
      buffer.write('  ${schema.title}Object.$fieldName($typeParam $fieldName)');
      buffer.write(' : _$fieldName = $fieldName');
      
      // Set concrete type fields to null
      for (final type in types) {
        final constructorName = _getConstructorName(type);
        buffer.write(', _$constructorName = null');
      }
      
      // Set other type parameter fields to null
      for (final otherFieldName in typeParams.values) {
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
    for (final entry in typeParams.entries) {
      final fieldName = entry.value;
      final capitalizedName = fieldName[0].toUpperCase() + fieldName.substring(1);
      buffer.writeln('  /// Returns true if this union contains a ${entry.key}.');
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
    for (final entry in typeParams.entries) {
      final typeParam = entry.key;
      final fieldName = entry.value;
      final capitalizedName = fieldName[0].toUpperCase() + fieldName.substring(1);
      buffer.writeln('  /// Gets the value as $typeParam, or null if it\'s not that type.');
      buffer.writeln('  $typeParam? get as$capitalizedName => _$fieldName;');
      buffer.writeln();
    }
    
    // Generate toJson
    buffer.writeln('  @override');
    buffer.writeln('  String toJson() {');
    for (final type in types) {
      final constructorName = _getConstructorName(type);
      buffer.writeln('    if (_$constructorName != null) return _$constructorName.toJson();');
    }
    for (final fieldName in typeParams.values) {
      buffer.writeln('    if (_$fieldName != null) return _$fieldName.toJson();');
    }
    buffer.writeln('    throw StateError(\'Union has no value set\');');
    buffer.writeln('  }');
    buffer.writeln();
    
    // Generate toYaml
    buffer.writeln('  @override');
    buffer.writeln('  String toYaml() {');
    for (final type in types) {
      final constructorName = _getConstructorName(type);
      buffer.writeln('    if (_$constructorName != null) return _$constructorName.toYaml();');
    }
    for (final fieldName in typeParams.values) {
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
      buffer.write(typeParams.keys.join(', '));
      buffer.write('>');
    }
    buffer.write(' fromJson');
    if (typeParams.isNotEmpty) {
      buffer.write('<');
      buffer.write(typeParams.keys.map((t) => '$t extends TreeObject').join(', '));
      buffer.write('>');
    }
    buffer.writeln('(String json) {');
    
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
    for (final entry in typeParams.entries) {
      final typeParam = entry.key;
      final fieldName = entry.value;
      
      if (attemptIndex > 0) buffer.writeln('    } catch (_) {');
      buffer.writeln('    try {');
      buffer.writeln('      return ${schema.title}Object.$fieldName(deserializers.fromJson<$typeParam>(json));');
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
      buffer.write(typeParams.keys.join(', '));
      buffer.write('>');
    }
    buffer.write(' fromYaml');
    if (typeParams.isNotEmpty) {
      buffer.write('<');
      buffer.write(typeParams.keys.map((t) => '$t extends TreeObject').join(', '));
      buffer.write('>');
    }
    buffer.writeln('(String yaml) {');
    
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
    for (final entry in typeParams.entries) {
      final typeParam = entry.key;
      final fieldName = entry.value;
      
      if (attemptIndex > 0) buffer.writeln('    } catch (_) {');
      buffer.writeln('    try {');
      buffer.writeln('      return ${schema.title}Object.$fieldName(deserializers.fromYaml<$typeParam>(yaml));');
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
    buffer.writeln('  @override');
    buffer.write('  String toString() => \'${schema.title}Object(');
    for (int i = 0; i < types.length; i++) {
      final constructorName = _getConstructorName(types[i]);
      if (i > 0) buffer.write(', ');
      buffer.write('\$_$constructorName');
    }
    for (int i = 0; i < typeParams.length; i++) {
      final fieldName = typeParams.values.elementAt(i);
      buffer.write(', \$_$fieldName');
    }
    buffer.writeln(')\';');
    buffer.writeln();
    
    // Generate operator==
    buffer.writeln('  @override');
    buffer.writeln('  bool operator ==(Object other) =>');
    buffer.writeln('      identical(this, other) ||');
    buffer.write('      other is ${schema.title}Object');
    if (typeParams.isNotEmpty) {
      buffer.write('<');
      buffer.write(typeParams.keys.join(', '));
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
    
    for (int i = 0; i < typeParams.length; i++) {
      final fieldName = typeParams.values.elementAt(i);
      buffer.writeln();
      buffer.write('      _$fieldName == other._$fieldName');
      if (i < typeParams.length - 1) buffer.write(' &&');
    }
    buffer.writeln(';');
    buffer.writeln();
    
    // Generate hashCode
    buffer.writeln('  @override');
    buffer.write('  int get hashCode => Object.hash(');
    final allFields = [...types.map((t) => '_${_getConstructorName(t)}'), ...typeParams.values.map((f) => '_$f')];
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

  /// Generates the constructor with validation.
  void _generateConstructor(StringBuffer buffer) {
    buffer.writeln('  ${schema.title}Object({');

    // Constructor parameters
    for (final property in schema.properties.values) {
      final prefix = property.nullable ? '' : 'required ';
      buffer.writeln('    ${prefix}this.${property.name},');
    }

    buffer.writeln('  }) {');

    // Validation code in constructor body
    for (final property in schema.properties.values) {
      final validation = validationGenerator.generateValidation(
        property.name,
        property.type,
        property.constraints,
        isNullable: property.nullable,
      );

      if (validation.isNotEmpty) {
        buffer.writeln('    $validation');
      }
    }

    buffer.writeln('  }');
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
      buffer.writeln('    return \'{"$escapedName": \' + $propAccess.toJson() + \'}\';');
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
        buffer.writeln('      buffer.write(\'"$escapedName": \');');
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
        buffer.writeln('    buffer.write(\'"$escapedName": \');');
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
      buffer.writeln('    return \'$escapedName: \' + $propAccess.toYaml();');
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
        buffer.writeln('      buffer.write(\'$escapedName: \');');
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
        buffer.writeln('    buffer.write(\'$escapedName: \');');
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
    buffer.writeln('  static ${schema.title}Object fromJson(String json) {');
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
        buffer.writeln('          allowedKeys: const [${schema.allowed!.map((k) => '\'$k\'').join(', ')}],');
      }
      
      if (hasRequired) {
        buffer.writeln('          requiredKeys: const [${schema.required.map((k) => '\'$k\'').join(', ')}],');
      }
      
      if (hasNullable) {
        // disallowNullValues should be properties that are NOT in the nullable list
        final disallowNull = schema.properties.keys
            .where((key) => !schema.nullable!.contains(key))
            .toList();
        if (disallowNull.isNotEmpty) {
          buffer.writeln('          disallowNullValues: const [${disallowNull.map((k) => '\'$k\'').join(', ')}],');
        }
      }
      
      buffer.writeln('        );');
    }

    // Generate the object construction
    buffer.writeln('        final val = ${schema.title}Object(');

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
    buffer.writeln('  static ${schema.title}Object fromYaml(String yaml) {');
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
        buffer.writeln('          allowedKeys: const [${schema.allowed!.map((k) => '\'$k\'').join(', ')}],');
      }
      
      if (hasRequired) {
        buffer.writeln('          requiredKeys: const [${schema.required.map((k) => '\'$k\'').join(', ')}],');
      }
      
      if (hasNullable) {
        // disallowNullValues should be properties that are NOT in the nullable list
        final disallowNull = schema.properties.keys
            .where((key) => !schema.nullable!.contains(key))
            .toList();
        if (disallowNull.isNotEmpty) {
          buffer.writeln('          disallowNullValues: const [${disallowNull.map((k) => '\'$k\'').join(', ')}],');
        }
      }
      
      buffer.writeln('        );');
    }

    // Generate the object construction
    buffer.writeln('        final val = ${schema.title}Object(');

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
    final convertLogic = isJson 
        ? _getFromJsonConvertLogic(property) 
        : _getFromYamlConvertLogic(property);
    
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
        return '${property.referencedSchema!.title}Object.fromJson($varName as String)';
      case SchemaType.array:
        if (property.referencedSchema != null) {
          final itemType = property.referencedSchema!.title;
          final listClass = '${property.name.capitalize()}ListObject';
          return '$listClass(extractJsonArrayElements($varName as String).map((item) => ${itemType}Object.fromJson(item)).toList())';
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
        return '${property.referencedSchema!.title}Object.fromYaml($varName as String)';
      case SchemaType.array:
        if (property.referencedSchema != null) {
          final itemType = property.referencedSchema!.title;
          final listClass = '${property.name.capitalize()}ListObject';
          return '$listClass(extractYamlSequenceElements($varName as String).map((item) => ${itemType}Object.fromYaml(item)).toList())';
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
        return '${property.referencedSchema!.title}Object';
      case SchemaType.array:
        if (property.referencedSchema != null) {
          return '${property.name.capitalize()}ListObject';
        }
        return 'ListObject<TreeObject>';
      case SchemaType.union:
        // Use the referenced schema's generated union type
        if (property.referencedSchema != null) {
          return '${property.referencedSchema!.title}Object';
        }
        return 'UnionObject2<TreeObject, TreeObject>';
    }
  }

}

