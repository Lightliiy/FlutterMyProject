import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/booking.dart';
import '../models/counselor.dart';

class BookingProvider with ChangeNotifier {
  List<Booking> _bookings = [];
  List<Counselor> _counselors = [];
  bool _isLoading = false;
  Timer? _bookingRefreshTimer;

  List<Booking> get bookings => _bookings;
  List<Counselor> get counselors => _counselors;
  bool get isLoading => _isLoading;

  static const String baseUrl = 'http://10.8.5.62:8080/api';

  BookingProvider();

  // Create a booking and refresh the booking list
  Future<bool> createBooking({
    required String studentId,
    required String counselorId,
    required SessionType sessionType,
    required IssueType issueType,
    required String description,
    required DateTime scheduledDate,
    required String timeSlot,
    List<String> attachments = const [],
  }) async {
    _setLoading(true);
    try {
      final bookingData = {
        'studentId': studentId,
        'counselorId': counselorId,
        'sessionType': sessionType.toShortString(),
        'issueType': issueType.toShortString(),
        'description': description,
        'scheduledDate': scheduledDate.toIso8601String().split('T').first,
        'timeSlot': timeSlot,
        'attachments': attachments,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/bookings/add'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(bookingData),
      );

      if (response.statusCode == 201) {
        await loadBookingsForStudent(studentId);
        // Start refreshing bookings periodically to track progress
        startAutoRefreshBookings(studentId);
        return true;
      } else {
        print('Failed to create booking: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error creating booking: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Load counselors assigned to a student
 Future<void> loadCounselorsForStudent(String studentId) async {
  _setLoading(true);
  try {
    final encodedStudentId = Uri.encodeComponent(studentId);
    final url = Uri.parse('$baseUrl/counselors/assigned?studentId=$encodedStudentId');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);

      _counselors = [Counselor.fromJson(jsonData)];
      
    } else {
      _counselors = [];
      print('Counselor not found for student ID: $studentId');
    }
  } catch (e) {
    _counselors = [];
    print('Error loading counselor: $e');
  } finally {
    _setLoading(false);
  }
}

  // Fetch a single counselor by ID
  Future<Counselor?> fetchCounselorById(String id) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/counselors/$id'));
      if (response.statusCode == 200) {
        return Counselor.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      print('Error fetching counselor: $e');
    }
    return null;
  }

  // Load bookings for a student
  Future<void> loadBookingsForStudent(String studentId) async {
    _setLoading(true);
    try {
      final encodedStudentId = Uri.encodeComponent(studentId);
      final response = await http.get(Uri.parse('$baseUrl/bookings/student?studentId=$encodedStudentId'));

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        _bookings = jsonData.map((json) => Booking.fromJson(json)).toList();
      } else {
        _bookings = [];
        print('Failed to load bookings: ${response.statusCode}');
      }
    } catch (e) {
      _bookings = [];
      print('Error loading bookings: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Filter bookings by status
  List<Booking> getBookingsByStatus(BookingStatus status) {
    return _bookings.where((booking) => booking.status == status).toList();
  }

  // Escalate an issue for a booking
  Future<void> escalateIssue(String bookingId) async {
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    if (index == -1) return;

    try {
      final response = await http.put(Uri.parse('$baseUrl/bookings/escalate/$bookingId'));
      if (response.statusCode == 200) {
        _bookings[index] = _bookings[index].copyWith(isEscalated: true);
        notifyListeners();
      } else {
        print('Failed to escalate issue: ${response.statusCode}');
      }
    } catch (e) {
      print('Error escalating issue: $e');
    }
  }

  // Start periodic refresh of bookings
  void startAutoRefreshBookings(String studentId, {int intervalSeconds = 5}) {
    _bookingRefreshTimer?.cancel(); // Cancel any existing timer

    _bookingRefreshTimer = Timer.periodic(Duration(seconds: intervalSeconds), (_) async {
      await loadBookingsForStudent(studentId);
    });
  }

  // Stop periodic refresh
  void stopAutoRefreshBookings() {
    _bookingRefreshTimer?.cancel();
    _bookingRefreshTimer = null;
  }

  // Helper to set loading state
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    stopAutoRefreshBookings();
    super.dispose();
  }
}
