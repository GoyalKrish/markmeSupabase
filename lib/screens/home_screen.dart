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
                final exists = await widget.folderService.folderExists(folderName);
                if (exists) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('A folder with this name already exists'),
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
              'Registered: ${user?.createdAt != null ? 
                DateFormat('yyyy-MM-dd – HH:mm').format(
                  DateTime.parse(user!.createdAt!).toLocal()
                ) : 
                'N/A'}'
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
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
      child: Scaffold(
        appBar: AppBar(
          title: const Text('MarkMe'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.folder), text: 'Folders'),
              Tab(icon: Icon(Icons.group), text: 'Lobbies'),
            ],
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
        body: TabBarView(
          children: [
            _buildFolderContent(),
            _buildLobbyContent(context),
          ],
        ),
        floatingActionButton: _buildFAB(context),
      ),
    );
  }

  Widget _buildFolderContent() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome ${widget.authService.currentUser?.email ?? 'User'}!',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 20),
          const Text(
            'Your Folders:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: FutureBuilder<List<String>>(
              future: _foldersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final folders = snapshot.data ?? [];
                
                if (folders.isEmpty) {
                  return const Center(child: Text('No folders yet'));
                }

                return ListView.builder(
                  itemCount: folders.length,
                  itemBuilder: (context, index) {
                    final folder = folders[index];
                    return Card(
                      child: ListTile(
                        title: Text(folder),
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
            onRetry: () => Provider.of<LobbyProvider>(context, listen: false).fetchActiveLobbies(),
          );
        }

        final lobbies = lobbyProvider.activeLobbies;
        
        if (lobbies.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.group_off,
            message: 'No Active Lobbies Found',
            actionText: 'Create New Lobby',
            onAction: () => Navigator.pushNamed(context, '/create-lobby'),
          );
        }

        return _buildLobbyList(lobbies);
      },
    );
  }

  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showCreateFolderDialog(),
      child: const Icon(Icons.add),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error leaving lobby: $e')),
        );
      }
    }
  }

  Widget _buildLobbyList(List<Lobby> lobbies) {
    return RefreshIndicator(
      onRefresh: () => Provider.of<LobbyProvider>(context, listen: false).fetchActiveLobbies(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: lobbies.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
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

  const _LobbyListItem({
    required this.lobby,
    required this.onLeaveLobby,
  });

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;
    final isHost = user?.id == lobby.hostId;

    return Card(
      child: ListTile(
        leading: const Icon(Icons.group),
        title: Text(
          lobby.name,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isHost) Text('Code: ${lobby.entryCode}'),
            const SizedBox(height: 4),
            _buildLobbyStats(),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.exit_to_app),
          onPressed: () => onLeaveLobby(lobby.id),
        ),
        onTap: () async {
          final lobbyService = Provider.of<LobbyService>(context, listen: false);
          final authService = Provider.of<AuthService>(context, listen: false);
          final isHost = authService.currentUser?.id == lobby.hostId;

          if (isHost) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ActiveLobbyScreen(lobbyId: lobby.id)),
            );
            return;
          }

          final isMember = await lobbyService.isUserMember(lobby.id);
          if (!isMember) {
            await _showEntryCodeDialog(context, lobby.id, lobbyService);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ActiveLobbyScreen(lobbyId: lobby.id)),
            );
          }
        },
      ),
    );
  }

  Widget _buildLobbyStats() {
    return Row(
      children: [
        _buildStatItem(
          Icons.people,
          '${lobby.memberCount}',
        ),
        const SizedBox(width: 12),
        _buildStatItem(
          Icons.checklist,
          '${lobby.attendanceCount}',
        ),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 4),
        Text(value),
      ],
    );
  }

  Future<void> _showEntryCodeDialog(BuildContext context, String lobbyId, LobbyService lobbyService) async {
    final codeController = TextEditingController();
    return showDialog<void>(
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
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ActiveLobbyScreen(lobbyId: lobbyId)),
                    );
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
  }
} 