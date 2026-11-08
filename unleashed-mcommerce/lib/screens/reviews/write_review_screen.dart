import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../core/app_theme.dart';
import '../../models/product_review.dart';
import '../../services/product_service.dart';
import '../../services/review_service.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/editorial.dart';

/// Reviews are only reachable from a delivered order (or from a product page
/// after [ReviewService] confirms a delivered purchase). Firestore rules
/// re-check the same condition on write, so the client check is convenience,
/// not the security boundary.
class WriteReviewScreen extends StatefulWidget {
  const WriteReviewScreen({
    super.key,
    required this.productId,
    required this.productName,
    required this.orderId,
  });

  final String productId;
  final String productName;
  final String orderId;

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  final _text = TextEditingController();
  int _rating = 5;
  bool _loading = true;
  bool _submitting = false;
  bool _editing = false;
  String? _loadError;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final uid = AppState.instance.user?.uid;
    if (uid == null) {
      setState(() {
        _loading = false;
        _loadError = 'Please sign in again to write a review.';
      });
      return;
    }
    try {
      final reviews = await ProductService.instance.fetchReviews(
        widget.productId,
      );
      final id = ProductReview.idFor(widget.productId, uid);
      ProductReview? mine;
      for (final review in reviews) {
        if (review.id == id || review.customerId == uid) {
          mine = review;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        if (mine != null) {
          _rating = mine.rating.clamp(1, 5);
          _text.text = mine.text;
          _editing = true;
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      // A failed pre-load must not block submitting; the write is validated by
      // the backend and rules.
      setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    final state = AppState.instance;
    final uid = state.user?.uid;
    if (uid == null) {
      setState(() => _error = 'Please sign in again to write a review.');
      return;
    }
    if (_rating < 1 || _rating > 5) {
      setState(() => _error = 'Choose a star rating.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ReviewService.instance.submitReview(
        customerId: uid,
        customerName: state.profile?.fullName ?? state.displayName,
        productId: widget.productId,
        orderId: widget.orderId,
        rating: _rating,
        text: _text.text,
      );
      if (!mounted) return;
      showAppSnack(
        context,
        _editing ? 'Your review has been updated.' : 'Thanks for your review.',
      );
      Navigator.of(context).pop(true);
    } on ReviewFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Your review could not be saved. Please try again in a moment.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('WRITE A REVIEW')),
      body: _loading
          ? const AppStateView.loading(message: 'Checking your purchase…')
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                const _ReviewIntro(),
                if (_loadError != null) ...[
                  const SizedBox(height: 16),
                  _ErrorBanner(message: _loadError!),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  _ErrorBanner(message: _error!),
                ],
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('Now reviewing'),
                      const SizedBox(height: 8),
                      Text(
                        widget.productName.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Reviews are linked to a delivered purchase and are '
                        'visible to other shoppers.',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Eyebrow('Your rating'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (var index = 1; index <= 5; index++)
                      IconButton(
                        tooltip: '$index star${index == 1 ? '' : 's'}',
                        onPressed: _submitting
                            ? null
                            : () => setState(() => _rating = index),
                        padding: const EdgeInsets.only(right: 6),
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          index <= _rating
                              ? Icons.star
                              : Icons.star_border,
                          size: 34,
                          color: index <= _rating
                              ? AppColors.accent
                              : AppColors.warmGray,
                        ),
                      ),
                    const Spacer(),
                    Text(
                      '$_rating / 5',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const Eyebrow('Your review'),
                const SizedBox(height: 8),
                TextField(
                  controller: _text,
                  maxLines: 6,
                  maxLength: AppConfig.maxReviewLength,
                  textCapitalization: TextCapitalization.sentences,
                  enabled: !_submitting,
                  decoration: const InputDecoration(
                    hintText:
                        'How is the fit, the fabric, the print? Optional, but '
                        'helpful to other customers.',
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: _editing ? 'Update review' : 'Submit review',
                  accent: true,
                  loading: _submitting,
                  onPressed: _loadError == null ? _submit : null,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Only one review per product is kept on your account. '
                  'Submitting again updates your existing review.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.5,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
    );
  }
}

class _ReviewIntro extends StatelessWidget {
  const _ReviewIntro();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(2, 10, 2, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AccentMark(),
              SizedBox(width: 7),
              Eyebrow('Verified purchase'),
              Spacer(),
              StatusDot(label: 'One per product', color: AppColors.muted),
            ],
          ),
          SizedBox(height: 10),
          Text(
            'WRITE A REVIEW',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
              height: 0.98,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBE9E7),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
