import 'package:flutter/material.dart';

import '../../../models/ministry_position.dart';

const _other = 'Other (type it below)';

/// Which ministry, and what the person is called there. Put inside a [Form]; it
/// validates with the form and reports the position through [onChanged]
/// (null while the fields are not yet valid).
class MinistryPositionFields extends StatefulWidget {
  const MinistryPositionFields({super.key, required this.onChanged});

  final ValueChanged<MinistryPosition?> onChanged;

  @override
  State<MinistryPositionFields> createState() => _MinistryPositionFieldsState();
}

class _MinistryPositionFieldsState extends State<MinistryPositionFields> {
  String? _choice;
  final _otherController = TextEditingController();
  final _titleController = TextEditingController();

  @override
  void dispose() {
    _otherController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _emit() {
    final ministry = _choice == _other ? _otherController.text : (_choice ?? '');
    final ok = validateMinistryText(ministry, what: 'the ministry') == null &&
        validateMinistryText(_titleController.text, what: 'the position') == null;
    widget.onChanged(ok
        ? MinistryPosition(
            ministry: ministry.trim(), title: _titleController.text.trim())
        : null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: const Key('ministry-choice'),
          initialValue: _choice,
          isExpanded: true,
          decoration: const InputDecoration(
              labelText: 'Ministry', prefixIcon: Icon(Icons.groups_outlined)),
          items: [
            for (final m in [...suggestedMinistries, _other])
              DropdownMenuItem(value: m, child: Text(m)),
          ],
          onChanged: (v) {
            setState(() => _choice = v);
            _emit();
          },
          validator: (v) => v == null ? 'Choose the ministry' : null,
        ),
        if (_choice == _other) ...[
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('ministry-other'),
            controller: _otherController,
            maxLength: ministryTextMaxLength,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name of the ministry'),
            onChanged: (_) => _emit(),
            validator: (v) => validateMinistryText(v, what: 'the ministry'),
          ),
        ],
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('ministry-title'),
          controller: _titleController,
          maxLength: ministryTextMaxLength,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Your position',
            hintText: 'e.g. Leader, Secretary, Treasurer',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
          onChanged: (_) => _emit(),
          validator: (v) => validateMinistryText(v, what: 'the position'),
        ),
      ],
    );
  }
}
