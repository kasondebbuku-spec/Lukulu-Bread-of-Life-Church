class ZmwDenomination {
  const ZmwDenomination({
    required this.key,
    required this.value,
    required this.label,
    this.isCoin = false,
  });

  /// Stable Firestore map key — not derived from [value].toString() so it
  /// stays human-readable in the console (e.g. "0.5" not "0.5" via double).
  final String key;
  final double value;
  final String label;
  final bool isCoin;
}

const zmwDenominations = [
  ZmwDenomination(key: '100', value: 100, label: 'K100'),
  ZmwDenomination(key: '50', value: 50, label: 'K50'),
  ZmwDenomination(key: '20', value: 20, label: 'K20'),
  ZmwDenomination(key: '10', value: 10, label: 'K10'),
  ZmwDenomination(key: '5', value: 5, label: 'K5'),
  ZmwDenomination(key: '2', value: 2, label: 'K2'),
  ZmwDenomination(key: '1', value: 1, label: 'K1', isCoin: true),
  ZmwDenomination(key: '0.5', value: 0.5, label: '50 ngwee', isCoin: true),
  ZmwDenomination(key: '0.1', value: 0.1, label: '10 ngwee', isCoin: true),
  ZmwDenomination(key: '0.05', value: 0.05, label: '5 ngwee', isCoin: true),
];
