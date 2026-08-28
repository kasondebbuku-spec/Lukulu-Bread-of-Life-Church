class ChequeEntry {
  const ChequeEntry({
    required this.name,
    required this.chequeNo,
    required this.amount,
  });

  final String name;
  final String chequeNo;
  final double amount;

  factory ChequeEntry.fromMap(Map<String, dynamic> map) => ChequeEntry(
        name: map['name'] as String? ?? '',
        chequeNo: map['chequeNo'] as String? ?? '',
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'chequeNo': chequeNo,
        'amount': amount,
      };
}
