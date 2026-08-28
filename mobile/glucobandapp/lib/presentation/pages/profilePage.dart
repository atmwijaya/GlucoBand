import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/authProvider.dart';
import '../providers/profileProvider.dart';
import '../providers/notificationProvider.dart';
import 'editHealthProfile.dart';
import 'loginPage.dart';

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
                                  color: Colors.black.withOpacity(0.04),
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

                      // Account Security Section
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
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
                              iconBgColor: const Color(0xFF613EEA).withOpacity(0.1),
                            ),
                            const Divider(height: 1, indent: 68, endIndent: 16, color: Color(0xFFE2E8F0)),
                            _buildModernMenuItem(
                              icon: Icons.shield_outlined,
                              title: 'Two-Factor Authentication',
                              onTap: () {},
                              iconColor: const Color(0xFF613EEA),
                              iconBgColor: const Color(0xFF613EEA).withOpacity(0.1),
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
                        iconBgColor: const Color(0xFF613EEA).withOpacity(0.1),
                      ),
                      const SizedBox(height: 16),

                      // About App Single Card
                      _buildSingleCardMenu(
                        icon: Icons.info_outline,
                        title: 'About App',
                        onTap: () {},
                        iconColor: const Color(0xFF613EEA),
                        iconBgColor: const Color(0xFF613EEA).withOpacity(0.1),
                      ),
                      const SizedBox(height: 16),

                      // Logout Single Card
                      _buildSingleCardMenu(
                        icon: Icons.logout,
                        title: 'Log Out',
                        onTap: () => _showLogoutDialog(context, auth),
                        iconColor: Colors.red,
                        iconBgColor: Colors.red.withOpacity(0.1),
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
    bool hideChevron = false,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
        trailing: hideChevron ? const SizedBox() : null,
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
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
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
            child: const Text('Keluar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
