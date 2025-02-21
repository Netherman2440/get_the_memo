import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:get_the_memo/view_models/record_viewmodel.dart';

class RecordPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RecordViewModel(),
      child: _RecordPageContent(),
    );
  }
}

class _RecordPageContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RecordViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Record Audio'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
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
                    onPressed: () => viewModel.saveRecording(),
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
