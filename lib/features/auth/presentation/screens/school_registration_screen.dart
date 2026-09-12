import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';

// ============================================================
// REGISTRATION STATE
// ============================================================

class RegistrationState {
  final bool isLoading;
  final XFile? logo;
  final Uint8List? logoBytes;
  final bool isObscure;

  const RegistrationState({
    this.isLoading = false,
    this.logo,
    this.logoBytes,
    this.isObscure = true,
  });

  RegistrationState copyWith({
    bool? isLoading,
    XFile? logo,
    Uint8List? logoBytes,
    bool? isObscure,
  }) {
    return RegistrationState(
      isLoading: isLoading ?? this.isLoading,
      logo: logo ?? this.logo,
      logoBytes: logoBytes ?? this.logoBytes,
      isObscure: isObscure ?? this.isObscure,
    );
  }
}

// ============================================================
// REGISTRATION NOTIFIER
// ============================================================

class RegistrationNotifier extends StateNotifier<RegistrationState> {
  RegistrationNotifier() : super(const RegistrationState());

  final ImagePicker _picker = ImagePicker();

  SupabaseClient get _client => SupabaseConfig.client;

  // ==========================================================
  // PASSWORD VISIBILITY
  // ==========================================================

  void togglePasswordVisibility() {
    state = state.copyWith(
      isObscure: !state.isObscure,
    );
  }

  // ==========================================================
  // PICK LOGO
  // ==========================================================

  Future<String?> pickLogo() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (image == null) {
        return null;
      }

      final bytes = await image.readAsBytes();

      state = state.copyWith(
        logo: image,
        logoBytes: bytes,
      );

