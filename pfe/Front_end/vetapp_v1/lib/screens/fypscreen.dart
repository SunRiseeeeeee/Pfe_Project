import 'package:flutter/material.dart';
import 'package:vetapp_v1/services/post_service.dart';
import 'package:vetapp_v1/models/token_storage.dart';
import 'dart:io' show File, Platform;
import 'package:file_picker/file_picker.dart';

class FypScreen extends StatefulWidget {
  const FypScreen({super.key});

  @override
  _FypScreenState createState() => _FypScreenState();
}

class _FypScreenState extends State<FypScreen> {
  late Future<List<Post>> postsFuture;
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
      debugPrint('User Location: $userLocation');
      final role = await TokenStorage.getUserRoleFromToken();
      debugPrint('User Role: $role');
      isVeterinarian = role?.toLowerCase() == 'veterinarian';
      postsFuture = PostService.getAllPosts();
      final posts = await postsFuture;
      debugPrint('Fetched ${posts.length} posts');
      setState(() {
        isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Error loading FYP posts: $e\nStackTrace: $stackTrace');
      setState(() {
        isLoading = false;
        errorMessage = e is PostServiceException ? e.message : 'Failed to load posts: $e';
      });
    }
  }

  void _showCommentDialog(String postId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Comment', style: TextStyle(fontFamily: 'Poppins')),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Write a comment...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins')),
          ),
          ElevatedButton(
            onPressed: () async {
              final content = controller.text.trim();
              if (content.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Comment cannot be empty.', style: TextStyle(fontFamily: 'Poppins'))),
                );
                return;
              }
              try {
                final userId = await TokenStorage.getUserId();
                if (userId == null) throw PostServiceException('User not authenticated.');
                await PostService.addComment(
                  postId: postId,
                  userId: userId,
                  content: content,
                );
                Navigator.pop(context);
                setState(() {
                  postsFuture = PostService.getAllPosts();
                });
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e', style: const TextStyle(fontFamily: 'Poppins'))),
                );
              }
            },
            child: const Text('Post', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
  }

  void _showCreatePostDialog() {
    if (!Platform.isIOS && !Platform.isAndroid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post creation is only supported on mobile devices.', style: TextStyle(fontFamily: 'Poppins')),
        ),
      );
      return;
    }

    final descriptionController = TextEditingController();
    File? mediaFile;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Post', style: TextStyle(fontFamily: 'Poppins')),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  hintText: 'Enter description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
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
                child: const Text('Pick Media', style: TextStyle(fontFamily: 'Poppins')),
              ),
              if (mediaFile != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Selected: ${mediaFile!.path.split('/').last}',
                    style: const TextStyle(fontFamily: 'Poppins'),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (mediaFile == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select a media file.', style: TextStyle(fontFamily: 'Poppins'))),
                );
                return;
              }
              try {
                final userId = await TokenStorage.getUserId();
                if (userId == null) throw PostServiceException('User not authenticated.');
                await PostService.createPost(
                  veterinaireId: userId,
                  media: mediaFile!,
                  description: descriptionController.text.trim(),
                );
                Navigator.pop(context);
                setState(() {
                  postsFuture = PostService.getAllPosts();
                });
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e', style: const TextStyle(fontFamily: 'Poppins'))),
                );
              }
            },
            child: const Text('Create', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('For You', style: TextStyle(fontFamily: 'Poppins')),
        centerTitle: true,
      ),
      floatingActionButton: isVeterinarian && (Platform.isIOS || Platform.isAndroid)
          ? FloatingActionButton(
        onPressed: _showCreatePostDialog,
        child: const Icon(Icons.add),
        tooltip: 'Create Post',
      )
          : null,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              errorMessage!,
              style: const TextStyle(color: Colors.red, fontFamily: 'Poppins'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUserDataAndPosts,
              child: const Text('Retry', style: TextStyle(fontFamily: 'Poppins')),
            ),
          ],
        ),
      )
          : FutureBuilder<List<Post>>(
        future: postsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red, fontFamily: 'Poppins'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadUserDataAndPosts,
                    child: const Text('Retry', style: TextStyle(fontFamily: 'Poppins')),
                  ),
                ],
              ),
            );
          }
          final posts = snapshot.data ?? [];
          if (posts.isEmpty) {
            return const Center(
              child: Text(
                'No posts available.',
                style: TextStyle(fontSize: 16, color: Colors.grey, fontFamily: 'Poppins'),
              ),
            );
          }

          // Filter posts by location if available
          final filteredPosts = userLocation != null && userLocation!.isNotEmpty
              ? posts.where((post) {
            return post.veterinaire.location?.toLowerCase().contains(userLocation!.toLowerCase()) ?? false;
          }).toList()
              : posts;

          return RefreshIndicator(
            onRefresh: _loadUserDataAndPosts,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: filteredPosts.length,
              itemBuilder: (context, index) {
                final post = filteredPosts[index];
                return Card(
                  elevation: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Post media
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: post.mediaType == 'image'
                            ? Image.network(
                          post.media.isNotEmpty ? post.media : 'https://via.placeholder.com/200',
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 200,
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image, size: 50),
                          ),
                        )
                            : Container(
                          height: 200,
                          color: Colors.grey[300],
                          child: const Center(
                            child: Text(
                              'Video Placeholder',
                              style: TextStyle(fontFamily: 'Poppins'),
                            ),
                          ),
                        ),
                      ),
                      // Veterinarian info
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: post.veterinaire.profilePicture != null
                                  ? NetworkImage(post.veterinaire.profilePicture!)
                                  : const AssetImage('assets/images/default_avatar.png') as ImageProvider,
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${post.veterinaire.firstName} ${post.veterinaire.lastName}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Poppins',
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  post.createdAt.toLocal().toString().split('.')[0],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'Poppins',
                                    color: Colors.grey,
                                  ),
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
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                          ),
                        ),
                      // Reactions
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.favorite, color: Colors.red, size: 20),
                            const SizedBox(width: 4),
                            Text(
                              '${post.reactionCounts.total} reactions',
                              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                            ),
                            const Spacer(),
                            Text(
                              '${post.commentCount} comments',
                              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      // Action buttons (like, comment)
                      ButtonBar(
                        alignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton.icon(
                            onPressed: () async {
                              try {
                                final userId = await TokenStorage.getUserId();
                                if (userId == null) throw PostServiceException('User not authenticated.');
                                // Check if user already liked the post
                                final hasLiked = post.userReactions.any((r) => r.user.id == userId && r.type == "j'aime");
                                if (hasLiked) {
                                  await PostService.deleteReaction(
                                    postId: post.id,
                                    userId: userId,
                                  );
                                } else {
                                  await PostService.addReaction(
                                    postId: post.id,
                                    userId: userId,
                                    type: "j'aime",
                                  );
                                }
                                setState(() {
                                  postsFuture = PostService.getAllPosts();
                                });
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e', style: const TextStyle(fontFamily: 'Poppins'))),
                                );
                              }
                            },
                            icon: const Icon(Icons.thumb_up, size: 20),
                            label: const Text('Like', style: TextStyle(fontFamily: 'Poppins')),
                          ),
                          TextButton.icon(
                            onPressed: () => _showCommentDialog(post.id),
                            icon: const Icon(Icons.comment, size: 20),
                            label: const Text('Comment', style: TextStyle(fontFamily: 'Poppins')),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}