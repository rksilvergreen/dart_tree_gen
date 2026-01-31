import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'schema_info.dart';

/// Analyzer that extracts schema information from @schema annotated variables.
///
/// NOTE: This is the legacy build_runner analyzer. For the new @tree annotation
/// based workflow, use StandaloneSchemaAnalyzer instead.
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
  Future<Map<String, SchemaInfo>> analyze() async {
    // Find all @schema annotated variables
    final schemaChecker = TypeChecker.fromUrl('package:dart_tree_gen/src/schema/schema.dart#_Tree');

    for (final annotatedElement in library.annotatedWith(schemaChecker)) {
      final element = annotatedElement.element;

      if (element is! TopLevelVariableElement) {
        throw InvalidGenerationSourceError('@tree can only be applied to top-level const variables', element: element);
      }

      final name = element.name;
      if (name == null) {
        throw InvalidGenerationSourceError('@tree variable must have a name', element: element);
      }

      _annotatedSchemas.add(name);

      final constValue = element.computeConstantValue();
      if (constValue == null) {
        throw InvalidGenerationSourceError(
          'Variable $name annotated with @tree must be a const value',
          element: element,
        );
      }

      _objectToSchemaName[constValue.hashCode] = name;

      await _analyzeTree(constValue, element);
    }

    return Map.unmodifiable(_schemas);
  }

  /// Analyzes a $Tree and extracts all schemas.
  Future<void> _analyzeTree(DartObject treeValue, Element element) async {
    final schemasField = treeValue.getField('schemas');
    if (schemasField == null || schemasField.isNull) return;

    final schemasList = schemasField.toListValue();
    if (schemasList == null) return;

    for (final schemaObj in schemasList) {
      final typeName = schemaObj.type?.element?.name;

      if (typeName == '\$Schema') {
        await _analyzeSchema(schemaObj, element);
      } else if (typeName == '\$Union') {
        await _analyzeUnion(schemaObj, element);
      }
    }
  }

  /// Analyzes a $Schema.
  Future<SchemaInfo> _analyzeSchema(DartObject value, Element element) async {
    final nameField = value.getField('name');
    final name = nameField?.toStringValue() ?? '';

    if (_schemas.containsKey(name)) {
      return _schemas[name]!;
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
            element,
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

  final Map<int, SchemaInfo> _objectToSchema = {};

  /// Analyzes a $Union schema.
  Future<SchemaInfo> _analyzeUnion(DartObject value, Element element) async {
    final nameField = value.getField('name');
    final name = nameField?.toStringValue() ?? '';

    if (_schemas.containsKey(name)) {
      return _schemas[name]!;
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

    // Extract types set
    final typesField = value.getField('types');
    final unionTypes = <SchemaInfo>[];

    if (typesField != null && !typesField.isNull) {
      final typesSet = typesField.toSetValue();
      if (typesSet != null) {
        for (final typeObj in typesSet) {
          final typeName = typeObj.type?.element?.name;

          if (typeName == '\$String') {
            unionTypes.add(SchemaInfo(name: '_String', title: 'String', isAnnotated: false, properties: {}));
          } else if (typeName == '\$Integer') {
            unionTypes.add(SchemaInfo(name: '_Integer', title: 'Integer', isAnnotated: false, properties: {}));
          } else if (typeName == '\$Double') {
            unionTypes.add(SchemaInfo(name: '_Number', title: 'Number', isAnnotated: false, properties: {}));
          } else if (typeName == '\$Boolean') {
            unionTypes.add(SchemaInfo(name: '_Boolean', title: 'Boolean', isAnnotated: false, properties: {}));
          } else if (typeName == '\$Object') {
            final schemaRef = typeObj.getField('schema');
            if (schemaRef != null && !schemaRef.isNull) {
              final refTypeName = schemaRef.type?.element?.name;
              if (refTypeName == '\$Schema') {
                final refSchema = await _analyzeSchema(schemaRef, element);
                unionTypes.add(refSchema);
              } else if (refTypeName == '\$Union') {
                final refSchema = await _analyzeUnion(schemaRef, element);
                unionTypes.add(refSchema);
              }
            }
          }
        }
      }
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

  /// Analyzes a property.
  Future<PropertyInfo> _analyzeProperty(
    String propertyName,
    DartObject value,
    Set<String> schemaTypeParameters,
    Element element, {
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
            final schemaRef = itemsField.getField('schema');
            if (schemaRef != null && !schemaRef.isNull) {
              final refTypeName = schemaRef.type?.element?.name;
              if (refTypeName == '\$Schema') {
                itemSchema = await _analyzeSchema(schemaRef, element);
              }
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
        final schemaRef = value.getField('schema');
        SchemaInfo? refSchema;
        if (schemaRef != null && !schemaRef.isNull) {
          final refTypeName = schemaRef.type?.element?.name;
          if (refTypeName == '\$Schema') {
            refSchema = await _analyzeSchema(schemaRef, element);
          } else if (refTypeName == '\$Union') {
            refSchema = await _analyzeUnion(schemaRef, element);
          }
        }
        return PropertyInfo(
          name: propertyName,
          type: SchemaType.object,
          nullable: !isRequired,
          referencedSchema: refSchema,
        );
      case '\$Union':
        final unionSchema = await _analyzeUnion(value, element);
        return PropertyInfo(
          name: propertyName,
          type: SchemaType.union,
          nullable: !isRequired,
          referencedSchema: unionSchema,
          unionInfo: unionSchema.unionInfo,
        );
      default:
        throw InvalidGenerationSourceError(
          'Unsupported property type: $typeName for property $propertyName',
          element: element,
        );
    }
  }
}
