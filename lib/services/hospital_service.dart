import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:NovaHealth/services/auth_service.dart';

class HospitalService {
  static const String baseUrl = 'https://1d1f28dfea3b.ngrok-free.app/api/v1';

  // Get the access token from shared preferences
  static Future<String?> _getToken() async {
    return await AuthService.getAccessToken();
  }

  // Get all available hospitals
  static Future<List<Map<String, dynamic>>> getAllHospitals() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('User not authenticated');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/hospitals/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((hospital) => hospital as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load hospitals: ${response.statusCode}');
    }
  }

  // Get linked hospitals for the current user
  static Future<List<Map<String, dynamic>>> getLinkedHospitals() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('User not authenticated');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/hospitals/my/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((hospital) => hospital as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load linked hospitals: ${response.statusCode}');
    }
  }

  // Get the current linked hospital (first one if multiple)
  static Future<Map<String, dynamic>> getLinkedHospital() async {
    try {
      // First check if we have a current hospital ID from login
      final currentHospitalId = await AuthService.getCurrentHospitalId();
      if (currentHospitalId != null) {
        // Try to find this hospital in the linked hospitals
        final hospitals = await getLinkedHospitals();
        final currentHospital = hospitals.firstWhere(
          (h) => h['id'] == currentHospitalId,
          orElse: () => {},
        );
        
        if (currentHospital.isNotEmpty) {
          return currentHospital;
        }
      }
      
      // If no current hospital ID or not found, return the first linked hospital
      final hospitals = await getLinkedHospitals();
      if (hospitals.isEmpty) {
        return {};
      }
      return hospitals.first;
    } catch (e) {
      print('Error getting linked hospital: $e');
      return {};
    }
  }

  // Get all profiles for the current user
  static Future<List<Map<String, dynamic>>> getUserProfiles() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('User not authenticated');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/profiles/patients/me/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((profile) => profile as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load user profiles: ${response.statusCode}');
    }
  }

  // Link a hospital to the user's account
  static Future<void> linkHospital(int hospitalId) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('User not authenticated');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/hospitals/$hospitalId/link/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to link hospital: ${response.statusCode}');
    }
    
    // After linking, get the updated profiles to save the new profile_id and hospital_id
    try {
      final profiles = await getUserProfiles();
      final newProfile = profiles.firstWhere(
        (p) => p['hospital_id'] == hospitalId,
        orElse: () => {},
      );
      
      if (newProfile.isNotEmpty) {
        // Save the new profile data
        await AuthService.saveProfileData({
          'profile_id': newProfile['profile_id'],
          'hospital_id': newProfile['hospital_id']
        });
      }
    } catch (e) {
      print('Error updating profile data after linking: $e');
    }
  }

  // Unlink a hospital from the user's account
  static Future<void> unlinkHospital(int hospitalId) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('User not authenticated');
    }

    final response = await http.delete(
      Uri.parse('$baseUrl/hospitals/$hospitalId/unlink/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to unlink hospital: ${response.statusCode}');
    }
    
    // If this was the current hospital, clear it from preferences
    final currentHospitalId = await AuthService.getCurrentHospitalId();
    if (currentHospitalId == hospitalId) {
      // Clear both profile_id and hospital_id
      await AuthService.clearProfileData();
      
      // Try to set another hospital as active if available
      try {
        final profiles = await getUserProfiles();
        if (profiles.isNotEmpty) {
          await AuthService.saveProfileData({
            'profile_id': profiles[0]['profile_id'],
            'hospital_id': profiles[0]['hospital_id']
          });
        }
      } catch (e) {
        print('Error setting new active hospital: $e');
      }
    }
  }

  // Switch to a different hospital profile
  static Future<void> switchHospital(int profileId) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('User not authenticated');
    }

    // First get the hospital_id for this profile
    final profiles = await getUserProfiles();
    final profile = profiles.firstWhere(
      (p) => p['profile_id'] == profileId,
      orElse: () => {},
    );
    
    if (profile.isEmpty || profile['hospital_id'] == null) {
      throw Exception('Invalid profile ID or missing hospital ID');
    }
    
    final int hospitalId = profile['hospital_id'];
    
    // Make the API call to switch profiles
    final response = await http.post(
      Uri.parse('$baseUrl/profiles/switch/$profileId/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to switch hospital: ${response.statusCode}');
    }
    
    // Update both profile_id and hospital_id in preferences
    await AuthService.saveProfileData({
      'profile_id': profileId,
      'hospital_id': hospitalId
    });
  }
} 