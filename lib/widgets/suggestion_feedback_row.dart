import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/health_provider.dart';
import '../theme/app_theme.dart';

class SuggestionFeedbackRow extends StatefulWidget {
  const SuggestionFeedbackRow({
    super.key,
    required this.suggestionId,
    this.onPositiveFeedback,
    this.leading,
  });

  final String suggestionId;
  final VoidCallback? onPositiveFeedback;
  final Widget? leading;

  @override
  State<SuggestionFeedbackRow> createState() => _SuggestionFeedbackRowState();
}

class _SuggestionFeedbackRowState extends State<SuggestionFeedbackRow>
    with SingleTickerProviderStateMixin {
  String? _selectedRating; // 'positive' | 'negative'
  late final AnimationController _thumbController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  late final Animation<double> _thumbScale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 50),
    TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 50),
  ]).animate(
    CurvedAnimation(parent: _thumbController, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _thumbController.dispose();
    super.dispose();
  }

  Future<void> _handlePositive() async {
    if (_selectedRating != null) return;
    setState(() => _selectedRating = 'positive');
    _thumbController.forward(from: 0.0);

    final provider = context.read<HealthProvider>();
    await provider.recordSuggestionFeedback(
      suggestionId: widget.suggestionId,
      rating: 'positive',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Glad it helped!',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: AppColors.tealDeep,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.only(bottom: 80, left: 24, right: 24),
      ),
    );

    widget.onPositiveFeedback?.call();
  }

  Future<void> _handleNegative() async {
    if (_selectedRating != null) return;
    final result = await showModalBottomSheet<_NegativeFeedbackData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NegativeFeedbackSheet(),
    );

    if (result != null && mounted) {
      setState(() => _selectedRating = 'negative');
      final provider = context.read<HealthProvider>();
      await provider.recordSuggestionFeedback(
        suggestionId: widget.suggestionId,
        rating: 'negative',
        reason: result.reason,
        comment: result.comment,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Thanks for the feedback!',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          ),
          backgroundColor: AppColors.tealDeep,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.only(bottom: 80, left: 24, right: 24),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (widget.leading != null)
            Flexible(child: widget.leading!)
          else
            const SizedBox.shrink(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Was this helpful?',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(width: 4),
              ScaleTransition(
                scale: _thumbScale,
                child: _FeedbackIconButton(
                  icon: Icons.thumb_up_alt_outlined,
                  selectedIcon: Icons.thumb_up_alt,
                  isSelected: _selectedRating == 'positive',
                  selectedColor: AppColors.teal,
                  tooltip: 'Helpful',
                  onTap: _selectedRating == null ? _handlePositive : null,
                ),
              ),
              const SizedBox(width: 2),
              _FeedbackIconButton(
                icon: Icons.thumb_down_alt_outlined,
                selectedIcon: Icons.thumb_down_alt,
                isSelected: _selectedRating == 'negative',
                selectedColor: AppColors.accent,
                tooltip: 'Not helpful',
                onTap: _selectedRating == null ? _handleNegative : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeedbackIconButton extends StatelessWidget {
  const _FeedbackIconButton({
    required this.icon,
    required this.selectedIcon,
    required this.isSelected,
    required this.selectedColor,
    required this.tooltip,
    this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final bool isSelected;
  final Color selectedColor;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? selectedColor
        : AppColors.textSecondary.withValues(alpha: 0.6);

    return IconButton(
      onPressed: onTap,
      icon: Icon(
        isSelected ? selectedIcon : icon,
        size: 18,
        color: color,
      ),
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      tooltip: tooltip,
    );
  }
}

class _NegativeFeedbackData {
  final String reason;
  final String? comment;
  const _NegativeFeedbackData({required this.reason, this.comment});
}

class _NegativeFeedbackSheet extends StatefulWidget {
  const _NegativeFeedbackSheet();

  @override
  State<_NegativeFeedbackSheet> createState() => _NegativeFeedbackSheetState();
}

class _NegativeFeedbackSheetState extends State<_NegativeFeedbackSheet> {
  static const _reasons = [
    'Missing ingredients',
    'Doesn\'t match my goal',
    'Already ate this',
    'Other',
  ];

  String _selectedReason = _reasons.first;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'How can we improve this suggestion?',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _reasons.map((reason) {
                final isSelected = _selectedReason == reason;
                return ChoiceChip(
                  label: Text(reason),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedReason = reason);
                    }
                  },
                  selectedColor: AppColors.teal.withValues(alpha: 0.15),
                  backgroundColor: AppColors.surfaceMuted,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? AppColors.teal : AppColors.textPrimary,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppColors.teal : AppColors.divider,
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 2,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Tell us more (optional)',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                ),
                filled: true,
                fillColor: AppColors.surfaceMuted,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.teal),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(_NegativeFeedbackData(
                  reason: _selectedReason,
                  comment: _commentController.text.trim().isEmpty
                      ? null
                      : _commentController.text.trim(),
                ));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Send feedback',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
