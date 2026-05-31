class Ledger {
  final int? id;
  final String name;
  final String icon;
  final String color;
  final String? createdAt;
  final String? updatedAt;

  Ledger({
    this.id,
    required this.name,
    this.icon = '📒',
    this.color = '#4A90D9',
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Ledger.fromMap(Map<String, dynamic> map) {
    return Ledger(
      id: map['id'] as int?,
      name: map['name'] as String,
      icon: (map['icon'] as String?) ?? '📒',
      color: (map['color'] as String?) ?? '#4A90D9',
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }
}
