import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/lobby_service.dart';
import '../providers/lobby_provider.dart';

class CreateLobbyScreen extends StatefulWidget {
  const CreateLobbyScreen({super.key});

  @override
  _CreateLobbyScreenState createState() => _CreateLobbyScreenState();
}

class _CreateLobbyScreenState extends State<CreateLobbyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  Future<void> _createLobby() async {
    if (!_formKey.currentState!.validate()) return;
    
    final lobbyService = context.read<LobbyService>();
    final lobbyProvider = context.read<LobbyProvider>();
    
    try {
      final lobby = await lobbyService.createLobby(_nameController.text);
      await lobbyProvider.initializeRealtime(lobby['id'] as String);
      Navigator.pushReplacementNamed(
        context, 
        '/active-lobby',
        arguments: lobby['id'] as String,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating lobby: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Create Lobby')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Event Name'),
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _createLobby,
                child: Text('Create Lobby'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 