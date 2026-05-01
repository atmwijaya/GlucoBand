import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/faqProvider.dart';
import '../providers/authProvider.dart';

class FaqPage extends StatefulWidget {
  const FaqPage({Key? key}) : super(key: key);

  @override
  State<FaqPage> createState() => _FaqPageState();
}

class _FaqPageState extends State<FaqPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFaqs());
  }

  void _loadFaqs() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final faqProvider = Provider.of<FaqProvider>(context, listen: false);
    if (auth.token != null) {
      faqProvider.fetchFaqs(auth.token!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FAQ')),
      body: Consumer<FaqProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.faqs.isEmpty) {
            return const Center(child: Text('Belum ada FAQ.'));
          }
          return ListView.separated(
            itemCount: provider.faqs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final faq = provider.faqs[index];
              return ExpansionTile(
                title: Text(faq.question),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(faq.answer),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}