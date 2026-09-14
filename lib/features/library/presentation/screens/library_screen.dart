import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/main_wrapper.dart';

class LibraryBook {
  final int id;
  final int? classId;
  final String title;
  final String author;
  final String isbn;
  final int quantity;
  final int availableQuantity;
  final String className;
  final String sectionName;

  const LibraryBook({
    required this.id,
    required this.classId,
    required this.title,
    required this.author,
    required this.isbn,
    required this.quantity,
    required this.availableQuantity,
    required this.className,
    required this.sectionName,
  });

  factory LibraryBook.fromMap(Map<String, dynamic> map) {
    final classes = map['classes'];

    String className = 'No Class';
    String sectionName = '';

    if (classes is Map<String, dynamic>) {
      className = classes['name']?.toString() ?? 'No Class';
      sectionName = classes['section_name']?.toString() ?? '';
    }

    return LibraryBook(
      id: (map['id'] as num?)?.toInt() ?? 0,
      classId: (map['class_id'] as num?)?.toInt(),
      title: map['title']?.toString() ?? '',
      author: map['author']?.toString() ?? '',
      isbn: map['isbn']?.toString() ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      availableQuantity:
      (map['available_quantity'] as num?)?.toInt() ?? 0,
      className: className,
      sectionName: sectionName,
    );
  }
}

class LibraryClass {
  final int id;
  final String name;
  final String sectionName;

  const LibraryClass({
    required this.id,
    required this.name,
    required this.sectionName,
  });

  factory LibraryClass.fromMap(Map<String, dynamic> map) {
    return LibraryClass(
      id: (map['id'] as num?)?.toInt() ?? 0,
      name: map['name']?.toString() ?? '',
      sectionName: map['section_name']?.toString() ?? '',
    );
  }
}

class LibraryRepository {
  final SupabaseClient client;

  LibraryRepository(this.client);

  Future<int> _getSchoolId() async {
    final user = client.auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }

    final result = await client
        .from('profiles')
        .select('school_id')
        .eq('id', user.id)
        .maybeSingle();

    if (result == null || result['school_id'] == null) {
      throw Exception('School ID not found');
    }

    return (result['school_id'] as num).toInt();
  }

  Future<List<LibraryBook>> getBooks() async {
    final schoolId = await _getSchoolId();

    final data = await client
        .from('library_books')
        .select('''
          id,
          title,
          author,
          isbn,
          quantity,
          available_quantity,
          class_id,
          classes (
            id,
            name,
            section_name
          )
        ''')
        .eq('school_id', schoolId)
        .order('created_at', ascending: false);

    return (data as List)
        .map(
          (item) => LibraryBook.fromMap(
        Map<String, dynamic>.from(item as Map),
      ),
    )
        .toList();
  }

  Future<List<LibraryClass>> getClasses() async {
    final schoolId = await _getSchoolId();

    final data = await client
        .from('classes')
        .select('id, name, section_name')
        .eq('school_id', schoolId)
        .order('name');

    return (data as List)
        .map(
          (item) => LibraryClass.fromMap(
        Map<String, dynamic>.from(item as Map),
      ),
    )
        .toList();
  }

  Future<int> getPendingIssues() async {
    final schoolId = await _getSchoolId();

    final data = await client
        .from('library_issues')
        .select('id')
        .eq('school_id', schoolId)
        .eq('status', 'issued');

    return (data as List).length;
  }

  Future<void> addBook({
    required int classId,
    required String title,
    required String author,
    required String isbn,
    required int quantity,
  }) async {
    final schoolId = await _getSchoolId();

    await client.from('library_books').insert({
      'school_id': schoolId,
      'class_id': classId,
      'title': title.trim(),
      'author': author.trim(),
      'isbn': isbn.trim(),
      'quantity': quantity,
      'available_quantity': quantity,
    });
  }

  Future<void> deleteBook(int bookId) async {
    final schoolId = await _getSchoolId();

    await client
        .from('library_books')
        .delete()
        .eq('id', bookId)
        .eq('school_id', schoolId);
  }
}

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return LibraryRepository(SupabaseConfig.client);
});

