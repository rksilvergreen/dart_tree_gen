// enum ????

class _Tree {
  const _Tree();
}

const tree = _Tree();

class $Tree {
  final String name;
  final List<_$Schema> schemas;

  const $Tree({required this.name, required this.schemas});
}

abstract class _$Schema {
  const _$Schema();
}

class $Schema extends _$Schema {
  final String name;
  final Set<String> typeParameters;
  final List<String>? required;
  final List<String>? allowed;
  final List<String>? nullable;
  final Map<String, $Type>? properties;

  const $Schema({
    required this.name,
    this.typeParameters = const {},
    this.required,
    this.allowed,
    this.nullable,
    this.properties,
  });
}

class $Union extends _$Schema {
  final String name;
  final Set<String> typeParameters;
  final Set<$Type> types;
  
  const $Union({required this.name, this.typeParameters = const {}, this.types = const {}});
}

abstract class $Type {
  const $Type();
}

class $TypeParameter extends $Type {
  final String name;
  const $TypeParameter(this.name);
}

class $Object extends $Type {
  final _$Schema schema;
  final Map<String, $Type> typeParameters;

  const $Object({required this.schema, this.typeParameters = const {}});
}

class $Array extends $Type {
  final $Type? items;
  final bool? uniqueItems;

  const $Array({this.items, this.uniqueItems});
}

class $Integer extends $Type {
  const $Integer();
}

class $Double extends $Type {
  const $Double();
}

class $String extends $Type {
  const $String();
}

class $Boolean extends $Type {
  const $Boolean();
}
