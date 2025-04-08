import 'package:flutter/material.dart';
import 'package:get_the_memo/services/process_service.dart';
import 'package:get_the_memo/view_models/details_view_model.dart';
import 'package:provider/provider.dart';

class DetailsPage extends StatelessWidget {
  final String meetingId;

  DetailsPage({required this.meetingId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => DetailsViewModel(processService: context.read<ProcessService>(), meetingId: meetingId),
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
            // Title section - centered
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Title',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  InkWell(
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
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        '${viewModel.meeting?.title}',
                        style: TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Description section - left aligned
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  InkWell(
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
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        '${viewModel.meeting?.description}',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
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
