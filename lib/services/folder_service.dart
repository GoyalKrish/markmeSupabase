import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/student.dart';

class FolderService {
  static const _foldersKey = 'user_folders';

  Future<List<String>> getFolders() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_foldersKey) ?? [];
  }

  Future<void> addFolder(String folderName) async {
    final prefs = await SharedPreferences.getInstance();
    final folders = await getFolders();
    folders.add(folderName);
    await prefs.setStringList(_foldersKey, folders);
  }

  Future<void> deleteFolder(String folderName) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Remove folder from folders list
    final folders = await getFolders();
    folders.remove(folderName);
    await prefs.setStringList(_foldersKey, folders);

    // Remove all associated data
    await _cleanupFolderData(folderName);
  }

  Future<void> _cleanupFolderData(String folderName) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Remove students list
    await prefs.remove('${folderName}_students');
    
    // Remove any other associated data keys
    final allKeys = prefs.getKeys();
    final folderKeys = allKeys.where((key) => key.startsWith('${folderName}_'));
    
    for (var key in folderKeys) {
      await prefs.remove(key);
    }
  }

  Future<void> updateFolder(String oldName, String newName) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get and update folder list
    final folders = await getFolders();
    final index = folders.indexOf(oldName);
    if (index != -1) {
      folders[index] = newName;
      await prefs.setStringList(_foldersKey, folders);

      // Move all associated data to new keys
      await _migrateFolderData(oldName, newName);
    }
  }

  Future<void> _migrateFolderData(String oldName, String newName) async {
    final prefs = await SharedPreferences.getInstance();
    final students = await getStudents(oldName);
    await saveStudents(newName, students);
    await _cleanupFolderData(oldName);
  }

  Future<List<Student>> getStudents(String folderName) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList('${folderName}_students') ?? [];
    return jsonList.map((json) => Student.fromJson(jsonDecode(json))).toList();
  }

  Future<void> saveStudents(String folderName, List<Student> students) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = students.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList('${folderName}_students', jsonList);
  }

  Future<void> addStudent(String folderName, Student student) async {
    final prefs = await SharedPreferences.getInstance();
    final students = await getStudents(folderName);
    students.insert(0, student);
    await saveStudents(folderName, students);
  }

  // Optional: Add a method to check if a folder exists
  Future<bool> folderExists(String folderName) async {
    final folders = await getFolders();
    return folders.contains(folderName);
  }

  Future<void> deleteStudent(String folderName, int index) async {
    final students = await getStudents(folderName);
    if (index >= 0 && index < students.length) {
      students.removeAt(index);
      await saveStudents(folderName, students);
    }
  }

  Future<void> insertStudent(String folderName, Student student, int index) async {
    final students = await getStudents(folderName);
    if (index >= 0 && index <= students.length) {
      students.insert(index, student);
      await saveStudents(folderName, students);
    }
  }
} 