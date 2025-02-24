import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:get_the_memo/services/database_service.dart';
import 'package:get_the_memo/models/meeting.dart';
import 'package:get_the_memo/view_models/history_view_model.dart';
import 'package:url_launcher/url_launcher.dart';

class HistoryPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HistoryViewModel()..loadMeetings(),
      child: Scaffold(
        appBar: AppBar(title: Text('History')),
        body: Consumer<HistoryViewModel>(
          builder: (context, viewModel, child) {
            if (viewModel.isLoading) {
              return Center(child: CircularProgressIndicator());
            }

            if (viewModel.error != null) {
              return Center(child: Text(viewModel.error!));
            }

            return ListView.builder(
              itemCount: viewModel.meetings.length,
              itemBuilder: (context, index) {
                final meeting = viewModel.meetings[index];
                return HistoryItem(
                  title: meeting.title,
                  date: meeting.createdAt,
                  duration: '00:00',
                  transcription: meeting.transcription ?? '',
                  meetingId: meeting.id,
                );
              },
            );
          },
        ),
      ),
    );
  }
}


class HistoryItem extends StatelessWidget {
  final String title;
  final DateTime date;
  final String duration;
  final String transcription;
  final String meetingId;

  HistoryItem({
    required this.title, 
    required this.date, 
    required this.duration,
    required this.meetingId,
    this.transcription = '',
  });

  String _formatDateTime(DateTime dateTime) {
    // Format date as HH:mm DD-MM-YYYY
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')} '
           '${dateTime.day.toString().padLeft(2, '0')}-'
           '${dateTime.month.toString().padLeft(2, '0')}-'
           '${dateTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HistoryViewModel>();
    final bool isPlaying = viewModel.isPlaying && viewModel.currentPlayingId == meetingId;
    final meeting = viewModel.meetings.firstWhere((m) => m.id == meetingId);
    
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
              '${_formatDateTime(date)} | $duration',
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
                icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
                label: Text(isPlaying ? 'Stop' : 'Play'),
                onPressed: () async {
                  if (meeting.audioUrl != null) {
                    viewModel.playAudio(meetingId);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('No audio file available')),
                    );
                  }
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
                  // Create controllers outside the dialog
                  final titleController = TextEditingController(text: meeting.title);
                  final transcriptionController = TextEditingController(text: meeting.transcription);

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
                              controller: titleController,
                              decoration: InputDecoration(
                                hintText: 'Enter title',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            SizedBox(height: 16),
                            Text('Transcription:', style: Theme.of(context).textTheme.titleSmall),
                            TextField(
                              controller: transcriptionController,
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
                            
                            final updatedMeeting = Meeting(
                              id: meetingId,
                              title: titleController.text,
                              transcription: transcriptionController.text,
                              createdAt: date,
                              audioUrl: meeting.audioUrl,
                              description: meeting.description,
                            );

                            print('Updated meeting object:');
                            print('Title: ${updatedMeeting.title}');
                            print('Transcription: ${updatedMeeting.transcription}');
                            
                            viewModel.saveEditedMeeting(updatedMeeting);
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
                            viewModel.deleteMeeting(meetingId);
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
