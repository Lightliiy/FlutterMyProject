// providers/booking_provider.dart
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

    static const String baseUrl = 'http://10.192.163.181:8080/api';

    BookingProvider();

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
        _isLoading = true;
        notifyListeners();
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
                // Reload data immediately after successful booking
                await loadBookingsForStudent(studentId);
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
            _isLoading = false;
            notifyListeners();
        }
    }

    Future<void> loadCounselorsForStudent(String studentId) async {
        _isLoading = true;
        notifyListeners();
        try {
            final encodedStudentId = Uri.encodeComponent(studentId);
            final url = Uri.parse('$baseUrl/counselors/assigned?studentId=$encodedStudentId');

            final response = await http.get(url);

            if (response.statusCode == 200) {
                final jsonData = json.decode(response.body);
                // Assume the API might return a list or a single object
                if (jsonData is List) {
                    _counselors = jsonData.map((json) => Counselor.fromJson(json)).toList();
                } else {
                    _counselors = [Counselor.fromJson(jsonData)];
                }
            } else {
                _counselors = [];
                print('Counselor not found for student ID: $studentId');
            }
        } catch (e) {
            _counselors = [];
            print('Error loading counselor: $e');
        } finally {
            _isLoading = false;
            notifyListeners();
        }
    }

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

    Future<void> archiveBooking(String bookingId, String studentId) async {
        try {
            final response = await http.put(
                Uri.parse('$baseUrl/bookings/$bookingId/archive'),
            );

            if (response.statusCode == 200) {
                // Remove the booking from the local list
                _bookings.removeWhere((booking) => booking.id == bookingId);
                notifyListeners();
                print('Booking $bookingId archived successfully.');
            } else {
                print('Failed to archive booking: ${response.statusCode} ${response.body}');
                throw Exception('Failed to archive booking.');
            }
        } catch (e) {
            print('Error archiving booking: $e');
            rethrow;
        }
    }

    Future<void> loadBookingsForStudent(String studentId) async {
        _isLoading = true;
        notifyListeners();
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
            _isLoading = false;
            notifyListeners();
        }
    }

    List<Booking> getBookingsByStatus(BookingStatus status) {
        return _bookings.where((booking) => booking.status == status).toList();
    }

    Future<void> escalateIssue(String bookingId, String studentId) async {
        final index = _bookings.indexWhere((booking) => booking.id == bookingId);
        if (index == -1) return;

        final originalStatus = _bookings[index].status;
        _bookings[index] = _bookings[index].copyWith(status: BookingStatus.ESCALATED_TO_HOD);
        notifyListeners();

        try {
            final url = Uri.parse('$baseUrl/hod/escalate-to-hod/$bookingId');
            final response = await http.post(
                url,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'studentId': studentId}),
            );

            if (response.statusCode == 200) {
                print('Issue escalated successfully');
                await loadBookingsForStudent(studentId);
            } else {
                _bookings[index] = _bookings[index].copyWith(status: originalStatus);
                print('Failed to escalate to HOD: ${response.statusCode}');
                print('Response body: ${response.body}');
                throw Exception('Failed to escalate issue.');
            }
        } catch (e) {
            _bookings[index] = _bookings[index].copyWith(status: originalStatus);
            print('Error escalating to HOD: $e');
            rethrow;
        }
    }

    void startAutoRefreshBookings(String studentId, {int intervalSeconds = 5}) {
        _bookingRefreshTimer?.cancel();

        _bookingRefreshTimer = Timer.periodic(Duration(seconds: intervalSeconds), (_) async {
            await loadBookingsForStudent(studentId);
        });
    }

    void stopAutoRefreshBookings() {
        _bookingRefreshTimer?.cancel();
        _bookingRefreshTimer = null;
    }

    @override
    void dispose() {
        stopAutoRefreshBookings();
        super.dispose();
    }
}