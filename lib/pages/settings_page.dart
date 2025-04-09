import 'package:flutter/material.dart';
import 'package:get_the_memo/services/api_key_service.dart';
import 'package:get_the_memo/services/openai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final ApiKeyService _apiKeyService = ApiKeyService();
  String _apiKey = '';
  bool _showApiKey = false;
  bool _showSecurityInfo = false;

  bool darkMode = true;
  OpenAIModel _openaiModel = OpenAIModel.o3Mini;
  SharedPreferences? prefs;

  @override
  void initState() {
    super.initState();

    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final apiKey = await _apiKeyService.getApiKey();
    prefs = await SharedPreferences.getInstance();
    final savedModel =
        prefs?.getString('openai_model') ?? OpenAIModel.o3Mini.modelId;
    _openaiModel = OpenAIModel.values.firstWhere(
      (e) => e.modelId == savedModel,
    );
    darkMode = prefs?.getBool('dark_mode') ?? true; 
    setState(() {
      _apiKey = apiKey;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        elevation: 0, // Flat design
      ),
      body: ListView(
        padding: EdgeInsets.all(16), // Add padding around the list
        children: [
          Card(
            elevation: 2,
            margin: EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                ListTile(
                  title: Row(
                    children: [
                      Text(
                        'OPENAI API Key',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.help_outline, size: 20),
                        onPressed: () {
                          setState(() {
                            _showSecurityInfo = true;
                          });
                        },
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 8),
                    child: TextField(
                      maxLines: 1,
                      onTap: () {
                        setState(() {
                          _showSecurityInfo = true;
                        });
                      },
                      controller: TextEditingController(text: _apiKey),
                      onChanged: (value) async {
                        _apiKey = value;
                        await _apiKeyService.saveApiKey(value);
                      },
                      obscureText: !_showApiKey,
                      obscuringCharacter: '*',
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceVariant,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                  trailing: IconButton(
                    onPressed: () {
                      setState(() {
                        _showApiKey = !_showApiKey;
                      });
                    },
                    icon: Icon(_showApiKey ? Icons.visibility : Icons.visibility_off),
                  ),
                ),
              ],
            ),
          ),

          if (_showSecurityInfo)
            Card(
              elevation: 2,
              margin: EdgeInsets.only(bottom: 16),
              color: Color.fromARGB(
                76,  // 30% of 255 (0.3 opacity)
                Theme.of(context).colorScheme.errorContainer.red,
                Theme.of(context).colorScheme.errorContainer.green,
                Theme.of(context).colorScheme.errorContainer.blue,
              ),
              child: ListTile(
                leading: Icon(
                  Icons.security_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Security Notice',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Your API key is stored only on your device and is never sent to our servers. '
                        'The app communicates directly with OpenAI servers using your key.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    _buildLinkButton(
                      'View source code on GitHub',
                      'https://github.com/Netherman2440/get_the_memo',
                    ),
                    SizedBox(height: 8),
                    _buildLinkButton(
                      'How to get OPENAI API Key?',
                      'https://help.openai.com/en/articles/4936850-where-do-i-find-my-openai-api-key',
                    ),
                  ],
                ),
              ),
            ),

          Card(
            elevation: 2,
            margin: EdgeInsets.only(bottom: 16),
            child: ListTile(
              title: Text(
                'OpenAI Model',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              subtitle: Padding(
                padding: EdgeInsets.only(top: 8),
                child: DropdownButtonFormField<OpenAIModel>(
                  value: _openaiModel,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceVariant,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  onChanged: (value) {
                    setState(() {
                      _openaiModel = value!;
                      prefs?.setString('openai_model', value.modelId);
                    });
                  },
                  items: OpenAIModel.values
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(e.modelId),
                          ))
                      .toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkButton(String text, String url) {
    return InkWell(
      onTap: () => launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
          fontSize: 12,
        ),
      ),
    );
  }
}
