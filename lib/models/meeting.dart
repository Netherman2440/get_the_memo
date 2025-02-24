class Meeting {
  final String id;
  final String title;
  final String description;
  final DateTime createdAt;
  final String audioUrl;
  String? transcription;
  int? duration;
  
  Meeting({
    required this.id, 
    required this.title,
    required this.description,
    required this.createdAt,
    required this.audioUrl,
    this.transcription,
    this.duration,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
    'audioUrl': audioUrl,
    'transcription': transcription,
    'duration': duration,
  };
  
  static Meeting fromJson(Map<String, dynamic> json) => Meeting(
    id: json['id'],
    title: json['title'],
    description: json['description'],
    createdAt: DateTime.parse(json['createdAt']),
    audioUrl: json['audioUrl'],
    transcription: json['transcription'],
    duration: json['duration'],
  );
}

enum MeetingStatus {
  none,
  recording,
  transcription,
  tasks,
  done,
}



