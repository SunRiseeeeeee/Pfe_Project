import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:vetapp_v1/models/token_storage.dart';
import 'package:http_parser/http_parser.dart' show MediaType;
import 'dart:convert';

// Custom exception for PostService errors
class PostServiceException implements Exception {
  final String message;
  PostServiceException(this.message);

  @override
  String toString() => message;
}

// Model for User details (used in reactions and comments)
class UserDetails {
  final String id;
  final String firstName;
  final String lastName;
  final String? profilePicture;

  UserDetails({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.profilePicture,
  });

  factory UserDetails.fromJson(Map<String, dynamic> json) {
    return UserDetails(
      id: json['_id']?.toString() ?? '',
      firstName: json['firstName']?.toString() ?? 'Unknown',
      lastName: json['lastName']?.toString() ?? '',
      profilePicture: json['profilePicture']?.toString(),
    );
  }

  @override
  String toString() {
    return 'UserDetails(id: $id, firstName: $firstName, lastName: $lastName, profilePicture: $profilePicture)';
  }
}


// Model for Veterinarian (used in Post)
class Veterinaire {
  final String id;
  final String firstName;
  final String lastName;
  final String? profilePicture;

  Veterinaire({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.profilePicture,
  });

  factory Veterinaire.fromJson(Map<String, dynamic> json) {
    return Veterinaire(
      id: json['_id']?.toString() ?? '',
      firstName: json['firstName']?.toString() ?? 'Unknown',
      lastName: json['lastName']?.toString() ?? '',
      profilePicture: json['profilePicture']?.toString(),
    );
  }
}

// Model for Reaction Counts
class ReactionCounts {
  final int total;
  final int jAime;
  final int jAdore;
  final int triste;
  final int jAdmire;

  ReactionCounts({
    required this.total,
    required this.jAime,
    required this.jAdore,
    required this.triste,
    required this.jAdmire,
  });

  factory ReactionCounts.fromJson(Map<String, dynamic> json) {
    return ReactionCounts(
      total: json['total'] as int? ?? 0,
      jAime: json["j'aime"] as int? ?? 0,
      jAdore: json["j'adore"] as int? ?? 0,
      triste: json['triste'] as int? ?? 0,
      jAdmire: json["j'admire"] as int? ?? 0,
    );
  }
}

// Model for Reaction
class Reaction {
  final String type;
  final UserDetails user;

  Reaction({required this.type, required this.user});

  factory Reaction.fromJson(Map<String, dynamic> json) {
    return Reaction(
      type: json['type']?.toString() ?? '',
      user: UserDetails.fromJson(json['user'] as Map<String, dynamic>? ?? {}),
    );
  }
}

// Model for Comment
class Comment {
  final String id;
  final String content;
  final UserDetails user;
  final List<Reaction> reactions;
  final DateTime createdAt;
  final DateTime updatedAt;

