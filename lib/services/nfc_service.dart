import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';

class NFCService {
  static final NFCService _instance = NFCService._internal();
  factory NFCService() => _instance;
  NFCService._internal();

  bool _isScanning = false;
  Function(Map<String, dynamic>)? _onTagRead;

  bool get isScanning => _isScanning;

  Future<bool> isNFCAvailable() async {
    try {
      return await NfcManager.instance.isAvailable();
    } catch (e) {
      debugPrint('Error checking NFC availability: $e');
      return false;
    }
  }

  Future<void> startScanning(Function(Map<String, dynamic>) onTagRead) async {
    if (_isScanning) return;
    
    _onTagRead = onTagRead;
    _isScanning = true;

    try {
      await NfcManager.instance.startSession(onDiscovered: _handleTag);
    } catch (e) {
      _isScanning = false;
      rethrow;
    }
  }

  Future<void> stopScanning() async {
    if (!_isScanning) return;
    
    try {
      await NfcManager.instance.stopSession();
    } finally {
      _isScanning = false;
      _onTagRead = null;
    }
  }

  Future<void> _handleTag(NfcTag tag) async {
    Map<String, dynamic> scannedData = {};

    if (tag.data['mifareclassic'] != null) {
      var mifareClassic = MifareClassic.from(tag);
      if (mifareClassic == null) {
        scannedData['Error'] = 'Failed to create MifareClassic instance';
      } else {
        try {
          List<List<int>> authKeys = [
            [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF],
            [0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5],
            [0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
          ];

          // Read only the sectors containing blocks 1 and 4
          for (int sector = 0; sector <= 1; sector++) {
            bool authenticated = false;
            for (var key in authKeys) {
              try {
                await mifareClassic.authenticateSectorWithKeyA(
                  sectorIndex: sector,
                  key: Uint8List.fromList(key),
                );
                authenticated = true;
                break;
              } catch (e) {
                continue;
              }
            }

            if (!authenticated) {
              scannedData['Sector $sector'] = 'Authentication failed';
              continue;
            }

            // Read blocks in the sector
            for (int block = sector * 4; block < (sector + 1) * 4; block++) {
              if (block % 4 != 3) { // Skip trailer blocks
                try {
                  var data = await mifareClassic.readBlock(blockIndex: block);
                  String blockData = String.fromCharCodes(data).trim();
                  if (blockData.isNotEmpty) {
                    scannedData['Block $block'] = blockData;
                  }
                } catch (e) {
                  scannedData['Block $block'] = 'Read failed: ${e.toString()}';
                }
              }
            }
          }
        } catch (e) {
          scannedData['Error'] = 'Failed to read card: ${e.toString()}';
        }
      }
    } else {
      scannedData['Error'] = 'Not a Mifare Classic card';
    }

    if (_onTagRead != null) {
      _onTagRead!(scannedData);
    }
  }
} 