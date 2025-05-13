import 'package:flutter/material.dart';
import 'package:vetapp_v1/services/post_service.dart';
import 'package:vetapp_v1/models/token_storage.dart';
import 'dart:io' show File, Platform;
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
  List<Post> posts = [];
  String? userLocation;
  bool isLoading = true;
  String? errorMessage;
  bool isVeterinarian = false;
  final Map<String, bool> _commentsExpanded = {};

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
      debugPrint('User role: $role');
      debugPrint('Platform: ${Platform.operatingSystem}, isIOS: ${Platform.isIOS}, isAndroid: ${Platform.isAndroid}');
      isVeterinarian = role != null && ['veterinaire', 'veterinarian'].contains(role.toLowerCase());
      debugPrint('isVeterinarian: $isVeterinarian');
      postsFuture = PostService.getAllPosts();
      posts = await postsFuture;
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

  void _showEditCommentDialog(String postId, Comment comment) {
    debugPrint('Opening edit comment dialog for comment ${comment.id}');
    final controller = TextEditingController(text: comment.content);
    try {
      showDialog(
        context: context,
        builder: (context) {
          debugPrint('Building edit comment dialog for comment ${comment.id}');
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Edit Comment',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Edit your comment...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    maxLines: 3,
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          debugPrint('Cancel pressed for comment ${comment.id}');
                          Navigator.pop(context);
                        },
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
                            debugPrint('Updating comment ${comment.id} with content: $content');
                            final updatedComment = await PostService.updateComment(
                              postId: postId,
                              commentId: comment.id,
                              content: content,
                            );
                            Navigator.pop(context);
                            setState(() {
                              final postIndex = posts.indexWhere((post) => post.id == postId);
                              if (postIndex != -1) {
                                final updatedComments = List<Comment>.from(posts[postIndex].comments);
                                final commentIndex = updatedComments.indexWhere((c) => c.id == comment.id);
                                if (commentIndex != -1) {
                                  updatedComments[commentIndex] = updatedComment;
                                }
                                posts[postIndex] = Post(
                                  id: posts[postIndex].id,
                                  media: posts[postIndex].media,
                                  mediaType: posts[postIndex].mediaType,
                                  description: posts[postIndex].description,
                                  createdAt: posts[postIndex].createdAt,
                                  updatedAt: posts[postIndex].updatedAt,
                                  veterinaire: posts[postIndex].veterinaire,
                                  reactionCounts: posts[postIndex].reactionCounts,
                                  userReactions: posts[postIndex].userReactions,
                                  comments: updatedComments,
                                  commentCount: posts[postIndex].commentCount,
                                );
                              }
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Comment updated successfully', style: GoogleFonts.poppins())),
                            );
                          } catch (e) {
                            debugPrint('Update comment error: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e', style: GoogleFonts.poppins())),
                            );
                          }
                        },
                        child: Text('Update', style: GoogleFonts.poppins(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      debugPrint('Error opening edit comment dialog: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening edit dialog: $e', style: GoogleFonts.poppins())),
      );
    }
  }

  void _showCreatePostDialog() {
    if (!Platform.isIOS && !Platform.isAndroid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Post creation is only supported on mobile devices', style: GoogleFonts.poppins())),
      );
      return;
    }

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
                          debugPrint('Creating post for userId: $userId');
                          await PostService.createPost(
                            veterinaireId: userId,
                            media: mediaFile!,
                            description: descriptionController.text.trim(),
                          );
                          Navigator.pop(context);
                          await _loadUserDataAndPosts();
                        } catch (e) {
                          debugPrint('Create post error: $e');
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

  void _showEditPostDialog(String postId, String currentDescription) {
    final descriptionController = TextEditingController(text: currentDescription);

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
                'Edit Post',
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
                      final newDescription = descriptionController.text.trim();
                      try {
                        final userId = await TokenStorage.getUserId();
                        if (userId == null) throw PostServiceException('User not authenticated');
                        await PostService.updatePost(
                          veterinaireId: userId,
                          postId: postId,
                          description: newDescription,
                        );
                        Navigator.pop(context);
                        setState(() {
                          final index = posts.indexWhere((post) => post.id == postId);
                          if (index != -1) {
                            posts[index] = Post(
                              id: posts[index].id,
                              media: posts[index].media,
                              mediaType: posts[index].mediaType,
                              description: newDescription,
                              createdAt: posts[index].createdAt,
                              updatedAt: DateTime.now(),
                              veterinaire: posts[index].veterinaire,
                              reactionCounts: posts[index].reactionCounts,
                              userReactions: posts[index].userReactions,
                              comments: posts[index].comments,
                              commentCount: posts[index].commentCount,
                            );
                          }
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Post updated successfully', style: GoogleFonts.poppins())),
                        );
                      } catch (e) {
                        debugPrint('Update post error: $e');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e', style: GoogleFonts.poppins())),
                        );
                      }
                    },
                    child: Text('Update', style: GoogleFonts.poppins(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeletePostDialog(String postId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Post',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: Colors.redAccent,
            ),
            onPressed: () async {
              try {
                final userId = await TokenStorage.getUserId();
                if (userId == null) throw PostServiceException('User not authenticated');
                await PostService.deletePost(
                  veterinaireId: userId,
                  postId: postId,
                );
                Navigator.pop(context);
                setState(() {
                  posts.removeWhere((post) => post.id == postId);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Post deleted successfully', style: GoogleFonts.poppins())),
                );
              } catch (e) {
                debugPrint('Delete post error: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e', style: GoogleFonts.poppins())),
                );
              }
            },
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  ImageProvider getProfilePictureProvider(String? profilePicture) {
    debugPrint('Loading profile picture: $profilePicture');
    if (profilePicture == null || profilePicture.isEmpty) {
      return const AssetImage('assets/images/default_avatar.png');
    }
    if (profilePicture.startsWith('/data/') || profilePicture.startsWith('file://')) {
      final path = profilePicture.startsWith('file://') ? profilePicture.substring(7) : profilePicture;
      return FileImage(File(path));
    }
    return CachedNetworkImageProvider(profilePicture);
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
            color: Colors.deepPurple,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        actions: [],
      ),
      floatingActionButton: isVeterinarian && (Platform.isIOS || Platform.isAndroid)
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
        child: Column(
          children: [
            Expanded(
              child: AnimationLimiter(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    if (userLocation != null &&
                        userLocation!.isNotEmpty &&
                        !(post.veterinaire.location?.toLowerCase().contains(userLocation!.toLowerCase()) ??
                            false)) {
                      return const SizedBox.shrink();
                    }
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
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(Post post) {
    final isCommentsExpanded = _commentsExpanded[post.id] ?? false;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
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
              FutureBuilder<String?>(
                future: TokenStorage.getUserId(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data == post.veterinaire.id) {
                    return Positioned(
                      top: 8,
                      right: 8,
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showEditPostDialog(post.id, post.description);
                          } else if (value == 'delete') {
                            _showDeletePostDialog(post.id);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit Post', style: GoogleFonts.poppins()),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete Post', style: GoogleFonts.poppins()),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: getProfilePictureProvider(post.veterinaire.profilePicture),
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
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _commentsExpanded[post.id] = !isCommentsExpanded;
                    });
                  },
                  child: Text(
                    '${post.commentCount} comments',
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.blueAccent),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildActionButton(
                  icon: post.userReactions
                      .any((r) => r.user.id == (TokenStorage.getUserId() ?? '') && r.type == "j'aime")
                      ? FontAwesomeIcons.solidHeart
                      : FontAwesomeIcons.heart,
                  label: 'Like',
                  color: post.userReactions
                      .any((r) => r.user.id == (TokenStorage.getUserId() ?? '') && r.type == "j'aime")
                      ? Colors.red
                      : Colors.grey,
                  onPressed: () async {
                    try {
                      final userId = await TokenStorage.getUserId();
                      if (userId == null) throw PostServiceException('User not authenticated');
                      final hasLiked = post.userReactions.any((r) => r.user.id == userId && r.type == "j'aime");
                      if (hasLiked) {
                        await PostService.deleteReaction(postId: post.id, userId: userId);
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
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: isCommentsExpanded ? (post.comments.isEmpty ? 60 : null) : 0,
            child: isCommentsExpanded
                ? post.comments.isEmpty
                ? Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'No comments yet.',
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
              ),
            )
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: post.comments.length,
              itemBuilder: (context, index) {
                final comment = post.comments[index];
                return _buildCommentItem(post.id, comment);
              },
            )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCommentItem(String postId, Comment comment) {
    return FutureBuilder<String?>(
      future: TokenStorage.getUserId(),
      builder: (context, snapshot) {
        final isOwnComment = snapshot.hasData && snapshot.data == comment.user.id;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: getProfilePictureProvider(comment.user.profilePicture),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${comment.user.firstName} ${comment.user.lastName}',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const Spacer(),
                        if (isOwnComment)
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                            onSelected: (value) {
                              debugPrint('Selected option: $value for comment ${comment.id}');
                              if (value == 'edit') {
                                debugPrint('Calling showEditCommentDialog for comment ${comment.id}');
                                _showEditCommentDialog(postId, comment);
                              } else if (value == 'delete') {
                                debugPrint('Initiating delete for comment ${comment.id}');
                                _handleDeleteComment(postId, comment);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit Comment', style: GoogleFonts.poppins()),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete Comment', style: GoogleFonts.poppins()),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      comment.content,
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      comment.createdAt.toLocal().toString().split('.')[0],
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleDeleteComment(String postId, Comment comment) async {
    final deletedComment = comment;
    final postIndex = posts.indexWhere((post) => post.id == postId);

    setState(() {
      if (postIndex != -1) {
        final updatedComments = List<Comment>.from(posts[postIndex].comments)
          ..removeWhere((c) => c.id == comment.id);
        posts[postIndex] = Post(
          id: posts[postIndex].id,
          media: posts[postIndex].media,
          mediaType: posts[postIndex].mediaType,
          description: posts[postIndex].description,
          createdAt: posts[postIndex].createdAt,
          updatedAt: posts[postIndex].updatedAt,
          veterinaire: posts[postIndex].veterinaire,
          reactionCounts: posts[postIndex].reactionCounts,
          userReactions: posts[postIndex].userReactions,
          comments: updatedComments,
          commentCount: posts[postIndex].commentCount - 1,
        );
      }
    });

    final snackBar = SnackBar(
      content: Text('Comment deleted', style: GoogleFonts.poppins()),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          setState(() {
            if (postIndex != -1) {
              final updatedComments = List<Comment>.from(posts[postIndex].comments)..add(deletedComment);
              posts[postIndex] = Post(
                id: posts[postIndex].id,
                media: posts[postIndex].media,
                mediaType: posts[postIndex].mediaType,
                description: posts[postIndex].description,
                createdAt: posts[postIndex].createdAt,
                updatedAt: posts[postIndex].updatedAt,
                veterinaire: posts[postIndex].veterinaire,
                reactionCounts: posts[postIndex].reactionCounts,
                userReactions: posts[postIndex].userReactions,
                comments: updatedComments,
                commentCount: posts[postIndex].commentCount + 1,
              );
            }
          });
        },
      ),
      duration: const Duration(seconds: 4),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);

    try {
      await PostService.deleteComment(
        postId: postId,
        commentId: comment.id,
      );
    } catch (e) {
      debugPrint('Delete comment error: $e');
      setState(() {
        if (postIndex != -1) {
          final updatedComments = List<Comment>.from(posts[postIndex].comments)..add(deletedComment);
          posts[postIndex] = Post(
            id: posts[postIndex].id,
            media: posts[postIndex].media,
            mediaType: posts[postIndex].mediaType,
            description: posts[postIndex].description,
            createdAt: posts[postIndex].createdAt,
            updatedAt: posts[postIndex].updatedAt,
            veterinaire: posts[postIndex].veterinaire,
            reactionCounts: posts[postIndex].reactionCounts,
            userReactions: posts[postIndex].userReactions,
            comments: updatedComments,
            commentCount: posts[postIndex].commentCount + 1,
          );
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting comment: $e', style: GoogleFonts.poppins())),
      );
    }
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
        child: CachedNetworkImage(
          imageUrl: 'https://images.pexels.com/photos/1108099/pexels-photo-1108099.jpeg',
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