  Comment({
    required this.id,
    required this.content,
    required this.user,
    required this.reactions,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['_id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      user: UserDetails.fromJson(json['user'] as Map<String, dynamic>? ?? {}),
      reactions: (json['reactions'] as List<dynamic>?)
          ?.map((r) => Reaction.fromJson(r as Map<String, dynamic>))
          .toList() ??
          [],
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

// Model for Post
class Post {
  final String id;
  final String media;
  final String mediaType;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Veterinaire veterinaire;
  final ReactionCounts reactionCounts;
  final List<Reaction> userReactions;
  final List<Comment> comments;
  final int commentCount;

  Post({
    required this.id,
    required this.media,
    required this.mediaType,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    required this.veterinaire,
    required this.reactionCounts,
    required this.userReactions,
    required this.comments,
    required this.commentCount,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['_id']?.toString() ?? '',
      media: json['media']?.toString() ?? '',
      mediaType: json['mediaType']?.toString() ?? 'image',
      description: json['description']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      veterinaire: Veterinaire.fromJson(json['veterinaire'] as Map<String, dynamic>? ?? {}),
      reactionCounts: ReactionCounts.fromJson(json['reactions']?['counts'] as Map<String, dynamic>? ?? {}),
      userReactions: (json['reactions']?['userReactions'] as List<dynamic>?)
          ?.map((r) => Reaction.fromJson(r as Map<String, dynamic>))
          .toList() ??
          [],
      comments: (json['comments'] as List<dynamic>?)
          ?.map((c) => Comment.fromJson(c as Map<String, dynamic>))
          .toList() ??
          [],
      commentCount: json['commentCount'] as int? ?? 0,
    );
  }
}

class PostService {
  static const String _baseUrl = "http://192.168.1.16:3000/api/posts";
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  // Initialize Dio with token interceptor
  static void _initializeDio() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await TokenStorage.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        debugPrint('PostService: Sending request to ${options.uri}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        debugPrint('PostService: Received response from ${response.requestOptions.uri}');
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        String message = 'An error occurred';
        if (e.response?.data != null && e.response?.data['message'] != null) {
          message = e.response!.data['message']?.toString() ?? message;
        } else if (e.type == DioExceptionType.connectionTimeout) {
          message = 'Connection timeout. Please check your internet.';
        } else if (e.type == DioExceptionType.receiveTimeout) {
          message = 'Server took too long to respond.';
        }
        debugPrint('PostService: Error on ${e.requestOptions.uri}: $message');
        return handler.reject(DioException(
          requestOptions: e.requestOptions,
          response: e.response,
          type: e.type,
          error: PostServiceException(message),
        ));
      },
    ));
  }

  // Check if user is a veterinarian
  static Future<bool> _isVeterinarian() async {
    final role = await TokenStorage.getUserRoleFromToken();
    debugPrint('PostService: Checking role: $role');
    return role != null && ['veterinaire', 'veterinarian'].contains(role.toLowerCase());
  }

  // Check if user is an admin
  static Future<bool> _isAdmin() async {
    final role = await TokenStorage.getUserRoleFromToken();
    debugPrint('PostService: Checking if admin, role: $role');
    return role != null && role.toLowerCase() == 'admin';
  }

  // Determine MIME type based on file extension
  static String _getMimeType(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'mp4':
      case 'mov':
        return 'video/mp4';
      case 'avi':
        return 'video/avi';
      case 'mpeg':
        return 'video/mpeg';
      default:
        return 'application/octet-stream';
    }
  }

  // Create a new post with media file (veterinarians only)
  static Future<Post> createPost({
    required String veterinaireId,
    required File media,
    required String description,
  }) async {
    if (await _isAdmin()) {
      throw PostServiceException('Admins cannot create posts.');
    }
    if (!await _isVeterinarian()) {
      throw PostServiceException('Only veterinarians can create posts.');
    }
    _initializeDio();
    try {
      final fileName = media.path.split('/').last;
      final mimeType = _getMimeType(media.path);
      final formData = FormData.fromMap({
        'media': await MultipartFile.fromFile(
          media.path,
          filename: fileName,
          contentType: MediaType.parse(mimeType),
        ),
        'description': description,
      });

      final response = await _dio.post(
        '/veterinaire/$veterinaireId',
        data: formData,
      );

      if (response.statusCode == 201) {
        return Post.fromJson(response.data['post'] as Map<String, dynamic>);
      } else {
        throw PostServiceException('Failed to create post: ${response.statusMessage ?? 'Unknown error'}');
      }
    } on DioException catch (e) {
      throw PostServiceException(
        e.error is PostServiceException ? (e.error as PostServiceException).message : 'Error creating post: ${e.message}',
      );
    }
  }

