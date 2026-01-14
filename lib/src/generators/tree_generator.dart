import 'package:code_builder/code_builder.dart';
import '../analyzers/tree_object_analyzer.dart';

/// Generates Tree extension with objectToNode conversion logic.
class TreeGenerator {
  final GenerateTreeInfo treeInfo;
  final List<TreeObjectInfo> treeObjects;
  
  TreeGenerator(this.treeInfo, this.treeObjects);
  
  String generate() {
    final library = Library((b) => b
      ..body.add(_generateTreeExtension()));
    
    final emitter = DartEmitter(useNullSafetySyntax: true);
    return library.accept(emitter).toString();
  }
  
  Extension _generateTreeExtension() {
    return Extension((b) => b
      ..name = '${treeInfo.className}Extension'
      ..on = refer(treeInfo.className)
      ..docs.add('/// Generated extension with objectToNode conversion logic')
      ..methods.add(_generateObjectToNodeMethod()));
  }
  
  Method _generateObjectToNodeMethod() {
    return Method((m) => m
      ..name = 'objectToNode'
      ..returns = refer('(TreeNode, List<(Edge, Object)>)?')
      ..annotations.add(refer('override'))
      ..requiredParameters.add(Parameter((p) => p
        ..name = 'object'
        ..type = refer('Object')))
      ..body = Code(_generateObjectToNodeBody()));
  }

  String _generateObjectToNodeBody() {
    final buffer = StringBuffer();
    
    // Generate value type conversions
    buffer.writeln('// Value objects');
    buffer.writeln('if (object is StringValue) {');
    buffer.writeln('  return (StringValueNode(object, sourceRange: object.sourceRange, jsonFormatting: object.jsonFormatting, yamlFormatting: object.yamlFormatting), []);');
    buffer.writeln('}');
    buffer.writeln('if (object is IntValue) {');
    buffer.writeln('  return (IntValueNode(object, sourceRange: object.sourceRange, jsonFormatting: object.jsonFormatting, yamlFormatting: object.yamlFormatting), []);');
    buffer.writeln('}');
    buffer.writeln('if (object is DoubleValue) {');
    buffer.writeln('  return (DoubleValueNode(object, sourceRange: object.sourceRange, jsonFormatting: object.jsonFormatting, yamlFormatting: object.yamlFormatting), []);');
    buffer.writeln('}');
    buffer.writeln('if (object is BoolValue) {');
    buffer.writeln('  return (BoolValueNode(object, sourceRange: object.sourceRange, jsonFormatting: object.jsonFormatting, yamlFormatting: object.yamlFormatting), []);');
    buffer.writeln('}');
    buffer.writeln('if (object is NullValue) {');
    buffer.writeln('  return (NullValueNode(object, sourceRange: object.sourceRange, jsonFormatting: object.jsonFormatting, yamlFormatting: object.yamlFormatting), []);');
    buffer.writeln('}');
    buffer.writeln();
    
    // Generate domain object conversions
    buffer.writeln('// Domain objects');
    for (final obj in treeObjects) {
      buffer.write(_generateObjectConversion(obj));
    }
    
    // Generate collection conversions
    buffer.writeln();
    buffer.writeln('// Collections');
    buffer.writeln('if (object is List) {');
    buffer.writeln('  final edges = <(Edge, Object)>[];');
    buffer.writeln('  for (var i = 0; i < object.length; i++) {');
    buffer.writeln('    edges.add((Edge(TreeNode, \'\$i\'), object[i]));');
    buffer.writeln('  }');
    buffer.writeln('  return (ListTreeNode(), edges);');
    buffer.writeln('}');
    buffer.writeln();
    buffer.writeln('if (object is Map) {');
    buffer.writeln('  final edges = <(Edge, Object)>[];');
    buffer.writeln('  for (final entry in object.entries) {');
    buffer.writeln('    edges.add((Edge(TreeNode, entry.key.toString()), entry.value));');
    buffer.writeln('  }');
    buffer.writeln('  return (MapTreeNode(), edges);');
    buffer.writeln('}');
    buffer.writeln();
    
    // Generate union conversions
    buffer.writeln('// Union objects');
    buffer.writeln('if (object is UnionObject2) {');
    buffer.writeln('  final innerObject = object.value;');
    buffer.writeln('  final conversion = objectToNode(innerObject);');
    buffer.writeln('  if (conversion != null) {');
    buffer.writeln('    final (innerNode, edges) = conversion;');
    buffer.writeln('    if (object.isFirst) {');
    buffer.writeln('      return (UnionNode2.first(innerNode), edges);');
    buffer.writeln('    } else {');
    buffer.writeln('      return (UnionNode2.second(innerNode), edges);');
    buffer.writeln('    }');
    buffer.writeln('  }');
    buffer.writeln('}');
    buffer.writeln();
    buffer.writeln('if (object is UnionObject3) {');
    buffer.writeln('  final innerObject = object.value;');
    buffer.writeln('  final conversion = objectToNode(innerObject);');
    buffer.writeln('  if (conversion != null) {');
    buffer.writeln('    final (innerNode, edges) = conversion;');
    buffer.writeln('    if (object.isFirst) {');
    buffer.writeln('      return (UnionNode3.first(innerNode), edges);');
    buffer.writeln('    } else if (object.isSecond) {');
    buffer.writeln('      return (UnionNode3.second(innerNode), edges);');
    buffer.writeln('    } else {');
    buffer.writeln('      return (UnionNode3.third(innerNode), edges);');
    buffer.writeln('    }');
    buffer.writeln('  }');
    buffer.writeln('}');
    buffer.writeln();
    buffer.writeln('if (object is UnionObject4) {');
    buffer.writeln('  final innerObject = object.value;');
    buffer.writeln('  final conversion = objectToNode(innerObject);');
    buffer.writeln('  if (conversion != null) {');
    buffer.writeln('    final (innerNode, edges) = conversion;');
    buffer.writeln('    if (object.isFirst) {');
    buffer.writeln('      return (UnionNode4.first(innerNode), edges);');
    buffer.writeln('    } else if (object.isSecond) {');
    buffer.writeln('      return (UnionNode4.second(innerNode), edges);');
    buffer.writeln('    } else if (object.isThird) {');
    buffer.writeln('      return (UnionNode4.third(innerNode), edges);');
    buffer.writeln('    } else {');
    buffer.writeln('      return (UnionNode4.fourth(innerNode), edges);');
    buffer.writeln('    }');
    buffer.writeln('  }');
    buffer.writeln('}');
    buffer.writeln();
    
    buffer.writeln('return null;');
    
    return buffer.toString();
  }
  
  String _generateObjectConversion(TreeObjectInfo obj) {
    final buffer = StringBuffer();
    
    buffer.writeln('if (object is ${obj.className}) {');
    buffer.writeln('  final edges = <(Edge, Object)>[];');
    
    // Add all fields as edges
    for (final field in obj.fields) {
      final edgeType = field.isTreeChild ? field.nodeTypeName : '${field.typeName}Node';
      
      if (field.isNullable) {
        buffer.writeln('  if (object.${field.name} != null) {');
        buffer.writeln('    edges.add((Edge($edgeType, \'${field.name}\'), object.${field.name}!));');
        buffer.writeln('  }');
      } else {
        buffer.writeln('  edges.add((Edge($edgeType, \'${field.name}\'), object.${field.name}));');
      }
    }
    
    buffer.writeln('  return (${obj.nodeClassName}(), edges);');
    buffer.writeln('}');
    buffer.writeln();
    
    return buffer.toString();
  }
}

