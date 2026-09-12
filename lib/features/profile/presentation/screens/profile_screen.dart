import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/main_wrapper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _client = SupabaseConfig.client;
  final ImagePicker _picker = ImagePicker();

  bool _loading = true;
  bool _uploadingLogo = false;

  int? _schoolId;
  String _schoolName = 'School';
  String? _schoolLogoUrl;

  @override
  void initState() {
    super.initState();
    _loadSchoolProfile();
  }

  Future<int?> _getSchoolId() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final profile = await _client
          .from('profiles')
          .select('school_id')
          .eq('id', userId)
          .maybeSingle();

      final value = profile?['school_id'];

      if (value is int) return value;

      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    } catch (_) {}

    try {
      final school = await _client
          .from('schools')
          .select('id')
          .eq('created_by', userId)
          .maybeSingle();

      final value = school?['id'];

      if (value is int) return value;

      return int.tryParse(value?.toString() ?? '');
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadSchoolProfile() async {
    try {
      final schoolId = await _getSchoolId();

      if (schoolId == null) {
        if (mounted) {
          setState(() {
            _loading = false;
          });
        }
        return;
      }

      final school = await _client
          .from('schools')
          .select('id, school_name, logo_url')
          .eq('id', schoolId)
          .maybeSingle();

      if (!mounted) return;

      final name =
          school?['school_name']?.toString().trim() ?? '';
      final logo =
          school?['logo_url']?.toString().trim() ?? '';

      setState(() {
        _schoolId = schoolId;
        _schoolName = name.isEmpty ? 'School' : name;
        _schoolLogoUrl = logo.isEmpty ? null : logo;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
        _showMessage('Could not load school profile.');
      }
    }
  }

  Future<void> _pickAndUploadLogo() async {
    if (_schoolId == null) {
      _showMessage('School profile was not found.');
      return;
    }

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (picked == null) return;

      setState(() {
        _uploadingLogo = true;
      });

      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('Selected image is empty.');
      }

      final extension = picked.name.contains('.')
          ? picked.name.split('.').last.toLowerCase()
          : 'jpg';

      final safeExtension =
      ['jpg', 'jpeg', 'png', 'webp'].contains(extension)
          ? extension
          : 'jpg';

      final filePath =
          'school-logos/${_schoolId}_${DateTime.now().millisecondsSinceEpoch}.$safeExtension';

      await _client.storage
          .from('school-assets')
          .uploadBinary(
        filePath,
        bytes,
        fileOptions: FileOptions(
          upsert: true,
          contentType: _contentType(safeExtension),
        ),
      );

      final publicUrl = _client.storage
          .from('school-assets')
          .getPublicUrl(filePath);

      await _client
          .from('schools')
          .update({
        'logo_url': publicUrl,
      })
          .eq('id', _schoolId!);

      if (!mounted) return;

      setState(() {
        _schoolLogoUrl = publicUrl;
        _uploadingLogo = false;
      });

      _showMessage('School logo updated successfully.');

      // Refresh MainWrapper so its AppBar picks up the new logo
      // when the wrapper is rebuilt/navigated.
    } on StorageException catch (e) {
      if (!mounted) return;

      setState(() {
        _uploadingLogo = false;
      });

      _showMessage('Storage error: ${e.message}');
    } on PostgrestException catch (e) {
      if (!mounted) return;

      setState(() {
        _uploadingLogo = false;
      });

      _showMessage('Database error: ${e.message}');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _uploadingLogo = false;
      });

      _showMessage(
        'Logo upload failed: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  String _contentType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpeg':
      case 'jpg':
      default:
        return 'image/jpeg';
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final user = _client.auth.currentUser;

    final rawName =
    user?.userMetadata?['full_name']?.toString().trim();

    final name =
    rawName != null && rawName.isNotEmpty
        ? rawName
        : 'School Admin';

    final email = user?.email ?? '';

    final role = (user?.userMetadata?['role'] ?? 'Principal')
        .toString()
        .toUpperCase();

    final phone =
    user?.userMetadata?['phone']?.toString().trim();

    return MainWrapper(
      child: RefreshIndicator(
        onRefresh: _loadSchoolProfile,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          children: [
            _buildProfileHeader(
              name,
              email,
              role,
            ),
            const SizedBox(height: 48),
            _buildSectionTitle('School'),
            const SizedBox(height: 16),
            _infoTile(
              'School Name',
              _schoolName,
              Icons.school_outlined,
            ),
            _schoolLogoTile(),
            const SizedBox(height: 32),
            _buildSectionTitle('Personal Information'),
            const SizedBox(height: 16),
            _infoTile(
              'Full Name',
              name,
              Icons.person_outline_rounded,
            ),
            _infoTile(
              'Email Address',
              email.isEmpty ? 'Not added' : email,
              Icons.email_outlined,
            ),
            _infoTile(
              'Contact Number',
              phone == null || phone.isEmpty
                  ? 'Not added'
                  : phone,
              Icons.phone_outlined,
            ),
            const SizedBox(height: 32),
            _buildSectionTitle('Account Security'),
            const SizedBox(height: 16),
            _actionTile(
              'Change Password',
              'Update your login credentials',
              Icons.lock_outline_rounded,
            ),
            _actionTile(
              'Two-Factor Auth',
              'Enabled for your safety',
              Icons.verified_user_outlined,
            ),
            const SizedBox(height: 48),
            FilledButton.tonal(
              onPressed: () async {
                await _client.auth.signOut();
              },
              style: FilledButton.styleFrom(
                backgroundColor:
                AppColors.error.withOpacity(0.1),
                foregroundColor: AppColors.error,
              ),
              child: const Text('Sign Out from Devices'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
      String name,
      String email,
      String role,
      ) {
    final hasLogo =
        _schoolLogoUrl != null &&
            _schoolLogoUrl!.isNotEmpty;

    return Center(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 120,
                height: 120,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color:
                  AppColors.primary.withOpacity(.08),
                  borderRadius:
                  BorderRadius.circular(40),
                  border: Border.all(
                    color: AppColors.border,
                  ),
                ),
                child: _loading
                    ? const Center(
                  child:
                  CircularProgressIndicator(),
                )
                    : hasLogo
                    ? Image.network(
                  _schoolLogoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, __, ___) {
                    return const Icon(
                      Icons.school_rounded,
                      color:
                      AppColors.primary,
                      size: 56,
                    );
                  },
                )
                    : const Icon(
                  Icons.school_rounded,
                  color: AppColors.primary,
                  size: 56,
                ),
              ),
              InkWell(
                onTap:
                _uploadingLogo
                    ? null
                    : _pickAndUploadLogo,
                borderRadius:
                BorderRadius.circular(30),
                child: Container(
                  padding:
                  const EdgeInsets.all(8),
                  decoration:
                  const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: _uploadingLogo
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed:
            _uploadingLogo
                ? null
                : _pickAndUploadLogo,
            icon: const Icon(
              Icons.photo_library_outlined,
              size: 18,
            ),
            label: Text(
              _uploadingLogo
                  ? 'Uploading...'
                  : hasLogo
                  ? 'Change School Logo'
                  : 'Upload School Logo',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          if (email.isNotEmpty)
            Text(
              email,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          const SizedBox(height: 8),
          Container(
            padding:
            const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color:
              AppColors.primary.withOpacity(0.1),
              borderRadius:
              BorderRadius.circular(20),
            ),
            child: Text(
              role,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _schoolLogoTile() {
    final hasLogo =
        _schoolLogoUrl != null &&
            _schoolLogoUrl!.isNotEmpty;

    return Card(
      margin:
      const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius:
            BorderRadius.circular(10),
          ),
          child: hasLogo
              ? Image.network(
            _schoolLogoUrl!,
            fit: BoxFit.cover,
            errorBuilder:
                (_, __, ___) =>
            const Icon(
              Icons.broken_image_outlined,
            ),
          )
              : const Icon(
            Icons.image_outlined,
            color:
            AppColors.textSecondary,
          ),
        ),
        title: const Text(
          'School Logo',
          style: TextStyle(
            color:
            AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          hasLogo
              ? 'Logo saved to School Profile'
              : 'No school logo uploaded yet',
          style: const TextStyle(
            color:
            AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        trailing: IconButton(
          tooltip: 'Change logo',
          onPressed:
          _uploadingLogo
              ? null
              : _pickAndUploadLogo,
          icon: const Icon(
            Icons.edit_rounded,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _infoTile(
      String label,
      String value,
      IconData icon,
      ) {
    return Card(
      margin:
      const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          icon,
          color:
          AppColors.textSecondary,
          size: 20,
        ),
        title: Text(
          label,
          style: const TextStyle(
            color:
            AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(
            color:
            AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _actionTile(
      String title,
      String sub,
      IconData icon,
      ) {
    return Card(
      margin:
      const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          icon,
          color: AppColors.primary,
          size: 20,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          sub,
          style: const TextStyle(
            color:
            AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          size: 20,
        ),
      ),
    );
  }
}
