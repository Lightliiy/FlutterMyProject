// lib/models/booking.dart
import 'package:flutter/material.dart'; // Keep this if Booking uses Flutter widgets directly, otherwise can be removed.

enum SessionType { physical, video, chat }
enum IssueType { academic, personal, career, mental_health, relationship, financial }
enum BookingStatus { pending, confirmed, completed, cancelled }

extension SessionTypeExtension on SessionType {
  String toShortString() => toString().split('.').last;
}

extension IssueTypeExtension on IssueType {
  String toShortString() => toString().split('.').last;
}

class Booking {
  final String id;
  final String studentId;
  final String counselorId;
  final String counselorName;
  final SessionType sessionType;
  final IssueType issueType;
  final String description;
  final DateTime scheduledDate;
  final String timeSlot;
  final BookingStatus status;
  final List<String> attachments;
  final bool isEscalated;
  final String? feedback;

  Booking({
    required this.id,
    required this.studentId,
    required this.counselorId,
    required this.counselorName,
    required this.sessionType,
    required this.issueType,
    required this.description,
    required this.scheduledDate,
    required this.timeSlot,
    required this.status,
    required this.attachments,
    this.isEscalated = false,
    this.feedback,
  });

 factory Booking.fromJson(Map<String, dynamic> json) {
  return Booking(
    id: json['id'].toString(),
    studentId: json['studentId'] ?? '',
    counselorId: json['counselorId'] ?? '',
    counselorName: json['counselorName'] ?? '',
    sessionType: SessionType.values.firstWhere((e) => e.name.toLowerCase() == json['sessionType'].toString().toLowerCase()),
    issueType: IssueType.values.firstWhere((e) => e.name.toLowerCase() == json['issueType'].toString().toLowerCase()),
    status: BookingStatus.values.firstWhere((e) => e.name.toLowerCase() == json['status'].toString().toLowerCase()),
    description: json['description'] ?? '',
    scheduledDate: DateTime.parse(json['scheduledDate']),
    timeSlot: json['timeSlot'] ?? '',
    attachments: json['attachments'] != null
        ? List<String>.from(json['attachments'])
        : [],
    isEscalated: json['isEscalated'] ?? false,
    feedback: json['feedback'],
  );
}


  Booking copyWith({
    String? id,
    String? studentId,
    String? counselorId,
    String? counselorName,
    SessionType? sessionType,
    IssueType? issueType,
    String? description,
    DateTime? scheduledDate,
    String? timeSlot,
    BookingStatus? status,
    List<String>? attachments,
    bool? isEscalated,
    String? feedback,
  }) {
    return Booking(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      counselorId: counselorId ?? this.counselorId,
      counselorName: counselorName ?? this.counselorName,
      sessionType: sessionType ?? this.sessionType,
      issueType: issueType ?? this.issueType,
      description: description ?? this.description,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      timeSlot: timeSlot ?? this.timeSlot,
      status: status ?? this.status,
      attachments: attachments ?? this.attachments,
      isEscalated: isEscalated ?? this.isEscalated,
      feedback: feedback ?? this.feedback,
    );
  }
}