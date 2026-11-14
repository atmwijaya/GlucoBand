import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/authProvider.dart';
import '../providers/profileProvider.dart';
import '../providers/notificationProvider.dart';
import 'editHealthProfile.dart';
import 'loginPage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/updateService.dart';
import '../../core/constants/appConstant.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
    });
  }

  Future<void> _loadProfile() async {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    await profileProvider.fetchProfile();
  }

  Future<void> _onRefresh() async {
    await _loadProfile();
    await Future.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: const Color(0xFF613EEA),
        backgroundColor: Colors.white,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Purple Header
              Container(
                width: double.infinity,
                color: const Color(0xFF613EEA),
                padding: const EdgeInsets.only(top: 60, bottom: 40, left: 16, right: 16),
                child: Column(
                  children: [
                    // Top Bar (Settings icon)
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: const Icon(Icons.settings_outlined, color: Colors.white),
                        onPressed: () {
                          // Settings action
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Avatar with Camera Badge
                    Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: CircleAvatar(
                            radius: 45,
                            backgroundColor: Colors.white,
                            backgroundImage: null, // Use user image if available
                            child: user?.name == null
                                ? const Icon(Icons.person, size: 45, color: Colors.grey)
                                : Text(
                                    user!.name[0].toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF613EEA),
                                    ),
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Name and Edit Icon
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          user?.name ?? 'Nama Pengguna',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            // Edit name action
                          },
                          child: const Icon(Icons.edit, color: Colors.white70, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? 'email@example.com',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Health Profile Data & Menu Options
              Transform.translate(
                offset: const Offset(0, -20), // Overlap slightly
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // Health Profile Section
                      Consumer<ProfileProvider>(
                        builder: (context, profileProvider, child) {
                          final profile = profileProvider.profileData;
                          final weight = profile?['weight_kg']?.toString() ?? '-';
                          final height = profile?['height_cm']?.toString() ?? '-';
                          final age = profile?['age']?.toString() ?? '-';
                          
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Profil Kesehatan',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => const EditHealthProfilePage()),
                                        );
                                        // Refresh data after edit
                                        _loadProfile();
                                      },
                                      child: const Icon(Icons.edit_note, color: Color(0xFF613EEA)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildHealthMetric('Umur', '$age th'),
                                    Container(width: 1, height: 40, color: Colors.grey[200]),
                                    _buildHealthMetric('Tinggi', '$height cm'),
                                    Container(width: 1, height: 40, color: Colors.grey[200]),
                                    _buildHealthMetric('Berat', '$weight kg'),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Card Tenaga Medis Penanggung Jawab
                      Consumer<ProfileProvider>(
                        builder: (context, profileProvider, child) {
                          final profile = profileProvider.profileData;
                          final doctorName = (profile?['tenaga_medis_name'] ?? profile?['medical_staff_name'])?.toString();
                          final doctorPhone = (profile?['tenaga_medis_phone'] ?? profile?['medical_staff_phone'])?.toString();
                          final doctorSpec = (profile?['tenaga_medis_specialization'] ?? profile?['medical_staff_specialization'])?.toString() ?? 'Tenaga Medis Penanggung Jawab';

                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF613EEA).withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.medical_services, color: Color(0xFF613EEA), size: 20),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text(
                                      'Tenaga Medis Anda',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                if (doctorName != null && doctorName.isNotEmpty) ...[
                                  Text(
                                    doctorName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    doctorSpec,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF613EEA),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Kontak Darurat: $doctorPhone',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      if (doctorPhone != null) ...[
                                        InkWell(
                                          onTap: () async {
                                            String wa = doctorPhone.trim();
                                            if (wa.startsWith('0')) wa = '62${wa.substring(1)}';
                                            final url = Uri.parse('https://wa.me/$wa');
                                            if (await canLaunchUrl(url)) {
                                              await launchUrl(url, mode: LaunchMode.externalApplication);
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Row(
                                              children: [
                                                Icon(Icons.chat, color: Colors.green, size: 14),
                                                SizedBox(width: 4),
                                                Text('WA', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        InkWell(
                                          onTap: () async {
                                            final url = Uri.parse('tel:$doctorPhone');
                                            if (await canLaunchUrl(url)) await launchUrl(url);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Row(
                                              children: [
                                                Icon(Icons.phone, color: Colors.blue, size: 14),
                                                SizedBox(width: 4),
                                                Text('Panggil', style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ] else ...[
                                  Text(
                                    'Belum ditentukan oleh tenaga medis.',
                                    style: TextStyle(fontSize: 13, color: Colors.grey[500], fontStyle: FontStyle.italic),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Pusat Bantuan Siaga Umum: 119',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Account Security Section
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                              child: Text(
                                'Account Security',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            _buildModernMenuItem(
                              icon: Icons.lock_outline,
                              title: 'Change Password',
                              onTap: () {},
                              iconColor: const Color(0xFF613EEA),
                              iconBgColor: const Color(0xFF613EEA).withValues(alpha: 0.1),
                            ),
                            const Divider(height: 1, indent: 68, endIndent: 16, color: Color(0xFFE2E8F0)),
                            _buildModernMenuItem(
                              icon: Icons.shield_outlined,
                              title: 'Two-Factor Authentication',
                              onTap: () {},
                              iconColor: const Color(0xFF613EEA),
                              iconBgColor: const Color(0xFF613EEA).withValues(alpha: 0.1),
                              trailing: Switch(
                                value: false,
                                onChanged: (val) {},
                                activeThumbColor: const Color(0xFF613EEA),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Help & Support Single Card
                      _buildSingleCardMenu(
                        icon: Icons.help_outline,
                        title: 'Help & Support',
                        onTap: () {},
                        iconColor: const Color(0xFF613EEA),
                        iconBgColor: const Color(0xFF613EEA).withValues(alpha: 0.1),
                      ),
                      const SizedBox(height: 16),

                      // About App Single Card
                      _buildSingleCardMenu(
                        icon: Icons.info_outline,
                        title: 'About App',
                        onTap: () {},
                        iconColor: const Color(0xFF613EEA),
                        iconBgColor: const Color(0xFF613EEA).withValues(alpha: 0.1),
                      ),
                      const SizedBox(height: 16),

                      // Periksa Pembaruan Aplikasi Card
                      _buildSingleCardMenu(
                        icon: Icons.system_update_outlined,
                        title: 'Periksa Pembaruan',
                        onTap: () => UpdateService.checkForUpdate(context, isManual: true),
                        iconColor: const Color(0xFF613EEA),
                        iconBgColor: const Color(0xFF613EEA).withValues(alpha: 0.1),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'v${AppConstants.currentVersion}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF613EEA),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Logout Single Card
                      _buildSingleCardMenu(
                        icon: Icons.logout,
                        title: 'Log Out',
                        onTap: () => _showLogoutDialog(context, auth),
                        iconColor: Colors.red,
                        iconBgColor: Colors.red.withValues(alpha: 0.1),
                        titleColor: Colors.red,
                        hideChevron: true,
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _buildSingleCardMenu({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required Color iconColor,
    required Color iconBgColor,
    Color? titleColor,
    Widget? trailing,
    bool hideChevron = false,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: _buildModernMenuItem(
        icon: icon,
        title: title,
        onTap: onTap,
        iconColor: iconColor,
        iconBgColor: iconBgColor,
        titleColor: titleColor,
        trailing: trailing ?? (hideChevron ? const SizedBox() : null),
      ),
    );
  }

  Widget _buildModernMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required Color iconColor,
    required Color iconBgColor,
    Color? titleColor,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: titleColor ?? const Color(0xFF1E293B),
                ),
              ),
            ),
            if (trailing != null)
              trailing
            else
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text(
          'Konfirmasi Logout',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Color(0xFF1E293B),
          ),
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari akun ini?',
          style: TextStyle(
            color: Color(0xFF475569),
            fontSize: 15,
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[600],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          ),
          ElevatedButton(
            onPressed: () {
              final notifProvider = Provider.of<NotificationProvider>(context, listen: false);
              notifProvider.disconnectSocket();
              auth.logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (_) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Keluar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }
}
