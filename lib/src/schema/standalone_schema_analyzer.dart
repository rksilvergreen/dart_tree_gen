import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';

import 'schema_info.dart';

/// Standalone version of SchemaAnalyzer that doesn't require build_runner.
///
/// Analyzes @tree annotated $Tree definitions and extracts schema information.
class StandaloneSchemaAnalyzer {
  final ResolvedLibraryResult libraryResult;

  /// All discovered schemas, keyed by schema name (title)
  final Map<String, SchemaInfo> _schemas = {};

  /// Maps DartObject identity to already-analyzed SchemaInfo
  final Map<int, SchemaInfo> _objectToSchema = {};

  StandaloneSchemaAnalyzer(this.libraryResult);

  /// Analyzes all @tree annotated variables in the library.
  Future<Map<String, SchemaInfo>> analyze() async {
    // Find all variables with @tree annotation using AST
    final annotatedVariableNames = <String>{};

    for (final unitResult in libraryResult.units) {
      final unit = unitResult.unit;

      for (final declaration in unit.declarations) {
        if (declaration is! TopLevelVariableDeclaration) continue;

        // Check for @tree annotation
        final hasTree = declaration.metadata.any((annotation) {
          final name = annotation.name;
          if (name is SimpleIdentifier) {
            return name.name == 'tree';
          } else if (name is PrefixedIdentifier) {
            return name.identifier.name == 'tree';
          }
          return false;
        });

        if (hasTree) {
          // Collect variable names
          for (final variable in declaration.variables.variables) {
            annotatedVariableNames.add(variable.name.lexeme);
          }
        }
      }
    }

    // Process each @tree annotated variable
    for (final variableName in annotatedVariableNames) {
      TopLevelVariableElement? element;

      // Search through all compilation units
      for (final unitResult in libraryResult.units) {
        final unitElement = unitResult.libraryFragment;

        // Find the variable in this unit
        for (final topLevelVariable in unitElement.topLevelVariables) {
          if (topLevelVariable.name == variableName) {
            element = topLevelVariable.element;
            break;
          }
        }

        if (element != null) break;
      }

      if (element == null) {
        throw Exception('Could not find element for variable $variableName');
      }

      // Get the constant value
      final constValue = element.computeConstantValue();
      if (constValue == null) {
        throw Exception('Variable $variableName annotated with @tree must be a const value');
      }

      // Verify it's a $Tree
      final typeName = constValue.type?.element?.name;
      if (typeName != '\$Tree') {
        throw Exception('@tree annotation must be on a \$Tree const, found: $typeName');
      }

      // Analyze the $Tree
      await _analyzeTree(constValue);
    }

    return Map.unmodifiable(_schemas);
  }

  /// Analyzes a $Tree constant and extracts all schemas.
  Future<void> _analyzeTree(DartObject treeValue) async {
    // Extract name
    final nameField = treeValue.getField('name');
    final treeName = nameField?.toStringValue();
    if (treeName == null || treeName.isEmpty) {
      throw Exception('\$Tree must have a non-empty name parameter');
    }

    // Extract schemas list
    final schemasField = treeValue.getField('schemas');
    if (schemasField == null || schemasField.isNull) {
      throw Exception('\$Tree must have a schemas list');
    }

    final schemasList = schemasField.toListValue();
    if (schemasList == null || schemasList.isEmpty) {
      throw Exception('\$Tree schemas list cannot be empty');
    }

    // First pass: collect all schemas by name for cross-referencing
    for (final schemaObj in schemasList) {
      final typeName = schemaObj.type?.element?.name;

      if (typeName == '\$Schema') {
        final nameField = schemaObj.getField('name');
        final name = nameField?.toStringValue();
        if (name != null && name.isNotEmpty) {
          _objectToSchema[schemaObj.hashCode] = SchemaInfo(name: name, title: name, isAnnotated: true, properties: {});
        }
      } else if (typeName == '\$Union') {
        final nameField = schemaObj.getField('name');
        final name = nameField?.toStringValue();
        if (name != null && name.isNotEmpty) {
          _objectToSchema[schemaObj.hashCode] = SchemaInfo(name: name, title: name, isAnnotated: true, properties: {});
        }
      }
    }

    // Second pass: fully analyze each schema
    for (final schemaObj in schemasList) {
      await _analyzeSchemaOrUnion(schemaObj);
    }
  }

  /// Analyzes a _$Schema (either $Schema or $Union).
  Future<SchemaInfo> _analyzeSchemaOrUnion(DartObject value) async {
    final typeName = value.type?.element?.name;

    if (typeName == '\$Schema') {
      return await _analyzeSchema(value);
    } else if (typeName == '\$Union') {
      return await _analyzeUnion(value);
    }

    throw Exception('Expected \$Schema or \$Union, got: $typeName');
  }

