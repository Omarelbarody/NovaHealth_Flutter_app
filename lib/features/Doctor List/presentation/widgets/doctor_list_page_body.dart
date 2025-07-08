import 'dart:convert';
import 'package:NovaHealth/features/HomePage/presentation/widgets/home_page_body.dart';
import 'package:NovaHealth/features/HomePage/presentation/widgets/home_page_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:NovaHealth/features/Doctor%20List/data/models/booking_model.dart';
import 'package:NovaHealth/utils/api_endpoint.dart';
import 'package:NovaHealth/services/auth_service.dart';
import 'package:NovaHealth/services/appointment_service.dart';
import 'package:NovaHealth/features/HomePage/data/models/appointment_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
//import 'package:NovaHealth/features/HomePage/presentation/widgets/home_view_body.dart';

class Doctor {
  final int userId;
  final String fullName;
  final String gender;
  final String specialty;
  final String education;
  final String? fees;
  final String? title;
  final List<dynamic> timeSlots;
  final String imageUrl;

  Doctor({
    required this.userId,
    required this.fullName,
    required this.gender,
    required this.specialty,
    required this.education,
    this.fees,
    this.title,
    required this.timeSlots,
    required this.imageUrl,
  });

  factory Doctor.fromJson(Map<String, dynamic> json) {
    // Parse the time slots to ensure they're in a usable format
    List<dynamic> parsedTimeSlots = [];
    if (json['time_slots'] != null) {
      if (json['time_slots'] is List) {
        parsedTimeSlots = json['time_slots'];
      }
    }
    
    return Doctor(
      userId: json['id'],
      fullName: json['full_name'],
      gender: json['gender'],
      specialty: json['specialty'],
      education: json['education'],
      fees: json['fees'],
      title: json['title'],
      timeSlots: parsedTimeSlots,
      imageUrl: json['image'],
    );
  }

  // Helper method to get time slot ID
  int? getTimeSlotId(String formattedTimeSlot) {
    for (var slot in timeSlots) {
      try {
        if (slot is Map<String, dynamic>) {
          // If slot has an id field, use it directly
          if (slot.containsKey('id')) {
            // Format the slot time to match the displayed format
            String slotTime = '';
            if (slot.containsKey('start_time') && slot.containsKey('end_time')) {
              final start = _convertTo12HourFormat(slot['start_time'].toString());
              final end = _convertTo12HourFormat(slot['end_time'].toString());
              slotTime = '$start - $end';
            } else if (slot.containsKey('time')) {
              slotTime = formatTimeSlot(slot['time']);
            }
            
            // Check if this is the selected time slot
            if (slotTime == formattedTimeSlot) {
              return slot['id'];
            }
          }
        } else if (slot is String) {
          // If the API returns a simple string format with ID embedded
          // This is just an example, adjust based on your API response format
          final parts = slot.split('|');
          if (parts.length >= 2) {
            final slotTime = formatTimeSlot(parts[0]);
            if (slotTime == formattedTimeSlot) {
              return int.tryParse(parts[1]);
            }
          }
        }
        
        // Debug: Print the slot and formatted time slot for comparison
        print('Comparing: API slot = $slot, formatted = ${formatTimeSlot(slot.toString())}, selected = $formattedTimeSlot');
      } catch (e) {
        print('Error parsing time slot: $e');
      }
    }
    
    // If we can't find the ID, return a default for testing
    print('Could not find time slot ID for $formattedTimeSlot, using default');
    return 1664; // Default for testing - remove in production
  }

  // Helper method to format a time slot
  String formatTimeSlot(dynamic slot) {
    // Handle different possible formats from the API
    if (slot is String) {
      // Check if the slot contains a range separator
      if (slot.contains('-') || slot.contains('to')) {
        // Parse both times in the range and reformat to 12-hour format
        try {
          final parts = slot.split(slot.contains('-') ? '-' : 'to');
          if (parts.length == 2) {
            final startTime = _convertTo12HourFormat(parts[0].trim());
            final endTime = _convertTo12HourFormat(parts[1].trim());
            return '$startTime - $endTime';
          }
        } catch (e) {
          print('Error reformatting time range: $e');
        }
        return slot; // Return original if parsing fails
      } else {
        // Single time format, create a 30-minute slot
        try {
          final time = _convertTo12HourFormat(slot);
          // Try to parse this time into a DateTime
          final parsedTime = _parseTime(time);
          if (parsedTime != null) {
            final endTime = parsedTime.add(const Duration(minutes: 30));
            final endTimeFormatted = DateFormat('h:mm a').format(endTime);
            return '$time - $endTimeFormatted';
          }
          return '$time - +30m';
        } catch (e) {
          print('Error formatting single time: $e');
        }
        return '$slot - +30m'; // Fallback
      }
    } else if (slot is Map) {
      // Handle if the slot is a map with start and end times
      final start = slot['start_time'] != null ? _convertTo12HourFormat(slot['start_time'].toString()) : '';
      final end = slot['end_time'] != null ? _convertTo12HourFormat(slot['end_time'].toString()) : '';
      return '$start - $end';
    }
    
    // Default fallback
    return slot.toString();
  }

