class PendingTransaction {
  final int? id;
  final String packageName;
  final String sourceName;
  final String title;
  final String text;
  final double amount;
  final String type; // 'expense' or 'income'
  final String? merchant;
  final String suggestedCategory;
  final String status; // 'pending', 'confirmed', 'ignored'
  final String createdAt;
  final String updatedAt;

  PendingTransaction({
    this.id,
    required this.packageName,
    required this.sourceName,
    this.title = '',
    this.text = '',
    required this.amount,
    required this.type,
    this.merchant,
    this.suggestedCategory = '其他',
    this.status = 'pending',
    String? createdAt,
    String? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now().toString(),
       updatedAt = updatedAt ?? DateTime.now().toString();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'package_name': packageName,
      'source_name': sourceName,
      'title': title,
      'text': text,
      'amount': amount,
      'type': type,
      'merchant': merchant,
      'suggested_category': suggestedCategory,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory PendingTransaction.fromMap(Map<String, dynamic> map) {
    return PendingTransaction(
      id: map['id'] as int?,
      packageName: map['package_name'] as String,
      sourceName: map['source_name'] as String,
      title: (map['title'] as String?) ?? '',
      text: (map['text'] as String?) ?? '',
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] as String,
      merchant: map['merchant'] as String?,
      suggestedCategory: (map['suggested_category'] as String?) ?? '其他',
      status: (map['status'] as String?) ?? 'pending',
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  PendingTransaction copyWith({
    int? id,
    String? status,
    String? updatedAt,
  }) {
    return PendingTransaction(
      id: id ?? this.id,
      packageName: packageName,
      sourceName: sourceName,
      title: title,
      text: text,
      amount: amount,
      type: type,
      merchant: merchant,
      suggestedCategory: suggestedCategory,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now().toString(),
    );
  }
}
