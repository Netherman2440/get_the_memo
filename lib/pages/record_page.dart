import 'package:flutter/material.dart';
import 'package:get_the_memo/services/process_service.dart';
import 'package:provider/provider.dart';
import 'package:get_the_memo/view_models/record_viewmodel.dart';

class RecordPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RecordViewModel(processService: context.read<ProcessService>()),

      child: _RecordPageContent(),
    );
  }
}

class _RecordPageContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RecordViewModel>();

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                viewModel.getRecordingStatusText(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(height: 40),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () => viewModel.toggleRecording(),
                style: ElevatedButton.styleFrom(
                  shape: CircleBorder(),
                  padding: EdgeInsets.all(32),
                  elevation: 4,
                  backgroundColor: _getButtonColor(context, viewModel.state),
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: Icon(
                  viewModel.state == RecordingState.idle 
                      ? Icons.mic
                      : viewModel.state == RecordingState.recording 
                          ? Icons.pause
                          : Icons.play_arrow,
                  size: 48,
                  color: Colors.white,
                ),
              ),
            ),
            if (viewModel.state == RecordingState.paused) ...[
              SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 100,
                    child: FilledButton(
                      onPressed: () async {
                        await viewModel.saveRecording();
                        if (context.mounted) {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return ChangeNotifierProvider.value(
                                value: viewModel,
                                child: ProcessOptionsDialog(),
                              );
                            },
                          );
                        }
                      },
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(
                        'Save',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  SizedBox(
                    width: 100,
                    child: OutlinedButton(
                      onPressed: () => viewModel.cancelRecording(),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(
                        'Cancel',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getButtonColor(BuildContext context, RecordingState state) {
    switch (state) {
      case RecordingState.recording:
        return Theme.of(context).colorScheme.primary;
      case RecordingState.paused:
        return Theme.of(context).colorScheme.secondary;
      case RecordingState.idle:
        return Theme.of(context).colorScheme.primary;
    }
  }
}

class ProcessOptionsDialog extends StatefulWidget {
  @override
  _ProcessOptionsDialogState createState() => _ProcessOptionsDialogState();
}

class _ProcessOptionsDialogState extends State<ProcessOptionsDialog> {
  // Processing options flags
  bool transcribe = false;
  bool summarize = false;
  bool extractTasks = false;
  bool autoTitle = false;
  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<RecordViewModel>();
    
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      title: Text(
        'Processing Options',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOptionTile(
            title: 'Transcribe',
            value: transcribe,
            onChanged: (bool? value) {
              setState(() {
                transcribe = value ?? false;
                if (!transcribe) {
                  summarize = false;
                  extractTasks = false;
                  autoTitle = false;
                }
              });
            },
          ),
          if (transcribe) ...[
            _buildOptionTile(
              title: 'Auto Title',
              value: autoTitle,
              onChanged: (bool? value) {
                setState(() {
                  autoTitle = value ?? false;
                });
              },
            ),
            _buildOptionTile(
              title: 'Summarize',
              value: summarize,
              onChanged: (bool? value) {
                setState(() {
                  summarize = value ?? false;
                });
              },
            ),
            _buildOptionTile(
              title: 'Extract Tasks',
              value: extractTasks,
              onChanged: (bool? value) {
                setState(() {
                  extractTasks = value ?? false;
                });
              },
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ),
        FilledButton(
          onPressed: () {
            final List<ProcessType> selectedOptions = [];
            if (transcribe) selectedOptions.add(ProcessType.transcription);
            if (summarize) selectedOptions.add(ProcessType.summarize);
            if (extractTasks) selectedOptions.add(ProcessType.actionPoints);
            if (autoTitle) selectedOptions.add(ProcessType.autoTitle);
            
            viewModel.processMeeting(
              context,
              viewModel.currentMeeting!,
              selectedOptions
            );
            Navigator.pop(context);
          },
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text('Process'),
        ),
      ],
    );
  }

  Widget _buildOptionTile({
    required String title,
    required bool value,
    required Function(bool?) onChanged,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      ),
      child: CheckboxListTile(
        title: Text(
          title,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        value: value,
        onChanged: onChanged,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}

