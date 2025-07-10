class Counselor {
  final String id;
  final String name;
  final String? profileImage;
  final List<String> availableSlots;
  final bool isOnline;
  final String description;
  final List<String> assignedStudentIds;

  Counselor({
    required this.id,
    required this.name,
    this.profileImage,
    required this.availableSlots,
    required this.isOnline,
    required this.description,
    required this.assignedStudentIds,
  });

  factory Counselor.fromJson(Map<String, dynamic> json) {
    return Counselor(
      id: json['id'].toString(),  // Convert id to string no matter what
      name: json['name'].toString(),  // Defensive: convert to string
      profileImage: json['profileImage']?.toString(), // Nullable and convert to string if present
      availableSlots: json['availableSlots'] != null
          ? List<String>.from(json['availableSlots'].map((x) => x.toString()))
          : [],
      isOnline: json['isOnline'] ?? false,
      description: json['description']?.toString() ?? '',
      assignedStudentIds: json['assignedStudentIds'] != null
          ? List<String>.from(json['assignedStudentIds'].map((x) => x.toString()))
          : [],
    );
  }
}
