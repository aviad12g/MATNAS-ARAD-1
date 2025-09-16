class GroupDefinition {
  GroupDefinition({required this.id, required this.name});

  final String id;
  final String name;

  GroupDefinition copyWith({String? id, String? name}) {
    return GroupDefinition(id: id ?? this.id, name: name ?? this.name);
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
  }

  factory GroupDefinition.fromJson(Map<String, dynamic> json) {
    return GroupDefinition(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
    );
  }
}

class ActivityDefinition {
  ActivityDefinition({
    required this.id,
    required this.name,
    required List<GroupDefinition> groups,
  }) : groups = List<GroupDefinition>.unmodifiable(groups);

  final String id;
  final String name;
  final List<GroupDefinition> groups;

  ActivityDefinition copyWith({
    String? id,
    String? name,
    List<GroupDefinition>? groups,
  }) {
    return ActivityDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      groups: groups ?? this.groups,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'groups': groups.map((group) => group.toJson()).toList(),
    };
  }

  factory ActivityDefinition.fromJson(Map<String, dynamic> json) {
    final rawGroups = json['groups'] as List<dynamic>? ?? <dynamic>[];
    return ActivityDefinition(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      groups:
          rawGroups
              .map(
                (item) =>
                    GroupDefinition.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
    );
  }
}
