import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/subscription_service.dart';
import '../../widgets/nutrition_ui.dart';
import '../chat/carlitos_chat_screen.dart';

class AiModuleScreen extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color accentColor;
  final List<String> upcomingFeatures;
  const AiModuleScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.upcomingFeatures,
  });
  @override
  Widget build(BuildContext context) {
    final premium = context.watch<SubscriptionService>().isPremium;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const NutritionHeading(
              'Ideas para tu alimentación',
              subtitle: 'Un espacio pensado para tus preferencias y objetivos.',
            ),
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/welcome_nutrition.png',
                height: 190,
                fit: BoxFit.cover,
                cacheWidth: 1000,
                excludeFromSemantics: true,
              ),
            ),
            const SizedBox(height: 24),
            NutritionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const NutritionStatus(
                    'En desarrollo',
                    icon: Icons.schedule_outlined,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Estamos preparando este módulo',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(subtitle),
                  const SizedBox(height: 16),
                  for (final feature in upcomingFeatures)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.eco_outlined,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              feature,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'Mientras tanto, puedes pedir ideas de comidas a Carlitos.',
                  ),
                  if (premium) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CarlitosChatScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline_rounded),
                        label: const Text('Consultar a Carlitos'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
