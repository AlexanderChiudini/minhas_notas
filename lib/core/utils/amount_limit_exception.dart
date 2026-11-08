class AmountLimitException implements Exception {
  const AmountLimitException();
  static const message =
      'Os totais excedem o limite suportado. Reduza os valores.';
  @override
  String toString() => message;
}
