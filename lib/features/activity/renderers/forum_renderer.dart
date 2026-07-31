import 'package:flutter/material.dart';

import '../data/activity_repository.dart';
import '../models/activity.dart';
import 'activity_renderer.dart';
import 'widgets/activity_layout.dart';
import 'widgets/activity_utils.dart';
import 'widgets/html_content.dart';

class ForumRendererAdapter extends ActivityRenderer {
  const ForumRendererAdapter();

  @override
  Widget build(
    BuildContext context,
    Activity activity, {
    ActivityRepository? repository,
  }) {
    return ForumRenderer(
      activity: activity,
      repository: repository ?? ActivityRepository(),
    );
  }
}

class ForumRenderer extends StatefulWidget {
  const ForumRenderer({
    super.key,
    required this.activity,
    required this.repository,
  });

  final Activity activity;
  final ActivityRepository repository;

  @override
  State<ForumRenderer> createState() => _ForumRendererState();
}

class _ForumRendererState extends State<ForumRenderer> {
  late Future<Map<String, dynamic>> _discussionsFuture;
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _discussionsFuture =
        widget.repository.getForumDiscussions(widget.activity.id);
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _createDiscussion() async {
    if (_subjectController.text.trim().isEmpty ||
        _messageController.text.trim().isEmpty) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.repository.createForumDiscussion(
        widget.activity.id,
        subject: _subjectController.text.trim(),
        message: _messageController.text.trim(),
      );
      _subjectController.clear();
      _messageController.clear();
      setState(_reload);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final forum = Map<String, dynamic>.from(
      widget.activity.details['forum'] as Map? ?? const {},
    );

    return ActivityLayout(
      activity: widget.activity,
      children: [
        HtmlContent(
          html: forum['intro']?.toString() ?? widget.activity.description,
        ),
        const SizedBox(height: 20),
        Text('New discussion', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _subjectController,
          decoration: const InputDecoration(labelText: 'Subject'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _messageController,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Message'),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _busy ? null : _createDiscussion,
          child: const Text('Post discussion'),
        ),
        const SizedBox(height: 24),
        Text('Discussions', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        FutureBuilder<Map<String, dynamic>>(
          future: _discussionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Card(
                child: ListTile(
                  title: const Text('Could not load discussions'),
                  subtitle: Text(snapshot.error.toString()),
                ),
              );
            }

            final discussions = List<dynamic>.from(
              snapshot.data?['discussions'] ?? const [],
            );

            if (discussions.isEmpty) {
              return const Card(
                child: ListTile(
                  leading: Icon(Icons.forum_outlined),
                  title: Text('No discussions yet'),
                ),
              );
            }

            return Column(
              children: discussions.map((discussion) {
                final map = Map<String, dynamic>.from(discussion as Map);
                final discussionId =
                    map['discussion'] as int? ?? map['id'] as int?;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    leading: const Icon(Icons.chat_bubble_outline_rounded),
                    title: Text(map['name']?.toString() ?? 'Discussion'),
                    subtitle: Text(
                      '${map['numposts'] ?? 0} posts • ${map['numunread'] ?? 0} unread',
                    ),
                    children: [
                      if (discussionId != null)
                        _DiscussionPosts(
                          cmid: widget.activity.id,
                          discussionId: discussionId,
                          repository: widget.repository,
                        ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
        if (widget.activity.url != null && widget.activity.url!.isNotEmpty) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => openExternalUrl(widget.activity.url),
            icon: const Icon(Icons.open_in_browser_rounded),
            label: const Text('Open forum in Moodle'),
          ),
        ],
      ],
    );
  }
}

class _DiscussionPosts extends StatefulWidget {
  const _DiscussionPosts({
    required this.cmid,
    required this.discussionId,
    required this.repository,
  });

  final int cmid;
  final int discussionId;
  final ActivityRepository repository;

  @override
  State<_DiscussionPosts> createState() => _DiscussionPostsState();
}

class _DiscussionPostsState extends State<_DiscussionPosts> {
  late Future<Map<String, dynamic>> _postsFuture;
  final _replyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _postsFuture = widget.repository.getForumDiscussionPosts(
      widget.cmid,
      widget.discussionId,
    );
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _reply(int parentPostId) async {
    if (_replyController.text.trim().isEmpty) return;
    await widget.repository.replyForumPost(
      widget.cmid,
      parentPostId,
      subject: 'Re:',
      message: _replyController.text.trim(),
    );
    _replyController.clear();
    setState(() {
      _postsFuture = widget.repository.getForumDiscussionPosts(
        widget.cmid,
        widget.discussionId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _postsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(snapshot.error.toString()),
          );
        }

        final posts = List<dynamic>.from(snapshot.data?['posts'] ?? const []);
        final firstPostId = posts.isNotEmpty
            ? Map<String, dynamic>.from(posts.first as Map)['id'] as int?
            : null;

        return Column(
          children: [
            ...posts.map((post) {
              final map = Map<String, dynamic>.from(post as Map);
              final postId = map['id'] as int?;
              return ListTile(
                title: Text(map['subject']?.toString() ?? 'Post'),
                subtitle: HtmlContent(html: map['message']?.toString() ?? ''),
                trailing: postId == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await widget.repository
                              .deleteForumPost(widget.cmid, postId);
                          setState(() {
                            _postsFuture =
                                widget.repository.getForumDiscussionPosts(
                              widget.cmid,
                              widget.discussionId,
                            );
                          });
                        },
                      ),
              );
            }),
            if (firstPostId != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _replyController,
                      decoration: const InputDecoration(labelText: 'Reply'),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: () => _reply(firstPostId),
                        child: const Text('Reply'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
