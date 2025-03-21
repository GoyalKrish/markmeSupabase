import 'package:flutter/material.dart';
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

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<String>> _foldersFuture;
  late Future<void> _lobbiesFuture;

  @override
  void initState() {
    super.initState();
    _refreshFolders();
    final lobbyProvider = Provider.of<LobbyProvider>(context, listen: false);
    _lobbiesFuture = lobbyProvider.fetchActiveLobbies();
    
    if (widget.authService.currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/login');
      });
    }
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
      builder:
          (context) => AlertDialog(
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
                          builder:
                              (context) => FolderScreen(
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
      builder:
          (context) => AlertDialog(
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
      builder:
          (context) => AlertDialog(
            title: const Text('User Profile'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Email: ${user?.email ?? 'N/A'}'),
                const SizedBox(height: 8),
                Text(
                  'Registered: ${user?.createdAt != null ? DateFormat('yyyy-MM-dd – HH:mm').format(DateTime.parse(user!.createdAt!).toLocal()) : 'N/A'}',
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
      builder:
          (context) => AlertDialog(
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
      builder:
          (context) => AlertDialog(
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
      builder:
          (context) => AlertDialog(
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
          return ListenableProvider.value(
            value: tabController,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                gradient: MarkMeTheme.backgroundGradient,
                image: DecorationImage(
                  image: AssetImage('assets/images/subtle_pattern.png'),
                  opacity: 0.03,
                  repeat: ImageRepeat.repeat,
                ),
              ),
              child: Scaffold(
                backgroundColor: Colors.transparent,
                appBar: PreferredSize(
                  preferredSize: const Size.fromHeight(kToolbarHeight),
                  child: _buildAppBar(),
                ),
                body: TabBarView(
                  physics: const BouncingScrollPhysics(), 
                  children: [_buildFolderContent(), _buildLobbyContent(context)],
                ),
                floatingActionButton: _buildFAB(context),
                bottomNavigationBar: Consumer<TabController>(
                  builder: (context, tabController, child) {
                    return Container(
                      decoration: BoxDecoration(
                        color: MarkMeTheme.surfaceDark,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, -1),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildNavItem(
                                icon: Icons.folder,
                                label: 'Folders',
                                isSelected: tabController.index == 0,
                                onTap: () => tabController.animateTo(0),
                              ),
                              _buildNavItem(
                                icon: Icons.group,
                                label: 'Lobbies',
                                isSelected: tabController.index == 1,
                                badgeCount: Provider.of<LobbyProvider>(context).activeLobbies.length,
                                onTap: () => tabController.animateTo(1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
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
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
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
                            valueColor: AlwaysStoppedAnimation<Color>(MarkMeTheme.primaryYellow),
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
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: MarkMeTheme.primaryYellow.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.folder_outlined,
                            size: 40,
                            color: MarkMeTheme.primaryYellow,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No folders yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: MarkMeTheme.primaryWhite,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            'Create your first folder to start organizing your attendance records',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: MarkMeTheme.primaryWhite.withOpacity(0.7),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _showCreateFolderDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Create Folder'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MarkMeTheme.primaryYellow,
                            foregroundColor: MarkMeTheme.darkBackground,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: folders.length,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    final folder = folders[index];
                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FolderScreen(
                              folderName: folder,
                              folderService: widget.folderService,
                            ),
                          ),
                        );
                      },
                      onLongPress: () => _showFolderContextMenu(context, folder),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: MarkMeTheme.primaryYellow.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.folder,
                                  color: MarkMeTheme.primaryYellow,
                                  size: 24,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: MarkMeTheme.primaryWhite.withOpacity(0.1),
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            folder,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Tap to view attendances',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: MarkMeTheme.primaryWhite.withOpacity(0.6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.more_vert,
                                        size: 20,
                                        color: MarkMeTheme.primaryWhite,
                                      ),
                                      onPressed: () => _showFolderContextMenu(context, folder),
                                    ),
                                  ],
                                ),
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
            onRetry:
                () =>
                    Provider.of<LobbyProvider>(
                      context,
                      listen: false,
                    ).fetchActiveLobbies(),
          );
        }

        final lobbies = lobbyProvider.activeLobbies;

        if (lobbies.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.group_off,
            message: 'No Active Lobbies Found',
            actionText: 'Create New Lobby',
            onAction: () => Navigator.pushNamed(context, '/create-lobby'),
            secondaryActionText: 'Refresh',
            onSecondaryAction: () => lobbyProvider.fetchActiveLobbies(),
          );
        }

        return _buildLobbyList(lobbies);
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
                  MaterialPageRoute(builder: (_) => const CreateLobbyScreen()),
                ),
          tooltip: isFirstTab ? 'Create Folder' : 'Create Lobby',
          backgroundColor: MarkMeTheme.primaryYellow,
          child: const Icon(
            Icons.add,
            color: MarkMeTheme.darkBackground,
          ),
          elevation: 4,
          shape: const CircleBorder(),
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
    return RefreshIndicator(
      color: MarkMeTheme.primaryYellow,
      backgroundColor: MarkMeTheme.surfaceDark,
      onRefresh: () => Provider.of<LobbyProvider>(
        context,
        listen: false,
      ).fetchActiveLobbies(),
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: lobbies.length,
        physics: const BouncingScrollPhysics(),
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final lobby = lobbies[index];
          return _LobbyListItem(
            lobby: lobby,
            onLeaveLobby: (lobbyId) => _leaveLobby(context, lobbyId),
          );
        },
      ),
    );
  }

  Widget _buildAppBar() {
    return AppBar(
      elevation: 0,
      title: Row(
        children: [
          Image.asset('assets/images/markme_icon.png', height: 28),
          const SizedBox(width: 10),
          const Text('MarkMe', 
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search',
          onPressed: () => _showSearchModal(context),
        ),
        PopupMenuButton(
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
        ),
      ],
    );
  }

  void _showSearchModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MarkMeTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer<TabController>(
          builder: (context, tabController, _) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(
                      color: MarkMeTheme.primaryWhite.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: tabController.index == 0 ? 'Search folders...' : 'Search lobbies...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: MarkMeTheme.darkBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                    ),
                    style: const TextStyle(color: MarkMeTheme.primaryWhite),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
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
}

class _LobbyListItem extends StatelessWidget {
  final Lobby lobby;
  final Function(String) onLeaveLobby;

  const _LobbyListItem({required this.lobby, required this.onLeaveLobby});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;
    final isHost = user?.id == lobby.hostId;

    return InkWell(
      onTap: () async {
        final lobbyService = Provider.of<LobbyService>(
          context,
          listen: false,
        );
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
          shouldNavigate = await _showEntryCodeDialog(context, lobby.id, lobbyService);
        }

        if (shouldNavigate && context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ActiveLobbyScreen(lobbyId: lobby.id),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isHost
                    ? MarkMeTheme.primaryYellow.withOpacity(0.15)
                    : MarkMeTheme.primaryWhite.withOpacity(0.1),
                shape: BoxShape.circle,
                border: isHost
                    ? Border.all(
                        color: MarkMeTheme.primaryYellow.withOpacity(0.5),
                        width: 1.5,
                      )
                    : null,
              ),
              child: Center(
                child: Icon(
                  Icons.group,
                  color: isHost
                      ? MarkMeTheme.primaryYellow
                      : MarkMeTheme.primaryWhite,
                  size: 24,
                ),
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: MarkMeTheme.primaryWhite.withOpacity(0.1),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  lobby.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                'Active',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: MarkMeTheme.primaryWhite.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (isHost)
                                Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: MarkMeTheme.primaryYellow.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: MarkMeTheme.primaryYellow.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    'Code: ${lobby.entryCode}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: MarkMeTheme.primaryYellow,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              Icon(
                                Icons.people,
                                size: 14,
                                color: MarkMeTheme.primaryWhite.withOpacity(0.6),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${lobby.memberCount}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: MarkMeTheme.primaryWhite.withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.checklist,
                                size: 14,
                                color: MarkMeTheme.primaryWhite.withOpacity(0.6),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${lobby.attendanceCount}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: MarkMeTheme.primaryWhite.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => onLeaveLobby(lobby.id),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.exit_to_app,
                          size: 20,
                          color: Colors.redAccent.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
}
