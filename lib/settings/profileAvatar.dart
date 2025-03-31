import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ProfileAvatar extends StatefulWidget {
  final double size;
  final String userId;
  final String name;
  final String email;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback? onTap;

  const ProfileAvatar({
    Key? key,
    required this.size,
    required this.userId,
    required this.name,
    this.email = '',
    this.backgroundColor = const Color(0xFF757575),
    this.textColor = Colors.white,
    this.onTap,
  }) : super(key: key);

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  File? _profileImage;
  bool _isLoading = true;
  bool _isMounted = false;

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    _loadProfileImage();
  }

  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
  }

  @override
  void didUpdateWidget(ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _loadProfileImage();
    }
  }

  Future<void> _loadProfileImage() async {
    // Only set loading state if widget is still mounted
    if (_isMounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final profileImagePath = await _getProfileImagePath();
      final file = File(profileImagePath);

      if (await file.exists()) {
        // Only update state if widget is still mounted
        if (_isMounted) {
          setState(() {
            _profileImage = file;
            _isLoading = false;
          });
        }
      } else {
        // Only update state if widget is still mounted
        if (_isMounted) {
          setState(() {
            _profileImage = null;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading profile image: $e');
      // Only update state if widget is still mounted
      if (_isMounted) {
        setState(() {
          _profileImage = null;
          _isLoading = false;
        });
      }
    }
  }

  Future<String> _getProfileImagePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return path.join(directory.path, 'profile_${widget.userId}.jpg');
  }

  String _getInitials() {
    if (widget.name.isEmpty) {
      return widget.email.isNotEmpty ? widget.email[0].toUpperCase() : '?';
    }

    final nameParts = widget.name.split(' ');
    if (nameParts.length > 1) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    } else {
      return widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (_profileImage != null) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          image: DecorationImage(
            image: FileImage(_profileImage!, scale: 1.0),
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      // Fallback to initials avatar
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.backgroundColor,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Center(
          child: Text(
            _getInitials(),
            style: TextStyle(
              color: widget.textColor,
              fontSize: widget.size * 0.4,
              fontWeight: FontWeight.bold,
              fontFamily: 'Avenir',
            ),
          ),
        ),
      );
    }
  }
}

