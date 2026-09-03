import 'package:flutter/material.dart';
import 'berandaPage.dart';
import 'predictionPage.dart';
import 'measurementPage.dart';
import 'faqPage.dart';
import 'profilePage.dart';
import 'package:provider/provider.dart';
import '../providers/settingsProvider.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  
  void setIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  final List<Widget> _pages = const [
    BerandaPage(),
    PredictionPage(),
    MeasurementPage(),
    FaqPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      floatingActionButton: _currentIndex != 2 ? FloatingActionButton(
        onPressed: () {
          final settings = Provider.of<SettingsProvider>(context, listen: false);
          final number = settings.emergencyContact ?? '119';
          
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Hubungi Darurat',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chat, color: Colors.green),
                    ),
                    title: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(number),
                    onTap: () async {
                      Navigator.pop(context);
                      String waNumber = number;
                      if (waNumber.startsWith('0')) {
                        waNumber = '62${waNumber.substring(1)}';
                      }
                      final url = Uri.parse('https://wa.me/$waNumber');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Tidak dapat membuka WhatsApp')),
                          );
                        }
                      }
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.phone, color: Colors.blue),
                    ),
                    title: const Text('Telepon Pulsa', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(number),
                    onTap: () async {
                      Navigator.pop(context);
                      final url = Uri.parse('tel:$number');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Tidak dapat melakukan panggilan telepon')),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
        backgroundColor: Colors.redAccent,
        child: const Icon(Icons.phone, color: Colors.white),
      ) : null,
      bottomNavigationBar: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Bar latar belakang
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey.withValues(alpha: 0.1), width: 1),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildNavItem(0, Icons.home_outlined, Icons.home, 'Home'),
                    _buildNavItem(1, Icons.show_chart, Icons.show_chart, 'Predict'),
                    const SizedBox(width: 56), // ruang untuk tombol tengah
                    _buildNavItem(3, Icons.help_outline, Icons.help, 'FAQ'),
                    _buildNavItem(4, Icons.person_outline, Icons.person, 'Profile'),
                  ],
                ),
              ),
            ),
          ),
          // Tombol Ukur melayang (FAB)
          Positioned(
            top: -24,
            child: GestureDetector(
              onTap: () => setIndex(2),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF613EEA).withValues(alpha: 0.2), // Halo effect
                ),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF613EEA),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x66613EEA),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.monitor_heart_outlined,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData outlinedIcon, IconData filledIcon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setIndex(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? filledIcon : outlinedIcon,
              color: isSelected ? const Color(0xFF613EEA) : const Color(0xFF94A3B8),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? const Color(0xFF613EEA) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