      return null;
    } catch (e) {
      return 'Could not select image: $e';
    }
  }

  // ==========================================================
  // REGISTER SCHOOL
  // ==========================================================

  Future<void> registerSchool({
    required String schoolName,
    required String schoolEmail,
    required String schoolPhone,
    required String schoolAddress,
    required String principalName,
    required String principalEmail,
    required String principalPassword,
    required Function(String message) onSuccess,
    required Function(String error) onError,
  }) async {
    if (state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
    );

    try {
      final cleanSchoolName = schoolName.trim();
      final cleanSchoolEmail =
      schoolEmail.trim().toLowerCase();
      final cleanSchoolPhone =
      schoolPhone.trim();
      final cleanSchoolAddress =
      schoolAddress.trim();

      final cleanPrincipalName =
      principalName.trim();
      final cleanPrincipalEmail =
      principalEmail.trim().toLowerCase();

      // ------------------------------------------------------
      // VALIDATION
      // ------------------------------------------------------

      if (cleanSchoolName.isEmpty) {
        throw Exception(
          'School name is required.',
        );
      }

      if (cleanSchoolEmail.isEmpty ||
          !cleanSchoolEmail.contains('@')) {
        throw Exception(
          'Enter a valid school email.',
        );
      }

      if (cleanSchoolPhone.isEmpty) {
        throw Exception(
          'School phone number is required.',
        );
      }

      if (cleanSchoolAddress.isEmpty) {
        throw Exception(
          'School address is required.',
        );
      }

      if (cleanPrincipalName.isEmpty) {
        throw Exception(
          'Principal name is required.',
        );
      }

      if (cleanPrincipalEmail.isEmpty ||
          !cleanPrincipalEmail.contains('@')) {
        throw Exception(
          'Enter a valid principal email.',
        );
      }

      if (principalPassword.length < 6) {
        throw Exception(
          'Password must contain at least 6 characters.',
        );
      }

      // ------------------------------------------------------
      // PAKISTAN PHONE
      // ------------------------------------------------------

      final phoneDigits = cleanSchoolPhone
          .replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );

      if (!RegExp(
        r'^3[0-9]{9}$',
      ).hasMatch(phoneDigits)) {
        throw Exception(
          'Enter a valid Pakistani mobile number, e.g. 3001234567.',
        );
      }

      final formattedSchoolPhone =
          '+92$phoneDigits';

      // ------------------------------------------------------
      // 1. CREATE NEW AUTH PRINCIPAL ACCOUNT
      // ------------------------------------------------------

      final authResponse =
      await _client.auth.signUp(
        email: cleanPrincipalEmail,
        password: principalPassword,
        data: {
          'full_name': cleanPrincipalName,
          'role': 'principal',
        },
      );

      final user = authResponse.user;

      if (user == null) {
        throw Exception(
          'Principal account could not be created.',
        );
      }

      // ------------------------------------------------------
      // SESSION CHECK
      // ------------------------------------------------------

      if (_client.auth.currentUser == null) {
        throw Exception(
          'Account was created, but no active session is available. '
              'Please check your Supabase email confirmation settings.',
        );
      }

      // ------------------------------------------------------
      // 2. REGISTRATION NUMBER
      //
      // School ID is NOT generated here.
      // Supabase automatically generates schools.id.
      // ------------------------------------------------------

      final registrationNumber =
          'SCH-${DateTime.now().millisecondsSinceEpoch}';

      // ------------------------------------------------------
      // 3. CREATE SCHOOL + LINK PRINCIPAL
      // ------------------------------------------------------

      final result = await _client.rpc(
        'register_school',
        params: {
          'p_school_name':
          cleanSchoolName,

          'p_registration_number':
          registrationNumber,

          'p_email':
          cleanSchoolEmail,

          'p_address':
          cleanSchoolAddress,

          'p_phone_number':
          formattedSchoolPhone,

          'p_logo_url':
          null,

          'p_principal_name':
          cleanPrincipalName,

          'p_principal_email':
          cleanPrincipalEmail,

          'p_principal_phone':
          formattedSchoolPhone,
        },
      );

      final schoolId =
      _extractSchoolId(result);

      if (schoolId == null) {
        throw Exception(
          'School was created, but School ID could not be obtained.',
        );
      }

      // ------------------------------------------------------
      // 4. UPLOAD LOGO
      // ------------------------------------------------------

      if (state.logo != null &&
          state.logoBytes != null) {
        await _uploadLogo(
          schoolId,
        );
      }

      // ------------------------------------------------------
      // 5. VERIFY PRINCIPAL
      // ------------------------------------------------------

      final profile =
      await _client
          .from('profiles')
          .select(
        'id, full_name, email, role, school_id',
      )
          .eq(
        'id',
        user.id,
      )
          .maybeSingle();

      if (profile == null) {
        throw Exception(
          'Principal profile was not found after registration.',
        );
      }

      final linkedSchoolId =
      profile['school_id'];

      if (linkedSchoolId == null) {
        throw Exception(
          'Principal was not linked to the new School.',
        );
      }

      if (linkedSchoolId.toString() !=
          schoolId.toString()) {
        throw Exception(
          'Principal School ID does not match the newly created School.',
        );
      }

      // ------------------------------------------------------
      // SUCCESS
      // ------------------------------------------------------

      onSuccess(
        'School registered successfully!\n'
            'School ID: $schoolId\n'
            'Principal Login: $cleanPrincipalEmail',
      );
    } on AuthException catch (e) {
      onError(
        'Authentication error: ${e.message}',
      );
    } on StorageException catch (e) {
      onError(
        'Logo upload failed: ${e.message}',
      );
    } on PostgrestException catch (e) {
      onError(
        'Database error: ${e.message}',
      );
    } catch (e) {
      onError(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    } finally {
      state = state.copyWith(
        isLoading: false,
      );
    }
  }

  // ==========================================================
  // EXTRACT SCHOOL ID
  // ==========================================================

  int? _extractSchoolId(
      dynamic result,
      ) {
    if (result == null) {
      return null;
    }

    if (result is int) {
      return result;
    }

    if (result is String) {
      return int.tryParse(result);
    }

    if (result is Map) {
      final value =
          result['school_id'] ??
              result['id'];

      if (value is int) {
        return value;
      }

      if (value is String) {
        return int.tryParse(value);
      }
    }

    if (result is List &&
        result.isNotEmpty) {
      return _extractSchoolId(
        result.first,
      );
    }

    return null;
  }

  // ==========================================================
  // UPLOAD LOGO
  // ==========================================================

  Future<void> _uploadLogo(
      int schoolId,
      ) async {
    final extension =
    _extension(
      state.logo!.name,
    );

    final path =
        'school-logos/'
        '${schoolId}_'
        '${DateTime.now().millisecondsSinceEpoch}'
        '.$extension';

    await _client.storage
        .from('school-assets')
        .uploadBinary(
      path,
      state.logoBytes!,
      fileOptions:
      FileOptions(
        upsert: true,
        contentType:
        _contentType(
          extension,
        ),
      ),
    );

    final url =
    _client.storage
        .from('school-assets')
        .getPublicUrl(
      path,
    );

    await _client
        .from('schools')
        .update({
      'logo_url': url,
    })
        .eq(
      'id',
      schoolId,
    );
  }

  // ==========================================================
  // EXTENSION
  // ==========================================================

  String _extension(
      String name,
      ) {
    final clean =
        name.split('?').first;

    final dot =
    clean.lastIndexOf('.');

    if (dot == -1) {
      return 'jpg';
    }

    final ext =
    clean
        .substring(dot + 1)
        .toLowerCase();

    if (ext == 'jpeg') {
      return 'jpg';
    }

    if (ext == 'png' ||
        ext == 'webp' ||
        ext == 'jpg') {
      return ext;
    }

    return 'jpg';
  }

  // ==========================================================
  // CONTENT TYPE
  // ==========================================================

  String _contentType(
      String ext,
      ) {
    switch (ext) {
      case 'png':
        return 'image/png';

      case 'webp':
        return 'image/webp';

      default:
        return 'image/jpeg';
    }
  }
}

