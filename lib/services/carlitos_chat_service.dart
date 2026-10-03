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
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      _isLoading = false;
      notifyListeners();
      return false;
    }
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
