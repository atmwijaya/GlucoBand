import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/authProvider.dart';
import '../providers/profileProvider.dart';
import 'editHealthProfile.dart';
import 'loginPage.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      if (auth.token != null) {
        profileProvider.fetchProfile(auth.token!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[300],
                  child: const Icon(Icons.person, size: 60, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.name ?? 'Nama Pengguna',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? 'email@example.com',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 20),
                Consumer<ProfileProvider>(
                  builder: (context, provider, _) {
                    if (provider.profileData == null) {
                      return const SizedBox(
                        height: 60,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final p = provider.profileData!;
                    return Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _infoChip('BMI', (p['bmi'] ?? 0).toStringAsFixed(1)),
                            _infoChip('Berat', '${p['weight_kg'] ?? '-'} kg'),
                            _infoChip('Tinggi', '${p['height_cm'] ?? '-'} cm'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'TD: ${p['blood_pressure_sys'] ?? '-'} / ${p['blood_pressure_dia'] ?? '-'}',
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          _buildMenuItem(Icons.fitness_center, 'Edit Profil Kesehatan', () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditHealthProfilePage()),
            ).then((_) {
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
              if (auth.token != null) profileProvider.fetchProfile(auth.token!);
            });
          }),
          _buildMenuItem(Icons.help, 'Bantuan', () {}),
          _buildMenuItem(Icons.lock, 'Ubah Password', () {
            // Navigasi ke halaman ubah password (belum dibuat)
          }),
          _buildMenuItem(Icons.info, 'Tentang Aplikasi', () {}),
          const Divider(),
          _buildMenuItem(Icons.logout, 'Keluar', () {
            _showLogoutDialog(context, auth);
          }, isDestructive: true),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : Colors.blueGrey),
      title: Text(title, style: TextStyle(color: isDestructive ? Colors.red : Colors.black)),
      onTap: onTap,
      trailing: const Icon(Icons.chevron_right),
    );
  }

  Widget _infoChip(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(
            onPressed: () {
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