// ============================================================
// RIVERPOD PROVIDER
// ============================================================

final registrationProvider =
StateNotifierProvider<
    RegistrationNotifier,
    RegistrationState>(
      (ref) {
    return RegistrationNotifier();
  },
);

// ============================================================
// SCHOOL REGISTRATION SCREEN
// ============================================================

class SchoolRegistrationScreen
    extends ConsumerStatefulWidget {
  const SchoolRegistrationScreen({
    super.key,
  });

  @override
  ConsumerState<
      SchoolRegistrationScreen>
  createState() =>
      _SchoolRegistrationScreenState();
}

class _SchoolRegistrationScreenState
    extends ConsumerState<
        SchoolRegistrationScreen> {

  final _formKey =
  GlobalKey<FormState>();

  final _schoolName =
  TextEditingController();

  final _schoolEmail =
  TextEditingController();

  final _schoolPhone =
  TextEditingController();

  final _schoolAddress =
  TextEditingController();

  final _pName =
  TextEditingController();

  final _pEmail =
  TextEditingController();

  final _pPassword =
  TextEditingController();

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    _schoolName.dispose();
    _schoolEmail.dispose();
    _schoolPhone.dispose();
    _schoolAddress.dispose();
    _pName.dispose();
    _pEmail.dispose();
    _pPassword.dispose();

    super.dispose();
  }

  // ==========================================================
  // SUBMIT
  // ==========================================================

  void _submitForm() {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    final notifier =
    ref.read(
      registrationProvider.notifier,
    );

    notifier.registerSchool(
      schoolName:
      _schoolName.text,

      schoolEmail:
      _schoolEmail.text,

      schoolPhone:
      _schoolPhone.text,

      schoolAddress:
      _schoolAddress.text,

      principalName:
      _pName.text,

      principalEmail:
      _pEmail.text,

      principalPassword:
      _pPassword.text,

      onSuccess:
          (message) async {
        if (!mounted) return;

        _showSnackBar(
          message,
          isError: false,
        );

        await Future.delayed(
          const Duration(
            milliseconds: 1200,
          ),
        );

        if (!mounted) return;

        context.go('/login');
      },

      onError:
          (error) {
        if (!mounted) return;

        _showSnackBar(
          error,
          isError: true,
        );
      },
    );
  }

  // ==========================================================
  // SNACKBAR
  // ==========================================================

  void _showSnackBar(
      String message, {
        required bool isError,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons
                    .error_outline_rounded
                    : Icons
                    .check_circle_outline_rounded,
                color:
                Colors.white,
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: Text(
                  message,
                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor:
          isError
              ? const Color(
            0xFFEF4444,
          )
              : const Color(
            0xFF10B981,
          ),
          behavior:
          SnackBarBehavior
              .floating,
          margin:
          const EdgeInsets.all(
            16,
          ),
          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(
              14,
            ),
          ),
        ),
      );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final state =
    ref.watch(
      registrationProvider,
    );

    final notifier =
    ref.read(
      registrationProvider.notifier,
    );

    return Scaffold(
      backgroundColor:
      const Color(
        0xFFF1F5F9,
      ),

      body:
      CustomScrollView(
        physics:
        const BouncingScrollPhysics(),

        slivers: [

          // ==================================================
          // HEADER
          // ==================================================

          SliverAppBar(
            expandedHeight:
            140,

            pinned: true,

            backgroundColor:
            AppColors.primary,

            elevation: 0,

            leading:
            IconButton(
              onPressed:
              state.isLoading
                  ? null
                  : () =>
                  context.pop(),

              icon:
              const Icon(
                Icons
                    .arrow_back_ios_new_rounded,
                color:
                Colors.white,
                size: 20,
              ),
            ),

            flexibleSpace:
            FlexibleSpaceBar(
              background:
              Container(
                decoration:
                BoxDecoration(
                  gradient:
                  LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary
                          .withOpacity(
                        0.85,
                      ),
                    ],
                    begin:
                    Alignment.topLeft,
                    end:
                    Alignment.bottomRight,
                  ),
                ),

                child:
                Align(
                  alignment:
                  Alignment.bottomLeft,

                  child:
                  Padding(
                    padding:
                    const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      bottom: 20,
                    ),

                    child:
                    Column(
                      mainAxisSize:
                      MainAxisSize.min,

                      crossAxisAlignment:
                      CrossAxisAlignment.start,

                      children: const [

                        Text(
                          'Register Your Institution',
                          style:
                          TextStyle(
                            color:
                            Colors.white,
                            fontSize:
                            22,
                            fontWeight:
                            FontWeight
                                .w800,
                          ),
                        ),

                        SizedBox(
                          height: 4,
                        ),

                        Text(
                          'Create a new school and principal account',
                          style:
                          TextStyle(
                            color:
                            Colors.white70,
                            fontSize:
                            13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ==================================================
          // FORM CONTENT
          // ==================================================

          SliverToBoxAdapter(
            child:
            Center(
              child:
              ConstrainedBox(
                constraints:
                const BoxConstraints(
                  maxWidth:
                  560,
                ),

                child:
                Padding(
                  padding:
                  const EdgeInsets
                      .symmetric(
                    horizontal:
                    20,
                    vertical:
                    24,
                  ),

                  child:
                  Form(
                    key:
                    _formKey,

                    child:
                    Column(
                      children: [

                        _buildLogoSection(
                          state,
                          notifier,
                        ),

                        const SizedBox(
                          height: 28,
                        ),

                        // ====================================
                        // SCHOOL
                        // ====================================

                        _buildSectionCard(
                          title:
                          'Institution Details',

                          subtitle:
                          'Basic contact details of your school',

                          icon:
                          Icons
                              .account_balance_rounded,

                          children: [

                            _buildStyledTextField(
                              label:
                              'School Name',

                              controller:
                              _schoolName,

                              icon:
                              Icons
                                  .school_outlined,

                              hint:
                              'e.g. Hadi Model School',
                            ),

                            const SizedBox(
                              height: 18,
                            ),

                            _buildStyledTextField(
                              label:
                              'Official Email',

                              controller:
                              _schoolEmail,

                              icon:
                              Icons
                                  .email_outlined,

                              hint:
                              'admin@school.com',

                              keyboard:
                              TextInputType
                                  .emailAddress,

                              isEmail:
                              true,
                            ),

                            const SizedBox(
                              height: 18,
                            ),

                            _buildPhonePickerField(),

                            const SizedBox(
                              height: 18,
                            ),

                            _buildStyledTextField(
                              label:
                              'School Address',

                              controller:
                              _schoolAddress,

                              icon:
                              Icons
                                  .location_on_outlined,

                              hint:
                              'Street, City, Country',
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 24,
                        ),

                        // ====================================
                        // PRINCIPAL
                        // ====================================

                        _buildSectionCard(
                          title:
                          'Principal Account',

                          subtitle:
                          'Administrator login credentials',

                          icon:
                          Icons
                              .admin_panel_settings_outlined,

                          children: [

                            _buildStyledTextField(
                              label:
                              'Principal Full Name',

                              controller:
                              _pName,

                              icon:
                              Icons
                                  .person_outline_rounded,

                              hint:
                              'e.g. Noor Ul Hadi',
                            ),

                            const SizedBox(
                              height: 18,
                            ),

                            _buildStyledTextField(
                              label:
                              'Principal Email',

                              controller:
                              _pEmail,

                              icon:
                              Icons
                                  .alternate_email_rounded,

                              hint:
                              'principal@school.com',

                              keyboard:
                              TextInputType
                                  .emailAddress,

                              isEmail:
                              true,
                            ),

                            const SizedBox(
                              height: 18,
                            ),

                            _buildStyledTextField(
                              label:
                              'Password',

                              controller:
                              _pPassword,

                              icon:
                              Icons
                                  .lock_outline_rounded,

                              hint:
                              '••••••••',

                              isPassword:
                              true,

                              isObscure:
                              state.isObscure,

                              onToggleVisibility:
                              notifier
                                  .togglePasswordVisibility,
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 32,
                        ),

                        // ====================================
                        // REGISTER
                        // ====================================

                        SizedBox(
                          width:
                          double.infinity,

                          height:
                          54,

                          child:
                          ElevatedButton(
                            onPressed:
                            state.isLoading
                                ? null
                                : _submitForm,

                            style:
                            ElevatedButton
                                .styleFrom(
                              backgroundColor:
                              AppColors.primary,

                              disabledBackgroundColor:
                              AppColors
                                  .primary
                                  .withOpacity(
                                0.55,
                              ),

                              elevation:
                              3,

                              shadowColor:
                              AppColors
                                  .primary
                                  .withOpacity(
                                0.4,
                              ),

                              shape:
                              RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius
                                    .circular(
                                  16,
                                ),
                              ),
                            ),

                            child:
                            state.isLoading
                                ? const SizedBox(
                              width:
                              24,
                              height:
                              24,
                              child:
                              CircularProgressIndicator(
                                strokeWidth:
                                2.5,
                                color:
                                Colors.white,
                              ),
                            )
                                : const Row(
                              mainAxisAlignment:
                              MainAxisAlignment
                                  .center,

                              children: [

                                Text(
                                  'Complete Registration',
                                  style:
                                  TextStyle(
                                    fontSize:
                                    16,
                                    fontWeight:
                                    FontWeight
                                        .bold,
                                    color:
                                    Colors.white,
                                  ),
                                ),

                                SizedBox(
                                  width:
                                  8,
                                ),

                                Icon(
                                  Icons
                                      .arrow_forward_rounded,
                                  color:
                                  Colors.white,
                                  size:
                                  20,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 32,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // LOGO
  // ==========================================================

  Widget _buildLogoSection(
      RegistrationState state,
      RegistrationNotifier notifier,
      ) {
    return Column(
      children: [

        GestureDetector(
          onTap:
          state.isLoading
              ? null
              : () async {
            final error =
            await notifier
                .pickLogo();

            if (error != null &&
                mounted) {
              _showSnackBar(
                error,
                isError:
                true,
              );
            }
          },

          child:
          Stack(
            alignment:
            Alignment.bottomRight,

            children: [

              Container(
                width:
                115,
                height:
                115,

                decoration:
                BoxDecoration(
                  color:
                  Colors.white,

                  shape:
                  BoxShape.circle,

                  boxShadow: [
                    BoxShadow(
                      color:
                      AppColors
                          .primary
                          .withOpacity(
                        0.12,
                      ),
                      blurRadius:
                      20,
                      offset:
                      const Offset(
                        0,
                        8,
                      ),
                    ),
                  ],

                  border:
                  Border.all(
                    color:
                    Colors.white,
                    width:
                    4,
                  ),
                ),

                child:
                ClipOval(
                  child:
                  state.logoBytes ==
                      null
                      ? Container(
                    color:
                    const Color(
                      0xFFF8FAFC,
                    ),

                    child:
                    Icon(
                      Icons
                          .add_a_photo_rounded,
                      size:
                      38,
                      color:
                      AppColors
                          .primary
                          .withOpacity(
                        0.6,
                      ),
                    ),
                  )
                      : Image.memory(
                    state
                        .logoBytes!,
                    fit:
                    BoxFit.cover,
                  ),
                ),
              ),

              Container(
                padding:
                const EdgeInsets.all(
                  8,
                ),

                decoration:
                BoxDecoration(
                  color:
                  AppColors.primary,

                  shape:
                  BoxShape.circle,

                  border:
                  Border.all(
                    color:
                    Colors.white,
                    width:
                    2.5,
                  ),
                ),

                child:
                const Icon(
                  Icons.edit_rounded,
                  color:
                  Colors.white,
                  size:
                  14,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(
          height: 12,
        ),

        Text(
          state.logo == null
              ? 'Upload School Logo'
              : 'Change Selected Logo',

          style:
          const TextStyle(
            color:
            Color(0xFF64748B),
            fontSize:
            13,
            fontWeight:
            FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // PAKISTAN PHONE FIELD
  // ==========================================================

  Widget _buildPhonePickerField() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,

      children: [

        const Text(
          'Contact Phone Number',

          style:
          TextStyle(
            fontSize:
            13,
            fontWeight:
            FontWeight.w600,
            color:
            Color(0xFF334155),
          ),
        ),

        const SizedBox(
          height: 6,
        ),

        TextFormField(
          controller:
          _schoolPhone,

          keyboardType:
          TextInputType.phone,

          maxLength:
          10,

          style:
          const TextStyle(
            fontSize:
            14,
            color:
            Color(0xFF0F172A),
          ),

          decoration:
          InputDecoration(
            counterText:
            '',

            hintText:
            '300 1234567',

            hintStyle:
            const TextStyle(
              color:
              Color(0xFF94A3B8),
              fontSize:
              13,
            ),

            prefixIcon:
            Container(
              width:
              72,

              alignment:
              Alignment.center,

              child:
              const Text(
                '+92',
                style:
                TextStyle(
                  fontSize:
                  14,
                  fontWeight:
                  FontWeight.w700,
                  color:
                  Color(
                    0xFF334155,
                  ),
                ),
              ),
            ),

            filled:
            true,

            fillColor:
            Colors.white,

            contentPadding:
            const EdgeInsets.symmetric(
              vertical:
              16,
              horizontal:
              16,
            ),

            border:
            OutlineInputBorder(
              borderRadius:
              BorderRadius.circular(
                14,
              ),
              borderSide:
              const BorderSide(
                color:
                Color(0xFFE2E8F0),
              ),
            ),

            enabledBorder:
            OutlineInputBorder(
              borderRadius:
              BorderRadius.circular(
                14,
              ),
              borderSide:
              const BorderSide(
                color:
                Color(0xFFE2E8F0),
              ),
            ),

            focusedBorder:
            OutlineInputBorder(
              borderRadius:
              BorderRadius.circular(
                14,
              ),
              borderSide:
              const BorderSide(
                color:
                AppColors.primary,
                width:
                1.5,
              ),
            ),
          ),

          validator:
              (value) {
            final number =
                value?.trim() ??
                    '';

            if (number.isEmpty) {
              return 'Phone number required';
            }

            if (!RegExp(
              r'^3[0-9]{9}$',
            ).hasMatch(number)) {
              return 'Enter 10 digits starting with 3';
            }

            return null;
          },

          onChanged:
              (value) {
            final number =
            value.replaceAll(
              RegExp(
                r'[^0-9]',
              ),
              '',
            );

            if (number != value) {
              _schoolPhone.value =
                  TextEditingValue(
                    text:
                    number,

                    selection:
                    TextSelection.collapsed(
                      offset:
                      number.length,
                    ),
                  );
            }
          },
        ),
      ],
    );
  }

  // ==========================================================
  // SECTION CARD
  // ==========================================================

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding:
      const EdgeInsets.all(
        22,
      ),

      decoration:
      BoxDecoration(
        color:
        Colors.white,

        borderRadius:
        BorderRadius.circular(
          24,
        ),

        boxShadow: [
          BoxShadow(
            color:
            const Color(
              0xFF0F172A,
            ).withOpacity(
              0.03,
            ),

            blurRadius:
            20,

            offset:
            const Offset(
              0,
              6,
            ),
          ),
        ],
      ),

      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [

          Row(
            children: [

              Container(
                padding:
                const EdgeInsets.all(
                  10,
                ),

                decoration:
                BoxDecoration(
                  color:
                  AppColors
                      .primary
                      .withOpacity(
                    0.08,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                ),

                child:
                Icon(
                  icon,
                  color:
                  AppColors.primary,
                  size:
                  22,
                ),
              ),

              const SizedBox(
                width:
                14,
              ),

              Expanded(
                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [

                    Text(
                      title,

                      style:
                      const TextStyle(
                        fontSize:
                        16,
                        fontWeight:
                        FontWeight.bold,
                        color:
                        Color(
                          0xFF0F172A,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height:
                      2,
                    ),

                    Text(
                      subtitle,

                      style:
                      const TextStyle(
                        fontSize:
                        12,
                        color:
                        Color(
                          0xFF64748B,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Padding(
            padding:
            EdgeInsets.symmetric(
              vertical:
              18,
            ),

            child:
            Divider(
              color:
              Color(
                0xFFF1F5F9,
              ),
              height:
              1,
            ),
          ),

          ...children,
        ],
      ),
    );
  }

  // ==========================================================
  // TEXT FIELD
  // ==========================================================

  Widget _buildStyledTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool isPassword = false,
    bool isEmail = false,
    bool isObscure = false,
    VoidCallback? onToggleVisibility,
    TextInputType? keyboard,
  }) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,

      children: [

        Text(
          label,

          style:
          const TextStyle(
            fontSize:
            13,
            fontWeight:
            FontWeight.w600,
            color:
            Color(
              0xFF334155,
            ),
          ),
        ),

        const SizedBox(
          height:
          6,
        ),

        TextFormField(
          controller:
          controller,

          obscureText:
          isPassword
              ? isObscure
              : false,

          keyboardType:
          keyboard,

          style:
          const TextStyle(
            fontSize:
            14,
            color:
            Color(
              0xFF0F172A,
            ),
          ),

          decoration:
          InputDecoration(
            hintText:
            hint,

            hintStyle:
            const TextStyle(
              color:
              Color(
                0xFF94A3B8,
              ),
              fontSize:
              13,
            ),

            prefixIcon:
            Icon(
              icon,
              size:
              20,
              color:
              const Color(
                0xFF64748B,
              ),
            ),

            suffixIcon:
            isPassword
                ? IconButton(
              onPressed:
              onToggleVisibility,

              icon:
              Icon(
                isObscure
                    ? Icons
                    .visibility_outlined
                    : Icons
                    .visibility_off_outlined,

                size:
                20,

                color:
                const Color(
                  0xFF64748B,
                ),
              ),
            )
                : null,

            filled:
            true,

            fillColor:
            Colors.white,

            contentPadding:
            const EdgeInsets.symmetric(
              vertical:
              16,
              horizontal:
              16,
            ),

            border:
            OutlineInputBorder(
              borderRadius:
              BorderRadius.circular(
                14,
              ),
              borderSide:
              const BorderSide(
                color:
                Color(
                  0xFFE2E8F0,
                ),
              ),
            ),

            enabledBorder:
            OutlineInputBorder(
              borderRadius:
              BorderRadius.circular(
                14,
              ),
              borderSide:
              const BorderSide(
                color:
                Color(
                  0xFFE2E8F0,
                ),
              ),
            ),

            focusedBorder:
            OutlineInputBorder(
              borderRadius:
              BorderRadius.circular(
                14,
              ),
              borderSide:
              const BorderSide(
                color:
                AppColors.primary,
                width:
                1.5,
              ),
            ),
          ),

          validator:
              (value) {
            if (value == null ||
                value.trim().isEmpty) {
              return 'Field required';
            }

            if (isEmail &&
                !RegExp(
                  r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                ).hasMatch(
                  value.trim(),
                )) {
              return 'Enter a valid email';
            }

            if (isPassword &&
                value.length < 6) {
              return 'Minimum 6 characters required';
            }

            return null;
          },
        ),
      ],
    );
  }
}