enum ForexCurrency {
  gbPound,
  euro,
  usDollar,
  saRand,
  botswanaPula,
  namibianDollar,
  malawianKwacha,
  other,
}

extension ForexCurrencyX on ForexCurrency {
  String get label {
    switch (this) {
      case ForexCurrency.gbPound:
        return 'GB Pound';
      case ForexCurrency.euro:
        return 'Euro';
      case ForexCurrency.usDollar:
        return 'US Dollar';
      case ForexCurrency.saRand:
        return 'SA Rand';
      case ForexCurrency.botswanaPula:
        return 'Botswana Pula';
      case ForexCurrency.namibianDollar:
        return 'Namibian Dollar';
      case ForexCurrency.malawianKwacha:
        return 'Malawian Kwacha';
      case ForexCurrency.other:
        return 'Other';
    }
  }

  /// Fixed conversion rates to ZMW, as used on the church's paper form.
  double get rateToKwacha {
    switch (this) {
      case ForexCurrency.gbPound:
        return 16.2;
      case ForexCurrency.euro:
        return 14.5;
      case ForexCurrency.usDollar:
        return 13;
      case ForexCurrency.saRand:
        return 0.9088;
      case ForexCurrency.botswanaPula:
        return 1.2137;
      case ForexCurrency.namibianDollar:
        return 0.9088;
      case ForexCurrency.malawianKwacha:
        return 0.01662;
      case ForexCurrency.other:
        return 18;
    }
  }
}

/// A single foreign-currency entry from the offering. `kwachaValue` is
/// always computed live from the current rate table, never stored — so a
/// future rate-table update can't leave old records showing a stale
/// conversion with no way to tell which rate produced it.
class ForexEntry {
  const ForexEntry({required this.currency, required this.amount});

  final ForexCurrency currency;
  final double amount;

  double get kwachaValue => amount * currency.rateToKwacha;

  factory ForexEntry.fromMap(Map<String, dynamic> map) {
    final raw = map['currency'] as String?;
    final currency = ForexCurrency.values.firstWhere(
      (c) => c.name == raw,
      orElse: () => ForexCurrency.other,
    );
    return ForexEntry(
      currency: currency,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'currency': currency.name,
        'amount': amount,
      };
}
