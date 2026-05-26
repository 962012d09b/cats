import 'package:flutter/material.dart';

class TagsEdit extends StatefulWidget {
  const TagsEdit({
    super.key,
    required this.tags,
    required this.onUpdateTags,
  });

  final List<String> tags;
  final Function(List<String>) onUpdateTags;

  @override
  State<TagsEdit> createState() => _TagsEditState();
}

class _TagsEditState extends State<TagsEdit> {
  List<String> _tags = [];
  bool _isAddingTag = false;
  String _errorMessage = "";
  final TextEditingController _tagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tags = widget.tags;
  }

  void _startAddingTag() {
    _errorMessage = "";
    _isAddingTag = true;
  }

  void _stopAddingTag() {
    _isAddingTag = false;
    _errorMessage = "";
    _tagController.clear();
  }

  void _addTag(String tag) {
    tag = tag.trim();

    if (_checkIfValid(tag)) {
      widget.onUpdateTags(_tags..add(tag));
      _stopAddingTag();
    }
  }

  bool _checkIfValid(String tag) {
    if (tag.isEmpty) {
      _errorMessage = "Tag cannot be empty";
    } else if (_tags.contains(tag)) {
      _errorMessage = "Tag already exists";
    } else {
      _errorMessage = "";
    }
    return _errorMessage.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var tag in widget.tags)
          Chip(
            label: Text(tag),
            onDeleted: () {
              widget.onUpdateTags(_tags..remove(tag));
            },
          ),
        _isAddingTag
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.onSurface),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IntrinsicWidth(
                      child: TextField(
                        controller: _tagController,
                        autofocus: true,
                        maxLength: 40,
                        decoration: InputDecoration(
                          isDense: true,
                          counterText: "",
                          contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          border: InputBorder.none,
                          hintText: 'Enter tag',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        onSubmitted: (tag) => setState(
                          () {
                            _addTag(tag);
                          },
                        ),
                        onTapOutside: (_) => setState(
                          () {
                            if (_tagController.text.trim().isEmpty) {
                              _stopAddingTag();
                            } else {
                              _addTag(_tagController.text);
                            }
                          },
                        ),
                        onChanged: (tag) => setState(
                          () {
                            _checkIfValid(tag);
                          },
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          height: 2.2,
                        ),
                      ),
                    ),
                  ),
                  _errorMessage.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            _errorMessage,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        )
                      : const SizedBox(),
                ],
              )
            : ActionChip(
                label: Icon(
                  Icons.add,
                  size: 20,
                ),
                onPressed: () => setState(
                  () {
                    _startAddingTag();
                  },
                ),
              ),
      ],
    );
  }
}
