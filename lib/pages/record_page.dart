import 'package:flutter/material.dart';

class RecordPage extends StatefulWidget {
  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  var state = RecordingState.idle;

  void toggleRecording() {
    switch (state) {
      case RecordingState.idle:
        state = RecordingState.recording;
        break;
      case RecordingState.recording:
        state = RecordingState.paused;
        break;
      case RecordingState.paused:
        state = RecordingState.recording;
        break;
    }

    setState(() {
      state = state;
    });
  }

  void saveRecording() {
    
    setState(() {
      state = RecordingState.idle;
    });
  }

  @override
  Widget build(BuildContext context) {
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
              _getRecordingStatusText(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: toggleRecording,
              style: ElevatedButton.styleFrom(
                shape: CircleBorder(),
                padding: EdgeInsets.all(30),
                elevation: 8,
                backgroundColor: _getButtonColor(context),
              ),
              child: Icon(
                _getRecordingIcon(),
                size: 40,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            if (state == RecordingState.paused) ...[
              SizedBox(height: 30),
              FilledButton.icon(
                onPressed: saveRecording,
                icon: Icon(Icons.save),
                label: Text('Save Recording'),
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Helper methods for UI elements
  IconData _getRecordingIcon() {
    switch (state) {
      case RecordingState.recording:
        return Icons.pause;
      case RecordingState.paused:
        return Icons.play_arrow;
      case RecordingState.idle:
        return Icons.mic;
    }
  }

  Color _getButtonColor(BuildContext context) {
    switch (state) {
      case RecordingState.recording:
        return Theme.of(context).colorScheme.error;
      case RecordingState.paused:
        return Theme.of(context).colorScheme.tertiary;
      case RecordingState.idle:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String _getRecordingStatusText() {
    switch (state) {
      case RecordingState.recording:
        return 'Recording...';
      case RecordingState.paused:
        return 'Recording Paused';
      case RecordingState.idle:
        return 'Ready to Record';
    }
  }
}

enum RecordingState { idle, recording, paused }
