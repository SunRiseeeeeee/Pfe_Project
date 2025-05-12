import 'package:flutter/material.dart';
import 'package:vetapp_v1/services/post_service.dart';
import 'package:vetapp_v1/models/token_storage.dart';
import 'dart:io' show File;
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:animations/animations.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class FypScreen extends StatefulWidget {
  const FypScreen({super.key});

  @override
  _FypScreenState createState() => _FypScreenState();
}

class _FypScreenState extends State<FypScreen> {
  late Future<List<Post>> postsFuture;
  List<Post> posts = []; // Local list to store posts
  String? userLocation;
  bool isLoading = true;
  String? errorMessage;
  bool isVeterinarian = false;

  @override
  void initState() {
    super.initState();
    _loadUserDataAndPosts();
  }

  Future<void> _loadUserDataAndPosts() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      userLocation = await TokenStorage.getUserLocationFromToken();
      final role = await TokenStorage.getUserRoleFromToken();
      isVeterinarian = role?.toLowerCase() == 'veterinarian';
      postsFuture = PostService.getAllPosts();
      posts = await postsFuture; // Store fetched posts locally
      setState(() {
        isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Error loading FYP posts: $e\nStackTrace: $stackTrace');
      setState(() {
        isLoading = false;
        errorMessage = e is PostServiceException ? e.message : 'Failed to load posts';
      });
    }
  }

