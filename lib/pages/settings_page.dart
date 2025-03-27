import 'package:flutter/material.dart';
import 'package:get_the_memo/services/api_key_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final apiKey = await _apiKeyService.getApiKey();
    setState(() {
      _apiKey = apiKey;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),

      body: ListView(
        children: [
          ListTile(
            title: Row(
              children: [
                Text('OPENAI API Key'),
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
            tileColor: Theme.of(context).colorScheme.surfaceContainerHigh,
            
            subtitle: TextField(
              maxLines: 1,
              onTap: () {
                print('onTap');
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
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
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
          if (_showSecurityInfo)
            ListTile(
              tileColor: Theme.of(context).colorScheme.errorContainer,
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
                  Text(
                    'Your API key is stored only on your device and is never sent to our servers. '
                    'The app communicates directly with OpenAI servers using your key.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  SizedBox(height: 8),
                  InkWell(
                    onTap: () => launchUrl(
                      Uri.parse('https://github.com/Netherman2440/get_the_memo'),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Text(
                      'View source code on GitHub',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        decoration: TextDecoration.underline,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  InkWell(
                    onTap: () => launchUrl(
                      Uri.parse('https://help.openai.com/en/articles/4936850-where-do-i-find-my-openai-api-key'),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Text(
                      'How to get OPENAI API Key?',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        decoration: TextDecoration.underline,
                        fontSize: 12,
                      ),
                    ),
                  )
                ],
              ),
            ),
        ],
      ),
    );
  }
}
