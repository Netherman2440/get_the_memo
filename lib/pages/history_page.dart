import 'package:flutter/material.dart';
import 'package:get_the_memo/pages/details_page.dart';
import 'package:provider/provider.dart';
import 'package:get_the_memo/models/meeting.dart';
import 'package:get_the_memo/view_models/history_view_model.dart';

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
  final String meetingId;

  HistoryItem({
    required this.title,
    required this.date,
    required this.duration,
    required this.meetingId,
  });

  String _formatDateTime(DateTime dateTime) {
    // Format date as HH:mm DD-MM-YYYY
    return '${dateTime.day.toString().padLeft(2, '0')}-'
        '${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HistoryViewModel>();
    final bool isPlaying =
        viewModel.isPlaying && viewModel.currentPlayingId == meetingId;
    final meeting = viewModel.meetings.firstWhere((m) => m.id == meetingId);

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListTile(
        leading: Icon(Icons.mic, color: Theme.of(context).colorScheme.primary),
        trailing: IconButton(
          icon: Icon(Icons.delete),
          onPressed: () {
            showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: Text('Delete Meeting'),
                    content: Text(
                      'Are you sure you want to delete this meeting?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          viewModel.deleteMeeting(meetingId);
                          Navigator.of(context).pop();
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                        child: Text('Delete',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onError,
                        ),
                        ),
                      ),
                    ],
                  ),
            );
          },
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${meeting.description}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '${_formatDateTime(date)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withOpacity(0.8),
              ),
            ),
            Text(
              duration,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withOpacity(0.8),
              ),
            ),
          ],
        ),
        onTap: () {
          viewModel.showDetails(context, meetingId);
        },
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
