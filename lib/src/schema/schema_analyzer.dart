import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'schema_info.dart';

/// Analyzer that extracts schema information from @jsonSchema annotated variables.
class SchemaAnalyzer {
  final BuildStep buildStep;
  final LibraryReader library;

  /// All discovered schemas, keyed by variable name
  final Map<String, SchemaInfo> _schemas = {};

  /// Schemas that were directly annotated
  final Set<String> _annotatedSchemas = {};

  /// Maps DartObject hash codes to schema names (to detect variable references)
  final Map<int, String> _objectToSchemaName = {};

  SchemaAnalyzer(this.buildStep, this.library);

  /// Analyzes all @schema annotated variables in the library.
  ///
  /// Returns a map of schema name to SchemaInfo.
  /// Throws if any annotated variable is not a $Object.
  Future<Map<String, SchemaInfo>> analyze() async {
    // Find all @schema annotated variables
    final schemaChecker = TypeChecker.fromUrl('package:dart_tree/src/schema/schema.dart#_Schema');

    // Use LibraryReader's annotatedWith to get all annotated elements
    for (final annotatedElement in library.annotatedWith(schemaChecker)) {
      final element = annotatedElement.element;

      // Check if it's a top-level variable
      if (element is! TopLevelVariableElement) {
        throw InvalidGenerationSourceError(
          '@schema can only be applied to top-level const variables',
          element: element,
        );
      }

      final name = element.name;
      if (name == null) {
        throw InvalidGenerationSourceError('@schema variable must have a name', element: element);
      }

      _annotatedSchemas.add(name);

      // Get the constant value
      final constValue = element.computeConstantValue();
      if (constValue == null) {
        throw InvalidGenerationSourceError(
          'Variable $name annotated with @schema must be a const value',
          element: element,
        );
      }

      // Track the DartObject for this schema
      _objectToSchemaName[constValue.hashCode] = name;

      // Analyze the schema
      await _analyzeSchema(name, constValue, element, isAnnotated: true);
    }

    return Map.unmodifiable(_schemas);
  }

  /// Analyzes a single schema constant value.
  Future<SchemaInfo> _analyzeSchema(String name, DartObject value, Element element, {required bool isAnnotated}) async {
    // Check if already analyzed
    if (_schemas.containsKey(name)) {
      return _schemas[name]!;
    }

    final type = value.type;
    if (type == null) {
      throw InvalidGenerationSourceError('Could not determine type of schema variable $name', element: element);
    }

    // In analyzer 9.x, we can get the name from element2
    final typeElement = type.element;
    final className = typeElement?.name;

    if (className == null) {
      throw InvalidGenerationSourceError('Could not determine class name for schema variable $name', element: element);
    }

    // Handle $Object
    if (className == '\$Object') {
      return await _analyzeObject(name, value, element, isAnnotated: isAnnotated);
    }

    // Handle $Union
    if (className == '\$Union') {
      return await _analyzeUnion(name, value, element, isAnnotated: isAnnotated);
    }

    // If annotated but not a $Object or $Union, throw error
    if (isAnnotated) {
      throw InvalidGenerationSourceError(
        '@schema can only annotate variables of type \$Object or \$Union. '
        'Found: $className',
        element: element,
      );
    }

    throw InvalidGenerationSourceError('Unsupported schema type: $className', element: element);
  }

  /// Analyzes a $Object schema.
  Future<SchemaInfo> _analyzeObject(String name, DartObject value, Element element, {required bool isAnnotated}) async {
    // Extract title - Note: title is in the parent $Schema class, so we need to get it from the superclass
    // DartObject.getField() doesn't automatically look at superclass fields
    final titleField = _getFieldFromHierarchy(value, 'title');
    final title = titleField?.toStringValue();

    if (title == null || title.isEmpty) {
      throw InvalidGenerationSourceError(
        '\$Object schema "$name" must have a non-empty title parameter',
        element: element,
      );
    }

    // Extract required list
    final requiredField = value.getField('required');
    final required = <String>[];
    if (requiredField != null && !requiredField.isNull) {
      final requiredList = requiredField.toListValue();
      if (requiredList != null) {
        for (final item in requiredList) {
          final str = item.toStringValue();
          if (str != null) required.add(str);
        }
      }
    }

    // Extract allowed list
    final allowedField = value.getField('allowed');
    final allowed = <String>[];
    if (allowedField != null && !allowedField.isNull) {
      final allowedList = allowedField.toListValue();
      if (allowedList != null) {
        for (final item in allowedList) {
          final str = item.toStringValue();
          if (str != null) allowed.add(str);
        }
      }
    }

    // Extract nullable list
    final nullableField = value.getField('nullable');
    final nullable = <String>[];
    if (nullableField != null && !nullableField.isNull) {
      final nullableList = nullableField.toListValue();
      if (nullableList != null) {
        for (final item in nullableList) {
          final str = item.toStringValue();
          if (str != null) nullable.add(str);
        }
      }
    }

    // Extract properties
    final propertiesField = value.getField('properties');
    final properties = <String, PropertyInfo>{};

    if (propertiesField != null && !propertiesField.isNull) {
      final propertiesMap = propertiesField.toMapValue();
      if (propertiesMap != null) {
        for (final entry in propertiesMap.entries) {
          final propertyName = entry.key?.toStringValue();
          final propertyValue = entry.value;

          if (propertyName == null || propertyValue == null) continue;

          final propertyInfo = await _analyzeProperty(
            propertyName,
            propertyValue,
            element,
            isRequired: required.contains(propertyName),
          );

          properties[propertyName] = propertyInfo;
        }
      }
    }

    // Extract min/max properties
    final minPropertiesField = value.getField('minProperties');
    final maxPropertiesField = value.getField('maxProperties');

    final schemaInfo = SchemaInfo(
      name: name,
      title: title,
      isAnnotated: isAnnotated,
      properties: properties,
      required: required,
      allowed: allowed.isNotEmpty ? allowed : null,
      nullable: nullable.isNotEmpty ? nullable : null,
      minProperties: minPropertiesField?.toIntValue(),
      maxProperties: maxPropertiesField?.toIntValue(),
    );

    _schemas[name] = schemaInfo;
    return schemaInfo;
  }

