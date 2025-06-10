import 'dart:io';

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
      print('Current user ID: ${widget.currentUserId}');
      print('Reviews: ${reviews.map((r) => {'id': r.id, 'client': r.client, 'review': r.review}).toList()}');
      print('Ratings: ${ratings.map((r) => {'id': r['id'], 'client': r['client'], 'rating': r['rating']}).toList()}');
      for (var review in reviews) {
        final clientId = extractClientId(review.client);
        print('Review ID: ${review.id}, Client: ${review.client}, ClientID: $clientId, '
            'IsOwnReview: ${clientId != null && clientId == widget.currentUserId}');
      }
      for (var rating in ratings) {
        final ratingClientId = extractClientId(rating['client']);
        print('Rating ID: ${rating['id']}, ClientID: $ratingClientId, Rating: ${rating['rating']}');
      }
    } else {
      setState(() {
        isLoading = false;
        isVetIdValid = false;
      });
      print('Failed to fetch reviews: ${response['message']}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'] ?? 'Failed to fetch reviews')),
      );
    }
  }

  String? extractClientId(dynamic client) {
    if (client == null) return null;
    if (client is String) return client;
    if (client is Map<String, dynamic>) {
      return client['clientId'] as String? ??
          client['_id'] as String? ??
          client['id'] as String? ??
          client['userId'] as String?;
    }
    print('Unknown client format: $client');
    return null;
  }

  bool _hasExistingReview() {
    return reviews.any((review) {
      final clientId = extractClientId(review.client);
      return clientId != null && clientId == widget.currentUserId;
    });
  }

  void _showReviewBottomSheet({Review? reviewToEdit}) {
    if (reviewToEdit == null && _hasExistingReview()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have already submitted a review for this veterinarian. Edit your existing review instead.')),
      );
      final existingReview = reviews.firstWhere(
            (review) => extractClientId(review.client) == widget.currentUserId,
      );
      return _showReviewBottomSheet(reviewToEdit: existingReview);
    }

    double? newRating = reviewToEdit != null
        ? ratings.firstWhere(
          (r) {
        final ratingClientId = extractClientId(r['client']);
        final reviewClientId = extractClientId(reviewToEdit.client);
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

                        try {
                          if (reviewToEdit == null) {
                            print('Adding new rating: vetId=${widget.vetId}, rating=$newRating');
                            ratingResponse = await ReviewService.addRating(widget.vetId, newRating!);
                            if (!ratingResponse['success']) {
                              print('Rating error: ${ratingResponse['message']}');
                              throw Exception(ratingResponse['message']);
                            }
                            print('Adding new review: vetId=${widget.vetId}, text=${_reviewController.text.trim()}');
                            reviewResponse = await ReviewService.addReview(widget.vetId, _reviewController.text.trim());
                            if (!reviewResponse['success']) {
                              print('Review error: ${reviewResponse['message']}');
                              throw Exception(reviewResponse['message']);
                            }
                          } else {
                            final ratingId = ratings.firstWhere(
                                  (r) {
                                final ratingClientId = extractClientId(r['client']);
                                final reviewClientId = extractClientId(reviewToEdit.client);
                                return ratingClientId != null && ratingClientId == reviewClientId;
                              },
                              orElse: () => {'id': null},
                            )['id'] as String?;
                            if (ratingId != null) {
                              print('Updating rating: vetId=${widget.vetId}, ratingId=$ratingId, rating=$newRating');
                              ratingResponse = await ReviewService.updateRating(widget.vetId, ratingId, newRating!);
                              if (!ratingResponse['success']) {
                                print('Rating update error: ${ratingResponse['message']}');
                                throw Exception(ratingResponse['message']);
                              }
                            } else {
                              print('Adding new rating for edit: vetId=${widget.vetId}, rating=$newRating');
                              ratingResponse = await ReviewService.addRating(widget.vetId, newRating!);
                              if (!ratingResponse['success']) {
                                print('Rating add error: ${ratingResponse['message']}');
                                throw Exception(ratingResponse['message']);
                              }
                            }
                            print('Updating review: vetId=${widget.vetId}, reviewId=${reviewToEdit.id}, text=${_reviewController.text.trim()}');
                            reviewResponse = await ReviewService.updateReview(widget.vetId, reviewToEdit.id, _reviewController.text.trim());
                            if (!reviewResponse['success']) {
                              print('Review update error: ${reviewResponse['message']}');
                              throw Exception(reviewResponse['message']);
                            }
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
                          }
                        } catch (e) {
                          setModalState(() => isSubmitting = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to save review: $e')),
                          );
                          print('Submission error: $e');
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
        content: Text('Are you sure you want to delete this review and its rating?', style: GoogleFonts.poppins()),
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

    try {
      // Find the review to get its clientId
      final review = reviews.firstWhere(
            (r) => r.id == reviewId,
        orElse: () => throw Exception('Review not found'),
      );
      final reviewClientId = extractClientId(review.client);
      if (reviewClientId == null) {
        throw Exception('Unable to extract client ID from review');
      }

      // Find the associated rating
      final rating = ratings.firstWhere(
            (r) {
          final ratingClientId = extractClientId(r['client']);
          return ratingClientId != null && ratingClientId == reviewClientId;
        },
        orElse: () => <String, dynamic>{'id': null},
      );
      final ratingId = rating['id'] as String?;

      // Delete the review
      print('Deleting review: vetId=${widget.vetId}, reviewId=$reviewId');
      final reviewResponse = await ReviewService.deleteReview(widget.vetId, reviewId);
      if (!reviewResponse['success']) {
        throw Exception(reviewResponse['message'] ?? 'Failed to delete review');
      }

      // Delete the rating if it exists
      if (ratingId != null) {
        print('Deleting rating: vetId=${widget.vetId}, ratingId=$ratingId');
        final ratingResponse = await ReviewService.deleteRating(widget.vetId, ratingId);
        if (!ratingResponse['success']) {
          print('Rating deletion failed: ${ratingResponse['message']}');
          // Log but don't fail, as review is already deleted
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Review deleted, but failed to delete rating: ${ratingResponse['message']}')),
          );
        }
      } else {
        print('No rating found for reviewId=$reviewId, clientId=$reviewClientId');
      }

      if (_isMounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review and rating deleted successfully')),
        );
        await checkVetIdAndFetchData();
      }
    } catch (e) {
      print('Delete error: $e');
      if (_isMounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    } finally {
      if (_isMounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _hasExistingReview()
            ? () {
          final existingReview = reviews.firstWhere(
                (review) => extractClientId(review.client) == widget.currentUserId,
            orElse: () => Review(
              id: '',
              client: null,
              veterinarian: widget.vetId,
              review: '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
          if (existingReview.id.isNotEmpty) {
            _showReviewBottomSheet(reviewToEdit: existingReview);
          }
        }
            : () => _showReviewBottomSheet(),
        backgroundColor: const Color(0xFF800080),
        child: Icon(_hasExistingReview() ? Icons.edit : Icons.add),
        tooltip: _hasExistingReview() ? 'Edit Review' : 'Add Review',
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
                            final clientId = extractClientId(review.client);
                            final isOwnReview = clientId != null && clientId == widget.currentUserId;
                            final rating = ratings.firstWhere(
                                  (r) {
                                final ratingClientId = extractClientId(r['client']);
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
                                          backgroundImage: review.client is Map<String, dynamic> && review.client!['profilePicture'] != null
                                              ? (review.client!['profilePicture'] as String).startsWith('http')
                                              ? NetworkImage(
                                            (review.client!['profilePicture'] as String).contains('localhost')
                                                ? (review.client!['profilePicture'] as String).replaceFirst('localhost', '192.168.1.16')
                                                : review.client!['profilePicture'] as String,
                                          )
                                              : Image.file(
                                            File(review.client!['profilePicture'] as String),
                                            width: 40,
                                            height: 40,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              debugPrint('Review file image error: $error');
                                              return Image.asset(
                                                'assets/images/default_avatar.png',
                                                width: 40,
                                                height: 40,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  debugPrint('Review asset error: $error');
                                                  return const Icon(Icons.person, color: Colors.grey);
                                                },
                                              );
                                            },
                                          ).image
                                              : Image.asset(
                                            'assets/images/default_avatar.png',
                                            width: 40,
                                            height: 40,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              debugPrint('Review asset error: $error');
                                              return const Icon(Icons.person, color: Colors.grey);
                                            },
                                          ).image,
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