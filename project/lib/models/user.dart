class User {
  final String id;
  final String name;
  final String email;
  final String studentId;
  final String phone;
  final String department;
  final int yearLevel;  // <-- Changed from String to int
  final String password;
  final String? profileImage;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.studentId,
    required this.phone,
    required this.department,
    required this.yearLevel,
    required this.password,
    this.profileImage,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'].toString(), // ensure id is a string
      name: json['name'],
      email: json['email'],
      studentId: json['studentId'],
      phone: json['phone'],
      department: json['department'],
      yearLevel: json['yearLevel'] is int 
          ? json['yearLevel'] 
          : int.parse(json['yearLevel'].toString()),  // parse if string
      password: json['password'],
      profileImage: json['profileImage'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'studentId': studentId,
      'phone': phone,
      'department': department,
      'yearLevel': yearLevel,  // send as int
      'password': password,
      'profileImage': profileImage,
    };
  }
}
