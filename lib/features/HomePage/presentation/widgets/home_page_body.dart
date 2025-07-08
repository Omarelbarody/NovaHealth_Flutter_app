import 'package:NovaHealth/core/utils/size_config.dart';
import 'package:NovaHealth/core/widgets/space_widget.dart';
import 'package:NovaHealth/features/Activities/presentation/widgets/Activities_page_body.dart';
import 'package:NovaHealth/features/Auth/presentation/pages/sign%20up/widgets/sign_up_view.dart';
import 'package:NovaHealth/features/ChatBot/presentation/widgets/chatbot_page_view.dart';
import 'package:NovaHealth/features/Consultaion/presentation/widgets/department_page_body.dart';
import 'package:NovaHealth/features/Consultaion/presentation/widgets/department_page_view.dart';
import 'package:NovaHealth/features/HomePage/presentation/widgets/home_page_view.dart';
import 'package:NovaHealth/features/MedicaNews/presentation/widgets/medical_news_view.dart';
import 'package:NovaHealth/features/Nova%20Ai/presentation/widgets/nova_ai_page_view.dart';
import 'package:NovaHealth/features/ProfilePage/Presentation/widgets/profile_page_body.dart';
import 'package:NovaHealth/features/ProfilePage/Presentation/widgets/profile_page_view.dart';
import 'package:NovaHealth/features/Activities/presentation/widgets/Activities_page_view.dart';
import 'package:NovaHealth/features/hospitals/presentation/pages/hospital_page_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_navigation/src/routes/transitions_type.dart';
import 'package:NovaHealth/features/HomePage/data/models/appointment_model.dart';
import 'package:NovaHealth/services/appointment_service.dart';
import 'package:intl/intl.dart';
import 'package:NovaHealth/features/HomePage/presentation/widgets/appointments_list_page.dart';
import 'package:NovaHealth/services/hospital_service.dart';

class HomePageBody extends StatefulWidget {
  const HomePageBody({super.key});

  @override
  _HomePageBodyState createState() => _HomePageBodyState();
}

class _HomePageBodyState extends State<HomePageBody> {
  int _selectedIndex = 0;
  final homeContentKey = GlobalKey<_HomeContentState>();

  List<Widget> get _pages => [
    HomeContent(key: homeContentKey),
    const ActivitiesContent(),
    const ProfileContent(),
  ];

