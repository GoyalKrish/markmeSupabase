import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/lobby_service.dart';
import '../providers/lobby_provider.dart';
import '../theme/markme_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/notification_extensions.dart';

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
      context.showErrorNotification('Error creating lobby: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: MarkMeTheme.backgroundGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text(
            'Create Lobby',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: MarkMeTheme.primaryWhite,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: MarkMeTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TextFormField(
                    controller: _nameController,
                    style: GoogleFonts.inter(
                      color: MarkMeTheme.primaryWhite,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Event Name',
                      labelStyle: GoogleFonts.inter(
                        color: MarkMeTheme.primaryWhite.withOpacity(0.7),
                      ),
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                    ),
                    maxLength: 18,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (value.length > 18) {
                        return 'Name cannot exceed 18 characters';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _createLobby,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MarkMeTheme.primaryYellow,
                    foregroundColor: MarkMeTheme.darkBackground,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 4,
                    shadowColor: MarkMeTheme.primaryYellow.withOpacity(0.5),
                  ),
                  child: Text(
                    'Create Lobby',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
