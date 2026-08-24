import 'package:flutter/material.dart';

import '../app/neo_components.dart';

class SharedCoachScreen extends StatefulWidget {
  const SharedCoachScreen({
    required this.snapshot,
    required this.perform,
    super.key,
  });

  final Map<Object?, Object?> snapshot;
  final Future<Object?> Function(
    String action, {
    Map<String, Object?> arguments,
  })
  perform;

  @override
  State<SharedCoachScreen> createState() => _SharedCoachScreenState();
}

class _SharedCoachScreenState extends State<SharedCoachScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send([String? suggestion]) async {
    final text = (suggestion ?? _controller.text).trim();
    if (text.isEmpty) return;
    _controller.clear();
    await widget.perform('coach.send', arguments: {'text': text});
  }

  void _openAttachments() {
    showNeoActionSheet(
      context,
      title: 'Add to Coach',
      subtitle: 'Attach visual context to your question',
      items: [
        NeoActionItem(
          label: 'Camera',
          icon: Icons.camera_alt,
          onTap: () => widget.perform(
            'coach.capability',
            arguments: {'capability': 'camera'},
          ),
        ),
        NeoActionItem(
          label: 'Photos',
          icon: Icons.photo_library,
          onTap: () => widget.perform(
            'coach.capability',
            arguments: {'capability': 'photos'},
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = (widget.snapshot['messages'] as List<Object?>? ?? const [])
        .map((item) => Map<Object?, Object?>.from(item! as Map))
        .toList();
    final suggestions =
        (widget.snapshot['suggestions'] as List<Object?>? ?? const [])
            .whereType<String>()
            .toList();
    final sending = widget.snapshot['sending'] as bool? ?? false;

    return ColoredBox(
      color: NeoColors.canvas(context),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: NeoHeader(
                eyebrow: 'Personal intelligence',
                title: 'AI Coach',
                subtitle: 'Your food, goals, and training in context',
                icon: Icons.auto_awesome,
                trailing: NeoIconTile(
                  icon: Icons.refresh,
                  color: NeoColors.acid,
                  onTap: messages.isEmpty
                      ? null
                      : () => widget.perform('coach.reset'),
                ),
              ),
            ),
            Expanded(
              child: messages.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: NeoEmpty(
                        text: 'Ask about your meals, progress, goals, recovery, or training.',
                        icon: Icons.auto_awesome,
                      ),
                    )
                  : ListView.separated(
                      reverse: false,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      itemCount: messages.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        return _MessageCard(message: messages[index]);
                      },
                    ),
            ),
            if (suggestions.isNotEmpty)
              SizedBox(
                height: 47,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: suggestions.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) => NeoButton(
                    label: suggestions[index],
                    compact: true,
                    color: index.isEven ? NeoColors.acid : NeoColors.cobalt,
                    onPressed: sending ? null : () => _send(suggestions[index]),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: NeoFrame(
                padding: const EdgeInsets.fromLTRB(8, 5, 5, 5),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: sending ? null : _openAttachments,
                      icon: Icon(Icons.add_a_photo, color: NeoColors.cobalt),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: sending ? null : (_) => _send(),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Ask your coach…',
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: sending
                          ? null
                          : () => widget.perform(
                              'coach.capability',
                              arguments: {'capability': 'voice'},
                            ),
                      icon: Icon(Icons.mic, color: NeoColors.cobalt),
                    ),
                    SizedBox.square(
                      dimension: 43,
                      child: Material(
                        color: sending ? Colors.grey : NeoColors.acid,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: NeoColors.ink(context),
                            width: 2,
                          ),
                        ),
                        child: InkWell(
                          onTap: sending ? null : _send,
                          child: sending
                              ? const Padding(
                                  padding: EdgeInsets.all(11),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: Colors.black,
                                  ),
                                )
                              : const Icon(
                                  Icons.arrow_upward,
                                  color: Colors.black,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});
  final Map<Object?, Object?> message;

  @override
  Widget build(BuildContext context) {
    final user = message['role'] == 'user';
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.84,
        ),
        child: NeoFrame(
          color: user ? NeoColors.cobalt : NeoColors.surface(context),
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user ? 'YOU' : 'FÜD AI',
                style: TextStyle(
                  color: user ? NeoColors.acid : NeoColors.cobalt,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message['content'] as String? ?? '',
                style: TextStyle(
                  color: user ? Colors.white : NeoColors.ink(context),
                  fontSize: 15,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
