class Debt {
  final String id;
  final String personName;
  final double originalAmount;
  final double interestRate; // Annual %
  final DateTime createdAt;
  final double accruedInterest; // Computed by API
  final double totalDebt; // Computed by API: originalAmount + accruedInterest

  Debt({
    required this.id,
    required this.personName,
    required this.originalAmount,
    required this.interestRate,
    required this.createdAt,
    required this.accruedInterest,
    required this.totalDebt,
  });

  factory Debt.fromJson(Map<String, dynamic> json) {
    return Debt(
      id: json['id'] ?? '',
      personName: json['person_name'] ?? '',
      originalAmount: (json['original_amount'] as num?)?.toDouble() ?? 0.0,
      interestRate: (json['interest_rate'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      accruedInterest: (json['accrued_interest'] as num?)?.toDouble() ?? 0.0,
      totalDebt: (json['total_debt'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'person_name': personName,
      'original_amount': originalAmount,
      'interest_rate': interestRate,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
