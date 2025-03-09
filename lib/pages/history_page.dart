import 'package:flutter/material.dart';
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
    return 
        '${dateTime.day.toString().padLeft(2, '0')}-'
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
        leading: Icon(
          Icons.mic,
          color: Theme.of(context).colorScheme.primary,
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
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8),
              ),
            ),
            Text(
              duration,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.edit,
            color: Theme.of(context).colorScheme.primary,
          ),
          onPressed: () {
            showEditDialog(context, meetingId);
          },
        ),
        onTap: () {
          print(meetingId);
        },
      ),
    );
  }

  void showEditDialog(BuildContext context, String meetingId) {
    final viewModel = context.read<HistoryViewModel>();
    final meeting = viewModel.meetings.firstWhere((m) => m.id == meetingId);
    String newDescription = meeting.description;
    String newTitle = meeting.title;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Meeting Title'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: TextEditingController(text: meeting.title),
              onChanged: (value) {
                newTitle = value;
              },
              decoration: InputDecoration(
                hintText: 'Title',
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: TextEditingController(text: meeting.description),
              onChanged: (value) {
                newDescription = value;
              },
              decoration: InputDecoration(
                hintText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              keyboardType: TextInputType.multiline,

            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              meeting.description = newDescription;
              meeting.title = newTitle;
              viewModel.updateMeeting(meeting);
              Navigator.of(context).pop();
            },
            child: Text('Save'),
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
}
