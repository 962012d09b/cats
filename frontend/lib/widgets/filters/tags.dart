import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TagList extends ConsumerWidget {
  const TagList({
    super.key,
    required this.tags,
    required this.tagColor,
    required this.highlightedTags,
    required this.onTagTap,
  });

  final List<String> tags;
  final Color tagColor;
  final List<String> highlightedTags;
  final Function(String) onTagTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        for (var tag in tags)
          _Tag(
            tagName: tag,
            tagColor: tagColor,
            highlight: highlightedTags.contains(tag),
            onTap: onTagTap,
          )
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  _Tag({
    required this.tagName,
    required this.tagColor,
    required this.highlight,
    required this.onTap,
  });

  final String tagName;
  final Color tagColor;
  final bool highlight;
  final Function(String) onTap;

  final BorderRadius borderRadius = BorderRadius.circular(8);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(tagName),
      borderRadius: borderRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: tagColor,
          borderRadius: borderRadius,
          border: Border.all(
            color: highlight ? Theme.of(context).colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          tagName,
        ),
      ),
    );
  }
}
