class TravelPreferences {
  final int pax;
  final bool hasChildren;
  final bool hasElderly;

  const TravelPreferences({
    required this.pax,
    required this.hasChildren,
    required this.hasElderly,
  });

  factory TravelPreferences.defaults() {
    return const TravelPreferences(
      pax: 1,
      hasChildren: false,
      hasElderly: false,
    );
  }

factory TravelPreferences.fromMap(Map<String, dynamic> data) {
  bool parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    if (value is int) return value == 1;
    return false;
  }

  return TravelPreferences(
    pax: data['pax'] is int
        ? data['pax']
        : int.tryParse('${data['pax']}') ?? 1,
    hasChildren: parseBool(data['hasChildren']),
    hasElderly: parseBool(data['hasElderly']),
  );
}

}
