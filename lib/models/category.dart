class CustomCategory {
  final String label;
  final String icon;
  final String color;
  final bool isDefault;

  CustomCategory({
    required this.label,
    required this.icon,
    required this.color,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'icon': icon,
      'color': color,
      'isDefault': isDefault,
    };
  }

  factory CustomCategory.fromJson(Map<String, dynamic> json) {
    return CustomCategory(
      label: json['label'] as String,
      icon: (json['icon'] as String?) ?? '📌',
      color: (json['color'] as String?) ?? '#95A5A6',
      isDefault: (json['isDefault'] as bool?) ?? false,
    );
  }
}

class CategoryInfo {
  final String label;
  final String icon;
  final String color;

  CategoryInfo({required this.label, required this.icon, required this.color});
}
