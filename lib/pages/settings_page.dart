import 'package:flutter/material.dart';
import 'package:get_the_memo/services/api_key_service.dart';
import 'package:get_the_memo/services/openai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:get_the_memo/theme/text_styles.dart';

class SettingsPage extends StatefulWidget {
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final ApiKeyService _apiKeyService = ApiKeyService();
  String _apiKey = '';
  bool _showApiKey = false;
  bool _showSecurityInfo = false;
  bool _betterResults = false;
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
    _betterResults = prefs?.getBool('better_results') ?? false;
    setState(() {
      _apiKey = apiKey;
    });
  }

  @override
  Widget build(BuildContext context) {
    String subtitle = _betterResults ? 'Wolno i dokładnie' : 'Szybko i prosto';
    String workDescription =
        _betterResults
            ? '• Transkrypcja jest przetwarzana w celu usunięcia powtórzeń, błędów i poprawy kontekstu\n'
                '• Podsumowanie koncentruje się na wnioskach ze spotkania i szczególnie zwraca uwagę na kluczowe frazy\n'
                '• Punkty akcji są generowane poprzez wielokrotne iteracje i logiczne łączenie każdej generacji\n\n'
                'Ta opcja jest droższa, ale powinna dawać lepsze wyniki'
            : '• Transkrypcja jest używana bez ulepszeń\n'
                '• Podsumowanie obejmuje całe spotkanie bez szczególnego ukierunkowania\n'
                '• Punkty akcji są generowane w pojedynczym przebiegu\n\n'
                'Ta opcja jest tańsza, ale wyniki mogą być mniej dokładne';
    return Scaffold(
      appBar: AppBar(
        title: Text('Ustawienia'),
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
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
                        'Klucz OPENAI API',
                        style: AppTextStyles.contentStyle.copyWith(
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
                    icon: Icon(
                      _showApiKey ? Icons.visibility : Icons.visibility_off,
                    ),
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
                76, // 30% of 255 (0.3 opacity)
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
                  'Informacja o bezpieczeństwie',
                  style: AppTextStyles.contentStyle.copyWith(
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
                        'Twój klucz API jest przechowywany tylko na Twoim urządzeniu i nigdy nie jest wysyłany na nasze serwery. '
                        'Aplikacja komunikuje się bezpośrednio z serwerami OpenAI używając Twojego klucza.',
                        style: AppTextStyles.labelStyle.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    _buildLinkButton(
                      'Zobacz kod źródłowy na GitHub',
                      'https://github.com/Netherman2440/get_the_memo',
                    ),
                    SizedBox(height: 8),
                    _buildLinkButton(
                      'Jak uzyskać klucz OPENAI API?',
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
                'Model OpenAI',
                style: AppTextStyles.contentStyle.copyWith(
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
                  items:
                      OpenAIModel.values
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(e.modelId),
                            ),
                          )
                          .toList(),
                ),
              ),
            ),
          ),

          Card(
            elevation: 2,
            margin: EdgeInsets.only(bottom: 16),
            child: ListTile(
              title: Text('Jak ma działać AI?'),
              subtitle: Text(subtitle),
              trailing: Switch(
                value: _betterResults,
                onChanged: (value) {
                  setState(() {
                    _betterResults = value;
                    prefs?.setBool('better_results', value);
                  });
                },
              ),
            ),
          ),

          Card(
            elevation: 2,
            margin: EdgeInsets.only(bottom: 16),
            child: ListTile(
              title: Text('Jak to działa?'),
              subtitle: Text(workDescription),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkButton(String text, String url) {
    return InkWell(
      onTap:
          () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Text(
        text,
        style: AppTextStyles.labelStyle.copyWith(
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
