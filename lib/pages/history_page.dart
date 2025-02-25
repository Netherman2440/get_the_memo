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
                  duration: _formatDuration(meeting.duration),
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

  String _formatDuration(int? seconds) {
    if (seconds == null) return '00:00';
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(minutes)}:${twoDigits(remainingSeconds)}';
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
              '${_formatDateTime(date)} | ${_formatDuration(meeting.duration)}',
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
                icon: Icon(Icons.info),
                label: Text('Details'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                ),
                onPressed: () => _showDetailsBottomSheet(context, meeting),
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

  String _formatDuration(int? seconds) {
    if (seconds == null) return '00:00';
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(minutes)}:${twoDigits(remainingSeconds)}';
  }

  void _showDetailsBottomSheet(BuildContext context, Meeting meeting) {
    final titleController = TextEditingController(text: meeting.title);
    final viewModel = context.read<HistoryViewModel>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                
                // Title section
                Text('Title:', style: Theme.of(context).textTheme.titleSmall),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    hintText: 'Enter title',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 24),
                
                // Transcription section
                Row(
                  children: [
                    Text(
                      'Transcription',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.record_voice_over),
                      onPressed: () {
                        // TODO: Implement transcription generation
                        // viewModel.generateTranscription(meetingId);
                      },
                      tooltip: 'Generate Transcription',
                    ),
                  ],
                ),
                Container(
                  margin: EdgeInsets.only(top: 8),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    meeting.transcription ?? 'No transcription available',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                SizedBox(height: 24),
                
                // Tasks section
                Row(
                  children: [
                    Text(
                      'Tasks',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.add_task),
                      onPressed: () {
                        // TODO: Implement tasks generation
                        // viewModel.generateTasks(meetingId);
                      },
                      tooltip: 'Generate Tasks',
                    ),
                  ],
                ),
                Container(
                  margin: EdgeInsets.only(top: 8),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'No tasks available',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                
                // Action buttons
                Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel'),
                      ),
                      SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          final updatedMeeting = Meeting(
                            id: meeting.id,
                            title: titleController.text,
                            transcription: meeting.transcription,
                            createdAt: meeting.createdAt,
                            audioUrl: meeting.audioUrl,
                            description: meeting.description,
                          );
                          
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