  // Update an existing post (veterinarians only)
  static Future<Post> updatePost({
    required String veterinaireId,
    required String postId,
    File? media,
    String? description,
  }) async {
    if (await _isAdmin()) {
      throw PostServiceException('Admins cannot update posts.');
    }
    if (!await _isVeterinarian()) {
      throw PostServiceException('Only veterinarians can update posts.');
    }
    _initializeDio();
    try {
      final formData = FormData.fromMap({
        if (description != null) 'description': description,
        if (media != null)
          'media': await MultipartFile.fromFile(
            media.path,
            filename: media.path.split('/').last,
            contentType: MediaType.parse(_getMimeType(media.path)),
          ),
      });

      final response = await _dio.put(
        '/veterinaire/$veterinaireId/$postId',
        data: formData,
      );

      if (response.statusCode == 200) {
        return Post.fromJson(response.data['post'] as Map<String, dynamic>);
      } else {
        throw PostServiceException('Failed to update post: ${response.statusMessage ?? 'Unknown error'}');
      }
    } on DioException catch (e) {
      throw PostServiceException(
        e.error is PostServiceException ? (e.error as PostServiceException).message : 'Error updating post: ${e.message}',
      );
    }
  }

  // Delete a post (veterinarians only)
  static Future<void> deletePost({
    required String veterinaireId,
    required String postId,
  }) async {
    if (await _isAdmin()) {
      throw PostServiceException('Admins cannot delete posts.');
    }
    if (!await _isVeterinarian()) {
      throw PostServiceException('Only veterinarians can delete posts.');
    }
    _initializeDio();
    try {
      final response = await _dio.delete('/veterinaire/$veterinaireId/$postId');
      if (response.statusCode != 200) {
        throw PostServiceException('Failed to delete post: ${response.statusMessage ?? 'Unknown error'}');
      }
    } on DioException catch (e) {
      throw PostServiceException(
        e.error is PostServiceException ? (e.error as PostServiceException).message : 'Error deleting post: ${e.message}',
      );
    }
  }

  // Get posts for a specific veterinarian (open to all)
  static Future<List<Post>> getVeterinairePosts({
    required String veterinaireId,
    int page = 1,
    int limit = 10,
    int commentsLimit = 15,
  }) async {
    _initializeDio();
    try {
      final response = await _dio.get(
        '/veterinaire/$veterinaireId',
        queryParameters: {
          'page': page,
          'limit': limit,
          'commentsLimit': commentsLimit,
        },
      );
      if (response.statusCode == 200) {
        return (response.data['posts'] as List<dynamic>)
            .map((post) => Post.fromJson(post as Map<String, dynamic>))
            .toList();
      } else {
        throw PostServiceException('Failed to fetch veterinarian posts: ${response.statusMessage ?? 'Unknown error'}');
      }
    } on DioException catch (e) {
      throw PostServiceException(
        e.error is PostServiceException ? (e.error as PostServiceException).message : 'Error fetching veterinarian posts: ${e.message}',
      );
    }
  }

  // Get all posts (for FYP, open to all)
  static Future<List<Post>> getAllPosts({
    int page = 1,
    int limit = 10,
    int commentsLimit = 15,
  }) async {
    _initializeDio();
    try {
      final response = await _dio.get(
        '/',
        queryParameters: {
          'postsPage': page,
          'postsLimit': limit,
          'commentsLimit': commentsLimit,
        },
      );
      if (response.statusCode == 200) {
        return (response.data['posts'] as List<dynamic>)
            .map((post) => Post.fromJson(post as Map<String, dynamic>))
            .toList();
      } else {
        throw PostServiceException('Failed to fetch posts: ${response.statusMessage ?? 'Unknown error'}');
      }
    } on DioException catch (e) {
      throw PostServiceException(
        e.error is PostServiceException ? (e.error as PostServiceException).message : 'Error fetching posts: ${e.message}',
      );
    }
  }

  // Add or update a reaction to a post (non-admins only)
  static Future<Reaction> addReaction({
    required String postId,
    required String userId,
    required String type,
  }) async {
    if (await _isAdmin()) {
      throw PostServiceException('Admins cannot add reactions.');
    }
    _initializeDio();
    try {
      final response = await _dio.post(
        '/$postId/reaction',
        data: {'userId': userId, 'type': type},
      );
      if (response.statusCode == 200) {
        return Reaction.fromJson(response.data['reaction'] as Map<String, dynamic>);
      } else {
        throw PostServiceException('Failed to add reaction: ${response.statusMessage ?? 'Unknown error'}');
      }
    } on DioException catch (e) {
      throw PostServiceException(
        e.error is PostServiceException ? (e.error as PostServiceException).message : 'Error adding reaction: ${e.message}',
      );
    }
  }

