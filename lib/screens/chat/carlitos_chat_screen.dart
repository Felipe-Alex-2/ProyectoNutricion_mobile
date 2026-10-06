import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../services/carlitos_chat_service.dart';
import '../../services/theme_service.dart';
import '../../services/subscription_service.dart';
import '../subscriptions/subscriptions_screen.dart';
import '../../modo_offline/conectividad_service.dart';

class CarlitosChatScreen extends StatefulWidget {
  const CarlitosChatScreen({super.key});

  @override
  State<CarlitosChatScreen> createState() => _CarlitosChatScreenState();
}

class _CarlitosChatScreenState extends State<CarlitosChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<String> _quickSuggestions = [
    '¿Qué snack saludable puedo comer?',
    '¿Cómo controlar la ansiedad por la tarde?',
    '¿Cuánta agua debo tomar si hago ejercicio?',
    '¿Puedo tomar gaseosas sin azúcar?',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.read<SubscriptionService>().isPremium) {
        context.read<CarlitosChatService>().fetchHistory();
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend([String? textOverride]) async {
    final text = textOverride ?? _textController.text;
    if (text.trim().isEmpty) return;

    final conectividad = context.read<ConectividadService>();
    if (!conectividad.estaConectado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: estás sin conexión a internet'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    _textController.clear();
    final service = context.read<CarlitosChatService>();
    final ok = await service.sendMessage(text);
    _scrollToBottom();

    if (!ok && mounted && service.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(service.errorMessage!),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final isDark = themeService.isDarkMode;
    final primaryGreen = isDark ? AppTheme.primaryGreenDark : AppTheme.primaryGreen;
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.lightCard;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    final subService = context.watch<SubscriptionService>();
    final isPremium = subService.isPremium;

    if (!isPremium) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
        appBar: AppBar(
          backgroundColor: isDark ? AppTheme.darkSidebar : AppTheme.lightSidebar,
          elevation: 0,
          title: Text(
            'Carlitos (Asistente IA)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFA855F7).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFA855F7).withValues(alpha: 0.35),
                          width: 2,
                        ),
                      ),
                      child: Image.asset(
                        'assets/images/peter_silhouette_purple.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFA855F7).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.workspace_premium_rounded, size: 16, color: Color(0xFF9333EA)),
                          SizedBox(width: 6),
                          Text(
                            'Exclusivo Plan Premium IA',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF9333EA),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Activa a Carlitos IA',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'El asistente conversacional nutricional personalizado está disponible exclusivamente para usuarios con el Plan Premium IA (\$5.00 USD/mes).\n\nSuscríbete para recibir orientación continua, aclaración de dudas sobre tu alimentación y sugerencias con inteligencia artificial según tu perfil.',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: textSecondary,
                        height: 1.45,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.star_rounded, color: Colors.white),
                        label: const Text(
                          'Obtener Plan Premium IA (\$5 USD)',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SubscriptionsScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final chatService = context.watch<CarlitosChatService>();
    final messages = chatService.messages;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkSidebar : AppTheme.lightSidebar,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: primaryGreen.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: primaryGreen.withValues(alpha: 0.3), width: 1.5),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/peter_griffin.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Carlitos (Asistente IA)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                ),
                Text(
                  'Apoyo nutricional preventivo',
                  style: TextStyle(fontSize: 11, color: textSecondary),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Borrar historial',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Limpiar Chat'),
                  content: const Text('¿Deseas vaciar los mensajes con Carlitos?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCoral),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Vaciar', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await chatService.clearHistory();
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            // Disclaimer Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: isDark ? const Color(0xFF1E281F) : const Color(0xFFE8F5E9),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: primaryGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Carlitos ofrece sugerencias educativas según tu perfil. No sustituye la consulta médica.',
                      style: TextStyle(fontSize: 11, color: primaryGreen, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

            // Messages List
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 110,
                              height: 110,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: primaryGreen.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: primaryGreen.withValues(alpha: 0.3),
                                  width: 2.5,
                                ),
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/peter_griffin.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '¡Hola! Soy Carlitos',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Conozco tus objetivos y alergias registradas en tu ficha. Pregúntame sobre alimentos, dudas de tu plan o alternativas saludables.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: textSecondary, height: 1.4),
                            ),
                            const SizedBox(height: 24),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: _quickSuggestions.map((suggestion) {
                                return ActionChip(
                                  backgroundColor: cardBg,
                                  label: Text(suggestion, style: TextStyle(fontSize: 12, color: textPrimary)),
                                  onPressed: () => _handleSend(suggestion),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isUser = msg.role == 'user';

                        return Align(
                          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.8,
                            ),
                            decoration: BoxDecoration(
                              color: isUser ? primaryGreen : cardBg,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
                                bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
                              ),
                              border: isUser
                                  ? null
                                  : Border.all(
                                      color: isDark ? Colors.white10 : const Color(0x0F000000),
                                    ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                if (!isUser) ...[
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: Image.asset(
                                          'assets/images/peter_griffin.png',
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Carlitos',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: primaryGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                ],
                                Text(
                                  msg.content,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isUser ? Colors.white : textPrimary,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            if (chatService.isLoading) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: primaryGreen),
                    ),
                    const SizedBox(width: 8),
                    Text('Carlitos está analizando tu consulta...', style: TextStyle(fontSize: 12, color: textSecondary)),
                  ],
                ),
              ),
            ],

            // Input Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSidebar : AppTheme.lightSidebar,
                border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: TextStyle(color: textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Escribe tu pregunta a Carlitos...',
                        hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                        filled: true,
                        fillColor: cardBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _handleSend(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: () => _handleSend(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
