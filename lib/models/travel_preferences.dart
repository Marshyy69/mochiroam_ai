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
    return TravelPreferences(
      pax:
          (data['pax'] ?? 1) is int
              ? (data['pax'] ?? 1)
              : int.tryParse("${data['pax']}") ?? 1,
      hasChildren: (data['hasChildren'] ?? false) as bool,
      hasElderly: (data['hasElderly'] ?? false) as bool,
    );
  }
}
