import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vetapp_v1/models/review.dart';
import 'package:vetapp_v1/services/review_service.dart';
import 'package:intl/intl.dart';

class ReviewsScreen extends StatefulWidget {
  final String vetId;
  final String currentUserId;

   ReviewsScreen({Key? key, required this.vetId, required this.currentUserId}) : super(key: key) {
    print('ReviewsScreen initialized with vetId: $vetId, currentUserId: $currentUserId');
  }

  @override
  _ReviewsScreenState createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  List<Review> reviews = [];
  List<dynamic> ratings = [];
  double averageRating = 0.0;
  int ratingCount = 0;
  double? userRating;
  String? userReview;
  String? userRatingId;
  String? userReviewId;
  final TextEditingController _reviewController = TextEditingController();
  bool isLoading = true;
  bool isVetIdValid = false;

  @override
  void initState() {
    super.initState();
    if (!_isValidObjectId(widget.vetId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid veterinarian ID format')),
        );
        setState(() => isLoading = false);
      });
    } else {
      checkVetIdAndFetchData();
    }
  }

  bool _isValidObjectId(String id) {
    return id.isNotEmpty && RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(id);
  }

  void checkVetIdAndFetchData() async {
    setState(() => isLoading = true);
    final vetCheckResponse = await ReviewService.checkVetId(widget.vetId);
    if (!vetCheckResponse['success']) {
      setState(() {
        isLoading = false;
        isVetIdValid = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vetCheckResponse['message'])),
      );
      return;
    }

    setState(() => isVetIdValid = true);
    final response = await ReviewService.getReviews(widget.vetId);
    if (response['success']) {
      setState(() {
        reviews = response['reviews'] as List<Review>;
        ratings = response['ratings'] as List<dynamic>;
        averageRating = response['averageRating'] as double;
        ratingCount = response['ratingCount'] as int;

        // Find user's existing rating
        final userRatingData = ratings.firstWhere(
              (rating) => rating['client']['_id'] == widget.currentUserId,
          orElse: () => <String, dynamic>{},
        );
        if (userRatingData.isNotEmpty) {
          userRating = (userRatingData['rating'] as num).toDouble();
          userRatingId = userRatingData['id'] as String;
        }

        // Find user's existing review
        final userReviewData = reviews.firstWhere(
              (review) => review.client['_id'] == widget.currentUserId,
          orElse: () => Review(
            id: '',
            client: <String, dynamic>{'_id': '', 'firstName': '', 'lastName': ''},
            veterinarian: '',
            review: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        if (userReviewData.id.isNotEmpty) {
          userReview = userReviewData.review;
          userReviewId = userReviewData.id;
          _reviewController.text = userReview!;
        }

        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'])),
      );
    }
  }

  void submitRatingAndReview() async {
    if (userRating == null || userRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }
    if (_reviewController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a review')),
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

    print('Submitting rating for vetId: ${widget.vetId}, userId: ${widget.currentUserId}');
    setState(() => isLoading = true);

    final ratingResponse = await ReviewService.addRating(widget.vetId, userRating!);
    if (!ratingResponse['success']) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ratingResponse['message'])),
      );
      return;
    }

    final reviewResponse = await ReviewService.addReview(widget.vetId, _reviewController.text.trim());
    setState(() => isLoading = false);

    if (reviewResponse['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userReviewId == null ? 'Review and rating added successfully' : 'Review and rating updated successfully')),
      );
      checkVetIdAndFetchData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reviewResponse['message'])),
      );
    }
  }

  void deleteRatingAndReview() async {
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
        const SnackBar(content: Text('Cannot delete: Invalid veterinarian ID')),
      );
      return;
    }

    setState(() => isLoading = true);

    if (userRatingId != null) {
      final ratingResponse = await ReviewService.deleteRating(widget.vetId, userRatingId!);
      if (!ratingResponse['success']) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ratingResponse['message'])),
        );
        return;
      }
    }

    if (userReviewId != null) {
      final reviewResponse = await ReviewService.deleteReview(widget.vetId, userReviewId!);
      if (!reviewResponse['success']) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(reviewResponse['message'])),
        );
        return;
      }
    }

    setState(() {
      isLoading = false;
      userRating = null;
      userReview = null;
      userRatingId = null;
      userReviewId = null;
      _reviewController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Review and rating deleted successfully')),
    );
    checkVetIdAndFetchData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF800080),
              Color(0xFF4B0082),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'Reviews & Ratings',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, -5),
                      ),
                    ],
                  ),
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : !isVetIdValid
                      ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Invalid veterinarian ID. Please select a valid veterinarian.',
                        style: GoogleFonts.poppins(fontSize: 16, color: Colors.red),
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(5, (index) {
                                return IconButton(
                                  icon: Icon(
                                    index < (userRating?.floor() ?? 0) ? Icons.star : Icons.star_border,
                                    color: Colors.amber,
                                    size: 32,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      userRating = (index + 1).toDouble();
                                    });
                                  },
                                );
                              }),
                            ),
                            TextField(
                              controller: _reviewController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText: 'Write your review...',
                                hintStyle: GoogleFonts.poppins(),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20.0),
                                ),
                                filled: true,
                                fillColor: Colors.grey[200],
                              ),
                              style: GoogleFonts.poppins(),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: submitRatingAndReview,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF800080),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    child: Text(
                                      userReviewId == null ? 'Submit' : 'Update',
                                      style: GoogleFonts.poppins(color: Colors.white),
                                    ),
                                  ),
                                ),
                                if (userRatingId != null || userReviewId != null)
                                  const SizedBox(width: 8),
                                if (userRatingId != null || userReviewId != null)
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: deleteRatingAndReview,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: reviews.length,
                          itemBuilder: (context, index) {
                            final review = reviews[index];
                            final rating = ratings.firstWhere(
                                  (r) => r['client']['_id'] == review.client['_id'],
                              orElse: () => <String, dynamic>{'rating': 0},
                            );
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundImage: review.client['profilePicture'] != null
                                              ? NetworkImage(review.client['profilePicture'])
                                              : null,
                                          child: review.client['profilePicture'] == null
                                              ? const Icon(Icons.person, color: Colors.grey)
                                              : null,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${review.client['firstName']} ${review.client['lastName']}',
                                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                                              ),
                                              Row(
                                                children: List.generate(5, (i) {
                                                  return Icon(
                                                    i < (rating['rating'] as num).toInt()
                                                        ? Icons.star
                                                        : Icons.star_border,
                                                    color: Colors.amber,
                                                    size: 16,
                                                  );
                                                }),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          DateFormat('dd MMM yyyy').format(review.createdAt),
                                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
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