  /// Analyzes a $Union schema.
  Future<SchemaInfo> _analyzeUnion(String name, DartObject value, Element element, {required bool isAnnotated}) async {
    // Extract title
    final titleField = _getFieldFromHierarchy(value, 'title');
    final title = titleField?.toStringValue();

    if (title == null || title.isEmpty) {
      throw InvalidGenerationSourceError(
        '\$Union schema "$name" must have a non-empty title parameter',
        element: element,
      );
    }

    // Extract types set
    final typesField = value.getField('types');
    final unionTypes = <SchemaInfo>[];

    if (typesField != null && !typesField.isNull) {
      final typesSet = typesField.toSetValue();
      if (typesSet != null) {
        for (final typeObj in typesSet) {
          final typeName = typeObj.type?.element?.name;

          // Analyze each type in the union
          if (typeName == '\$String') {
            unionTypes.add(SchemaInfo(name: '_String', title: 'String', isAnnotated: false, properties: {}));
          } else if (typeName == '\$Integer') {
            unionTypes.add(SchemaInfo(name: '_Integer', title: 'Integer', isAnnotated: false, properties: {}));
          } else if (typeName == '\$Number' || typeName == '\$Double') {
            unionTypes.add(SchemaInfo(name: '_Number', title: 'Number', isAnnotated: false, properties: {}));
          } else if (typeName == '\$Boolean') {
            unionTypes.add(SchemaInfo(name: '_Boolean', title: 'Boolean', isAnnotated: false, properties: {}));
          } else if (typeName == '\$Object') {
            // Check if this is a reference to an existing schema
            final existingSchemaName = _objectToSchemaName[typeObj.hashCode];
            if (existingSchemaName != null) {
              final existing = _schemas[existingSchemaName];
              if (existing != null) {
                unionTypes.add(existing);
              }
            } else {
              // Inline object in union
              final inlineName = '_Inline${title}Type${unionTypes.length + 1}';
              final inlineSchema = await _analyzeObject(inlineName, typeObj, element, isAnnotated: false);
              unionTypes.add(inlineSchema);
            }
          }
        }
      }
    }

    // Extract type parameters
    final typeParamsField = value.getField('typeParameters');
    final typeParameters = <String, String>{};
    
    if (typeParamsField != null && !typeParamsField.isNull) {
      final paramsMap = typeParamsField.toMapValue();
      if (paramsMap != null) {
        for (final entry in paramsMap.entries) {
          final key = entry.key?.toStringValue();
          final value = entry.value?.toStringValue();
          if (key != null && value != null) {
            typeParameters[key] = value;
          }
        }
      }
    }

    final totalTypes = unionTypes.length + typeParameters.length;
    if (totalTypes < 2 || totalTypes > 4) {
      throw InvalidGenerationSourceError(
        '\$Union "$name" must have between 2 and 4 total types (concrete + type parameters), got $totalTypes',
        element: element,
      );
    }

    final unionInfo = UnionInfo(title: title, types: unionTypes, typeParameters: typeParameters);

    final schemaInfo = SchemaInfo(
      name: name,
      title: title,
      isAnnotated: isAnnotated,
      properties: {},
      unionInfo: unionInfo,
    );

    _schemas[name] = schemaInfo;
    return schemaInfo;
  }