  // Helper to convert time string to 12-hour format
  String _convertTo12HourFormat(String timeStr) {
    timeStr = timeStr.trim();
    
    // If already has AM/PM, it's likely already in 12-hour format
    if (timeStr.toLowerCase().contains('am') || timeStr.toLowerCase().contains('pm')) {
      return timeStr;
    }
    
    try {
      // Check if it's in 24-hour format (like "14:30")
      final timeParts = timeStr.split(':');
      if (timeParts.length >= 2) {
        int hour = int.tryParse(timeParts[0]) ?? 0;
        int minute = int.tryParse(timeParts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        
        final now = DateTime.now();
        final dateTime = DateTime(now.year, now.month, now.day, hour, minute);
        return DateFormat('h:mm a').format(dateTime); // Returns like "2:30 PM"
      }
    } catch (e) {
      print('Error converting to 12-hour format: $e');
    }
    
    return timeStr; // Return original if parsing fails
  }
  
  // Helper to parse a time string into DateTime
  DateTime? _parseTime(String timeStr) {
    try {
      final now = DateTime.now();
      timeStr = timeStr.toLowerCase().trim();
      
      // Extract hour, minute, and AM/PM
      RegExp regExp = RegExp(r'(\d+):(\d+)\s*(am|pm)?');
      var match = regExp.firstMatch(timeStr);
      
      if (match != null) {
        int hour = int.parse(match.group(1)!);
        int minute = int.parse(match.group(2)!);
        String? amPm = match.group(3);
        
        // Adjust hour for PM
        if (amPm == 'pm' && hour < 12) {
          hour += 12;
        } else if (amPm == 'am' && hour == 12) {
          hour = 0;
        }
        
        return DateTime(now.year, now.month, now.day, hour, minute);
      }
    } catch (e) {
      print('Error parsing time: $e');
    }
    return null;
  }
}

class doctorListPageBody extends StatefulWidget {
  final String specialty;

  const doctorListPageBody({
    Key? key,
    required this.specialty,
  }) : super(key: key);

  @override
  State<doctorListPageBody> createState() => _doctorListPageBodyState();
}

class _doctorListPageBodyState extends State<doctorListPageBody> {
  List<Doctor> doctors = [];
  List<Doctor> filteredDoctors = [];
  bool isLoading = true;
  String? genderFilter;
  String searchQuery = '';
  String selectedDate = 'Today';
  TextEditingController searchController = TextEditingController();
  Map<int, String?> selectedTimeSlots = {}; // doctorId -> selected time slot
  bool isSearchVisible = false;

  @override
  void initState() {
    super.initState();
    fetchDoctors();
  }

  Future<void> fetchDoctors({String? searchQuery}) async {
    setState(() {
      isLoading = true;
    });

    try {
      // Format today's date in yyyy-MM-dd format
      final formattedDate = formatDate(selectedDate);
      
      final hospitalId = await SharedPreferences.getInstance().then((prefs) => prefs.getString('hospitalId'));
      if (hospitalId == null) {
        throw Exception('Hospital ID not found in local storage');
      }
      
      String url = ApiEndPoints.baseUrl + ApiEndPoints.doctorEndpoints.doctorsBySpecialty(widget.specialty, formattedDate, hospitalId);
      
      // Add search query if provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        url += '&search=$searchQuery';
      }
      
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          doctors = data.map((json) => Doctor.fromJson(json)).toList();
          filteredDoctors = List.from(doctors);
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
        print('Failed to load doctors: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error fetching doctors: $e');
    }
  }