  void _onItemTapped(int index) {
    if (_selectedIndex == index) {
      // If tapping the home tab while already on it, refresh appointments
      if (index == 0 && homeContentKey.currentState != null) {
        homeContentKey.currentState!._loadAppointments();
        homeContentKey.currentState!._loadLinkedHospital();
      }
      return; // Do nothing else if already selected
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //***********************************************Nova bot************************************************* */
      body: Stack(
        children: [
          _pages[_selectedIndex],
          if (_selectedIndex == 0) // Show FAB only on HomeContent page
            Positioned(
              bottom: 5,
              right: 5,
              child: SizedBox(
                height: 82,
                width: 92,
                child: FloatingActionButton(
                  onPressed: () {
                    Get.to(() => ChatbotPageView(),
                        transition: Transition.rightToLeft,
                        duration: const Duration(milliseconds: 150));
                    // Add your AI bot functionality here
                  },
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  child: Image.asset(
                    'assets/images/Ai bot.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
        ],
      ),
      //*****************************************Home&Activities&Profile bar************************************** */
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 0.5, thickness: 1),
          BottomNavigationBar(
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined, size: 28),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.assignment_outlined, size: 28),
                label: 'Activities',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline, size: 28),
                label: 'Profile',
              ),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor: Colors.blue,
            unselectedItemColor: Colors.grey,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400),
            showUnselectedLabels: true,
            onTap: _onItemTapped,
            // type: BottomNavigationBarType.fixed,
            // elevation: 0,
            backgroundColor: Colors.white,
          ),
        ],
      ),
    );
  }
}

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  _HomeContentState createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  List<AppointmentModel> upcomingAppointments = [];
  bool isLoading = true;
  bool isLoadingHospital = true;
  Map<String, dynamic> linkedHospital = {};

  @override
  void initState() {
    super.initState();
    _loadAppointments();
    _loadLinkedHospital();
  }
  
  Future<void> _loadLinkedHospital() async {
    try {
      setState(() {
        isLoadingHospital = true;
      });
      
      final hospital = await HospitalService.getLinkedHospital();
      
      setState(() {
        linkedHospital = hospital;
        isLoadingHospital = false;
      });
    } catch (e) {
      print('Error loading linked hospital: $e');
      setState(() {
        isLoadingHospital = false;
      });
    }
  }

  Future<void> _loadAppointments() async {
    try {
      final appointments = await AppointmentService.getUpcomingAppointments();
      setState(() {
        upcomingAppointments = appointments;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading appointments: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // Cancel appointment function
  Future<void> _cancelAppointment(int appointmentId) async {
    try {
      // Immediately remove the appointment from the UI for better responsiveness
      setState(() {
        upcomingAppointments.removeWhere((a) => a.appointmentId == appointmentId);
      });
      
      // Show immediate feedback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment cancelled'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.blue,
        ),
      );
      
      // Delete from storage asynchronously
      await AppointmentService.deleteAppointment(appointmentId);
      
      // No need to reload all appointments since we've already updated the UI
    } catch (e) {
      print('Error cancelling appointment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel appointment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show confirmation dialog before cancelling
  void _showCancelConfirmationDialog(AppointmentModel appointment) {
    // Use a simpler dialog for better performance
    showDialog(
      context: context,
      barrierDismissible: true, // Allow tapping outside to dismiss
      builder: (context) => AlertDialog(
        title: const Text('Cancel Appointment?'),
        content: const Text('This appointment will be removed from your schedule.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('NO'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelAppointment(appointment.appointmentId);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('YES'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          _loadAppointments(),
          _loadLinkedHospital(),
        ]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(), // Enable scrolling even when content is small
        reverse: true,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //***********************************************logo************************************************* */
              VerticallSpace(5),
              Row(
                children: [
                  HorizintalSpace(1),
                  SizedBox(
                    child: Image.asset('assets/images/logo.png'),
                  )
                ],
              ),
              VerticallSpace(2),
              //***********************************************How can we help?************************************************* */

              Row(
                children: [
                  HorizintalSpace(3),
                  const Text(
                    'How can we help?',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              Row(
              //***********************************************consultaion**************************************** */
                
                children: [
                  HorizintalSpace(1),
                  InkWell(
                    onTap: () {
                      Get.to(() => DepartmentView(),
                          transition: Transition.rightToLeft,
                          duration: const Duration(milliseconds: 150));
                    },
                    child: Ink.image(
                      image: const AssetImage('assets/images/consultaion.png'),
                      height: 107,
                      width: 120.33,
                      fit: BoxFit.cover,
                    ),
                  ),
                  InkWell(
              //***********************************************Laboratory**************************************** */
                    onTap: () {},
                    child: Ink.image(
                      image: const AssetImage('assets/images/Laboratory.png'),
                      height: 107,
                      width: 120.33,
                      fit: BoxFit.cover,
                    ),
                  ),
                  InkWell(
              //***********************************************Radiology**************************************** */
                
                    onTap: () {},
                    child: Ink.image(
                      image: const AssetImage('assets/images/Radiology.png'),
                      height: 107,
                      width: 120.33,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
              VerticallSpace(1),
              //***********************************************Don't feel right?**************************************** */

              Row(
                children: [
                  HorizintalSpace(2),
                  const Text(
                    'Don\'t feel right?',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              //***********************************************NovaAi**************************************** */

              Row(
                children: [
                  InkWell(
                    onTap: () {
                      Get.to(() => NovaAiPageView(),
                          transition: Transition.rightToLeft,
                          duration: const Duration(milliseconds: 150));
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        alignment: Alignment.centerRight,
                        children: [
                          Ink.image(
                            image: const AssetImage('assets/images/NovaAi.png'),
                            height: 98,
                            width: 380,
                            fit: BoxFit.cover,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 20),
                              child: Image.asset(
                                'assets/images/o3.png',
                                width: 50,
                                height: 100,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              ),
              VerticallSpace(1),
              //***********************************************Upcoming Appointments**************************************** */

              Row(
                children: [
                  HorizintalSpace(2),
                  const Text(
                    'Upcoming Appointments',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const Spacer(),
                  if (upcomingAppointments.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        // Navigate to appointments list view with refresh callback
                        Get.to(
                          () => AppointmentsListPage(
                            onReturn: () => _loadAppointments(),
                          ),
                          transition: Transition.rightToLeft,
                          duration: const Duration(milliseconds: 150)
                        );
                      },
                      child: const Text(
                        'See All',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Color.fromARGB(255, 45, 132, 251),
                        ),
                      ),
                    ),
                  HorizintalSpace(1),
                ],
              ),
              VerticallSpace(1),
              //***********************************************Appointment Cards**************************************** */

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    HorizintalSpace(2),
                    if (isLoading)
                      const SizedBox(
                        height: 150, // Match the height of appointment cards
                        width: 218,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (upcomingAppointments.isEmpty)
                      Container(
                        height: 150, // Match the height of appointment cards
                        width: 218,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'No upcoming appointments',
                            style: TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      )
                    else
                      ...upcomingAppointments.map((appointment) => 
                        Padding(
                          padding: const EdgeInsets.only(right: 16.0),
                          child: _buildAppointmentCard(appointment),
                        ),
                      ).toList(),
                  ],
                ),
              ),
              VerticallSpace(1),
              //***********************************************Linked Hospital**************************************** */

              Row(
                children: [
                  HorizintalSpace(2),
                  const Text(
                    'Linked Hospital',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              VerticallSpace(1),
              //***********************************************Hospital Card**************************************** */
              
              FutureBuilder<Map<String, dynamic>>(
                future: isLoadingHospital ? Future.value(linkedHospital) : HospitalService.getLinkedHospital(),
                builder: (context, snapshot) {
                  if (isLoadingHospital && linkedHospital.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return _buildLinkHospitalButton();
                  } else {
                    final hospital = snapshot.data ?? linkedHospital;
                    if (hospital.isEmpty) {
                      return _buildLinkHospitalButton();
                    } else {
                      return _buildLinkedHospitalCard(hospital);
                    }
                  }
                },
              ),
              
              VerticallSpace(3),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildAppointmentCard(AppointmentModel appointment) {
    // Format date for display
    String formattedDate = '';
    try {
      final date = DateFormat('yyyy-MM-dd').parse(appointment.date);
      formattedDate = DateFormat('EEE, MMM d').format(date);
    } catch (e) {
      formattedDate = appointment.date;
    }
    
    return Container(
      height: 180, // Increased height to accommodate cancel button
      width: 218,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background color
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.blue.withOpacity(0.1), Colors.white],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Use minimum space needed
              children: [
                Text(
                  formattedDate,
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  appointment.time,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Dr. ${appointment.doctorName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  appointment.specialty,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                // Cancel Button
                SizedBox(
                  width: double.infinity,
                  height: 30,
                  child: TextButton(
                    onPressed: () => _showCancelConfirmationDialog(appointment),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: const Size(0, 30),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cancel_outlined, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Cancel',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkHospitalButton() {
    return Center(
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            const Text(
              'No hospital linked to your account',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Get.to(() => HospitalPageView(),
                    transition: Transition.rightToLeft,
                    duration: const Duration(milliseconds: 150));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Link Hospital'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkedHospitalCard(Map<String, dynamic> hospital) {
    return Center(
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Hospital logo
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    hospital['logo'] ?? '',
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[200],
                        child: const Icon(Icons.local_hospital, color: Colors.grey),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Hospital name and type
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hospital['name'] ?? 'Unknown Hospital',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          hospital['type']?.toUpperCase() ?? 'UNKNOWN',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Connected status indicator
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Connected',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Hospital address
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    hospital['address'] ?? 'No address available',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Hospital contact
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  hospital['phone_number'] ?? 'No phone available',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Get.to(() => HospitalPageView(),
                        transition: Transition.rightToLeft,
                        duration: const Duration(milliseconds: 150));
                  },
                  icon: const Icon(Icons.swap_horiz, size: 16),
                  label: const Text('Change'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    _showUnlinkConfirmationDialog(hospital['id']);
                  },
                  icon: const Icon(Icons.link_off, size: 16),
                  label: const Text('Unlink'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  void _showUnlinkConfirmationDialog(int hospitalId) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('Unlink Hospital?'),
        content: const Text('Are you sure you want to unlink this hospital from your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _unlinkHospital(hospitalId);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('UNLINK'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _unlinkHospital(int hospitalId) async {
    try {
      await HospitalService.unlinkHospital(hospitalId);
      setState(() {}); // Refresh the UI
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hospital unlinked successfully'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      print('Error unlinking hospital: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to unlink hospital: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
