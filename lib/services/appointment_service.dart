import 'dart:convert';
import 'package:NovaHealth/features/HomePage/data/models/appointment_model.dart';
import 'package:NovaHealth/utils/api_endpoint.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class AppointmentService {
  static const String _appointmentsKey = 'user_appointments';
  
  // Save a new appointment
  static Future<void> saveAppointment(AppointmentModel appointment) async {
    final prefs = await SharedPreferences.getInstance();
    final appointmentsJson = prefs.getStringList(_appointmentsKey) ?? [];
    
    // Add the new appointment
    appointmentsJson.add(jsonEncode(appointment.toJson()));
    
    // Save back to SharedPreferences
    await prefs.setStringList(_appointmentsKey, appointmentsJson);
  }
  
  // Get all appointments
  static Future<List<AppointmentModel>> getAppointments() async {
    final prefs = await SharedPreferences.getInstance();
    final appointmentsJson = prefs.getStringList(_appointmentsKey) ?? [];
    
    // Convert JSON strings to AppointmentModel objects
    return appointmentsJson
        .map((json) => AppointmentModel.fromJson(jsonDecode(json)))
        .toList();
  }
  
  // Get upcoming appointments only
  static Future<List<AppointmentModel>> getUpcomingAppointments() async {
    try {
      // Try to get appointments from API first
      final profileId = await AuthService.getCurrentProfileId();
      if (profileId != null) {
        final headers = await AuthService.getAuthHeaders();
        final url = Uri.parse('${ApiEndPoints.baseUrl}/scheduling/appointments/?profile_id=$profileId&status=upcoming');
        
        final response = await http.get(url, headers: headers);
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          return data.map((json) => AppointmentModel.fromJson(json)).toList();
        }
      }
    } catch (e) {
      print('Error fetching appointments from API: $e');
    }
    
    // Fall back to local storage if API fails
    final appointments = await getAppointments();
    return appointments.where((appointment) => appointment.status == 'upcoming').toList();
  }
  
  // Delete an appointment - optimized for speed
  static Future<void> deleteAppointment(int appointmentId) async {
    final prefs = await SharedPreferences.getInstance();
    final appointmentsJson = prefs.getStringList(_appointmentsKey) ?? [];
    
    // Use indexWhere for faster lookup
    final index = appointmentsJson.indexWhere((json) {
      final appointment = AppointmentModel.fromJson(jsonDecode(json));
      return appointment.appointmentId == appointmentId;
    });
    
    // If found, remove directly by index (faster than filtering)
    if (index >= 0) {
      appointmentsJson.removeAt(index);
      await prefs.setStringList(_appointmentsKey, appointmentsJson);
    }
  }
  
  // Update an appointment status
  static Future<void> updateAppointmentStatus(int appointmentId, String status) async {
    final prefs = await SharedPreferences.getInstance();
    final appointmentsJson = prefs.getStringList(_appointmentsKey) ?? [];
    
    // Find and update the appointment
    final updatedAppointments = appointmentsJson.map((json) {
      final appointment = AppointmentModel.fromJson(jsonDecode(json));
      if (appointment.appointmentId == appointmentId) {
        // Create a new appointment with updated status
        final updatedAppointment = AppointmentModel(
          appointmentId: appointment.appointmentId,
          doctorId: appointment.doctorId,
          doctorName: appointment.doctorName,
          specialty: appointment.specialty,
          date: appointment.date,
          time: appointment.time,
          fee: appointment.fee,
          doctorImageUrl: appointment.doctorImageUrl,
          status: status,
        );
        return jsonEncode(updatedAppointment.toJson());
      }
      return json;
    }).toList();
    
    // Save back to SharedPreferences
    await prefs.setStringList(_appointmentsKey, updatedAppointments);
  }
  
  // Get queue status for an appointment
  static Future<Map<String, dynamic>> getQueueStatus(int appointmentId) async {
    final headers = await AuthService.getAuthHeaders();
    final profileId = await AuthService.getCurrentProfileId();
    
    String url = '${ApiEndPoints.baseUrl}${ApiEndPoints.schedulingEndpoints.queueStatus(appointmentId)}';
    if (profileId != null) {
      url += '?profile_id=$profileId';
    }
    
    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get queue status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting queue status: $e');
    }
  }
  
  // Cancel appointment
  static Future<Map<String, dynamic>> cancelAppointment(int appointmentId) async {
    final headers = await AuthService.getAuthHeaders();
    final profileId = await AuthService.getCurrentProfileId();
    
    String url = '${ApiEndPoints.baseUrl}${ApiEndPoints.schedulingEndpoints.cancelAppointment(appointmentId)}';
    if (profileId != null) {
      url += '?profile_id=$profileId';
    }
    
    try {
      final response = await http.post(Uri.parse(url), headers: headers);
      
      if (response.statusCode == 200) {
        // Delete from local storage
        await deleteAppointment(appointmentId);
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to cancel appointment: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error cancelling appointment: $e');
    }
  }
} 