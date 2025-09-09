class Employee {
  final String id;
  final String name;
  final String faceImageUrl; // This now stores base64 image data
  final List<double> faceEmbedding;
  final List<List<double>> faceEmbeddings; // Multi-sample embeddings (optional)
  final DateTime createdAt;
  final bool isActive;

  Employee({
    required this.id,
    required this.name,
    required this.faceImageUrl,
    required this.faceEmbedding,
    required this.faceEmbeddings,
    required this.createdAt,
    required this.isActive,
  });

  factory Employee.fromMap(Map<String, dynamic> map, String id) {
    // Backward compatibility: support both single and multi-embedding
    final List<dynamic>? multi = map['faceEmbeddings'];
    List<List<double>> multiEmbeddings = [];
    if (multi != null) {
      multiEmbeddings =
          multi.map((e) {
            if (e is List) {
              // Legacy format: List<List<double>> (unsupported by Firestore to write, but may exist in reads)
              return List<double>.from(e);
            } else if (e is Map) {
              // New format: List<Map{ 'e': List<double> }>
              final dynamic val = e['e'];
              return List<double>.from(val is List ? val : <double>[]);
            }
            return <double>[];
          }).toList();
    }
    final List<double> single = List<double>.from(map['faceEmbedding'] ?? []);
    if (multiEmbeddings.isEmpty && single.isNotEmpty) {
      multiEmbeddings = [single];
    }
    return Employee(
      id: id,
      name: map['name'] ?? '',
      faceImageUrl: map['faceImageUrl'] ?? '',
      faceEmbedding: single,
      faceEmbeddings: multiEmbeddings,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'faceImageUrl': faceImageUrl,
      'faceEmbedding': faceEmbedding,
      // Store as List<Map> to avoid nested array restriction in Firestore
      // Each sample is wrapped as { 'e': List<double> }
      'faceEmbeddings': faceEmbeddings.map((e) => {'e': e}).toList(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'isActive': isActive,
    };
  }
}
