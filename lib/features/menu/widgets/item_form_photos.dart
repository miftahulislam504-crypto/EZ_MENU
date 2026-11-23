import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/error_text.dart';
import '../../../core/supabase/storage_service.dart';
import '../../../core/widgets/widgets.dart';
import '../item_form_logic.dart';
import 'editor_common.dart';

/// Up to [maxItemImages] photos of a dish. The first one is the cover. Tap a
/// photo to make it the cover; press and hold, then drag, to reorder.
class ItemPhotosSection extends ConsumerStatefulWidget {
  const ItemPhotosSection({
    super.key,
    required this.urls,
    required this.businessId,
    required this.onChanged,
    required this.onUploaded,
    this.errorText,
  });

  final List<String> urls;
  final String? businessId;
  final ValueChanged<List<String>> onChanged;

  /// Every new upload, so the screen can delete it if it is never saved.
  final ValueChanged<String> onUploaded;
  final String? errorText;

  @override
  ConsumerState<ItemPhotosSection> createState() => _ItemPhotosSectionState();
}

class _ItemPhotosSectionState extends ConsumerState<ItemPhotosSection> {
  bool _busy = false;

  static const double _tile = 108;

  Future<void> _add() async {
    final businessId = widget.businessId;
    if (_busy || businessId == null) return;
    if (widget.urls.length >= maxItemImages) {
      showToast(context, 'A dish can have at most $maxItemImages photos.');
      return;
    }
    setState(() => _busy = true);
    try {
      final url = await ref
          .read(imageUploadServiceProvider)
          .pickAndUpload(
            businessId: businessId,
            bucket: AppBucket.menu,
            folder: 'items',
          );
      if (url != null) {
        widget.onUploaded(url);
        widget.onChanged([...widget.urls, url]);
      }
    } catch (error) {
      if (mounted) showToast(context, friendlyError(error), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final urls = widget.urls;
    final full = urls.length >= maxItemImages;
    return FormSection(
      title: 'Photos',
      subtitle: 'The first photo is the cover shown on the menu.',
      children: [
        SizedBox(
          height: _tile,
          child: Row(
            children: [
              if (urls.isNotEmpty)
                Flexible(
                  child: ReorderableListView(
                    scrollDirection: Axis.horizontal,
                    shrinkWrap: true,
                    buildDefaultDragHandles: false,
                    proxyDecorator: (child, index, animation) =>
                        Material(color: Colors.transparent, child: child),
                    onReorder: (oldIndex, newIndex) =>
                        widget.onChanged(moveImage(urls, oldIndex, newIndex)),
                    children: [
                      for (var i = 0; i < urls.length; i++)
                        ReorderableDelayedDragStartListener(
                          key: ValueKey(urls[i]),
                          index: i,
                          child: Padding(
                            padding: const EdgeInsets.only(right: Sp.sm),
                            child: _PhotoTile(
                              url: urls[i],
                              isCover: i == 0,
                              size: _tile,
                              onMakeCover: () =>
                                  widget.onChanged(makeCover(urls, i)),
                              onRemove: () =>
                                  widget.onChanged(removeImageAt(urls, i)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              _AddTile(
                size: _tile,
                busy: _busy,
                enabled: !full && widget.businessId != null,
                onTap: _add,
              ),
            ],
          ),
        ),
        Text(
          '${urls.length} of $maxItemImages photos. JPG, PNG or WebP, up to 5 MB each. '
          '${urls.length > 1 ? 'Tap a photo to make it the cover, or press and hold to drag it.' : ''}',
          style: context.textStyles.bodySmall?.copyWith(color: palette.muted),
        ),
        if (widget.errorText != null)
          EditorNote(widget.errorText!, tone: PillTone.danger),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.url,
    required this.isCover,
    required this.size,
    required this.onMakeCover,
    required this.onRemove,
  });

  final String url;
  final bool isCover;
  final double size;
  final VoidCallback onMakeCover;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: InkWell(
              borderRadius: BorderRadius.circular(Rad.control),
              onTap: isCover ? null : onMakeCover,
              child: NetworkImageBox(
                url: url,
                width: size,
                height: size,
                radius: Rad.control,
                cacheWidth: size.round(),
              ),
            ),
          ),
          Positioned(
            left: 6,
            bottom: 6,
            child: isCover
                ? const StatusPill('Cover', tone: PillTone.success)
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      'Make cover',
                      style: context.textStyles.labelSmall?.copyWith(color: Colors.white),
                    ),
                  ),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: Tooltip(
              message: 'Remove photo',
              child: InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: onRemove,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.lineStrong),
                  ),
                  child: Icon(Icons.close_rounded, size: 16, color: palette.muted),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({
    required this.size,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  final double size;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      borderRadius: BorderRadius.circular(Rad.control),
      onTap: enabled && !busy ? onTap : null,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Rad.control),
          border: Border.all(color: palette.lineStrong),
          color: palette.paper,
        ),
        child: busy
            ? const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 28,
                    color: enabled ? context.colors.primary : palette.muted,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    enabled ? 'Add photo' : 'Limit reached',
                    style: context.textStyles.labelSmall?.copyWith(color: palette.muted),
                  ),
                ],
              ),
      ),
    );
  }
}
