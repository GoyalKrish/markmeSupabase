import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/lobby_provider.dart';

class ActiveLobbyScreen extends StatelessWidget {
  final String lobbyId;

  const ActiveLobbyScreen({super.key, required this.lobbyId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Active Lobby')),
      body: Center(
        child: Text('Lobby ID: $lobbyId'),
      ),
    );
  }
} 