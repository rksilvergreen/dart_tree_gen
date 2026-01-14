# dart_tree_gen

Code generator for `dart_tree` - automatically generates TreeObject and TreeNode classes from schema definitions.

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  dart_tree:
    path: ../dart_tree

dev_dependencies:
  dart_tree_gen:
    path: ../dart_tree_gen
```

## Usage

### Standalone Generator (Recommended)

The standalone generator runs outside `build_runner` for better performance:

```bash
# Generate code for all schema files in your project
dart run dart_tree_gen:generate

# Generate for a specific directory
dart run dart_tree_gen:generate --directory lib

# Clean generated files
dart run dart_tree_gen:generate --clean

# Show help
dart run dart_tree_gen:generate --help
```

### Define Your Schema

Create a file with your schema definitions:

```dart
// lib/blog_post_schema.dart
import 'package:dart_tree/dart_tree.dart';

@schema
const blogPost = $Object(
  title: 'BlogPost',
  properties: {
    'title': $String(),
    'content': $String(),
    'author': user,
    'comments': $Array(title: 'CommentsList', items: comment),
  },
  required: ['title', 'content'],
);

@schema
const user = $Object(
  title: 'User',
  properties: {
    'name': $String(),
    'email': $String(format: 'email'),
  },
  required: ['name', 'email'],
);

@schema
const comment = $Object(
  title: 'Comment',
  properties: {
    'text': $String(),
    'author': user,
  },
  required: ['text', 'author'],
);
```

### Generated Code

The generator creates:

- **TreeObject classes**: `BlogPostObject`, `UserObject`, `CommentObject`
- **TreeNode classes**: `BlogPostNode`, `UserNode`, `CommentNode`
- **Tree class**: `BlogPostSchemaTree` with `objectToNode` implementation
- **Barrel file**: `blog_post_schema.generated.dart` that exports everything

File structure:

```
lib/
  blog_post_schema.dart (your schema)
  blog_post_schema.generated.dart (barrel file)
  blog_post_schema/
    objects/
      blog_post_object.dart
      user_object.dart
      comment_object.dart
      comments_list_object.dart
    nodes/
      blog_post_node.dart
      user_node.dart
      comment_node.dart
    trees/
      blog_post_schema_tree.dart
```

### Use the Generated Code

```dart
import 'blog_post_schema.generated.dart';

void main() {
  // Create objects
  final post = BlogPostObject(
    title: StringValue('My Post'),
    content: StringValue('Hello world!'),
    author: UserObject(
      name: StringValue('John'),
      email: StringValue('john@example.com'),
    ),
    comments: CommentsListObject([
      CommentObject(
        text: StringValue('Great post!'),
        author: UserObject(
          name: StringValue('Jane'),
          email: StringValue('jane@example.com'),
        ),
      ),
    ]),
  );

  // Create tree
  final tree = BlogPostSchemaTree(root: post);

  // Work with the tree
  final json = tree.toJson();
  final yaml = tree.toYaml();
}
```

## Legacy build_runner Integration (Deprecated)

The `build_runner` integration is deprecated in favor of the standalone generator.

If you still need to use it:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Features

- **Schema-first**: Define your data structure once using `$Object`, `$String`, `$Array`, etc.
- **Automatic generation**: TreeObject, TreeNode, and Tree classes generated automatically
- **Validation**: Constraints (min/max length, patterns, etc.) enforced in constructors and setters
- **Serialization**: `toJson`/`fromJson` and `toYaml`/`fromYaml` methods included
- **Type-safe**: Full Dart type checking on generated code
- **Fast**: Standalone generator is faster than `build_runner`

## Schema Types

- `$Object`: Custom object types
- `$String`: String values (with optional constraints: minLength, maxLength, pattern, format)
- `$Integer`: Integer values (with optional constraints: minimum, maximum, multipleOf)
- `$Number`: Double values (with optional constraints: minimum, maximum, multipleOf)
- `$Boolean`: Boolean values
- `$Array`: Array/List types (with optional constraints: minItems, maxItems, uniqueItems)
- `$Union`: Union types (coming soon)

## Options

The standalone generator supports the following options:

- `--directory`, `-d`: Directory to search for schema files (default: current directory)
- `--watch`, `-w`: Watch for file changes and regenerate (not yet implemented)
- `--clean`, `-c`: Clean generated files before generating
- `--help`, `-h`: Show usage information

## Development Status

The standalone generator is in active development. Currently implemented:

- ✅ File discovery and scanning
- ✅ Standalone executable
- ✅ File organization structure
- ⏳ Schema parsing (in progress)
- ⏳ Code generation (in progress)
- ⏳ Watch mode (not yet implemented)

The schema parsing and code generation logic from the `build_runner` version is being migrated to work in the standalone context.
