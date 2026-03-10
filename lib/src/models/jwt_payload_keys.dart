/// Key lookup for JWT payload parsing (snake_case or camelCase).

dynamic getKey(Map<String, dynamic> m, String snake, String camel) =>
    m[snake] ?? m[camel];

int? parseInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return null;
}

DateTime dateTimeFromUnixSeconds(int seconds) =>
    DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
