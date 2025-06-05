import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vetapp_v1/models/review.dart';
import 'package:vetapp_v1/services/review_service.dart';
import 'package:intl/intl.dart';

class ReviewsScreen extends StatefulWidget {
  final String vetId;
  final String currentUserId;

  const ReviewsScreen({Key? key, required this.vetId, required this.currentUserId}) : super(key: key);

  @override
  _ReviewsScreenState createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  List<Review> reviews = [];
  List<dynamic> ratings = [];
  double averageRating = 0.0;
  int ratingCount = 0;
  bool isLoading = true;
  bool isVetIdValid = false;
  bool _isMounted = false;
  final TextEditingController _reviewController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    if (!_isValidObjectId(widget.vetId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isMounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid veterinarian ID format')),
          );
          setState(() => isLoading = false);
        }
      });
    } else {
      checkVetIdAndFetchData();
    }
  }

  @override
  void dispose() {
    _isMounted = false;
    _reviewController.dispose();
    super.dispose();
  }

  bool _isValidObjectId(String id) {
    return id.isNotEmpty && RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(id);
  }

  Future<void> checkVetIdAndFetchData() async {
    if (!_isMounted) return;
    setState(() => isLoading = true);
    final vetCheckResponse = await ReviewService.checkVetId(widget.vetId);
    if (!_isMounted) return;

    if (!vetCheckResponse['success']) {
      setState(() {
        isLoading = false;
        isVetIdValid = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vetCheckResponse['message'] ?? 'Failed to validate veterinarian ID')),
      );
      return;
    }

    setState(() => isVetIdValid = true);
    final response = await ReviewService.getReviews(widget.vetId);
    if (!_isMounted) return;

    if (response['success']) {
      setState(() {
        reviews = (response['reviews'] as List<dynamic>)
            .whereType<Review>()
            .where((review) => review.id.isNotEmpty)
            .toList();
        ratings = (response['ratings'] as List<dynamic>).where((rating) => rating['id'] != null).toList();
        averageRating = (response['averageRating'] as num?)?.toDouble() ?? 0.0;
        ratingCount = (response['ratingCount'] as int?) ?? 0;
        isLoading = false;
      });
      // Debug logging for client ID issues
      print('Current user ID: ${widget.currentUserId}');
      for (var review in reviews) {
        final clientId = _extractClientId(review.client);
        print('Review ID: ${review.id}, Client: ${review.client}, Client ID: $clientId, '
            'IsOwnReview: ${clientId != null && clientId == widget.currentUserId}');
      }
      for (var rating in ratings) {
        final ratingClientId = _extractClientId(rating['client']);
        print('Rating ID: ${rating['id']}, Client ID: $ratingClientId');
      }
    } else {
      setState(() {
        isLoading = false;
        isVetIdValid = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'] ?? 'Failed to fetch reviews')),
      );
    }
  }

  // Helper to extract client ID safely
  String? _extractClientId(dynamic client) {
    if (client is String) return client;
    if (client is Map<String, dynamic>) {
      return client['clientId'] as String? ??
          client['_id'] as String? ??
          client['id'] as String?;
    }
    return null;
  }

  void _showReviewBottomSheet({Review? reviewToEdit}) {
    double? newRating = reviewToEdit != null
        ? ratings.firstWhere(
          (r) {
        final ratingClientId = _extractClientId(r['client']);
        final reviewClientId = _extractClientId(reviewToEdit.client);
        return ratingClientId != null && ratingClientId == reviewClientId;
      },
      orElse: () => {'rating': 0},
    )['rating']?.toDouble()
        : null;
    _reviewController.text = reviewToEdit?.review ?? '';
    String? reviewError;
    bool isSubmitting = false;
    final GlobalKey bottomSheetKey = GlobalKey();

    void validateReview(String text) {
      final trimmed = text.trim();
      if (trimmed.isEmpty) {
        reviewError = 'Review cannot be empty';
      } else if (trimmed.length < 10) {
        reviewError = 'Review must be at least 10 characters';
      } else if (trimmed.length > 500) {
        reviewError = 'Review cannot exceed 500 characters';
      } else {
        reviewError = null;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        key: bottomSheetKey,
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                reviewToEdit == null ? 'Add Review' : 'Edit Review',
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < (newRating?.floor() ?? 0) ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () {
                      setModalState(() {
                        newRating = (index + 1).toDouble();
                      });
                    },
                  );
                }),
              ),
              TextField(
                controller: _reviewController,
                maxLines: 3,
                maxLength: 500,
                onChanged: (text) => setModalState(() => validateReview(text)),
                decoration: InputDecoration(
                  hintText: 'Write your review...',
                  hintStyle: GoogleFonts.poppins(),
                  border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                  filled: true,
                  fillColor: Colors.grey[200],
                  errorText: reviewError,
                  counterText: '${_reviewController.text.length}/500',
                ),
                style: GoogleFonts.poppins(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                        if (newRating == null || newRating == 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select a rating')),
                          );
                          return;
                        }
                        if (_reviewController.text.trim().isEmpty || reviewError != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a valid review (10–500 characters)')),
                          );
                          return;
                        }
                        if (!_isValidObjectId(widget.vetId)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Invalid veterinarian ID format')),
                          );
                          return;
                        }
                        if (!_isValidObjectId(widget.currentUserId)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Invalid user ID. Please login again.')),
                          );
                          return;
                        }
                        if (!isVetIdValid) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Cannot submit: Invalid veterinarian ID')),
                          );
                          return;
                        }

                        setModalState(() => isSubmitting = true);
                        Map<String, dynamic>? ratingResponse;
                        Map<String, dynamic>? reviewResponse;

                        if (reviewToEdit == null) {
                          ratingResponse = await ReviewService.addRating(widget.vetId, newRating!);
                          if (!ratingResponse['success']) {
                            setModalState(() => isSubmitting = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(ratingResponse['message'] ?? 'Failed to add rating')),
                            );
                            return;
                          }
                          reviewResponse = await ReviewService.addReview(widget.vetId, _reviewController.text.trim());
                        } else {
                          final ratingId = ratings.firstWhere(
                                (r) {
                              final ratingClientId = _extractClientId(r['client']);
                              final reviewClientId = _extractClientId(reviewToEdit.client);
                              return ratingClientId != null && ratingClientId == reviewClientId;
                            },
                            orElse: () => {'id': null},
                          )['id'] as String?;
                          if (ratingId != null) {
                            ratingResponse = await ReviewService.updateRating(widget.vetId, ratingId, newRating!);
                            if (!ratingResponse['success']) {
                              setModalState(() => isSubmitting = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(ratingResponse['message'] ?? 'Failed to update rating')),
                              );
                              return;
                            }
                          } else {
                            ratingResponse = await ReviewService.addRating(widget.vetId, newRating!);
                            if (!ratingResponse['success']) {
                              setModalState(() => isSubmitting = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(ratingResponse['message'] ?? 'Failed to add rating')),
                              );
                              return;
                            }
                          }
                          reviewResponse = await ReviewService.updateReview(widget.vetId, reviewToEdit.id, _reviewController.text.trim());
                        }

                        setModalState(() => isSubmitting = false);
                        if (reviewResponse['success']) {
                          Navigator.pop(context);
                          if (_isMounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(reviewToEdit == null ? 'Review and rating added successfully' : 'Review and rating updated successfully'),
                              ),
                            );
                            _reviewController.clear();
                            await checkVetIdAndFetchData();
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(reviewResponse['message'] ?? 'Failed to save review')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF800080),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Text(
                        reviewToEdit == null ? 'Submit' : 'Update',
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      _reviewController.clear();
                      Navigator.pop(context);
                    },
                    child: Text('Cancel', style: GoogleFonts.poppins()),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> deleteReview(String reviewId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Delete', style: GoogleFonts.poppins()),
        content: Text('Are you sure you want to delete this review?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !_isMounted) return;

    setState(() => isLoading = true);
    final reviewResponse = await ReviewService.deleteReview(widget.vetId, reviewId);
    if (!_isMounted) return;

    setState(() => isLoading = false);
    if (reviewResponse['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review deleted successfully')),
      );
      await checkVetIdAndFetchData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reviewResponse['message'] ?? 'Failed to delete review')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showReviewBottomSheet(),
        backgroundColor: const Color(0xFF800080),
        child: const Icon(Icons.add),
        tooltip: 'Add Review',
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF800080), Color(0xFF4B0082)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        'Reviews & Ratings',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -4)),
                    ],
                  ),
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : !isVetIdValid
                      ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Invalid veterinarian ID.',
                        style: GoogleFonts.poppins(fontSize: 14, color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                      : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              averageRating.toStringAsFixed(1),
                              style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              children: List.generate(5, (index) {
                                return Icon(
                                  index < averageRating.floor() ? Icons.star : Icons.star_border,
                                  color: Colors.amber,
                                  size: 24,
                                );
                              }),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '($ratingCount)',
                              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      if (ratingCount == 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Text(
                            'No reviews or ratings yet. Be the first to share your experience!',
                            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      Expanded(
                        child: reviews.isEmpty && ratings.isEmpty
                            ? Center(
                          child: Text(
                            'No reviews available yet.',
                            style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
                          ),
                        )
                            : ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: reviews.length,
                          itemBuilder: (context, index) {
                            final review = reviews[index];
                            final clientId = _extractClientId(review.client);
                            final isOwnReview = clientId != null && clientId == widget.currentUserId;
                            final rating = ratings.firstWhere(
                                  (r) {
                                final ratingClientId = _extractClientId(r['client']);
                                return ratingClientId != null && ratingClientId == clientId;
                              },
                              orElse: () => <String, dynamic>{'rating': 0},
                            );
                            final ratingValue = (rating['rating'] as num?)?.toInt() ?? 0;

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundImage: review.client is Map<String, dynamic> &&
                                              review.client!['profilePicture'] != null
                                              ? NetworkImage(review.client!['profilePicture'] as String)
                                              : null,
                                          child: review.client is! Map<String, dynamic> ||
                                              review.client!['profilePicture'] == null
                                              ? const Icon(Icons.person, color: Colors.grey)
                                              : null,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                review.client is Map<String, dynamic>
                                                    ? '${review.client!['firstName'] ?? 'Unknown'} ${review.client!['lastName'] ?? ''}'
                                                    : 'Anonymous',
                                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                                              ),
                                              Row(
                                                children: List.generate(5, (i) {
                                                  return Icon(
                                                    i < ratingValue ? Icons.star : Icons.star_border,
                                                    color: Colors.amber,
                                                    size: 16,
                                                  );
                                                }),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              DateFormat('dd MMM yyyy').format(review.createdAt),
                                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                                            ),
                                            if (isOwnReview) ...[
                                              const SizedBox(width: 8),
                                              IconButton(
                                                icon: const Icon(Icons.edit, color: Colors.blue),
                                                onPressed: () => _showReviewBottomSheet(reviewToEdit: review),
                                                tooltip: 'Edit review',
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete, color: Colors.red),
                                                onPressed: () => deleteReview(review.id),
                                                tooltip: 'Delete review',
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      review.review,
                                      style: GoogleFonts.poppins(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}