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
            Text(
              viewModel.getRecordingStatusText(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => viewModel.toggleRecording(),
              style: ElevatedButton.styleFrom(
                shape: CircleBorder(),
                padding: EdgeInsets.all(30),
                elevation: 8,
                backgroundColor: viewModel.getButtonColor(context),
              ),
              child: Icon(
                viewModel.getRecordingIcon(),
                size: 40,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            if (viewModel.state == RecordingState.paused) ...[
              SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
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
                    icon: Icon(Icons.save),
                    label: Text('Save Recording'),
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: () => viewModel.cancelRecording(),
                    icon: Icon(Icons.delete),
                    label: Text('Cancel'),
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      backgroundColor: Theme.of(context).colorScheme.error,
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
      title: Text('Processing Options'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CheckboxListTile(
            title: Text('Transcribe'),
            value: transcribe,
            onChanged: (bool? value) {
              setState(() {
                transcribe = value ?? false;
              });
            },
          ),
          CheckboxListTile(
            title: Text('Auto Title'),
            value: autoTitle,
            onChanged: (bool? value) {
              setState(() {
                autoTitle = value ?? false;
              });
            },
          ),
          CheckboxListTile(
            title: Text('Summarize'),
            value: summarize,
            onChanged: (bool? value) {
              setState(() {
                summarize = value ?? false;
              });
            },
          ),
          CheckboxListTile(
            title: Text('Extract Tasks'),
            value: extractTasks,
            onChanged: (bool? value) {
              setState(() {
                extractTasks = value ?? false;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            // Convert selected options to ProcessType list
            final List<ProcessType> selectedOptions = [];
            if (transcribe) selectedOptions.add(ProcessType.transcription);
            if (summarize) selectedOptions.add(ProcessType.summarize);
            if (extractTasks) selectedOptions.add(ProcessType.actionPoints);
            if (autoTitle) selectedOptions.add(ProcessType.autoTitle);
            // Process the meeting with selected options
            viewModel.processMeeting(
              context,
              viewModel.currentMeeting!, 
              selectedOptions
            );
            Navigator.pop(context);
          },
          child: Text('Process'),
        ),
      ],
    );
  }
}
