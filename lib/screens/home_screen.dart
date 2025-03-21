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
                appBar: AppBar(
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
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(48),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TabBar(
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.circular(50.0),
                          color: MarkMeTheme.primaryYellow.withOpacity(0.15),
                          border: Border.all(
                            color: MarkMeTheme.primaryYellow,
                            width: 1.5,
                          ),
                        ),
                        labelColor: MarkMeTheme.primaryYellow,
                        unselectedLabelColor: MarkMeTheme.primaryWhite.withOpacity(0.7),
                        tabs: const [
                          Tab(icon: Icon(Icons.folder), text: 'Folders'),
                          Tab(icon: Icon(Icons.group), text: 'Lobbies'),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.info_outline),
                      onPressed: () => _showAboutDialog(context),
                      tooltip: 'About',
                    ),
                    IconButton(
                      icon: const Icon(Icons.person_outline),
                      onPressed: () => _showUserDialog(context),
                      tooltip: 'User Profile',
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout),
                      onPressed: () async {
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
                      tooltip: 'Logout',
                    ),
                  ],
                ),
                body: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: TabBarView(
                    physics: const BouncingScrollPhysics(),
                    children: [_buildFolderContent(), _buildLobbyContent(context)],
                  ),
                ),
                floatingActionButton: _buildFAB(context),
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
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: MarkMeTheme.surfaceDark,
                            borderRadius: BorderRadius.circular(40),
                            border: Border.all(
                              color: MarkMeTheme.primaryYellow.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.folder_outlined,
                            size: 40,
                            color: MarkMeTheme.primaryYellow.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No folders yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: MarkMeTheme.primaryWhite,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the + button to create your first folder',
                          style: TextStyle(
                            fontSize: 14,
                            color: MarkMeTheme.primaryWhite.withOpacity(0.6),
                          ),
                          textAlign: TextAlign.center,
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
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: MarkMeTheme.primaryYellow.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          highlightColor: MarkMeTheme.primaryYellow.withOpacity(0.05),
                          splashColor: MarkMeTheme.primaryYellow.withOpacity(0.1),
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
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: MarkMeTheme.primaryYellow.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.folder,
                                  color: MarkMeTheme.primaryYellow,
                                  size: 24,
                                ),
                              ),
                              title: Text(
                                folder,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              trailing: Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: MarkMeTheme.primaryWhite.withOpacity(0.6),
                              ),
                            ),
                          ),
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
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return ScaleTransition(scale: animation, child: child);
          },
          child: tabController.index == 0
              ? FloatingActionButton(
                  key: const ValueKey('folderFAB'),
                  onPressed: _showCreateFolderDialog,
                  tooltip: 'Create Folder',
                  backgroundColor: MarkMeTheme.primaryYellow,
                  foregroundColor: MarkMeTheme.darkBackground,
                  elevation: 4,
                  child: const Icon(Icons.create_new_folder, size: 26),
                )
              : FloatingActionButton(
                  key: const ValueKey('lobbyFAB'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateLobbyScreen()),
                  ),
                  tooltip: 'Create Lobby',
                  backgroundColor: MarkMeTheme.primaryYellow,
                  foregroundColor: MarkMeTheme.darkBackground,
                  elevation: 4,
                  child: const Icon(Icons.add, size: 26),
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
}

class _LobbyListItem extends StatelessWidget {
  final Lobby lobby;
  final Function(String) onLeaveLobby;

  const _LobbyListItem({required this.lobby, required this.onLeaveLobby});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;
    final isHost = user?.id == lobby.hostId;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isHost 
              ? MarkMeTheme.primaryYellow.withOpacity(0.3)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: MarkMeTheme.primaryYellow.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.group,
                    color: MarkMeTheme.primaryYellow,
                  ),
                ),
                title: Text(
                  lobby.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                    letterSpacing: 0.2,
                  ),
                ),
                trailing: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.exit_to_app,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                  ),
                  onPressed: () => onLeaveLobby(lobby.id),
                ),
              ),
              if (isHost)
                Padding(
                  padding: const EdgeInsets.only(left: 72.0, right: 16.0, bottom: 8.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                    decoration: BoxDecoration(
                      color: MarkMeTheme.primaryYellow.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: MarkMeTheme.primaryYellow.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.vpn_key,
                          size: 14,
                          color: MarkMeTheme.primaryYellow,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Code: ${lobby.entryCode}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: MarkMeTheme.primaryYellow,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(left: 72.0, right: 16.0, top: 4.0),
                child: _buildEnhancedLobbyStats(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedLobbyStats() {
    return Row(
      children: [
        _buildStatItem(
          Icons.people,
          '${lobby.memberCount}',
          'Members',
        ),
        const SizedBox(width: 20),
        _buildStatItem(
          Icons.checklist,
          '${lobby.attendanceCount}',
          'Attendances',
        ),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 16,
          color: MarkMeTheme.primaryWhite.withOpacity(0.7),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: MarkMeTheme.primaryWhite,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: MarkMeTheme.primaryWhite.withOpacity(0.5),
          ),
        ),
      ],
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
