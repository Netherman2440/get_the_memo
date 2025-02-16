import 'package:flutter/material.dart';

class HistoryPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('History')),
      body: ListView.builder(
        
        itemBuilder: (context, index) {
          return HistoryItem(
            title: 'Item $index',
            date: 'Date $index',
            duration: 'Duration $index'
          );
        },
      ),
    );
  }
}


class HistoryItem extends StatelessWidget {
  final String title;
  final String date;
  final String duration;
  final String transcription;

  HistoryItem({
    required this.title, 
    required this.date, 
    required this.duration,
    this.transcription = '',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Column(
        children: [
          ListTile(
            title: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            subtitle: Text(
              '$date | $duration',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8),
              ),
            ),
            leading: Icon(Icons.mic, color: Theme.of(context).colorScheme.primary),
          ),
          OverflowBar(
            alignment: MainAxisAlignment.spaceEvenly,
            children: [
              FilledButton.icon(
                icon: Icon(Icons.send),
                label: Text('Send'),
                onPressed: () {
                  // Add send functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Sending...')),
                  );
                },
              ),
              FilledButton.icon(
                icon: Icon(Icons.edit),
                label: Text('Edit'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Edit Recording Details'),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Title:', style: Theme.of(context).textTheme.titleSmall),
                            TextField(
                              controller: TextEditingController(text: title),
                              decoration: InputDecoration(
                                hintText: 'Enter title',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            SizedBox(height: 16),
                            Text('Transcription:', style: Theme.of(context).textTheme.titleSmall),
                            TextField(
                              controller: TextEditingController(text: transcription),
                              maxLines: 5,
                              decoration: InputDecoration(
                                hintText: 'Enter transcription',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Changes saved')),
                            );
                          },
                          child: Text('Save'),
                        ),
                      ],
                    ),
                  );
                },
              ),
               FilledButton.icon(
                icon: Icon(Icons.delete),
                label: Text('Delete'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () {
                  // Add delete functionality
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Confirm Delete'),
                      content: Text('Are you sure you want to delete this item?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Item deleted')),
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.error,
                            foregroundColor: Theme.of(context).colorScheme.onError,
                          ),
                          child: Text('Delete'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
