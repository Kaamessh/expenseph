class AppTransaction {
  final String id;
  final String type; // 'gain' or 'spend'
  final double amount;
  final String description;
  final DateTime timestamp;
  final String category;

  AppTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.timestamp,
    required this.category,
  });

  factory AppTransaction.fromJson(Map<String, dynamic> json) {
    return AppTransaction(
      id: json['id'] ?? '',
      type: json['type'] ?? 'spend',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] ?? '',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      category: json['category'] ?? 'General',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'amount': amount,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'category': category,
    };
  }
}