  // Delete a reaction from a post (non-admins only)
  static Future<void> deleteReaction({
    required String postId,
    required String userId,
  }) async {
    if (await _isAdmin()) {
      throw PostServiceException('Admins cannot delete reactions.');
    }
    _initializeDio();
    try {
      final response = await _dio.delete(
        '/$postId/reaction',
        data: {'userId': userId},
      );
      if (response.statusCode != 200) {
        throw PostServiceException('Failed to delete reaction: ${response.statusMessage ?? 'Unknown error'}');
      }
    } on DioException catch (e) {
      throw PostServiceException(
        e.error is PostServiceException ? (e.error as PostServiceException).message : 'Error deleting reaction: ${e.message}',
      );
    }
  }

  // Get reactions summary for a post (open to all)
  static Future<Map<String, dynamic>> getReactionsSummary({
    required String postId,
  }) async {
    _initializeDio();
    try {
      final response = await _dio.get('/$postId/reactions/summary');
      if (response.statusCode == 200) {
        return {
          'counts': ReactionCounts.fromJson(response.data['counts'] as Map<String, dynamic>? ?? {}),
          'userReactions': (response.data['userReactions'] as List<dynamic>?)
              ?.map((r) => Reaction.fromJson(r as Map<String, dynamic>))
              .toList() ??
              [],
        };
      } else {
        throw PostServiceException('Failed to fetch reactions summary: ${response.statusMessage ?? 'Unknown error'}');
      }
    } on DioException catch (e) {
      throw PostServiceException(
        e.error is PostServiceException ? (e.error as PostServiceException).message : 'Error fetching reactions summary: ${e.message}',
      );
    }
  }

  // Add a comment to a post (non-admins only)
  static Future<Comment> addComment({
    required String postId,
    required String userId,
    required String content,
  }) async {
    if (await _isAdmin()) {
      throw PostServiceException('Admins cannot add comments.');
    }
    _initializeDio();
    try {
      final response = await _dio.post(
        '/$postId/comment',
        data: {'userId': userId, 'content': content},
      );
      if (response.statusCode == 201) {
        return Comment.fromJson(response.data['comment'] as Map<String, dynamic>);
      } else {
        throw PostServiceException('Failed to add comment: ${response.statusMessage ?? 'Unknown error'}');
      }
    } on DioException catch (e) {
      throw PostServiceException(
        e.error is PostServiceException ? (e.error as PostServiceException).message : 'Error adding comment: ${e.message}',
      );
    }
  }

  // Update a comment (non-admins only)
  static Future<Comment> updateComment({
    required String postId,
    required String commentId,
    required String content,
  }) async {
    if (await _isAdmin()) {
      throw PostServiceException('Admins cannot update comments.');
    }
    _initializeDio();
    try {
      final response = await _dio.put(
        '/$postId/comment/$commentId',
        data: {'content': content},
      );
      if (response.statusCode == 200) {
        return Comment.fromJson(response.data['comment'] as Map<String, dynamic>);
      } else {
        throw PostServiceException('Failed to update comment: ${response.statusMessage ?? 'Unknown error'}');
      }
    } on DioException catch (e) {
      throw PostServiceException(
        e.error is PostServiceException ? (e.error as PostServiceException).message : 'Error updating comment: ${e.message}',
      );
    }
  }

  // Delete a comment (non-admins only)
  static Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    if (await _isAdmin()) {
      throw PostServiceException('Admins cannot delete comments.');
    }
    _initializeDio();
    try {
      final response = await _dio.delete('/$postId/comment/$commentId');
      if (response.statusCode != 200) {
        throw PostServiceException('Failed to delete comment: ${response.statusMessage ?? 'Unknown error'}');
      }
    } on DioException catch (e) {
      throw PostServiceException(
        e.error is PostServiceException ? (e.error as PostServiceException).message : 'Error deleting comment: ${e.message}',
      );
    }
  }
}