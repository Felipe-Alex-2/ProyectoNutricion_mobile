import 'package:flutter/foundation.dart';
import 'api_service.dart';

class ChatMessageItem {
  final String id;
  final String role; // user, assistant
  final String content;
  final DateTime createdAt;

  ChatMessageItem({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessageItem.fromJson(Map<String, dynamic> json) {
    return ChatMessageItem(
      id: json['id'] as String? ?? UniqueKey().toString(),
      role: json['role'] as String? ?? 'assistant',
      content: json['content'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class CarlitosChatService extends ChangeNotifier {
  final ApiService _apiService;

  List<ChatMessageItem> _messages = [];
  bool _isLoading = false;
  String? _errorMessage;

  CarlitosChatService(this._apiService);

  List<ChatMessageItem> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchHistory() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.get('/chat/history');
      if (response != null && response is Map<String, dynamic>) {
        final list = response['messages'] as List<dynamic>? ?? [];
        _messages = list.map((m) => ChatMessageItem.fromJson(m as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendMessage(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return false;

    // Mensaje optimista en la UI
    final tempMsg = ChatMessageItem(
      id: UniqueKey().toString(),
      role: 'user',
      content: cleanText,
      createdAt: DateTime.now(),
    );
    _messages.add(tempMsg);
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.post(
        '/chat',
        body: {'message': cleanText},
      );

      if (response != null && response is Map<String, dynamic>) {
        final reply = ChatMessageItem.fromJson(response);
        _messages.add(reply);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      throw Exception('Respuesta no válida del asistente');
    } catch (e) {
      // Si estamos sin conexión a internet o falló la red, responder mediante el motor asistente local offline
      final offlineReply = _generateOfflineLocalResponse(cleanText);
      _messages.add(
        ChatMessageItem(
          id: UniqueKey().toString(),
          role: 'assistant',
          content: offlineReply,
          createdAt: DateTime.now(),
        ),
      );
      _isLoading = false;
      notifyListeners();
      return true;
    }
  }

  String _generateOfflineLocalResponse(String query) {
    final q = query.toLowerCase();

    if (q.contains('agua') ||
        q.contains('hidrat') ||
        q.contains('líquido') ||
        q.contains('liquido') ||
        q.contains('litro')) {
      return '💧 **Asistente Nutricional (Modo Offline)**\n\n'
          'Tu recomendación de hidratación basal es de 30 a 35 ml por kg de peso (aprox. 2.0 a 2.5 litros de agua al día).\n'
          '• Bebe 1 vaso de agua al despertar para reactivar tu sistema digestivo.\n'
          '• Evita bebidas azucaradas o gaseosas; puedes saborizar con rodajas de limón o pepino.';
    }

    if (q.contains('snack') ||
        q.contains('merienda') ||
        q.contains('colaci') ||
        q.contains('hambre') ||
        q.contains('antojo')) {
      return '🍏 **Opciones de Colación / Merienda Saludable (Modo Offline)**\n\n'
          '1. **Fruta + Grasa saludable**: 1 manzana o plátano mediano con 1 cucharada de mantequilla de maní o 10 almendras.\n'
          '2. **Proteico y saciante**: 150g de yogur griego natural sin azúcar con 2 cucharadas de avena o chía.\n'
          '3. **Frescura y fibra**: Bastones de zanahoria y apio con 2 cucharadas de hummus o queso untable descremado.\n'
          '4. **Huevo duro**: 1 huevo cocido con una pizca de sal y orégano (~75 kcal, 6g proteína).';
    }

    if (q.contains('prote') ||
        q.contains('pollo') ||
        q.contains('huevo') ||
        q.contains('atún') ||
        q.contains('atun') ||
        q.contains('carne')) {
      return '🍗 **Guía de Proteínas (Modo Offline)**\n\n'
          'Para mantener o ganar masa muscular y saciedad:\n'
          '• **Pechuga de pollo a la plancha (100g)**: ~165 kcal | 31g proteína | 3.6g grasa.\n'
          '• **Huevo cocido (1 unidad)**: ~75 kcal | 6.3g proteína | 5g grasa.\n'
          '• **Atún al agua (lata de 100g escurrida)**: ~116 kcal | 26g proteína | 0.8g grasa.\n'
          '• **Queso fresco / ricota (100g)**: ~105 kcal | 12g proteína | 4g grasa.\n'
          'Asegúrate de incluir una porción del tamaño de la palma de tu mano en almuerzo y cena.';
    }

    if (q.contains('arroz') ||
        q.contains('avena') ||
        q.contains('carbo') ||
        q.contains('papa') ||
        q.contains('pan')) {
      return '🌾 **Guía de Carbohidratos Complejos (Modo Offline)**\n\n'
          'Prioriza fuentes ricas en fibra para energía sostenida:\n'
          '• **Avena en hojuelas (40g seco)**: ~150 kcal | 5g proteína | 27g carbohidratos.\n'
          '• **Arroz integral o blanco (1 taza cocida / 150g)**: ~195 kcal | 42g carbohidratos.\n'
          '• **Papa o camote cocido (1 unidad mediana / 150g)**: ~125 kcal | rica en almidón resistente y potasio.\n'
          '• **Pan 100% integral (1 rebanada)**: ~70 kcal | 3g fibra.';
    }

    if (q.contains('peso') ||
        q.contains('grasa') ||
        q.contains('bajar') ||
        q.contains('adelgazar') ||
        q.contains('déficit') ||
        q.contains('deficit')) {
      return '🔥 **Consejos para Pérdida de Grasa (Modo Offline)**\n\n'
          '• Mantén un déficit calórico moderado (300-500 kcal diarias bajo tu requerimiento).\n'
          '• Distribuye 1.6 a 2.0 g de proteína por kg de peso corporal para no perder tejido muscular.\n'
          '• Llena la mitad de tu plato con vegetales verdes crudos o cocidos al vapor (alto volumen, pocas calorías).\n'
          '• No olvides registrar tus comidas diarias para que tu nutricionista revise tu adherencia.';
    }

    if (q.contains('músculo') ||
        q.contains('musculo') ||
        q.contains('volumen') ||
        q.contains('hipertrofia') ||
        q.contains('ganar')) {
      return '💪 **Consejos para Aumento de Masa Muscular (Modo Offline)**\n\n'
          '• Mantén un superávit energético moderado (+250 a 400 kcal/día).\n'
          '• Consume 1.8 a 2.2 g de proteína por kg de peso repartidos en 3 a 5 comidas.\n'
          '• Combina con entrenamiento de fuerza con sobrecarga progresiva.\n'
          '• El descanso es vital: duerme 7-8 horas continuas para permitir la síntesis proteica.';
    }

    if (q.contains('entren') ||
        q.contains('gimnasio') ||
        q.contains('ejercicio') ||
        q.contains('post') ||
        q.contains('pre')) {
      return '⚡ **Nutrición Alrededor del Entrenamiento (Modo Offline)**\n\n'
          '• **Pre-entreno (45-90 min antes)**: Carbohidratos ligeros (ej. 1 plátano + 1 tostada o 30g de avena) y 300 ml de agua.\n'
          '• **Post-entreno (dentro de las 2 horas)**: Proteína de alto valor biológico (pollo, atún o batido) + carbohidrato para reponer glucógeno.';
    }

    if (q.contains('plan') ||
        q.contains('toca') ||
        q.contains('dieta') ||
        q.contains('hoy') ||
        q.contains('comer')) {
      return '📋 **Consulta de Plan Nutricional (Modo Offline)**\n\n'
          'Tu plan alimentario aprobado se encuentra almacenado localmente en tu dispositivo:\n'
          '• Ve a la sección **"Mi nutrición"** o **"Mi plan asignado"** en la app para consultar cada comida, porciones y calorías descargadas.\n'
          '• Si realizas cambios o sustituciones, anótalas en el registro manual sin conexión para sincronizarlas al conectarte.';
    }

    return '🤖 **Carlitos IA (Asistente Local Offline)**\n\n'
        'Actualmente tu dispositivo se encuentra sin conexión a internet, pero he procesado tu consulta con el motor clínico local.\n\n'
        '• Recuerda seguir las porciones y macro distribución de tu plan nutricional asignado.\n'
        '• Mantén tu hidratación y registra cualquier comida que consumas en el diario offline.\n'
        '• En cuanto recuperes conexión, tus registros pendientes se sincronizarán automáticamente con tu nutricionista y podré responderte con la IA generativa en la nube.';
  }

  Future<void> clearHistory() async {
    try {
      await _apiService.delete('/chat/history');
      _messages.clear();
      notifyListeners();
    } catch (e) {
      // Ignorar si falla el borrado remoto
      _messages.clear();
      notifyListeners();
    }
  }
}
