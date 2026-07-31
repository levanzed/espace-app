import 'package:flutter/material.dart';

import '../data/activity_repository.dart';
import '../models/activity.dart';
import 'activity_renderer.dart';
import 'detail_renderer.dart';
import 'widgets/activity_layout.dart';
import 'widgets/html_content.dart';

class ChoiceRenderer extends ActivityRenderer {
  const ChoiceRenderer();

  @override
  Widget build(
    BuildContext context,
    Activity activity, {
    ActivityRepository? repository,
  }) {
    return _ChoiceView(
      activity: activity,
      repository: repository ?? ActivityRepository(),
    );
  }
}

class _ChoiceView extends StatefulWidget {
  const _ChoiceView({
    required this.activity,
    required this.repository,
  });

  final Activity activity;
  final ActivityRepository repository;

  @override
  State<_ChoiceView> createState() => _ChoiceViewState();
}

class _ChoiceViewState extends State<_ChoiceView> {
  late Future<Map<String, dynamic>> _optionsFuture;
  final Set<int> _selected = {};
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _optionsFuture = widget.repository.getChoiceOptions(widget.activity.id);
  }

  Future<void> _submit() async {
    if (_selected.isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.repository.submitChoice(
        widget.activity.id,
        _selected.toList(),
      );
      setState(() {
        _message = 'Response submitted.';
        _optionsFuture =
            widget.repository.getChoiceOptions(widget.activity.id);
      });
    } catch (error) {
      setState(() => _message = error.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ActivityLayout(
      activity: widget.activity,
      children: [
        HtmlContent(html: widget.activity.description),
        const SizedBox(height: 16),
        FutureBuilder<Map<String, dynamic>>(
          future: _optionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              // Fall back to detail renderer content if options WS fails.
              return const DetailRenderer(
                detailKey: 'choice',
                actionLabel: 'Open choice activity',
                actionIcon: Icons.ballot_rounded,
              ).build(context, widget.activity);
            }

            final options = List<dynamic>.from(
              snapshot.data?['options'] ?? const [],
            );

            return Column(
              children: [
                ...options.map((option) {
                  final map = Map<String, dynamic>.from(option as Map);
                  final id = map['id'] as int? ?? 0;
                  return CheckboxListTile(
                    value: _selected.contains(id),
                    title: Text(map['text']?.toString() ?? 'Option'),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selected.add(id);
                        } else {
                          _selected.remove(id);
                        }
                      });
                    },
                  );
                }),
                if (_message != null) Text(_message!),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: const Text('Submit choice'),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
