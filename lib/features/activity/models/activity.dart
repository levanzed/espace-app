class Activity {
  final int id;
  final String name;
  final String modname;
  final String description;
  final String? url;
  final int visible;
  final List<dynamic> contents;
  final Map<String, dynamic> completion;
  final Map<String, dynamic> details;
  final int courseId;
  final int instance;
  final Map<String, dynamic> raw;

  Activity({
    required this.id,
    required this.name,
    required this.modname,
    required this.description,
    required this.url,
    required this.visible,
    required this.contents,
    required this.completion,
    required this.details,
    required this.courseId,
    required this.instance,
    required this.raw,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json["id"] ?? 0,
      name: json["name"] ?? "",
      modname: json["module"] ?? "",
      description: json["description"] ?? "",
      url: json["url"],
      visible: json["visible"] ?? 1,
      contents: List<dynamic>.from(json["contents"] ?? const []),
      completion: Map<String, dynamic>.from(json["completion"] ?? const {}),
      details: Map<String, dynamic>.from(json["details"] ?? const {}),
      courseId: json["course_id"] ?? 0,
      instance: json["instance"] ?? 0,
      raw: Map<String, dynamic>.from(json["raw"] ?? const {}),
    );
  }

  bool get isVisible => visible == 1;

  Map<String, dynamic>? get detailForType {
    if (details.containsKey(modname)) {
      return Map<String, dynamic>.from(details[modname] ?? const {});
    }
    return details.isNotEmpty
        ? Map<String, dynamic>.from(details.values.first as Map? ?? const {})
        : null;
  }
}
