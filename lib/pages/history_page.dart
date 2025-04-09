import 'package:flutter/material.dart';
import 'package:get_the_memo/services/process_service.dart';
import 'package:provider/provider.dart';
import 'package:get_the_memo/view_models/history_view_model.dart';
import 'package:get_the_memo/theme/text_styles.dart';

class HistoryPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create:
          (_) =>
              HistoryViewModel(processService: context.read<ProcessService>()),
      child: Scaffold(
        body: Consumer<HistoryViewModel>(
          builder: (context, viewModel, child) {
           

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
                  description: _formatDescription(meeting.description),
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

  String _formatDescription(String description) {
    if (description.isEmpty) return 'No description';
    return description.length > 25 
        ? '${description.substring(0, 25)}...' 
        : description;
  }
}

class HistoryItem extends StatelessWidget {
  final String title;
  final DateTime date;
  final String duration;
  final String meetingId;
  final String description;

  const HistoryItem({
    Key? key,
    required this.title,
    required this.date,
    required this.duration,
    required this.meetingId,
    required this.description,
  }) : super(key: key);

  String get formattedDate => _formatDateTime(date);

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
      margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(12.0),
        title: Text(
          title,
          style: AppTextStyles.contentStyle.copyWith(
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Padding(
          padding: EdgeInsets.only(top: 6.0),
          child: Row(
            children: [
              Icon(Icons.calendar_today, 
                size: 16, 
                color: Colors.grey[600]
              ),
              SizedBox(width: 8),
              Text(
                formattedDate,
                style: AppTextStyles.labelStyle.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(width: 16),
              Icon(Icons.access_time, 
                size: 16, 
                color: Colors.grey[600]
              ),
              SizedBox(width: 8),
              Text(
                duration,
                style: AppTextStyles.labelStyle.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        trailing: viewModel.getHistoryIcon(context, meetingId),
        onTap: () => viewModel.showDetails(context, meetingId),
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
