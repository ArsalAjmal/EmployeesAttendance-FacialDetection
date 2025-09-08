class Employee {
  final String id;
  final String name;
  final String faceImageUrl; // This now stores base64 image data
  final List<double> faceEmbedding;
  final DateTime createdAt;
  final bool isActive;

  Employee({
    required this.id,
    required this.name,
    required this.faceImageUrl,
    required this.faceEmbedding,
    required this.createdAt,
    required this.isActive,
  });

  factory Employee.fromMap(Map<String, dynamic> map, String id) {
    return Employee(
      id: id,
      name: map['name'] ?? '',
      faceImageUrl: map['faceImageUrl'] ?? '',
      faceEmbedding: List<double>.from(map['faceEmbedding'] ?? []),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'faceImageUrl': faceImageUrl,
      'faceEmbedding': faceEmbedding,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'isActive': isActive,
    };
  }
}