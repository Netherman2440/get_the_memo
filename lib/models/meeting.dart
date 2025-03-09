
class Meeting {
  final String id;
  String title;
  String description;
  final DateTime createdAt;
  final String? audioUrl;
  int? duration;


  
  Meeting({
    required this.id, 
    required this.title,
    required this.description,
    required this.createdAt,
    this.audioUrl,
    this.duration,
  });
  // Create a copy with some fields replaced
  Meeting copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? createdAt,
    String? audioUrl,
    int? duration,
  }) {
    return Meeting(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      audioUrl: audioUrl ?? this.audioUrl,
      duration: duration ?? this.duration,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
    'audioUrl': audioUrl,
    'duration': duration,
  };
  
  static Meeting fromJson(Map<String, dynamic> json) => Meeting(
    id: json['id'],
    title: json['title'],
    description: json['description'],
    createdAt: DateTime.parse(json['createdAt']),
    audioUrl: json['audioUrl'],
    duration: json['duration']
  );
}