  void applyFilters() {
    setState(() {
      filteredDoctors = doctors.where((doctor) {
        // Apply gender filter
        if (genderFilter != null && doctor.gender != genderFilter) {
          return false;
        }
        
        // Apply search query
        if (searchQuery.isNotEmpty && 
            !doctor.fullName.toLowerCase().contains(searchQuery.toLowerCase())) {
          return false;
        }
        
        return true;
      }).toList();
    });
  }

  String formatDate(String dateText) {
    if (dateText == 'Today') {
      return DateFormat('yyyy-MM-dd').format(DateTime.now());
    } else if (dateText == 'Tomorrow') {
      return DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 1)));
    } else {
      // For "Fri, 23" type format, extract the day and use current month/year
      try {
        final parts = dateText.split(', ');
        if (parts.length == 2) {
          final day = int.parse(parts[1]);
          final now = DateTime.now();
          return DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, day));
        }
      } catch (e) {
        print('Error parsing date: $e');
      }
      return DateFormat('yyyy-MM-dd').format(DateTime.now());
    }
  }

  void selectTimeSlot(int doctorId, String time, Doctor doctor) {
    setState(() {
      selectedTimeSlots[doctorId] = time;
      
      // Debug: Print the time slot ID for the selected time
      final timeSlotId = doctor.getTimeSlotId(time);
      print('Selected time slot: $time, ID: $timeSlotId');
    });
  }

  Future<void> bookAppointment(Doctor doctor) async {
    final selectedTime = selectedTimeSlots[doctor.userId];
    if (selectedTime == null) {
      // Show an error message or prompt to select a time slot
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time slot')),
      );
      return;
    }


    // Show booking confirmation with payment options
    showDialog(
      context: context,
      builder: (context) {
        String selectedPaymentMethod = 'cash'; // Default to cash
        
        return StatefulBuilder(
          builder: (context, setState) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8, // Shadow depth
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Confirm Booking',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text('Doctor: Dr. ${doctor.fullName}'),
                  Text('Specialty: ${doctor.specialty}'),
                  Text('Date: ${formatDate(selectedDate)}'),
                  Text('Time: $selectedTime'),
                  Text('Fee: ${doctor.fees ?? "Not specified"} EGP'),
                  const SizedBox(height: 16),
                  
                  // Payment method selection
                  const Text(
                    'Payment Method:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  
                  // Radio buttons for payment methods
                  Row(
                    children: [
                      Radio(
                        value: 'cash',
                        groupValue: selectedPaymentMethod,
                        onChanged: (value) {
                          setState(() {
                            selectedPaymentMethod = value.toString();
                          });
                        },
                        activeColor: Colors.blue,
                      ),
                      const Text('Cash'),
                      const SizedBox(width: 16),
                      Radio(
                        value: 'visa',
                        groupValue: selectedPaymentMethod,
                        onChanged: (value) {
                          setState(() {
                            selectedPaymentMethod = value.toString();
                          });
                        },
                        activeColor: Colors.blue,
                      ),
                      const Text('Visa'),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // Close the dialog
                          
                          if (selectedPaymentMethod == 'cash') {
                            // Process cash payment
                            processCashPayment(doctor);
                          } else {
                            // For Visa payment - to be implemented
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Visa payment will be implemented soon')),
                            );
                          }
                        },
                        child: const Text(
                          'Confirm',
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Process cash payment and book appointment
  Future<void> processCashPayment(Doctor doctor) async {
    setState(() {
      isLoading = true;
    });

    try {
      // Get the selected time slot
      final selectedTime = selectedTimeSlots[doctor.userId];
      if (selectedTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a time slot')),
        );
        setState(() {
          isLoading = false;
        });
        return;
      }
      
      // Get the time slot ID from the doctor's time slots
      final timeSlotId = doctor.getTimeSlotId(selectedTime);
      
      if (timeSlotId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find time slot ID. Please try again.')),
        );
        setState(() {
          isLoading = false;
        });
        return;
      }
      
      final url = 'https://1d1f28dfea3b.ngrok-free.app/api/v1/scheduling/appointments/book-cash/';
      
      // Get authentication headers with token
      final headers = await AuthService.getAuthHeaders();
      
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode({
          'time_slot_id': timeSlotId,
          'amount': doctor.fees ?? '0.00',
        }),
      );

      setState(() {
        isLoading = false;
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        final appointmentId = responseData['appointment_id'];
        
        // Create and save the appointment
        final appointment = AppointmentModel(
          appointmentId: appointmentId,
          doctorId: doctor.userId,
          doctorName: doctor.fullName,
          specialty: doctor.specialty,
          date: formatDate(selectedDate),
          time: selectedTime,
          fee: doctor.fees ?? '0.00',
          doctorImageUrl: doctor.imageUrl,
          status: 'upcoming',
        );
        
        // Save the appointment to local storage
        await AppointmentService.saveAppointment(appointment);
        
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Appointment booked successfully! Appointment ID: $appointmentId')),
        // );
        
        // Navigate back to home page to see the updated appointment list
        Get.offAll(() => const HomeViewBody(), 
          transition: Transition.leftToRight,
          duration: const Duration(milliseconds: 150)
        );
      } else {
        // Try to get error message from response
        String errorMessage = 'Failed to book appointment';
        try {
          final errorData = json.decode(response.body);
          if (errorData.containsKey('detail')) {
            errorMessage = errorData['detail'];
          } else if (errorData.containsKey('message')) {
            errorMessage = errorData['message'];
          }
        } catch (e) {
          // Use default error message
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$errorMessage (${response.statusCode})')),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error booking appointment: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
appBar: AppBar(
    backgroundColor: Colors.white,
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios, color: Colors.blue),
      onPressed: () => Navigator.of(context).pop(),
    ),
    title: Text(
      widget.specialty,
      style: const TextStyle(color: Colors.black),
    ),
    actions: [
      // Search icon
      IconButton(
        icon: const Icon(Icons.search, color: Colors.blue),
        onPressed: () {
          setState(() {
            isSearchVisible = !isSearchVisible;
            if (!isSearchVisible) {
              searchController.clear();
              searchQuery = '';
              fetchDoctors();
            }
          });
        },
      ),

      // Gender filter icon with popup menu
      PopupMenuButton<String>(
        icon: const Icon(Icons.filter_list, color: Colors.blue),
        color: Colors.white, // White background for popup
        elevation: 8, // Shadow for the popup
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        onSelected: (value) {
          setState(() {
            genderFilter = value == 'all' ? null : value;
            applyFilters();
          });
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'all',
            child: Row(
              children: [
                Icon(
                  Icons.people_outline,
                  color: genderFilter == null ? Colors.blue : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'All',
                  style: TextStyle(
                    color: genderFilter == null ? Colors.blue : Colors.black,
                    fontWeight: genderFilter == null
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'male',
            child: Row(
              children: [
                Icon(
                  Icons.man,
                  color: genderFilter == 'male' ? Colors.blue : Colors.black,
                ),
                const SizedBox(width: 8),
                Text(
                  'Male',
                  style: TextStyle(
                    color:
                        genderFilter == 'male' ? Colors.blue : Colors.black,
                    fontWeight: genderFilter == 'male'
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'female',
            child: Row(
              children: [
                Icon(
                  Icons.woman,
                  color:
                      genderFilter == 'female' ? Colors.blue : Colors.pink,
                ),
                const SizedBox(width: 8),
                Text(
                  'Female',
                  style: TextStyle(
                    color: genderFilter == 'female'
                        ? Colors.blue
                        : Colors.black,
                    fontWeight: genderFilter == 'female'
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ],
  ), /* Your widget body here */
      body: Column(
        children: [
          // Search bar (visible only when search icon is clicked)
          if (isSearchVisible)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[200]!),
                  borderRadius: BorderRadius.circular(8),
                  // boxShadow: [
                  //   BoxShadow(
                  //     color: Colors.grey.withOpacity(0.2),
                  //     spreadRadius: 1,
                  //     blurRadius: 4,
                  //     offset: const Offset(0, 2),
                  //   ),
                  // ],
                ),
                child: TextField(
                  controller: searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search doctor',
                    prefixIcon: Icon(Icons.search, color: Colors.blue),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                      // For server-side search, fetch with search query
                      if (value.length > 2) {
                        fetchDoctors(searchQuery: value);
                      } else if (value.isEmpty) {
                        fetchDoctors();
                      }
                      // Still apply client-side filtering for immediate feedback
                      applyFilters();
                    });
                  },
                ),
              ),
            ),

          // Date Selection
SizedBox(
  height: 60,
  child: ListView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    children: [
      _buildDateButton('Today', selectedDate == 'Today'),
      _buildDateButton('Tomorrow', selectedDate == 'Tomorrow'),
      _buildDateButton(
        '${DateFormat('EEE').format(DateTime.now().add(const Duration(days: 2)))}, ${DateTime.now().add(const Duration(days: 2)).day}',
        selectedDate ==
            '${DateFormat('EEE').format(DateTime.now().add(const Duration(days: 2)))}, ${DateTime.now().add(const Duration(days: 2)).day}',
      ),
      _buildDateButton(
        '${DateFormat('EEE').format(DateTime.now().add(const Duration(days: 3)))}, ${DateTime.now().add(const Duration(days: 3)).day}',
        selectedDate ==
            '${DateFormat('EEE').format(DateTime.now().add(const Duration(days: 3)))}, ${DateTime.now().add(const Duration(days: 3)).day}',
      ),
    ],
  ),
),


          // Filter indicator row
          if (genderFilter != null || searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  if (genderFilter != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Chip(
                        backgroundColor: Colors.blue.withOpacity(0.1),
                        label: Text(
                          genderFilter == 'male' ? 'Male' : 'Female',
                          style: const TextStyle(color: Colors.blue),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 18, color: Colors.blue),
                        onDeleted: () {
                          setState(() {
                            genderFilter = null;
                            applyFilters();
                          });
                        },
                      ),
                    ),
                  if (searchQuery.isNotEmpty)
                    Expanded(
                      child: Chip(
                        backgroundColor: Colors.blue.withOpacity(0.1),
                        label: Text(
                          'Search: $searchQuery',
                          style: const TextStyle(color: Colors.blue),
                          overflow: TextOverflow.ellipsis,
                        ),
                        deleteIcon: const Icon(Icons.close, size: 18, color: Colors.blue),
                        onDeleted: () {
                          setState(() {
                            searchQuery = '';
                            searchController.clear();
                            fetchDoctors();
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),

          // Doctor List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredDoctors.isEmpty
                    ? const Center(child: Text('No doctors found'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredDoctors.length,
                        itemBuilder: (context, index) {
                          final doctor = filteredDoctors[index];
                          return _buildDoctorCard(doctor);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateButton(String text, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () {
            setState(() {
              selectedDate = text;
              // Clear previously selected time slots when date changes
              selectedTimeSlots.clear();
              // Fetch doctors for the new selected date
              fetchDoctors();
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? Colors.blue : Colors.white,
            foregroundColor: isSelected ? Colors.white : Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
            minimumSize: const Size(100, 40),
          ),
          child: Text(text),
        ),
      ),
    );
  }

  Widget _buildDoctorCard(Doctor doctor) {
    // Use the time slots from the API, or show a message if none are available
    final hasTimeSlots = doctor.timeSlots.isNotEmpty;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Doctor info row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Doctor details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dr. ${doctor.fullName}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        doctor.education,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${doctor.title ?? 'Specialist'} - ${doctor.specialty}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Fees: ${doctor.fees ?? 'Not specified'} EGP',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Select Time: $selectedDate',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                // Doctor image
                CircleAvatar(
                  radius: 35,
                   backgroundImage: NetworkImage(doctor.imageUrl),
                ),
              ],
            ),
            
            // Time slots
            const SizedBox(height: 16),
            if (hasTimeSlots)
              SizedBox(
                height: 45, // Slightly taller to accommodate time ranges
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: doctor.timeSlots.map((slot) {
                    // Format the slot as a time range
                    final timeSlot = doctor.formatTimeSlot(slot);
                    final isSelected = selectedTimeSlots[doctor.userId] == timeSlot;
                    
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: OutlinedButton(
                        onPressed: () => selectTimeSlot(doctor.userId, timeSlot, doctor),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: isSelected ? Colors.blue : Colors.transparent,
                          foregroundColor: isSelected ? Colors.white : Colors.blue,
                          side: const BorderSide(color: Colors.blue),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        ),
                        child: Text(
                          timeSlot,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              )
            else
              const Center(
                child: Text(
                  'No available appointments for this date',
                  style: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            
            // Book button
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: hasTimeSlots ? () => bookAppointment(doctor) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  disabledBackgroundColor: Colors.grey[300],
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Book Appointment',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}