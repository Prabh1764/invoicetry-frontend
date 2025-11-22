import 'package:flutter/material.dart';

class GoogleDriveFolderDialog extends StatefulWidget {
  final String? defaultFolderName;

  const GoogleDriveFolderDialog({
    super.key,
    this.defaultFolderName,
  });

  @override
  State<GoogleDriveFolderDialog> createState() =>
      _GoogleDriveFolderDialogState();
}

class _GoogleDriveFolderDialogState extends State<GoogleDriveFolderDialog> {
  final _controller = TextEditingController();
  bool _isValid = true;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.defaultFolderName ?? 'Invoices';
    _controller.addListener(_validate);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validate() {
    setState(() {
      _isValid = _controller.text.trim().isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose Folder Name'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your invoices will be saved to this folder in your Google Drive.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'Folder Name',
              hintText: 'e.g., ABC Construction Invoices',
              border: const OutlineInputBorder(),
              errorText: _isValid ? null : 'Folder name is required',
            ),
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isValid
              ? () => Navigator.of(context).pop(_controller.text.trim())
              : null,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

