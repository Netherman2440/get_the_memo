import 'package:flutter/material.dart';
import 'package:get_the_memo/view_models/details_view_model.dart';
import 'package:provider/provider.dart';

class DetailsPage extends StatelessWidget {
  final String meetingId;

  DetailsPage({required this.meetingId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => DetailsViewModel(meetingId: meetingId),
      child: DetailsPageContent(),
    );
  }
}

class DetailsPageContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DetailsViewModel>();

    return Scaffold(
      appBar: AppBar(title: Text('Details')),
      body: Column(
        children: [
          Card(
            margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: ListTile(
              title: Text('Title'),
              subtitle: Text('${viewModel.meeting?.title}'),
              tileColor: Theme.of(context).colorScheme.onPrimary,
              onTap: () {
                viewModel.showEditDialog(
                  context: context,
                  title: 'Edit Title',
                  initialContent: viewModel.meeting?.title ?? '',
                  onSave: (newTitle) {
                    viewModel.editTitle(newTitle);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: ListTile(
              title: Text('Description'),
              subtitle: Text('${viewModel.meeting?.description}'),
              tileColor: Theme.of(context).colorScheme.onPrimary,
              onTap: () {
                viewModel.showEditDialog(
                  context: context,
                  title: 'Edit Description',
                  initialContent: viewModel.meeting?.description ?? '',
                  onSave: (newDescription) {
                    viewModel.editDescription(newDescription);
                  },
                );
              },
            ),
          ),
          SizedBox(height: 10),


// Transcription
          switch (viewModel.transcriptionStatus) {
            TranscriptionStatus.notStarted => ElevatedButton(
              onPressed: () {
                viewModel.createTranscript(viewModel.meeting?.id ?? '');
              },
              child: Text('Create Transcript'),
            ),

            TranscriptionStatus.inProgress => ElevatedButton(
              onPressed: null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('Transcript in progress'),
                ],
              ),
            ),

            TranscriptionStatus.completed => Card(
              margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: ListTile(
                title: Text('Transcript'),
                subtitle: Text('${viewModel.transcript}'),
                onTap: () {
                  viewModel.showEditDialog(
                    context: context,
                    title: 'Edit Transcript',
                    initialContent: viewModel.transcript ?? '',
                    onSave: (newTranscript) {
                      viewModel.editTranscript(newTranscript);
                    },
                  );
                },
              ),
            ),

            TranscriptionStatus.failed => ElevatedButton(
              onPressed: () {
                viewModel.createTranscript(viewModel.meeting?.id ?? '');
              },
              child: Text('Retry Transcript'),
            ),
          },
          const SizedBox(height: 10),
          
          // summary
          viewModel.getSummarySection(context),

          // Add after summary section
          const SizedBox(height: 10),
          viewModel.getActionPointsSection(context),
        ],
      ),
    );
  }

  
}