  void _showCommentDialog(String postId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add Comment',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Write a comment...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: Colors.blueAccent,
                    ),
                    onPressed: () async {
                      final content = controller.text.trim();
                      if (content.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Comment cannot be empty', style: GoogleFonts.poppins())),
                        );
                        return;
                      }
                      try {
                        final userId = await TokenStorage.getUserId();
                        if (userId == null) throw PostServiceException('User not authenticated');
                        final newComment = await PostService.addComment(
                          postId: postId,
                          userId: userId,
                          content: content,
                        );
                        Navigator.pop(context);
                        // Update only the affected post locally
                        setState(() {
                          final index = posts.indexWhere((post) => post.id == postId);
                          if (index != -1) {
                            posts[index] = Post(
                              id: posts[index].id,
                              media: posts[index].media,
                              mediaType: posts[index].mediaType,
                              description: posts[index].description,
                              createdAt: posts[index].createdAt,
                              updatedAt: posts[index].updatedAt,
                              veterinaire: posts[index].veterinaire,
                              reactionCounts: posts[index].reactionCounts,
                              userReactions: posts[index].userReactions,
                              comments: [...posts[index].comments, newComment],
                              commentCount: posts[index].commentCount + 1,
                            );
                          }
                        });
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e', style: GoogleFonts.poppins())),
                        );
                      }
                    },
                    child: Text('Post', style: GoogleFonts.poppins(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreatePostDialog() {
    final descriptionController = TextEditingController();
    File? mediaFile;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: StatefulBuilder(
          builder: (context, setDialogState) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Create Post',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    hintText: 'Enter description',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['jpg', 'jpeg', 'png', 'mp4', 'mov'],
                    );
                    if (result != null && result.files.single.path != null) {
                      setDialogState(() {
                        mediaFile = File(result.files.single.path!);
                      });
                    }
                  },
                  icon: const Icon(Icons.photo_library, color: Colors.white),
                  label: Text('Pick Media', style: GoogleFonts.poppins(color: Colors.white)),
                ),
                if (mediaFile != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Selected: ${mediaFile!.path.split('/').last}',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: Colors.blueAccent,
                      ),
                      onPressed: () async {
                        if (mediaFile == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Please select a media file', style: GoogleFonts.poppins())),
                          );
                          return;
                        }
                        try {
                          final userId = await TokenStorage.getUserId();
                          if (userId == null) throw PostServiceException('User not authenticated');
                          await PostService.createPost(
                            veterinaireId: userId,
                            media: mediaFile!,
                            description: descriptionController.text.trim(),
                          );
                          Navigator.pop(context);
                          // Refresh posts fully after creating a new post
                          await _loadUserDataAndPosts();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e', style: GoogleFonts.poppins())),
                          );
                        }
                      },
                      child: Text('Create', style: GoogleFonts.poppins(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'For You',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        actions: [
          if (isVeterinarian) // Show create post button for veterinarians
            IconButton(
              icon: const Icon(FontAwesomeIcons.camera, color: Colors.black),
              onPressed: _showCreatePostDialog,
              tooltip: 'Create Post',
            ),
        ],
      ),
      floatingActionButton: isVeterinarian // Show FAB for veterinarians
          ? FloatingActionButton(
        onPressed: _showCreatePostDialog,
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Create Post',
      )
          : null,
      body: isLoading
          ? Center(
        child: SpinKitDoubleBounce(
          color: Colors.blueAccent,
          size: 50,
        ),
      )
          : errorMessage != null
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              errorMessage!,
              style: GoogleFonts.poppins(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                backgroundColor: Colors.blueAccent,
              ),
              onPressed: _loadUserDataAndPosts,
              child: Text('Retry', style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadUserDataAndPosts,
        child: AnimationLimiter(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              // Filter posts by location
              if (userLocation != null &&
                  userLocation!.isNotEmpty &&
                  !(post.veterinaire.location?.toLowerCase().contains(userLocation!.toLowerCase()) ?? false)) {
                return const SizedBox.shrink();
              }
              // Debug video URL
              if (post.mediaType == 'video') {
                debugPrint('Video URL for post ${post.id}: ${post.media}');
              }
              return AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 375),
                child: SlideAnimation(
                  verticalOffset: 50,
                  child: FadeInAnimation(
                    child: _buildPostCard(post),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPostCard(Post post) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post media
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: post.mediaType == 'image'
                ? CachedNetworkImage(
              imageUrl: post.media.isNotEmpty ? post.media : 'https://via.placeholder.com/400',
              width: double.infinity,
              height: 300,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                height: 300,
                color: Colors.grey[200],
                child: const Center(child: SpinKitPulse(color: Colors.blueAccent)),
              ),
              errorWidget: (context, url, error) => Container(
                height: 300,
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
              ),
            )
                : _buildVideoPlayer(post.media),
          ),
          // Veterinarian info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: post.veterinaire.profilePicture != null
                      ? NetworkImage(post.veterinaire.profilePicture!)
                      : const AssetImage('assets/images/default_avatar.png') as ImageProvider,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${post.veterinaire.firstName} ${post.veterinaire.lastName}',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    Text(
                      post.createdAt.toLocal().toString().split('.')[0],
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Description
          if (post.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                post.description,
                style: GoogleFonts.poppins(fontSize: 14),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          // Reactions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const FaIcon(FontAwesomeIcons.heart, color: Colors.red, size: 20),
                const SizedBox(width: 6),
                Text(
                  '${post.reactionCounts.total}',
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
                const Spacer(),
                Text(
                  '${post.commentCount} comments',
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
              ],
            ),
          ),
          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildActionButton(
                  icon: post.userReactions.any((r) => r.user.id == (TokenStorage.getUserId() ?? '') && r.type == "j'aime")
                      ? FontAwesomeIcons.solidHeart
                      : FontAwesomeIcons.heart,
                  label: 'Like',
                  color: post.userReactions.any((r) => r.user.id == (TokenStorage.getUserId() ?? '') && r.type == "j'aime")
                      ? Colors.red
                      : Colors.grey,
                  onPressed: () async {
                    try {
                      final userId = await TokenStorage.getUserId();
                      if (userId == null) throw PostServiceException('User not authenticated');
                      final hasLiked = post.userReactions.any((r) => r.user.id == userId && r.type == "j'aime");
                      if (hasLiked) {
                        await PostService.deleteReaction(postId: post.id, userId: userId);
                        // Update post locally
                        setState(() {
                          final index = posts.indexWhere((p) => p.id == post.id);
                          if (index != -1) {
                            final updatedReactions = List<Reaction>.from(posts[index].userReactions)
                              ..removeWhere((r) => r.user.id == userId && r.type == "j'aime");
                            posts[index] = Post(
                              id: posts[index].id,
                              media: posts[index].media,
                              mediaType: posts[index].mediaType,
                              description: posts[index].description,
                              createdAt: posts[index].createdAt,
                              updatedAt: posts[index].updatedAt,
                              veterinaire: posts[index].veterinaire,
                              reactionCounts: ReactionCounts(
                                total: posts[index].reactionCounts.total - 1,
                                jAime: posts[index].reactionCounts.jAime - 1,
                                jAdore: posts[index].reactionCounts.jAdore,
                                triste: posts[index].reactionCounts.triste,
                                jAdmire: posts[index].reactionCounts.jAdmire,
                              ),
                              userReactions: updatedReactions,
                              comments: posts[index].comments,
                              commentCount: posts[index].commentCount,
                            );
                          }
                        });
                      } else {
                        final newReaction = await PostService.addReaction(
                          postId: post.id,
                          userId: userId,
                          type: "j'aime",
                        );
                        // Update post locally
                        setState(() {
                          final index = posts.indexWhere((p) => p.id == post.id);
                          if (index != -1) {
                            final updatedReactions = List<Reaction>.from(posts[index].userReactions)..add(newReaction);
                            posts[index] = Post(
                              id: posts[index].id,
                              media: posts[index].media,
                              mediaType: posts[index].mediaType,
                              description: posts[index].description,
                              createdAt: posts[index].createdAt,
                              updatedAt: posts[index].updatedAt,
                              veterinaire: posts[index].veterinaire,
                              reactionCounts: ReactionCounts(
                                total: posts[index].reactionCounts.total + 1,
                                jAime: posts[index].reactionCounts.jAime + 1,
                                jAdore: posts[index].reactionCounts.jAdore,
                                triste: posts[index].reactionCounts.triste,
                                jAdmire: posts[index].reactionCounts.jAdmire,
                              ),
                              userReactions: updatedReactions,
                              comments: posts[index].comments,
                              commentCount: posts[index].commentCount,
                            );
                          }
                        });
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e', style: GoogleFonts.poppins())),
                      );
                    }
                  },
                ),
                _buildActionButton(
                  icon: FontAwesomeIcons.comment,
                  label: 'Comment',
                  onPressed: () => _showCommentDialog(post.id),
                ),
                _buildActionButton(
                  icon: FontAwesomeIcons.share,
                  label: 'Share',
                  onPressed: () {
                    // Implement share functionality if needed
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color color = Colors.grey,
  }) {
    return OpenContainer(
      closedElevation: 0,
      closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      closedBuilder: (context, openContainer) => InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              FaIcon(icon, size: 20, color: color),
              const SizedBox(width: 6),
              Text(label, style: GoogleFonts.poppins(fontSize: 14, color: color)),
            ],
          ),
        ),
      ),
      openBuilder: (context, closeContainer) => Container(),
    );
  }

  Widget _buildVideoPlayer(String url) {
    if (url.isEmpty) {
      debugPrint('Empty video URL');
      return Container(
        height: 300,
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.videocam_off, size: 50, color: Colors.grey),
        ),
      );
    }

    return _VideoPlayerWidget(url: url);
  }
}

// Separate widget to manage video player lifecycle
class _VideoPlayerWidget extends StatefulWidget {
  final String url;

  const _VideoPlayerWidget({required this.url});

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      // Get token for authentication
      final token = await TokenStorage.getToken();
      final headers = token != null ? {'Authorization': 'Bearer $token'} : null;

      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
        httpHeaders: headers ?? {},
      );

      await _controller.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        // Auto-play can be enabled here if desired
        // _controller.play();
      }
    } catch (e) {
      debugPrint('Video initialization error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load video: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Container(
        height: 300,
        color: Colors.grey[200],
        child: Center(
          child: Text(
            _errorMessage!,
            style: GoogleFonts.poppins(color: Colors.red, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        height: 300,
        color: Colors.grey[200],
        child: const Center(child: SpinKitPulse(color: Colors.blueAccent)),
      );
    }

    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(_controller),
          IconButton(
            icon: Icon(
              _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              size: 50,
              color: Colors.white.withOpacity(0.8),
            ),
            onPressed: () {
              setState(() {
                if (_controller.value.isPlaying) {
                  _controller.pause();
                } else {
                  _controller.play();
                }
              });
            },
          ),
        ],
      ),
    );
  }
}