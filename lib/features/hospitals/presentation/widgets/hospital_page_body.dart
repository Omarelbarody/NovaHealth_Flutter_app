import 'package:flutter/material.dart';
import 'package:NovaHealth/services/hospital_service.dart';
import 'package:NovaHealth/services/auth_service.dart';
import 'package:NovaHealth/core/widgets/space_widget.dart';
import 'package:get/get.dart';

class HospitalPageBody extends StatefulWidget {
  const HospitalPageBody({super.key});

  @override
  State<HospitalPageBody> createState() => _HospitalPageBodyState();
}

class _HospitalPageBodyState extends State<HospitalPageBody> {
  bool isLoading = true;
  List<Map<String, dynamic>> hospitals = [];
  List<Map<String, dynamic>> linkedHospitals = [];
  int? currentHospitalId;
  int? currentProfileId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Load all hospitals and linked hospitals in parallel
      final results = await Future.wait([
        HospitalService.getAllHospitals(),
        HospitalService.getLinkedHospitals(),
        HospitalService.getUserProfiles(),
        AuthService.getCurrentHospitalId(),
        AuthService.getCurrentProfileId(),
      ]);

      final allHospitals = results[0] as List<Map<String, dynamic>>;
      final userLinkedHospitals = results[1] as List<Map<String, dynamic>>;
      final userProfiles = results[2] as List<Map<String, dynamic>>;
      final storedHospitalId = results[3] as int?;
      final storedProfileId = results[4] as int?;

      // Use the stored hospital ID if available, otherwise get from profiles
      int? activeHospitalId = storedHospitalId;
      int? activeProfileId = storedProfileId;
      
      // If no stored hospital ID, try to get from profiles
      if (activeHospitalId == null && userProfiles.isNotEmpty) {
        activeHospitalId = userProfiles.first['hospital_id'] as int?;
        activeProfileId = userProfiles.first['profile_id'] as int?;
        
        // Save these values for future use
        if (activeHospitalId != null && activeProfileId != null) {
          await AuthService.saveProfileData({
            'hospital_id': activeHospitalId,
            'profile_id': activeProfileId
          });
        }
      }

      setState(() {
        hospitals = allHospitals;
        linkedHospitals = userLinkedHospitals;
        currentHospitalId = activeHospitalId;
        currentProfileId = activeProfileId;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading hospitals: $e');
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load hospitals: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _linkHospital(int hospitalId) async {
    try {
      setState(() {
        isLoading = true;
      });

      await HospitalService.linkHospital(hospitalId);
      
      // Refresh the data
      await _loadData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link request sent successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error linking hospital: $e');
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to link hospital: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _unlinkHospital(int hospitalId) async {
    try {
      setState(() {
        isLoading = true;
      });

      await HospitalService.unlinkHospital(hospitalId);
      
      // Refresh the data
      await _loadData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hospital unlinked successfully'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      print('Error unlinking hospital: $e');
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to unlink hospital: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _switchHospital(int profileId, int hospitalId) async {
    try {
      setState(() {
        isLoading = true;
      });

      await HospitalService.switchHospital(profileId);
      
      // Refresh the data
      await _loadData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Switched hospital successfully'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      print('Error switching hospital: $e');
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to switch hospital: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Linked hospitals section
              if (linkedHospitals.isNotEmpty) ...[
                const Text(
                  'Your Linked Hospitals',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...linkedHospitals.map((hospital) => _buildLinkedHospitalCard(hospital)),
                const Divider(height: 32),
              ],
              
              // All hospitals section
              const Text(
                'Available Hospitals',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...hospitals.map((hospital) => _buildHospitalCard(hospital)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkedHospitalCard(Map<String, dynamic> hospital) {
    final bool isCurrentHospital = hospital['id'] == currentHospitalId;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCurrentHospital 
            ? BorderSide(color: Colors.blue, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                const SizedBox(width: 16),
                // Hospital details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              hospital['name'] ?? 'Unknown Hospital',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCurrentHospital)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
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
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.email_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  hospital['email'] ?? 'No email available',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isCurrentHospital)
                  OutlinedButton.icon(
                    onPressed: () async {
                      // Find the profile ID for this hospital
                      final profiles = await HospitalService.getUserProfiles();
                      final profile = profiles.firstWhere(
                        (p) => p['hospital_id'] == hospital['id'],
                        orElse: () => {},
                      );
                      
                      if (profile.isNotEmpty && profile['profile_id'] != null) {
                        _switchHospital(profile['profile_id'], hospital['id']);
                      }
                    },
                    icon: const Icon(Icons.swap_horiz, size: 16),
                    label: const Text('Switch'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                    ),
                  ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _showUnlinkConfirmationDialog(hospital['id']),
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

  Widget _buildHospitalCard(Map<String, dynamic> hospital) {
    // Check if this hospital is already linked
    final bool isLinked = linkedHospitals.any((h) => h['id'] == hospital['id']);
    
    if (isLinked) {
      return const SizedBox.shrink(); // Skip already linked hospitals
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                const SizedBox(width: 16),
                // Hospital details
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
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.email_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  hospital['email'] ?? 'No email available',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Link button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showLinkConfirmationDialog(hospital['id']),
                icon: const Icon(Icons.link),
                label: const Text('Link Hospital'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLinkConfirmationDialog(int hospitalId) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('Link Hospital?'),
        content: const Text('Do you want to send a request to link this hospital to your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _linkHospital(hospitalId);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue,
            ),
            child: const Text('LINK'),
          ),
        ],
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
}