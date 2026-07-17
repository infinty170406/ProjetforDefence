class Family {
  final String id;
  final String name;
  final String adminParentId;
  final List<String> parents;
  final List<String> children;
  final Map<String, dynamic>? subscription;

  Family({
    required this.id,
    required this.name,
    required this.adminParentId,
    required this.parents,
    required this.children,
    this.subscription,
  });

  factory Family.fromJson(Map<String, dynamic> json) {
    return Family(
      id: json['id'] as String,
      name: json['name'] ?? 'Famille',
      adminParentId: json['adminParentId'] ?? '',
      parents: List<String>.from(json['parents'] ?? []),
      children: List<String>.from(json['children'] ?? []),
      subscription: json['subscription'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'adminParentId': adminParentId,
      'parents': parents,
      'children': children,
      if (subscription != null) 'subscription': subscription,
    };
  }
}
