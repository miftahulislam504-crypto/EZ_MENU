import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../supabase/error_text.dart';
import '../supabase/storage_service.dart';
import '../theme/app_theme.dart';
import 'feedback.dart';
import 'inputs.dart';

/// A network image with a quiet placeholder while it loads or when it is
/// missing or broken. Shrinks decoded size to keep slow phones smooth.
class NetworkImageBox extends StatelessWidget {
  const NetworkImageBox({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius = 12,
    this.placeholderIcon = Icons.restaurant_menu_rounded,
    this.cacheWidth,
  });

  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double radius;
  final IconData placeholderIcon;

  /// Decode width in logical pixels (multiplied by 2 for sharp screens).
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final placeholder = Container(
      width: width,
      height: height,
      color: context.colors.surfaceContainerHigh,
      alignment: Alignment.center,
      child: Icon(
        placeholderIcon,
        color: palette.muted.withValues(alpha: 0.55),
      ),
    );
    final address = url;
    Widget child;
    if (address == null || address.isEmpty) {
      child = placeholder;
    } else {
      child = CachedNetworkImage(
        imageUrl: address,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: cacheWidth == null ? null : cacheWidth! * 2,
        fadeInDuration: const Duration(milliseconds: 160),
        placeholder: (_, __) =>
            Container(width: width, height: height, color: palette.line),
        errorWidget: (_, __, ___) => placeholder,
      );
    }
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: child);
  }
}

/// Pick one image (logo, cover, category picture) and upload it.
class ImagePickerField extends ConsumerStatefulWidget {
  const ImagePickerField({
    super.key,
    required this.label,
    required this.imageUrl,
    required this.businessId,
    required this.bucket,
    required this.folder,
    required this.onChanged,
    this.aspectRatio = 16 / 9,
    this.circle = false,
    this.helper,
    this.optional = true,
    this.maxDimension = 1600,
    this.placeholderIcon = Icons.add_photo_alternate_outlined,
  });

  final String label;
  final String? imageUrl;
  final String businessId;
  final AppBucket bucket;

  /// Sub folder inside the business folder, e.g. `logo` or `categories`.
  final String folder;

  /// Called with the new public URL, or null when the image was removed.
  final ValueChanged<String?> onChanged;
  final double aspectRatio;

  /// Round preview, for logos.
  final bool circle;
  final String? helper;
  final bool optional;
  final double maxDimension;
  final IconData placeholderIcon;

  @override
  ConsumerState<ImagePickerField> createState() => _ImagePickerFieldState();
}

class _ImagePickerFieldState extends ConsumerState<ImagePickerField> {
  bool _busy = false;

  Future<void> _pick() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final url = await ref
          .read(imageUploadServiceProvider)
          .pickAndUpload(
            businessId: widget.businessId,
            bucket: widget.bucket,
            folder: widget.folder,
            maxDimension: widget.maxDimension,
          );
      if (url != null) widget.onChanged(url);
    } catch (error) {
      if (mounted) showToast(context, friendlyError(error), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasImage = widget.imageUrl != null && widget.imageUrl!.isNotEmpty;
    final radius = widget.circle ? 999.0 : 16.0;

    final preview = AspectRatio(
      aspectRatio: widget.circle ? 1 : widget.aspectRatio,
      child: Material(
        color: context.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: palette.lineStrong),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _busy ? null : _pick,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage)
                NetworkImageBox(
                  url: widget.imageUrl,
                  radius: 0,
                  cacheWidth: 600,
                )
              else
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.placeholderIcon,
                      size: 30,
                      color: palette.muted,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Add image',
                      style: context.textStyles.labelMedium?.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
              if (_busy)
                Container(
                  color: context.colors.surface.withValues(alpha: 0.75),
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(strokeWidth: 2.6),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(widget.label, optional: widget.optional),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: widget.circle ? 120 : 520),
          child: preview,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            TextButton.icon(
              onPressed: _busy ? null : _pick,
              icon: Icon(
                hasImage ? Icons.swap_horiz_rounded : Icons.upload_rounded,
                size: 18,
              ),
              label: Text(hasImage ? 'Change image' : 'Upload image'),
            ),
            if (hasImage)
              TextButton.icon(
                onPressed: _busy ? null : () => widget.onChanged(null),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Remove'),
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.error,
                ),
              ),
          ],
        ),
        if (widget.helper != null)
          Text(
            widget.helper!,
            style: context.textStyles.bodySmall?.copyWith(color: palette.muted),
          ),
      ],
    );
  }
}

/// A row of photos for one item. The first photo is the main one.
class MultiImageField extends ConsumerStatefulWidget {
  const MultiImageField({
    super.key,
    required this.urls,
    required this.onChanged,
    required this.businessId,
    this.bucket = AppBucket.menu,
    this.folder = 'items',
    this.maxImages = 6,
    this.label = 'Photos',
    this.helper,
  });

  final List<String> urls;
  final ValueChanged<List<String>> onChanged;
  final String businessId;
  final AppBucket bucket;
  final String folder;
  final int maxImages;
  final String label;
  final String? helper;

  @override
  ConsumerState<MultiImageField> createState() => _MultiImageFieldState();
}

class _MultiImageFieldState extends ConsumerState<MultiImageField> {
  bool _busy = false;

  Future<void> _add() async {
    if (_busy || widget.urls.length >= widget.maxImages) return;
    setState(() => _busy = true);
    try {
      final url = await ref
          .read(imageUploadServiceProvider)
          .pickAndUpload(
            businessId: widget.businessId,
            bucket: widget.bucket,
            folder: widget.folder,
          );
      if (url != null) widget.onChanged([...widget.urls, url]);
    } catch (error) {
      if (mounted) showToast(context, friendlyError(error), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _remove(int index) {
    final next = [...widget.urls]..removeAt(index);
    widget.onChanged(next);
  }

  void _makeMain(int index) {
    final next = [...widget.urls];
    final picked = next.removeAt(index);
    next.insert(0, picked);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const tile = 92.0;
    final canAdd = widget.urls.length < widget.maxImages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: FieldLabel(widget.label, optional: true)),
            Text(
              '${widget.urls.length} of ${widget.maxImages}',
              style: context.textStyles.bodySmall?.copyWith(
                color: palette.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < widget.urls.length; i++)
              SizedBox(
                width: tile,
                height: tile,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    NetworkImageBox(
                      url: widget.urls[i],
                      radius: 14,
                      cacheWidth: 200,
                    ),
                    if (i == 0)
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: StatusPill('Main', tone: PillTone.info),
                      )
                    else
                      Positioned(
                        left: 4,
                        bottom: 4,
                        child: _TileButton(
                          icon: Icons.star_outline_rounded,
                          tooltip: 'Make main photo',
                          onTap: () => _makeMain(i),
                        ),
                      ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: _TileButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Remove photo',
                        onTap: () => _remove(i),
                      ),
                    ),
                  ],
                ),
              ),
            if (canAdd)
              SizedBox(
                width: tile,
                height: tile,
                child: Material(
                  color: context.colors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: palette.lineStrong),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _busy ? null : _add,
                    child: Center(
                      child: _busy
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                              ),
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color: palette.muted,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Add',
                                  style: context.textStyles.labelSmall
                                      ?.copyWith(color: palette.muted),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (widget.helper != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.helper!,
            style: context.textStyles.bodySmall?.copyWith(color: palette.muted),
          ),
        ],
      ],
    );
  }
}

class _TileButton extends StatelessWidget {
  const _TileButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