  /// Analyzes a property schema.
  Future<PropertyInfo> _analyzeProperty(
    String propertyName,
    DartObject value,
    Element element, {
    required bool isRequired,
  }) async {
    final type = value.type;
    if (type == null) {
      throw InvalidGenerationSourceError('Could not determine type of property $propertyName', element: element);
    }

    final className = type.element?.name;

    // Determine schema type and constraints
    SchemaType schemaType;
    ValidationConstraints constraints;
    SchemaInfo? referencedSchema;

    switch (className) {
      case '\$String':
        schemaType = SchemaType.string;
        constraints = _extractStringConstraints(value);
        break;

      case '\$Integer':
        schemaType = SchemaType.integer;
        constraints = _extractNumberConstraints(value);
        break;

      case '\$Number':
        schemaType = SchemaType.number;
        constraints = _extractNumberConstraints(value);
        break;

      case '\$Boolean':
        schemaType = SchemaType.boolean;
        constraints = const ValidationConstraints();
        break;

      case '\$Array':
        schemaType = SchemaType.array;
        constraints = _extractArrayConstraints(value);

        // Get the items schema
        final itemsField = value.getField('items');
        if (itemsField != null && !itemsField.isNull) {
          final itemsType = itemsField.type?.element?.name;
          if (itemsType == '\$Object') {
            // Check if this is a reference to an existing schema variable
            final existingSchemaName = _objectToSchemaName[itemsField.hashCode];
            if (existingSchemaName != null) {
              referencedSchema = _schemas[existingSchemaName];
            } else {
              // Inline object in array
              final inlineName = '_Inline${propertyName.capitalize()}Item';
              referencedSchema = await _analyzeObject(inlineName, itemsField, element, isAnnotated: false);
            }
          }
        }
        break;

      case '\$Object':
        schemaType = SchemaType.object;
        constraints = const ValidationConstraints();

        // Check if this is a reference to an existing schema variable
        final existingSchemaName = _objectToSchemaName[value.hashCode];
        if (existingSchemaName != null) {
          // This is a reference to an existing schema
          referencedSchema = _schemas[existingSchemaName];
          if (referencedSchema == null) {
            throw InvalidGenerationSourceError(
              'Referenced schema $existingSchemaName not found for property $propertyName',
              element: element,
            );
          }
        } else {
          // This is an inline $Object - need to generate it
          final inlineName = '_Inline${propertyName.capitalize()}';
          referencedSchema = await _analyzeObject(inlineName, value, element, isAnnotated: false);
        }
        break;

      case '\$Union':
        schemaType = SchemaType.union;
        constraints = const ValidationConstraints();

        // Analyze the union inline
        final inlineName = '_Inline${propertyName.capitalize()}Union';
        final unionSchema = await _analyzeUnion(inlineName, value, element, isAnnotated: false);
        referencedSchema = unionSchema;
        break;

      default:
        throw InvalidGenerationSourceError(
          'Unsupported property type: $className for property $propertyName',
          element: element,
        );
    }

    return PropertyInfo(
      name: propertyName,
      type: schemaType,
      nullable: !isRequired,
      referencedSchema: referencedSchema,
      constraints: constraints,
    );
  }

  /// Extracts string validation constraints.
  ValidationConstraints _extractStringConstraints(DartObject value) {
    return ValidationConstraints(
      pattern: value.getField('pattern')?.toStringValue(),
      minLength: value.getField('minLength')?.toIntValue(),
      maxLength: value.getField('maxLength')?.toIntValue(),
      format: value.getField('format')?.toStringValue(),
    );
  }

  /// Extracts number validation constraints.
  ValidationConstraints _extractNumberConstraints(DartObject value) {
    return ValidationConstraints(
      minimum: value.getField('minimum')?.toDoubleValue() ?? value.getField('minimum')?.toIntValue()?.toDouble(),
      exclusiveMinimum:
          value.getField('exclusiveMinimum')?.toDoubleValue() ??
          value.getField('exclusiveMinimum')?.toIntValue()?.toDouble(),
      maximum: value.getField('maximum')?.toDoubleValue() ?? value.getField('maximum')?.toIntValue()?.toDouble(),
      exclusiveMaximum:
          value.getField('exclusiveMaximum')?.toDoubleValue() ??
          value.getField('exclusiveMaximum')?.toIntValue()?.toDouble(),
      multipleOf:
          value.getField('multipleOf')?.toDoubleValue() ?? value.getField('multipleOf')?.toIntValue()?.toDouble(),
    );
  }

  /// Extracts array validation constraints.
  ValidationConstraints _extractArrayConstraints(DartObject value) {
    return ValidationConstraints(
      minItems: value.getField('minItems')?.toIntValue(),
      maxItems: value.getField('maxItems')?.toIntValue(),
      uniqueItems: value.getField('uniqueItems')?.toBoolValue(),
    );
  }

  /// Helper method to get a field from a DartObject, checking parent classes if needed.
  DartObject? _getFieldFromHierarchy(DartObject object, String fieldName) {
    // First try to get the field directly
    final field = object.getField(fieldName);
    if (field != null) return field;

    // If not found, try to get it from the superclass
    // In DartObject, superclass fields are accessible through getField('(super)')
    var superObject = object.getField('(super)');
    while (superObject != null && !superObject.isNull) {
      final field = superObject.getField(fieldName);
      if (field != null) return field;
      superObject = superObject.getField('(super)');
    }

    return null;
  }
}

/// Extension to capitalize strings.
extension on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}
