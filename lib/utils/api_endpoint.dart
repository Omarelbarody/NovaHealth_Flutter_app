class ApiEndPoints {
  static const String proxy = '1d1f28dfea3b.ngrok-free.app';
  static const String baseUrl = 'https://1d1f28dfea3b.ngrok-free.app/api/v1/';

  static AuthEndPoints authEndpoints = AuthEndPoints();
  static DoctorEndPoints doctorEndpoints = DoctorEndPoints();
  static ProfileEndPoints profileEndpoints = ProfileEndPoints();
  static PrescriptionEndPoints prescriptionEndpoints = PrescriptionEndPoints();
  static SchedulingEndPoints schedulingEndpoints = SchedulingEndPoints();
}

class AuthEndPoints {
  final String login = 'auth/login/';
  final String register = 'auth/signup/';
  final String verifyOtp = 'auth/verify-otp/';
  final String resetPassword = 'auth/reset-password/';
  final String sendOtp = 'auth/send-otp/';
  final String signup = 'auth/register/';
}

class DoctorEndPoints {
  String doctorsBySpecialty(String specialty, String date, String hospital_id, String profile_id) {
    return 'profiles/doctors/?specialty=$specialty&date=$date&hospital_id=$hospital_id&profile_id=$profile_id';
  }
}

class ProfileEndPoints {
  final String patients = 'profiles/patients/';
  final String doctors = 'profiles/doctors/';
}

class PrescriptionEndPoints {
  final String prescriptions = 'prescriptions/';
  
  String getPrescriptions(String profile_id) {
    return 'prescriptions/?profile_id=$profile_id';
  }
}

class SchedulingEndPoints {
  String queueStatus(int appointmentId) {
    return 'scheduling/appointments/$appointmentId/queue-status';
  }
  
  String cancelAppointment(int appointmentId) {
    return 'scheduling/appointments/$appointmentId/cancel/';
  }
  
  String bookAppointment(String profile_id) {
    return 'scheduling/appointments/book-cash/?profile_id=$profile_id';
  }
}