final libraryBooksProvider = FutureProvider<List<LibraryBook>>((ref) async {
  final repository = ref.read(libraryRepositoryProvider);
  return repository.getBooks();
});

final libraryClassesProvider =
FutureProvider<List<LibraryClass>>((ref) async {
  final repository = ref.read(libraryRepositoryProvider);
  return repository.getClasses();
});

final libraryPendingProvider = FutureProvider<int>((ref) async {
  final repository = ref.read(libraryRepositoryProvider);
  return repository.getPendingIssues();
});

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(libraryBooksProvider);
    final classesAsync = ref.watch(libraryClassesProvider);
    final pendingAsync = ref.watch(libraryPendingProvider);

    return MainWrapper(
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(libraryBooksProvider);
            ref.invalidate(libraryClassesProvider);
            ref.invalidate(libraryPendingProvider);

            await Future.wait([
              ref.read(libraryBooksProvider.future),
              ref.read(libraryClassesProvider.future),
            ]);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _buildHeader(context),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: _buildStats(
                    context,
                    booksAsync,
                    classesAsync,
                    pendingAsync,
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildClassSection(
                    context,
                    ref,
                    classesAsync,
                    booksAsync,
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                  child: _buildAllBooksTitle(booksAsync),
                ),
              ),

              booksAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
                error: (error, stack) => SliverToBoxAdapter(
                  child: _buildError(
                    context,
                    ref,
                    error.toString(),
                  ),
                ),
                data: (books) {
                  if (books.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: _EmptyBooks(),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.crossAxisExtent;

                        int count = 1;

                        if (width >= 1200) {
                          count = 4;
                        } else if (width >= 850) {
                          count = 3;
                        } else if (width >= 600) {
                          count = 2;
                        }

                        return SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                                (context, index) {
                              return _BookCard(
                                book: books[index],
                                onDelete: () => _deleteBook(
                                  context,
                                  ref,
                                  books[index],
                                ),
                              );
                            },
                            childCount: books.length,
                          ),
                          gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: count,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: width < 600 ? 1.45 : 1.30,
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 650;

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title(),
                const SizedBox(height: 16),
                _addButton(context),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: _title()),
              _addButton(context),
            ],
          );
        },
      ),
    );
  }

  Widget _title() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.local_library_rounded,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Library',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Manage books class-wise, issues and returns.',
          style: TextStyle(
            color: Colors.black54,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _addButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _showAddBookDialog(context),
      icon: const Icon(Icons.add_rounded),
      label: const Text('Add Book'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 15,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
        ),
      ),
    );
  }

  Widget _buildStats(
      BuildContext context,
      AsyncValue<List<LibraryBook>> booksAsync,
      AsyncValue<List<LibraryClass>> classesAsync,
      AsyncValue<int> pendingAsync,
      ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final books = booksAsync.valueOrNull ?? [];
        final classes = classesAsync.valueOrNull ?? [];

        final total = books.fold<int>(
          0,
              (sum, book) => sum + book.quantity,
        );

        final available = books.fold<int>(
          0,
              (sum, book) => sum + book.availableQuantity,
        );

        final pending = pendingAsync.valueOrNull ?? 0;

        final items = [
          _StatItem(
            'Total Books',
            total.toString(),
            Icons.menu_book_rounded,
            AppColors.primary,
          ),
          _StatItem(
            'Available',
            available.toString(),
            Icons.check_circle_rounded,
            AppColors.success,
          ),
          _StatItem(
            'Classes',
            classes.length.toString(),
            Icons.class_rounded,
            AppColors.info,
          ),
          _StatItem(
            'Issued',
            pending.toString(),
            Icons.assignment_rounded,
            Colors.orange,
          ),
        ];

        final width = constraints.maxWidth;

        int count = 1;

        if (width >= 1000) {
          count = 4;
        } else if (width >= 650) {
          count = 2;
        }

        if (count == 1) {
          return Column(
            children: items
                .map(
                  (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _StatCard(item: item),
              ),
            )
                .toList(),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: width >= 1000 ? 2.2 : 2.0,
          ),
          itemBuilder: (context, index) {
            return _StatCard(item: items[index]);
          },
        );
      },
    );
  }

  Widget _buildClassSection(
      BuildContext context,
      WidgetRef ref,
      AsyncValue<List<LibraryClass>> classesAsync,
      AsyncValue<List<LibraryBook>> booksAsync,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Books by Class',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        classesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, stack) => _buildError(
            context,
            ref,
            error.toString(),
            classesOnly: true,
          ),
          data: (classes) {
            if (classes.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text(
                  'No classes found.',
                  textAlign: TextAlign.center,
                ),
              );
            }

            final books = booksAsync.valueOrNull ?? [];

            return LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;

                int count = 1;

                if (width >= 1000) {
                  count = 4;
                } else if (width >= 700) {
                  count = 3;
                } else if (width >= 450) {
                  count = 2;
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: classes.length,
                  gridDelegate:
                  SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: count,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.15,
                  ),
                  itemBuilder: (context, index) {
                    final cls = classes[index];

                    final classBooks = books
                        .where((book) => book.classId == cls.id)
                        .length;

                    return _ClassCard(
                      classItem: cls,
                      bookCount: classBooks,
                      onTap: () {
                        _showClassBooks(
                          context,
                          cls,
                          books,
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildAllBooksTitle(
      AsyncValue<List<LibraryBook>> booksAsync,
      ) {
    final count = booksAsync.valueOrNull?.length ?? 0;

    return Row(
      children: [
        const Expanded(
          child: Text(
            'All Books',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          '$count records',
          style: const TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildError(
      BuildContext context,
      WidgetRef ref,
      String error, {
        bool classesOnly = false,
      }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.red.withValues(alpha: .15),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.red,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: () {
              if (classesOnly) {
                ref.invalidate(libraryClassesProvider);
              } else {
                ref.invalidate(libraryBooksProvider);
              }
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBook(
      BuildContext context,
      WidgetRef ref,
      LibraryBook book,
      ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Book'),
          content: Text(
            'Delete "${book.title}" from library?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await ref
          .read(libraryRepositoryProvider)
          .deleteBook(book.id);

      ref.invalidate(libraryBooksProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Book deleted successfully'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
          ),
        );
      }
    }
  }

  void _showAddBookDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return const _AddBookDialog();
      },
    );
  }

  void _showClassBooks(
      BuildContext context,
      LibraryClass cls,
      List<LibraryBook> books,
      ) {
    final classBooks = books
        .where((book) => book.classId == cls.id)
        .toList();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            '${cls.name}'
                '${cls.sectionName.isNotEmpty ? ' - ${cls.sectionName}' : ''}',
          ),
          content: SizedBox(
            width: 520,
            child: classBooks.isEmpty
                ? const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No books added for this class.',
                textAlign: TextAlign.center,
              ),
            )
                : ListView.separated(
              shrinkWrap: true,
              itemCount: classBooks.length,
              separatorBuilder: (_, __) =>
              const Divider(height: 1),
              itemBuilder: (context, index) {
                final book = classBooks[index];

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                    AppColors.primary.withValues(alpha: .12),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  title: Text(
                    book.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    book.author.isEmpty
                        ? 'No author'
                        : book.author,
                  ),
                  trailing: Text(
                    '${book.availableQuantity}/${book.quantity}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

class _AddBookDialog extends ConsumerStatefulWidget {
  const _AddBookDialog();

  @override
  ConsumerState<_AddBookDialog> createState() =>
      _AddBookDialogState();
}

class _AddBookDialogState extends ConsumerState<_AddBookDialog> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _isbnController = TextEditingController();
  final _quantityController = TextEditingController(
    text: '1',
  );

  int? _selectedClassId;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _isbnController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a class'),
        ),
      );
      return;
    }

    final quantity =
        int.tryParse(_quantityController.text.trim()) ?? 0;

    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quantity must be greater than 0'),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await ref.read(libraryRepositoryProvider).addBook(
        classId: _selectedClassId!,
        title: _titleController.text,
        author: _authorController.text,
        isbn: _isbnController.text,
        quantity: quantity,
      );

      ref.invalidate(libraryBooksProvider);

      if (mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Book added successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add book: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(libraryClassesProvider);

    return AlertDialog(
      title: const Text(
        'Add New Book',
        style: TextStyle(
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                classesAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(),
                  ),
                  error: (error, stack) => Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: .06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Classes loading failed: $error',
                      style: const TextStyle(
                        color: Colors.red,
                      ),
                    ),
                  ),
                  data: (classes) {
                    if (classes.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'No classes available.',
                        ),
                      );
                    }

                    return DropdownButtonFormField<int>(
                      initialValue: _selectedClassId,
                      decoration: const InputDecoration(
                        labelText: 'Class *',
                        prefixIcon:
                        Icon(Icons.class_rounded),
                        border: OutlineInputBorder(),
                      ),
                      items: classes.map((cls) {
                        final label = cls.sectionName.isEmpty
                            ? cls.name
                            : '${cls.name} - ${cls.sectionName}';

                        return DropdownMenuItem<int>(
                          value: cls.id,
                          child: Text(label),
                        );
                      }).toList(),
                      onChanged: _saving
                          ? null
                          : (value) {
                        setState(() {
                          _selectedClassId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Select class';
                        }
                        return null;
                      },
                    );
                  },
                ),

                const SizedBox(height: 14),

                TextFormField(
                  controller: _titleController,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Book Title *',
                    prefixIcon:
                    Icon(Icons.menu_book_rounded),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Enter book title';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                TextFormField(
                  controller: _authorController,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Author',
                    prefixIcon:
                    Icon(Icons.person_outline_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 14),

                TextFormField(
                  controller: _isbnController,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'ISBN',
                    prefixIcon:
                    Icon(Icons.numbers_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 14),

                TextFormField(
                  controller: _quantityController,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantity *',
                    prefixIcon:
                    Icon(Icons.inventory_2_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final number =
                    int.tryParse(value?.trim() ?? '');

                    if (number == null || number <= 0) {
                      return 'Enter valid quantity';
                    }

                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
            width: 17,
            height: 17,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : const Icon(Icons.save_rounded),
          label: Text(
            _saving ? 'Saving...' : 'Save Book',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _StatItem {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem(
      this.title,
      this.value,
      this.icon,
      this.color,
      );
}

class _StatCard extends StatelessWidget {
  final _StatItem item;

  const _StatCard({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.black.withValues(alpha: .05),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 6),
            color: Colors.black.withValues(alpha: .04),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              item.icon,
              color: item.color,
              size: 25,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.value,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  final LibraryClass classItem;
  final int bookCount;
  final VoidCallback onTap;

  const _ClassCard({
    required this.classItem,
    required this.bookCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = classItem.sectionName.isEmpty
        ? '$bookCount books'
        : '${classItem.sectionName} • $bookCount books';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.black.withValues(alpha: .06),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.class_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      classItem.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.black38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  final LibraryBook book;
  final VoidCallback onDelete;

  const _BookCard({
    required this.book,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final available = book.availableQuantity;
    final total = book.quantity;

    final double progress = total > 0
        ? (available / total).clamp(0.0, 1.0).toDouble()
        : 0.0;

    final classText = book.sectionName.isEmpty
        ? book.className
        : '${book.className} • ${book.sectionName}';

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.black.withValues(alpha: .06),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 5),
            color: Colors.black.withValues(alpha: .035),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.red,
                        ),
                        SizedBox(width: 8),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 13),

          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            book.author.isEmpty
                ? 'Author not specified'
                : book.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 13,
            ),
          ),

          const Spacer(),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .035),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.class_outlined,
                  size: 15,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    classText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Text(
                  'Available: $available / $total',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (book.isbn.isNotEmpty)
                Text(
                  'ISBN: ${book.isbn}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.black45,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.black.withValues(alpha: .06),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBooks extends StatelessWidget {
  const _EmptyBooks();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 55,
            color: Colors.black26,
          ),
          SizedBox(height: 12),
          Text(
            'No books found',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Add books for your classes.',
            style: TextStyle(
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}