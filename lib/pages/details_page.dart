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
      body: SingleChildScrollView(
        child: Column(
          children: [
            Card(
              margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: ExpansionTile(
                title: Text('Title'),
                children: [
                  ListTile(
                    subtitle: Text('${viewModel.meeting?.title}'),
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
                ],
              ),
            ),
            const SizedBox(height: 10),
            Card(
              margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: ExpansionTile(
                title: Text('Description'),
                children: [
                  ListTile(
                    title: Text('Description'),
                    subtitle: Text('${viewModel.meeting?.description}'),
                    
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
                ],
              ),
            ),
            SizedBox(height: 10),
        
            // Transcription section
            viewModel.getTranscriptionSection(context),
        
            const SizedBox(height: 10),
        
            // Summary section
            viewModel.getSummarySection(context),
        
            const SizedBox(height: 10),
            viewModel.getActionPointsSection(context),
            
            const SizedBox(height: 20),
            
            // Email button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: () => viewModel.sendEmailWithMeetingDetails(),
                icon: const Icon(Icons.email),
                label: const Text('Share via Email'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
