import 'package:shared_preferences/shared_preferences.dart';

class ApiKeyService {
  static const String _keyName = 'openai_api_key';
  
  // Get saved API key
  Future<String> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyName) ?? '';
  }

  // Save new API key
  Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, apiKey);
  }

  // Delete API key
  Future<void> deleteApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyName);
  }

  // Check if API key exists
  Future<bool> hasApiKey() async {
    final key = await getApiKey();
    return key.isNotEmpty;
  }
} 