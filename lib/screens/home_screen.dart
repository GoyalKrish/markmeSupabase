import 'package:flutter/material.dart';
import 'package:markme/models/student.dart';
import '../services/auth_service.dart';
import '../services/folder_service.dart';
import 'folder_screen.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/lobby_provider.dart';
import '../services/lobby_service.dart';
import './active_lobby_screen.dart';
import '../models/lobby.dart';
import '../components/error_widget_handler.dart';
import '../components/empty_state_widget.dart';
import './create_lobby_screen.dart';
import '../theme/markme_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomeScreen extends StatefulWidget {
  final AuthService authService;
  final FolderService folderService;

  const HomeScreen({
    super.key,
    required this.authService,
    required this.folderService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<String>> _foldersFuture;
  late Future<void> _lobbiesFuture;
  late PageController _pageController; 
  String _searchQuery = '';

  // Controller for the search field
  final TextEditingController _searchController = TextEditingController();
  // Focus node for the search field
  final FocusNode _searchFocusNode = FocusNode();
  // Whether the search bar is expanded
  bool _isSearchExpanded = false;

  // Animation controller for the search panel
  late AnimationController _searchPanelController;
  late Animation<double> _searchPanelAnimation;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _refreshFolders();
    final lobbyProvider = Provider.of<LobbyProvider>(context, listen: false);
    _lobbiesFuture = lobbyProvider.fetchActiveLobbies();

    // Initialize search panel animation controller
    _searchPanelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _searchPanelAnimation = CurvedAnimation(
      parent: _searchPanelController,
      curve: Curves.easeInOut,
    );

    // Listen for changes in the search field
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });

    if (widget.authService.currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/login');
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchPanelController.dispose();
    super.dispose();
  }

  void _refreshFolders() {
    setState(() {
      _foldersFuture = widget.folderService.getFolders();
    });
  }

  void _showCreateFolderDialog() {
    final formKey = GlobalKey<FormState>();
    final folderNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Folder'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: folderNameController,
            decoration: const InputDecoration(labelText: 'Folder Name'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a folder name';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final folderName = folderNameController.text;

                // Check if folder already exists
                final exists = await widget.folderService.folderExists(
                  folderName,
                );
                if (exists) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'A folder with this name already exists',
                        ),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                  return;
                }

                await widget.folderService.addFolder(folderName);
                if (context.mounted) {
                  Navigator.pop(context);
                  _refreshFolders();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FolderScreen(
                        folderName: folderName,
                        folderService: widget.folderService,
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About MarkMe'),
        content: const Text(
          'MarkMe is an attendance taking app designed to help you manage class attendance easily .\n\nVersion: 1.0.0\ndeveloped by: Krish Goyal & Aditya Pandey\nContact us at : in.markme@gmail.com',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showUserDialog(BuildContext context) {
    final user = widget.authService.currentUser;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('User Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${user?.email ?? 'N/A'}'),
            const SizedBox(height: 8),
            Text(
              'Registered: ${user?.createdAt != null ? DateFormat('yyyy-MM-dd – HH:mm').format(DateTime.parse(user!.createdAt).toLocal()) : 'N/A'}',
            ),
            const SizedBox(height: 8),
            Text('User ID: ${user?.id ?? 'N/A'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFolderContextMenu(BuildContext context, String folder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(folder),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _showEditFolderDialog(context, folder);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmationDialog(context, folder);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditFolderDialog(BuildContext context, String oldName) {
    final formKey = GlobalKey<FormState>();
    final folderNameController = TextEditingController(text: oldName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Folder'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: folderNameController,
            decoration: const InputDecoration(labelText: 'Folder Name'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a folder name';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final newName = folderNameController.text;
                await widget.folderService.updateFolder(oldName, newName);
                if (context.mounted) {
                  Navigator.pop(context);
                  _refreshFolders();
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, String folder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder'),
        content: Text('Are you sure you want to delete "$folder"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await widget.folderService.deleteFolder(folder);
              if (context.mounted) {
                Navigator.pop(context);
                _refreshFolders();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (context) {
          final tabController = DefaultTabController.of(context);

          tabController.addListener(() {
            if (tabController.index != _pageController.page?.round()) {
              _pageController.animateToPage(
                tabController.index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.ease,
              );
            }
          });

          return ListenableProvider.value(
            value: tabController,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                gradient: MarkMeTheme.backgroundGradient,
                // Removed the missing asset reference that was causing errors
              ),
              child: Scaffold(
                backgroundColor: Colors.transparent,
                appBar: PreferredSize(
                  preferredSize: Size.fromHeight(kToolbarHeight + 8),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: MarkMeTheme.backgroundGradient,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: AppBar(
                      elevation: 0,
                      flexibleSpace: _buildParallaxBackground(),
                      title: Row(
                        children: [
                          Hero(
                            tag: 'app_logo',
                            child: Image.asset('assets/images/markme_icon.png',
                                height: 32),
                          ),
                          const SizedBox(width: 12),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: Duration(milliseconds: 800),
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, 10 * (1 - value)),
                                  child: child,
                                ),
                              );
                            },
                            child: Text(
                              'MarkMe',
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                                color: MarkMeTheme.primaryWhite,
                              ),
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        // Search icon button
                        IconButton(
                          icon: const Icon(Icons.search, size: 26),
                          color: MarkMeTheme.primaryWhite,
                          onPressed: () {
                            setState(() {
                              _isSearchExpanded = true;
                            });
                            // Start the animation to show the search panel
                            _searchPanelController.forward();
                            // Focus the search field after animation completes
                            Future.delayed(const Duration(milliseconds: 250),
                                () {
                              _searchFocusNode.requestFocus();
                            });
                          },
                          tooltip: 'Search',
                        ),
                        _buildProfileMenu(),
                      ],
                    ),
                  ),
                ),
                body: SafeArea(
                  child: Column(
                    children: [
                      // Animated search panel
                      SizeTransition(
                        sizeFactor: _searchPanelAnimation,
                        axis: Axis.vertical,
                        child: Container(
                          width: double.infinity,
                          color: MarkMeTheme.surfaceDark,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  style: TextStyle(
                                      color: MarkMeTheme.primaryWhite),
                                  textInputAction: TextInputAction.search,
                                  decoration: InputDecoration(
                                    hintText:
                                        'Search ${DefaultTabController.of(context).index == 0 ? "folders" : "lobbies"}...',
                                    hintStyle: TextStyle(
                                      color: MarkMeTheme.primaryWhite
                                          .withOpacity(0.5),
                                    ),
                                    prefixIcon: Icon(
                                      Icons.search,
                                      color: MarkMeTheme.primaryYellow,
                                      size: 20,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide: BorderSide.none,
                                    ),
                                    filled: true,
                                    fillColor: MarkMeTheme.darkBackground,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                      horizontal: 16,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.clear, size: 24),
                                color:
                                    MarkMeTheme.primaryWhite.withOpacity(0.7),
                                onPressed: () {
                                  // Clear search and collapse panel
                                  _searchController.clear();
                                  setState(() {
                                    _isSearchExpanded = false;
                                    _searchQuery = '';
                                  });
                                  FocusScope.of(context).unfocus();
                                  _searchPanelController.reverse();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Main content
                      Expanded(
                        child: PageView(
                          children: [
                            _buildFolderContent(),
                            _buildLobbyContent(context),
                          ],
                          onPageChanged: (index) {
                            tabController.index = index; 
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                floatingActionButton: Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: _buildFAB(context),
                ),
                bottomNavigationBar: Container(
                  height: kBottomNavigationBarHeight + 40,
                  decoration: BoxDecoration(
                    color: MarkMeTheme.surfaceDark,
                    border: Border(
                        top: BorderSide(
                            color: MarkMeTheme.primaryYellow.withOpacity(0.1),
                            width: 1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 24,
                        offset: Offset(0, -8),
                      ),
                    ],
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(28)),
                    child: Consumer<TabController>(
                      builder: (context, tabController, child) {
                        // Listen for tab changes to update search hint
                        tabController.addListener(() {
                          if (_isSearchExpanded) {
                            // Force rebuild to update hint text
                            setState(() {});
                          }
                        });

                        return NavigationBar(
                          height: kBottomNavigationBarHeight,
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          selectedIndex: tabController.index,
                          animationDuration: Duration(milliseconds: 300),
                          onDestinationSelected: (index) =>
                              tabController.animateTo(index),
                          destinations: [
                            NavigationDestination(
                              icon: Icon(Icons.folder_outlined),
                              selectedIcon: Icon(Icons.folder),
                              label: 'Folders',
                            ),
                            NavigationDestination(
                              icon: Icon(Icons.group_outlined),
                              selectedIcon: Icon(Icons.group),
                              label: 'Lobbies',
                            ),
                          ],
                          labelBehavior:
                              NavigationDestinationLabelBehavior.alwaysShow,
                          indicatorColor:
                              MarkMeTheme.primaryYellow.withOpacity(0.4),
                          surfaceTintColor: Colors.transparent,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFolderContent() {
    return Padding(
      padding: const EdgeInsets.only(
        left: 24.0,
        right: 24.0,
        top: 16.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Text(
                    'Welcome ${widget.authService.currentUser?.email ?? 'User'}!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: MarkMeTheme.primaryWhite,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                height: 24,
                width: 4,
                decoration: BoxDecoration(
                  color: MarkMeTheme.primaryYellow,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Your Folders',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                  color: MarkMeTheme.primaryWhite,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<String>>(
              future: _foldersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                MarkMeTheme.primaryYellow),
                            strokeWidth: 2.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading folders...',
                          style: TextStyle(
                            color: MarkMeTheme.primaryWhite.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final folders = snapshot.data ?? [];

                if (folders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.folder_off_rounded,
                          size: 100,
                          color: MarkMeTheme.primaryYellow.withOpacity(0.3),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No Folders Found',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: MarkMeTheme.primaryWhite,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Create new folders to organize your attendance records',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: MarkMeTheme.primaryWhite.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          icon: Icon(
                            Icons.create_new_folder,
                            size: 20,
                            color: MarkMeTheme.darkBackground,
                          ),
                          label: Text(
                            'Create Folder',
                            style: TextStyle(color: MarkMeTheme.darkBackground),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MarkMeTheme.primaryYellow,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: _showCreateFolderDialog,
                        ),
                      ],
                    ),
                  );
                }

                // Filter folders based on search query
                final filteredFolders = _searchQuery.isEmpty
                    ? folders
                    : folders
                        .where((folder) =>
                            folder.toLowerCase().contains(_searchQuery))
                        .toList();

                if (filteredFolders.isEmpty && _searchQuery.isNotEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 80,
                          color: MarkMeTheme.primaryYellow.withOpacity(0.3),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No Matching Folders',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: MarkMeTheme.primaryWhite,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Try a different search term',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: MarkMeTheme.primaryWhite.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount:
                        MediaQuery.of(context).size.width > 600 ? 3 : 2,
                    childAspectRatio: 1.2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                  ),
                  itemCount: filteredFolders.length,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    final folder = filteredFolders[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _navigateToFolder(context, folder),
                      onLongPress: () =>
                          _showFolderContextMenu(context, folder),
                      child: Container(
                        decoration: BoxDecoration(
                          color: MarkMeTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        MarkMeTheme.primaryYellow
                                            .withOpacity(0.1),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.folder,
                                      size: 32,
                                      color: MarkMeTheme.primaryYellow),
                                  SizedBox(height: 12),
                                  Text(
                                    folder,
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: MarkMeTheme.primaryWhite,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Spacer(),
                                  FutureBuilder<List<Student>>(
                                    future: widget.folderService
                                        .getStudents(folder),
                                    builder: (context, snapshot) {
                                      final recordCount = snapshot.hasData
                                          ? snapshot.data!.length
                                          : 0;
                                      final text = snapshot.connectionState ==
                                              ConnectionState.waiting
                                          ? 'Loading...'
                                          : '$recordCount Records';

                                      return Text(
                                        text,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: MarkMeTheme.primaryWhite
                                              .withOpacity(0.6),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLobbyContent(BuildContext context) {
    final lobbyProvider = Provider.of<LobbyProvider>(context);

    return FutureBuilder(
      future: _lobbiesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('Lobby fetch error: ${snapshot.error}');
          return ErrorWidgetHandler(
            error: snapshot.error!,
            onRetry: () => Provider.of<LobbyProvider>(
              context,
              listen: false,
            ).fetchActiveLobbies(),
          );
        }

        // Filter lobbies based on search query
        final lobbies = lobbyProvider.activeLobbies;
        final filteredLobbies = _searchQuery.isEmpty
            ? lobbies
            : lobbies
                .where((lobby) =>
                    lobby.name.toLowerCase().contains(_searchQuery) ||
                    lobby.id.toLowerCase().contains(_searchQuery))
                .toList();

        if (filteredLobbies.isEmpty) {
          if (_searchQuery.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.group_off,
              message: 'No Active Lobbies Found',
              actionText: 'Create New Lobby',
              onAction: () => Navigator.pushNamed(context, '/create-lobby'),
              secondaryActionText: 'Refresh',
              onSecondaryAction: () => lobbyProvider.fetchActiveLobbies(),
            );
          } else {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 80,
                    color: MarkMeTheme.primaryYellow.withOpacity(0.3),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No Matching Lobbies',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: MarkMeTheme.primaryWhite,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Try a different search term',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: MarkMeTheme.primaryWhite.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            );
          }
        }

        return _buildLobbyList(filteredLobbies);
      },
    );
  }

  Widget _buildFAB(BuildContext context) {
    return Consumer<TabController>(
      builder: (context, tabController, child) {
        final isFirstTab = tabController.index == 0;

        return FloatingActionButton(
          onPressed: isFirstTab
              ? _showCreateFolderDialog
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CreateLobbyScreen()),
                  ),
          tooltip: isFirstTab ? 'Create Folder' : 'Create Lobby',
          backgroundColor: MarkMeTheme.primaryYellow,
          elevation: 4,
          shape: const CircleBorder(),
          child: SvgPicture.asset(
            'assets/icon/knot.svg',
            colorFilter: ColorFilter.mode(
              MarkMeTheme.darkBackground,
              BlendMode.srcIn,
            ),
            semanticsLabel: 'Knot Icon',
            height: 30,
          ),
        );
      },
    );
  }

  void _leaveLobby(BuildContext context, String lobbyId) async {
    try {
      final lobbyService = Provider.of<LobbyService>(context, listen: false);
      final lobbyProvider = Provider.of<LobbyProvider>(context, listen: false);

      await lobbyService.leaveLobby(lobbyId);
      await lobbyProvider.fetchActiveLobbies();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Left lobby successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error leaving lobby: $e')));
      }
    }
  }

  Widget _buildLobbyList(List<Lobby> lobbies) {
    // Filter lobbies into my rooms and live rooms
    final myRooms = lobbies
        .where((l) => l.hostId == widget.authService.currentUser?.id)
        .toList();
    final liveRooms = lobbies
        .where((l) => l.hostId != widget.authService.currentUser?.id)
        .toList();

    return RefreshIndicator(
      color: MarkMeTheme.primaryYellow,
      backgroundColor: MarkMeTheme.surfaceDark,
      onRefresh: () => Provider.of<LobbyProvider>(
        context,
        listen: false,
      ).fetchActiveLobbies(),
      child: ListView(
        children: [
          _buildSectionHeader('My Rooms (${myRooms.length})', myRooms.isEmpty),
          if (myRooms.isNotEmpty) ..._buildLobbyItems(myRooms),
          _buildSectionHeader(
              'Live Rooms (${liveRooms.length})', liveRooms.isEmpty),
          if (liveRooms.isNotEmpty) ..._buildLobbyItems(liveRooms),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isEmpty) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: MarkMeTheme.primaryYellow,
            ),
          ),
          if (isEmpty)
            Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text(
                '(None)',
                style: TextStyle(
                  color: MarkMeTheme.primaryWhite.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildLobbyItems(List<Lobby> lobbies) {
    return [
      for (final lobby in lobbies)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: MarkMeTheme.surfaceDark,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(
              color: MarkMeTheme.primaryYellow.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _handleLobbyTap(context, lobby),
              onLongPress: lobby.hostId == widget.authService.currentUser?.id
                  ? () => _showLobbyOptionsMenu(context, lobby)
                  : null,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: MarkMeTheme.primaryYellow.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child:
                          Icon(Icons.group, color: MarkMeTheme.primaryYellow),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lobby.name,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: MarkMeTheme.primaryWhite,
                            ),
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              _buildStatusIndicator(lobby.active),
                              SizedBox(width: 8),
                              Text(
                                '${lobby.memberCount} members',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color:
                                      MarkMeTheme.primaryWhite.withOpacity(0.6),
                                ),
                              ),
                              SizedBox(width: 12),
                              Icon(
                                Icons.assignment_turned_in,
                                size: 14,
                                color:
                                    MarkMeTheme.primaryWhite.withOpacity(0.6),
                              ),
                              SizedBox(width: 4),
                              Text(
                                '${lobby.attendanceCount} entries',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color:
                                      MarkMeTheme.primaryWhite.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (lobby.hostId == widget.authService.currentUser?.id)
                      IconButton(
                        icon: Icon(
                          Icons.more_vert,
                          color: MarkMeTheme.primaryWhite.withOpacity(0.7),
                        ),
                        onPressed: () => _showLobbyOptionsMenu(context, lobby),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      SizedBox(height: 8),
    ];
  }

  Widget _buildParallaxBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MarkMeTheme.primaryYellow.withOpacity(0.15),
            Colors.transparent,
          ],
        ),
      ),
      child: ShaderMask(
        shaderCallback: (rect) {
          return LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.transparent],
          ).createShader(Rect.fromLTRB(0, 0, rect.width, rect.height));
        },
        blendMode: BlendMode.dstIn,
        child: Container(
          decoration: BoxDecoration(
            // Removed the missing asset reference that was causing errors
            color: Colors.transparent,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileMenu() {
    // Implementation of _buildProfileMenu method
    // This method should return a widget that implements the profile menu
    return PopupMenuButton(
      icon: const Icon(Icons.more_vert),
      tooltip: 'More options',
      itemBuilder: (context) => [
        PopupMenuItem(
          child: const Text('Profile'),
          onTap: () => _showUserDialog(context),
        ),
        PopupMenuItem(
          child: const Text('About'),
          onTap: () => _showAboutDialog(context),
        ),
        PopupMenuItem(
          child: const Text('Logout'),
          onTap: () async {
            try {
              await widget.authService.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Logout failed: $e')),
                );
              }
            }
          },
        ),
      ],
    );
  }

  // This method is no longer needed as we've replaced it with the inline search bar
  // Keeping an empty implementation in case it's referenced elsewhere
  void _showSearchModal() {
    // No longer used - search is now inline in the AppBar
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    int? badgeCount,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? MarkMeTheme.primaryYellow
                      : MarkMeTheme.primaryWhite.withOpacity(0.7),
                  size: 24,
                ),
                if (badgeCount != null && badgeCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: MarkMeTheme.primaryYellow,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: TextStyle(
                          color: MarkMeTheme.darkBackground,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? MarkMeTheme.primaryYellow
                    : MarkMeTheme.primaryWhite.withOpacity(0.7),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToFolder(BuildContext context, String folderName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FolderScreen(
          folderName: folderName,
          folderService: widget.folderService,
        ),
      ),
    );
  }

  void _handleLobbyTap(BuildContext context, Lobby lobby) async {
    final lobbyService = Provider.of<LobbyService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final isHost = authService.currentUser?.id == lobby.hostId;

    if (isHost) {
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ActiveLobbyScreen(lobbyId: lobby.id),
          ),
        );
      }
      return;
    }

    final isMember = await lobbyService.isUserMember(lobby.id);
    bool shouldNavigate = isMember;

    if (!isMember) {
      shouldNavigate =
          await _showEntryCodeDialog(context, lobby.id, lobbyService);
    }

    if (shouldNavigate && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveLobbyScreen(lobbyId: lobby.id),
        ),
      );
    }
  }

  Future<bool> _showEntryCodeDialog(
    BuildContext context,
    String lobbyId,
    LobbyService lobbyService,
  ) async {
    final codeController = TextEditingController();
    bool joinSuccessful = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enter Lobby Code'),
          content: TextField(
            controller: codeController,
            decoration: const InputDecoration(hintText: '6-digit code'),
            keyboardType: TextInputType.number,
            maxLength: 6,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Join'),
              onPressed: () async {
                try {
                  await lobbyService.joinLobby(codeController.text, lobbyId);
                  joinSuccessful = true;
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );

    return joinSuccessful;
  }

  Widget _buildStatusIndicator(bool isActive) {
    return Icon(
      Icons.circle,
      size: 12,
      color: isActive ? Colors.greenAccent : Colors.grey,
    );
  }

  void _deleteLobby(BuildContext context, Lobby lobby) async {
    // Check if user is the host
    if (lobby.hostId != widget.authService.currentUser?.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You can only delete lobbies that you have created')),
      );
      return;
    }

    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Lobby'),
            content: Text(
                'Are you sure you want to delete "${lobby.name}"? This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete) return;

    try {
      final lobbyService = Provider.of<LobbyService>(context, listen: false);
      final lobbyProvider = Provider.of<LobbyProvider>(context, listen: false);

      await lobbyService.deleteLobby(lobby.id);
      await lobbyProvider.fetchActiveLobbies();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lobby deleted successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting lobby: $e')),
        );
      }
    }
  }

  void _showLobbyOptionsMenu(BuildContext context, Lobby lobby) {
    showModalBottomSheet(
      context: context,
      backgroundColor: MarkMeTheme.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.redAccent),
                title: Text(
                  'Delete Lobby',
                  style: TextStyle(color: MarkMeTheme.primaryWhite),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteLobby(context, lobby);
                },
              ),
              ListTile(
                leading: Icon(Icons.cancel_outlined,
                    color: MarkMeTheme.primaryWhite),
                title: Text(
                  'Cancel',
                  style: TextStyle(color: MarkMeTheme.primaryWhite),
                ),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
