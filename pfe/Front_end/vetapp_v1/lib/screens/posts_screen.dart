import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vetapp_v1/services/post_service.dart';

import 'package:vetapp_v1/models/token_storage.dart';
import 'package:video_player/video_player.dart';

class PostsScreen extends StatefulWidget {
  final String vetId;

  const PostsScreen({super.key, required this.vetId});

  @override
  State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> {
  List<Post> _posts = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _userId;
  String? _userRole;
  final Map<String, TextEditingController> _commentControllers = {};
  final Map<String, TextEditingController> _editCommentControllers = {};
  final Map<String, bool> _showComments = {};

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);
    try {
      _userId = await TokenStorage.getUserId();
      _userRole = await TokenStorage.getUserRoleFromToken();
      print('PostsScreen: User ID: $_userId, Role: $_userRole');
      await _fetchPosts();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize: $e';
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize: $e')),
        );
      }
    }
  }

  Future<void> _fetchPosts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final posts = await PostService.getVeterinairePosts(
        veterinaireId: widget.vetId,
        page: 1,
        limit: 10,
        commentsLimit: 15,
      );
      setState(() {
        _posts = posts;
        for (var post in posts) {
          _commentControllers[post.id] = TextEditingController();
          _showComments[post.id] = false;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load posts: $e')),
        );
      }
    }
  }

  Future<void> _addComment(String postId) async {
    if (_userId == null || _userRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to add a comment')),
      );
      return;
    }
    if (!['client', 'veterinaire', 'secretary'].contains(_userRole!.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only clients, veterinarians, or secretaries can add comments')),
      );
      return;
    }
    final controller = _commentControllers[postId]!;
    if (controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment cannot be empty')),
      );
      return;
    }

    try {
      await PostService.addComment(
        postId: postId,
        userId: _userId!,
        content: controller.text.trim(),
      );
      controller.clear();
      await _fetchPosts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add comment: $e')),
        );
      }
    }
  }

  Future<void> _addReaction(String postId, String reactionType) async {
    if (_userId == null || _userRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to add a reaction')),
      );
      return;
    }
    if (!['client', 'veterinaire', 'secretary'].contains(_userRole!.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only clients, veterinarians, or secretaries can add reactions')),
      );
      return;
    }

    try {
      await PostService.addReaction(
        postId: postId,
        userId: _userId!,
        type: reactionType,
      );
      await _fetchPosts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$reactionType reaction added')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add reaction: $e')),
        );
      }
    }
  }

  Future<void> _editComment(String postId, String commentId, String content) async {
    if (_userId == null || _userRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to edit a comment')),
      );
      return;
    }

    try {
      await PostService.updateComment(
        postId: postId,
        commentId: commentId,
        content: content,
      );
      await _fetchPosts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update comment: $e')),
        );
      }
    }
  }

  Future<void> _deleteComment(String postId, String commentId) async {
    if (_userId == null || _userRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to delete a comment')),
      );
      return;
    }

    try {
      await PostService.deleteComment(
        postId: postId,
        commentId: commentId,
      );
      await _fetchPosts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete comment: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Veterinarian Posts',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : _errorMessage != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: GoogleFonts.poppins(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchPosts,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Retry',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        ),
      )
          : _posts.isEmpty
          ? Center(
        child: Text(
          'No posts available for this veterinarian.',
          style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          final post = _posts[index];
          return _buildPostCard(post);
        },
      ),
    );
  }

  Widget _buildPostCard(Post post) {
    String mediaUrl = post.media;
    if (mediaUrl.contains('localhost')) {
      mediaUrl = mediaUrl.replaceAll('localhost', '192.168.1.16');
    }
    final showComments = _showComments[post.id] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              radius: 20,
              backgroundImage: post.veterinaire.profilePicture != null &&
                  post.veterinaire.profilePicture!.isNotEmpty
                  ? post.veterinaire.profilePicture!.startsWith('http')
                  ? NetworkImage(post.veterinaire.profilePicture!.replaceAll('localhost', '192.168.1.16'))
                  : FileImage(File(post.veterinaire.profilePicture!)) as ImageProvider
                  : const AssetImage('assets/images/default_avatar.png'),
            ),
            title: Text(
              'Dr. ${post.veterinaire.firstName} ${post.veterinaire.lastName}',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              _formatDate(post.createdAt),
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
            ),
          ),
          if (post.media.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: post.mediaType.toLowerCase().contains('image')
                  ? Image.network(
                mediaUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 200,
                errorBuilder: (context, error, stackTrace) {
                  print('Error loading image: $error');
                  return Container(
                    height: 200,
                    color: Colors.grey[200],
                    child: const Center(child: Icon(Icons.error, color: Colors.red)),
                  );
                },
              )
                  : post.mediaType.toLowerCase().contains('video')
                  ? _VideoPlayerWidget(videoUrl: mediaUrl)
                  : Container(
                height: 200,
                color: Colors.grey[200],
                child: const Center(child: Text('Unsupported media type')),
              ),
            ),
          if (post.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                post.description,
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.favorite, size: 20, color: Colors.red),
                        const SizedBox(width: 4),
                        Text(
                          '${post.reactionCounts.total} Reactions',
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showComments[post.id] = !showComments;
                        });
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.comment, size: 20, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            '${post.commentCount} Comments',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.blue),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_userRole != null && ['client', 'veterinaire', 'secretary'].contains(_userRole!.toLowerCase()))
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildReactionButton(post.id, "j'aime", Icons.thumb_up),
                        _buildReactionButton(post.id, "j'adore", Icons.favorite),
                        _buildReactionButton(post.id, "triste", Icons.sentiment_dissatisfied),
                        _buildReactionButton(post.id, "j'admire", Icons.star),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (_userRole != null && ['client', 'veterinaire', 'secretary'].contains(_userRole!.toLowerCase()))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentControllers[post.id],
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      style: GoogleFonts.poppins(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.deepPurple),
                    onPressed: () => _addComment(post.id),
                  ),
                ],
              ),
            ),
          if (showComments && post.comments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comments',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...post.comments.map((comment) => _buildCommentTile(post.id, comment)),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildReactionButton(String postId, String reactionType, IconData icon) {
    bool isReacted = _posts
        .firstWhere((post) => post.id == postId)
        .userReactions
        .any((reaction) => reaction.type == reactionType && reaction.user.id == _userId);
    return IconButton(
      icon: Icon(
        icon,
        color: isReacted ? Colors.deepPurple : Colors.grey,
      ),
      onPressed: () => _addReaction(postId, reactionType),
      tooltip: reactionType,
    );
  }

  Widget _buildCommentTile(String postId, Comment comment) {
    // Extract user ID from the nested structure
    String? commentUserId;

    try {
      // Convert the user.id object to string and extract the actual ID
      String userIdString = comment.user.id.toString();
      print('Raw user.id string: $userIdString');

      // Use regex to extract the ID from the string representation
      // Looking for pattern: id: 67e8bbdb091252cf65aca2f9
      final regex = RegExp(r'id: ([a-fA-F0-9]{24})');
      final match = regex.firstMatch(userIdString);

      if (match != null) {
        commentUserId = match.group(1);
        print('Extracted user ID: $commentUserId');
      } else {
        // Try alternative regex patterns
        final altRegex = RegExp(r'([a-fA-F0-9]{24})');
        final altMatches = altRegex.allMatches(userIdString);

        for (final match in altMatches) {
          final potentialId = match.group(0);
          if (potentialId != null && potentialId.length == 24) {
            commentUserId = potentialId;
            print('Extracted user ID (alternative): $commentUserId');
            break;
          }
        }

        if (commentUserId == null) {
          print('Failed to extract user ID from: $userIdString');
        }
      }
    } catch (e) {
      print('Error extracting comment user ID: $e');
      commentUserId = null;
    }

    final isOwnComment = _userId != null && commentUserId == _userId;
    print('PostsScreen: Fixed comment ownership check - commentUserId: $commentUserId, _userId: $_userId, isOwnComment: $isOwnComment');

    final editController = _editCommentControllers.putIfAbsent(
      comment.id,
          () => TextEditingController(text: comment.content),
    );

    return ListTile(
      leading: CircleAvatar(
        radius: 16,
        backgroundImage: comment.user.profilePicture != null &&
            comment.user.profilePicture!.isNotEmpty
            ? comment.user.profilePicture!.startsWith('http')
            ? NetworkImage(comment.user.profilePicture!.replaceAll('localhost', '192.168.1.16'))
            : FileImage(File(comment.user.profilePicture!)) as ImageProvider
            : const AssetImage('assets/images/default_avatar.png'),
      ),
      title: Text(
        '${comment.user.firstName} ${comment.user.lastName}',
        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            comment.content,
            style: GoogleFonts.poppins(fontSize: 12),
          ),
          Text(
            _formatDate(comment.createdAt),
            style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
      trailing: isOwnComment && _userRole != null && ['client', 'veterinaire', 'secretary'].contains(_userRole!.toLowerCase())
          ? PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Colors.grey),
        onSelected: (value) {
          if (value == 'edit') {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Edit Comment', style: GoogleFonts.poppins()),
                content: TextField(
                  controller: editController,
                  decoration: InputDecoration(
                    hintText: 'Edit your comment...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  style: GoogleFonts.poppins(),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: GoogleFonts.poppins()),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (editController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Comment cannot be empty')),
                        );
                        return;
                      }
                      _editComment(postId, comment.id, editController.text.trim());
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('Save', style: GoogleFonts.poppins(color: Colors.white)),
                  ),
                ],
              ),
            );
          } else if (value == 'delete') {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Delete Comment', style: GoogleFonts.poppins()),
                content: Text(
                  'Are you sure you want to delete this comment?',
                  style: GoogleFonts.poppins(),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: GoogleFonts.poppins()),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _deleteComment(postId, comment.id);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white)),
                  ),
                ],
              ),
            );
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'edit',
            child: Text('Edit', style: GoogleFonts.poppins()),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
      )
          : null,
    );
  }




  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _commentControllers.values.forEach((controller) => controller.dispose());
    _editCommentControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }
}

class _VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const _VideoPlayerWidget({required this.videoUrl});

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      }).catchError((error) {
        print('Error initializing video player: $error');
        if (mounted) {
          setState(() {
            _isInitialized = false;
          });
        }
      });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: _isInitialized
          ? Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(_controller),
          IconButton(
            icon: Icon(
              _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 50,
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
      )
          : const Center(child: CircularProgressIndicator(color: Colors.deepPurple)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}