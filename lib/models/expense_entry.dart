class ExpenseEntry {
  const ExpenseEntry({
    required this.description,
    required this.amount,
  });

  final String description;
  final double amount;

  factory ExpenseEntry.fromMap(Map<String, dynamic> map) => ExpenseEntry(
        description: map['description'] as String? ?? '',
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'description': description,
        'amount': amount,
      };
}