  /// Analyzes a $Schema object.
  Future<SchemaInfo> _analyzeSchema(DartObject value) async {
    // Check if already fully analyzed
    final existing = _schemas.values
        .where((s) => _objectToSchema[value.hashCode]?.title == s.title && s.properties.isNotEmpty)
        .firstOrNull;
    if (existing != null) return existing;

    // Extract name
    final nameField = value.getField('name');
    final name = nameField?.toStringValue();
    if (name == null || name.isEmpty) {
      throw Exception('\$Schema must have a non-empty name parameter');
    }

    // Extract type parameters
    final typeParamsField = value.getField('typeParameters');
    final typeParameters = <String>{};
    if (typeParamsField != null && !typeParamsField.isNull) {
      final paramsSet = typeParamsField.toSetValue();
      if (paramsSet != null) {
        for (final param in paramsSet) {
          final paramStr = param.toStringValue();
          if (paramStr != null) typeParameters.add(paramStr);
        }
      }
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
            typeParameters,
            isRequired: required.contains(propertyName),
          );

          properties[propertyName] = propertyInfo;
        }
      }
    }

    final schemaInfo = SchemaInfo(
      name: name,
      title: name,
      isAnnotated: true,
      typeParameters: typeParameters,
      properties: properties,
      required: required,
      allowed: allowed.isNotEmpty ? allowed : null,
      nullable: nullable.isNotEmpty ? nullable : null,
    );

    _schemas[name] = schemaInfo;
    _objectToSchema[value.hashCode] = schemaInfo;
    return schemaInfo;
  }

  /// Analyzes a $Union schema.
  Future<SchemaInfo> _analyzeUnion(DartObject value) async {
    // Check if already fully analyzed
    final existing = _schemas.values
        .where((s) => _objectToSchema[value.hashCode]?.title == s.title && s.unionInfo != null)
        .firstOrNull;
    if (existing != null) return existing;

    // Extract name
    final nameField = value.getField('name');
    final name = nameField?.toStringValue();
    if (name == null || name.isEmpty) {
      throw Exception('\$Union must have a non-empty name parameter');
    }

    // Extract type parameters (now a Set<String>)
    final typeParamsField = value.getField('typeParameters');
    final typeParameters = <String>{};
    if (typeParamsField != null && !typeParamsField.isNull) {
      final paramsSet = typeParamsField.toSetValue();
      if (paramsSet != null) {
        for (final param in paramsSet) {
          final paramStr = param.toStringValue();
          if (paramStr != null) typeParameters.add(paramStr);
        }
      }
    }

    // Extract types set
    final typesField = value.getField('types');
    final unionTypes = <SchemaInfo>[];

    if (typesField != null && !typesField.isNull) {
      final typesSet = typesField.toSetValue();
      if (typesSet != null) {
        for (final typeObj in typesSet) {
          final typeName = typeObj.type?.element?.name;

          if (typeName == '\$Object') {
            // Get the referenced schema
            final schemaRef = typeObj.getField('schema');
            if (schemaRef != null && !schemaRef.isNull) {
              final refSchema = await _analyzeSchemaOrUnion(schemaRef);
              unionTypes.add(refSchema);
            }
          } else if (typeName == '\$String') {
            unionTypes.add(SchemaInfo(name: '_String', title: 'String', isAnnotated: false, properties: {}));
          } else if (typeName == '\$Integer') {
            unionTypes.add(SchemaInfo(name: '_Integer', title: 'Integer', isAnnotated: false, properties: {}));
          } else if (typeName == '\$Double') {
            unionTypes.add(SchemaInfo(name: '_Number', title: 'Number', isAnnotated: false, properties: {}));
          } else if (typeName == '\$Boolean') {
            unionTypes.add(SchemaInfo(name: '_Boolean', title: 'Boolean', isAnnotated: false, properties: {}));
          }
        }
      }
    }

    final totalTypes = unionTypes.length + typeParameters.length;
    if (totalTypes < 2) {
      throw Exception('\$Union "$name" must have at least 2 total types (concrete + type parameters), got $totalTypes');
    }

    final unionInfo = UnionInfo(title: name, types: unionTypes, typeParameters: typeParameters);

    final schemaInfo = SchemaInfo(
      name: name,
      title: name,
      isAnnotated: true,
      typeParameters: typeParameters,
      properties: {},
      unionInfo: unionInfo,
    );

    _schemas[name] = schemaInfo;
    _objectToSchema[value.hashCode] = schemaInfo;
    return schemaInfo;
  }

  /// Analyzes a property schema.
  Future<PropertyInfo> _analyzeProperty(
    String propertyName,
    DartObject value,
    Set<String> schemaTypeParameters, {
    required bool isRequired,
  }) async {
    final typeName = value.type?.element?.name;

    switch (typeName) {
      case '\$String':
        return PropertyInfo(name: propertyName, type: SchemaType.string, nullable: !isRequired);

      case '\$Integer':
        return PropertyInfo(name: propertyName, type: SchemaType.integer, nullable: !isRequired);

      case '\$Double':
        return PropertyInfo(name: propertyName, type: SchemaType.number, nullable: !isRequired);

      case '\$Boolean':
        return PropertyInfo(name: propertyName, type: SchemaType.boolean, nullable: !isRequired);

      case '\$TypeParameter':
        final paramNameField = value.getField('name');
        final paramName = paramNameField?.toStringValue();

        if (paramName == null) {
          throw Exception('$TypeParameter must have a name');
        }

        // Validate that this type parameter is defined in the schema
        if (!schemaTypeParameters.contains(paramName)) {
          throw Exception(
            'Property "$propertyName" references type parameter "$paramName" '
            'which is not defined in the schema. Available type parameters: $schemaTypeParameters',
          );
        }

        return PropertyInfo(
          name: propertyName,
          type: SchemaType.typeParameter,
          nullable: !isRequired,
          typeParameterName: paramName,
        );

      case '\$Array':
        final uniqueItemsField = value.getField('uniqueItems');
        final uniqueItems = uniqueItemsField?.toBoolValue() ?? false;

        SchemaInfo? itemSchema;
        final itemsField = value.getField('items');
        if (itemsField != null && !itemsField.isNull) {
          final itemsTypeName = itemsField.type?.element?.name;
          if (itemsTypeName == '\$Object') {
            // Get the referenced schema
            final schemaRef = itemsField.getField('schema');
            if (schemaRef != null && !schemaRef.isNull) {
              itemSchema = await _analyzeSchemaOrUnion(schemaRef);
            }
          }
        }

        return PropertyInfo(
          name: propertyName,
          type: SchemaType.array,
          nullable: !isRequired,
          referencedSchema: itemSchema,
          uniqueItems: uniqueItems,
        );

      case '\$Object':
        // Get the referenced schema
        final schemaRef = value.getField('schema');
        if (schemaRef == null || schemaRef.isNull) {
          throw Exception('\$Object property "$propertyName" must reference a schema');
        }

        final refSchema = await _analyzeSchemaOrUnion(schemaRef);

        // Extract and validate type parameters
        final typeArgsField = value.getField('typeParameters');
        Map<String, PropertyInfo>? typeArguments;

        if (typeArgsField != null && !typeArgsField.isNull) {
          final argsMap = typeArgsField.toMapValue();
          if (argsMap != null && argsMap.isNotEmpty) {
            typeArguments = {};
            for (final entry in argsMap.entries) {
              final key = entry.key?.toStringValue();
              final argValue = entry.value;

              if (key == null || argValue == null) continue;

              // Validate this type param exists in the referenced schema
              if (!refSchema.typeParameters.contains(key)) {
                throw Exception(
                  'Property "$propertyName" provides type argument "$key" '
                  'but schema "${refSchema.title}" does not define this type parameter. '
                  'Available type parameters: ${refSchema.typeParameters}',
                );
              }

              // Analyze the type argument
              final argInfo = await _analyzeProperty('_typeArg_$key', argValue, schemaTypeParameters, isRequired: true);
              typeArguments[key] = argInfo;
            }
          }
        }

        // Validate all required type parameters are provided
        for (final requiredParam in refSchema.typeParameters) {
          if (typeArguments == null || !typeArguments.containsKey(requiredParam)) {
            throw Exception(
              'Property "$propertyName" references schema "${refSchema.title}" '
              'but does not provide required type parameter "$requiredParam". '
              'Required type parameters: ${refSchema.typeParameters}',
            );
          }
        }

        return PropertyInfo(
          name: propertyName,
          type: SchemaType.object,
          nullable: !isRequired,
          referencedSchema: refSchema,
          typeArguments: typeArguments,
        );

      case '\$Union':
        // Inline union
        final unionSchema = await _analyzeUnion(value);
        return PropertyInfo(
          name: propertyName,
          type: SchemaType.union,
          nullable: !isRequired,
          referencedSchema: unionSchema,
          unionInfo: unionSchema.unionInfo,
        );

      default:
        throw Exception('Unsupported property type: $typeName for property $propertyName');
    }
  }
}
