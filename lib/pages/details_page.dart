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
            Card(
              margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
              color: Colors.transparent,
              elevation: 0,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Center(
                      child: Text(
                        'Title',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        viewModel.startTitleEditing();
                      },
                      child: viewModel.isTitleEditing 
                        ? Column(
                            children: [
                              TextField(
                                controller: TextEditingController(text: viewModel.meeting?.title),
                                maxLines: null,
                                autofocus: true,
                                style: TextStyle(fontSize: 24),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(),
                                  hintText: 'Enter title here',
                                ),
                                onChanged: (value) {
                                  viewModel.meeting?.title = value;
                                },
                              ),
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      viewModel.isTitleEditing = false;
                                      viewModel.meeting?.title = viewModel.originalTitle ?? '';
                                      viewModel.notifyListeners();
                                    },
                                    child: Text('Cancel'),
                                  ),
                                  SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () {
                                      viewModel.isTitleEditing = false;
                                      viewModel.editTitle(viewModel.meeting?.title ?? '');
                                    },
                                    child: Text('Save'),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Text(
                            viewModel.meeting?.title ?? '',
                            style: TextStyle(fontSize: 24),
                          ),
                    ),
                  ],
                ),
              ),
            ),
            // Description section - left aligned
            Card(
              margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
              color: Colors.transparent,
              elevation: 0,
              child: Padding(
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
                    GestureDetector(
                      onTap: () {
                        viewModel.startDescriptionEditing();
                      },
                      child: viewModel.isDescriptionEditing 
                        ? Column(
                            children: [
                              TextField(
                                controller: TextEditingController(text: viewModel.meeting?.description),
                                maxLines: null,
                                autofocus: true,
                                style: TextStyle(fontSize: 16),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(),
                                  hintText: 'Enter description here',
                                ),
                                onChanged: (value) {
                                  viewModel.meeting?.description = value;
                                },
                              ),
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      viewModel.isDescriptionEditing = false;
                                      viewModel.meeting?.description = viewModel.originalDescription ?? '';
                                      viewModel.notifyListeners();
                                    },
                                    child: Text('Cancel'),
                                  ),
                                  SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () {
                                      viewModel.isDescriptionEditing = false;
                                      viewModel.editDescription(viewModel.meeting?.description ?? '');
                                    },
                                    child: Text('Save'),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Text(
                            viewModel.meeting?.description ?? '',
                            style: TextStyle(fontSize: 16),
                          ),
                    ),
                  ],
                ),
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
