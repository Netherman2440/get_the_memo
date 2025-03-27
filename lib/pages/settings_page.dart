import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _apiKey = '';
  bool _showApiKey = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),

      body: ListView(
        children: [
          ListTile(
            title: Text('Api Key'),
            tileColor: Theme.of(context).colorScheme.surfaceContainerHigh,
            subtitle: TextField(
              onChanged: (value) {
                _apiKey = value;
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
        ],
      ),
    );
  }
}
