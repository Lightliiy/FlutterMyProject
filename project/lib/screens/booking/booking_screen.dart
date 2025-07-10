import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../../providers/user_provider.dart';
import '../../providers/booking_provider.dart' show BookingProvider;
import '../../models/booking.dart';
import '../../models/counselor.dart';

class BookingScreen extends StatefulWidget {
  @override
  _BookingScreenState createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  SessionType _selectedSessionType = SessionType.physical;
  IssueType _selectedIssueType = IssueType.academic;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _selectedTimeSlot = '';
  List<String> _attachments = [];

  Counselor? _counselor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Object? args = ModalRoute.of(context)?.settings.arguments;
    if (args is Counselor) {
      _counselor = args;
      _loadLatestCounselor();
    }
  }

  Future<void> _loadLatestCounselor() async {
    if (_counselor == null) return;

    try {
      final updated = await Provider.of<BookingProvider>(context, listen: false)
          .fetchCounselorById(_counselor!.id);
      if (updated != null) {
        setState(() {
          _counselor = updated;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch counselor data.'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      );
      if (result != null) {
        setState(() {
          _attachments.addAll(result.files.map((file) => file.name));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error picking files'), backgroundColor: Colors.red),
      );
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedTimeSlot = '';
      });
    }
  }

  void _bookSession() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);

    if (_counselor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No counselor assigned.'), backgroundColor: Colors.red),
      );
      return;
    }

    final studentId = userProvider.user?.studentId ?? '';
    final counselorId = _counselor!.id.toString();  // Convert counselor ID to String

    if (studentId.isEmpty || counselorId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User or counselor ID is missing.'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_formKey.currentState!.validate() && _selectedTimeSlot.isNotEmpty) {
      final success = await bookingProvider.createBooking(
        studentId: studentId,
        counselorId: counselorId,
        sessionType: _selectedSessionType,
        issueType: _selectedIssueType,
        description: _descriptionController.text,
        scheduledDate: _selectedDate,
        timeSlot: _selectedTimeSlot,
        attachments: _attachments,
      );

      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session booked successfully!'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to book session. Please try again.'), backgroundColor: Colors.red),
        );
      }
    } else if (_selectedTimeSlot.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time slot'), backgroundColor: Colors.orange),
      );
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book Session')),
      body: _counselor == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No counselor has been assigned to you yet.\nPlease wait until one is available.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            )
          : _buildBookingForm(_counselor!),
    );
  }

  Widget _buildBookingForm(Counselor counselor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Text(
                        counselor.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        counselor.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Session Type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Row(
              children: SessionType.values.map((type) {
                return Expanded(
                  child: RadioListTile<SessionType>(
                    title: Text(type.name.toUpperCase(), style: const TextStyle(fontSize: 12)),
                    value: type,
                    groupValue: _selectedSessionType,
                    onChanged: (value) => setState(() => _selectedSessionType = value!),
                    contentPadding: EdgeInsets.zero,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Text('Issue Type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            DropdownButtonFormField<IssueType>(
              value: _selectedIssueType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: IssueType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.name.replaceAll('_', ' ').toUpperCase()),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedIssueType = value!),
            ),
            const SizedBox(height: 24),
            const Text('Description', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Describe your issue...'),
              validator: (value) => value == null || value.isEmpty ? 'Please provide a description' : null,
            ),
            const SizedBox(height: 24),
            const Text('Select Date', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            InkWell(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today),
                    const SizedBox(width: 12),
                    Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Available Time Slots', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (counselor.availableSlots ?? []).map((slot) {
                final isSelected = _selectedTimeSlot == slot;
                return ChoiceChip(
                  label: Text(slot),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _selectedTimeSlot = selected ? slot : '');
                  },
                  selectedColor: Theme.of(context).primaryColor,
                  labelStyle: TextStyle(color: isSelected ? Colors.white : null),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Text('Attachments (Optional)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            OutlinedButton.icon(
              onPressed: _pickFiles,
              icon: const Icon(Icons.attach_file),
              label: const Text('Add Files'),
            ),
            if (_attachments.isNotEmpty)
              Column(
                children: _attachments.asMap().entries.map((entry) {
                  final index = entry.key;
                  final filename = entry.value;
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.insert_drive_file),
                      title: Text(filename),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => _removeAttachment(index),
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: Consumer<BookingProvider>(
                builder: (context, bookingProvider, child) {
                  return ElevatedButton(
                    onPressed: bookingProvider.isLoading ? null : _bookSession,
                    child: bookingProvider.isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Book Session'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
