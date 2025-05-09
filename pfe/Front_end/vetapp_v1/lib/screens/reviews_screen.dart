import 'dart:io';

import 'package:flutter/material.dart';
import 'package:vetapp_v1/models/review.dart';
import 'package:vetapp_v1/services/review_service.dart';

class ReviewsScreen extends StatefulWidget {
  final String vetId;
  final String? currentUserId; // Add this to identify user's own reviews

  const ReviewsScreen({Key? key, required this.vetId, this.currentUserId}) : super(key: key);

  @override
  _ReviewsScreenState createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  List<Review> reviews = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final response = await ReviewService.getReviews(widget.vetId);
      if (response['success'] == true) {
        setState(() {
          reviews = (response['reviews'] as List<Review>);
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage = response['message'] ?? 'Failed to load reviews';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load reviews: ${e.toString()}';
      });
    }
  }

  Future<void> _addReview() async {
    double rating = 0;
    TextEditingController reviewController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Review'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 30,
                  ),
                  onPressed: () {
                    setState(() {
                      rating = index + 1.0;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reviewController,
              decoration: const InputDecoration(
                labelText: 'Your Review',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final response = await ReviewService.addReview(
                  widget.vetId,
                  rating,
                  reviewController.text,
                );
                if (response['success'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Review added successfully')),
                  );
                  Navigator.pop(context);
                  _loadReviews(); // Refresh the list
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(response['message'])),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to add review: ${e.toString()}')),
                );
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteReview(String reviewId) async {
    try {
      final response = await ReviewService.deleteReview(reviewId);
      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review deleted successfully')),
        );
        _loadReviews(); // Refresh the list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'])),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete review: ${e.toString()}')),
      );
    }
  }

  Future<void> _editReview(Review review) async {
    final TextEditingController reviewController = TextEditingController(text: review.review);
    double currentRating = review.rating;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Review'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < currentRating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 30,
                  ),
                  onPressed: () {
                    setState(() {
                      currentRating = index + 1.0;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reviewController,
              decoration: const InputDecoration(
                labelText: 'Your Review',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final response = await ReviewService.updateReview(
                  review.id,
                  currentRating,
                  reviewController.text,
                );
                if (response['success'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Review updated successfully')),
                  );
                  Navigator.pop(context);
                  _loadReviews(); // Refresh the list
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(response['message'])),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to update review: ${e.toString()}')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reviews'),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _addReview, // Open the add review dialog
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage.isNotEmpty) {
      return Center(child: Text(errorMessage));
    }

    if (reviews.isEmpty) {
      return const Center(child: Text('No reviews yet.'));
    }

    return Expanded(
      child: RefreshIndicator(
        onRefresh: _loadReviews,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reviews.length,
          itemBuilder: (context, index) {
            final review = reviews[index];
            return _buildReviewCard(review);
          },
        ),
      ),
    );
  }

  Widget _buildReviewCard(Review review) {
    final isCurrentUserReview = widget.currentUserId != null &&
        review.client.id == widget.currentUserId;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Client profile picture
                CircleAvatar(
                  radius: 24,
                  backgroundImage: review.client.profilePicture.isNotEmpty
                      ? FileImage(File(review.client.profilePicture))
                      : const AssetImage('assets/default_avatar.png') as ImageProvider,
                ),
                const SizedBox(width: 12),
                // Client name and rating
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${review.client.firstName} ${review.client.lastName}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < review.rating
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 18,
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                // Edit and delete buttons
                if (isCurrentUserReview) ...[
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _editReview(review),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteReview(review.id),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(review.review),
          ],
        ),
      ),
    );
  }
}
