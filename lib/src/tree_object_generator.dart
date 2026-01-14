import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'analyzers/tree_object_analyzer.dart';
import 'generators/node_generator.dart';
import 'generators/tree_generator.dart';
import 'generators/serialization_generator.dart';

/// Generator that creates TreeNode classes, Tree extensions, and serialization methods
/// from @treeObject annotated classes.
class TreeObjectGenerator extends Generator {
  @override
  String generate(LibraryReader library, BuildStep buildStep) {
    final analyzer = TreeObjectAnalyzer(library);
    
    // Find all @treeObject classes
    final treeObjects = analyzer.findTreeObjects();
    
    // Find @GenerateTree class
    final treeClass = analyzer.findGenerateTreeClass();
    
    if (treeObjects.isEmpty && treeClass == null) {
      // Nothing to generate
      return '';
    }
    
    final output = StringBuffer();
    
    // Generate TreeNode classes and serialization methods for each TreeObject
    if (treeObjects.isNotEmpty) {
      final nodeGenerator = NodeGenerator(treeObjects);
      output.writeln(nodeGenerator.generate());
      
      // Generate serialization methods for each TreeObject
      for (final treeObject in treeObjects) {
        final serializationGenerator = SerializationGenerator(treeObject);
        output.writeln(serializationGenerator.generate());
      }
    }
    
    // Generate Tree extension (not class)
    if (treeClass != null && treeObjects.isNotEmpty) {
      final treeGenerator = TreeGenerator(treeClass, treeObjects);
      output.writeln(treeGenerator.generate());
    }
    
    // Return unformatted code (IDE will format it)
    return output.toString();
  }
}

