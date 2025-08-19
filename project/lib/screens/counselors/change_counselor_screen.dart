import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/booking.dart';
import '../../models/counselor.dart';

class ChangeCounselorScreen extends StatefulWidget {
  @override
  _ChangeCounselorScreenState createState() => _ChangeCounselorScreenState();
}

class _ChangeCounselorScreenState extends State<ChangeCounselorScreen> {
  final _formKey = GlobalKey<FormState>();
  String _reason = '';
  bool _isLoading = false;
  String? _currentCounselorName;

  @override
  void initState() {
    super.initState();
    _loadCurrentCounselor();
  }

  Future<void> _loadCurrentCounselor() async {
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Find the latest active booking to get the current counselor ID
    final activeBookings = bookingProvider.bookings
        .where((b) => b.status == BookingStatus.confirmed || b.status == BookingStatus.pending)
        .toList();

    if (activeBookings.isNotEmpty) {
      final latestBooking = activeBookings.first; // Or use a more specific logic to find the 'current' one
      final counselor = await bookingProvider.fetchCounselorById(latestBooking.counselorId);
      if (counselor != null) {
        setState(() {
          _currentCounselorName = counselor.name;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final studentName = authProvider.user?.name ?? 'Student';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Counselor Change'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please provide a reason for your request to be reassigned. This request will be sent directly to the Head of Department (HOD) for review.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              
              if (_currentCounselorName != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Counselor:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentCounselorName!,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              
              // Reason Text Field
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Reason for Change',
                  hintText: 'e.g., "I feel I need a counselor with a different specialization."',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                onChanged: (value) {
                  _reason = value;
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Reason cannot be empty.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        onPressed: _submitRequest,
                        icon: const Icon(Icons.send),
                        label: const Text('Submit Request'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitRequest() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
      final studentId = authProvider.user!.studentId;
      final studentName = authProvider.user!.name;
      
      try {
        await bookingProvider.requestCounselorChangeToHOD(
          studentId: studentId,
          studentName: studentName,
          currentCounselorName: _currentCounselorName,
          reason: _reason,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Counselor change request submitted successfully to HOD.'),
          ),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit request: $e'),
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}