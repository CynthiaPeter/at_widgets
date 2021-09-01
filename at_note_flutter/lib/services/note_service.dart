/// A service to handle save and retrieve operation on note
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

// ignore: import_of_legacy_library_into_null_safe
import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:at_note_flutter/utils/strings.dart';
import 'package:image/image.dart' as img;

// ignore: import_of_legacy_library_into_null_safe
import 'package:at_commons/at_commons.dart';
import 'package:at_note_flutter/models/key_model.dart';
import 'package:at_note_flutter/models/note_model.dart';
import 'package:at_note_flutter/utils/note_utils.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

class NoteService {
  NoteService._();

  static final NoteService _instance = NoteService._();

  factory NoteService() => _instance;

  final String storageKey = 'note.';
  final String noteKey = 'noteKey';

  String? sendToAtSign;

  late AtClientManager atClientManager;
  late AtClient atClient;

  String? rootDomain;
  int? rootPort;
  String? currentAtSign;

  List<Note> notes = [];
  List<dynamic>? notesJson = [];

  StreamController<List<Note>> noteStreamController =
      StreamController<List<Note>>.broadcast();

  Sink get noteSink => noteStreamController.sink;

  Stream<List<Note>> get noteStream => noteStreamController.stream;

  void disposeControllers() {
    noteStreamController.close();
  }

  void initNoteService(
      AtClientManager atClientManagerFromApp,
      AtClientPreference atClientPreference,
      String currentAtSignFromApp,
      String rootDomainFromApp,
      int rootPortFromApp) async {
    currentAtSign = currentAtSignFromApp;
    rootDomain = rootDomainFromApp;
    rootPort = rootPortFromApp;
    atClientManager = atClientManagerFromApp;
    atClientManager.setCurrentAtSign(
        currentAtSignFromApp, '', atClientPreference);

    atClient = atClientManager.atClient;

    // notificationService.subscribe(regex: '.wavi').listen((notification) {
    //   _notificationCallback(notification);
    // });

    //   await startMonitor();
    atClientManager.notificationService.subscribe().listen((notification) {
      _notificationCallback(notification);
    });
  }

  /// Listen Notification
  void _notificationCallback(dynamic notification) async {
    AtNotification atNotification = notification;
    var notificationKey = atNotification.key;
    var fromAtsign = atNotification.from;
    var toAtsign = atNotification.to;

    // remove from and to atsigns from the notification key
    if (notificationKey.contains(':')) {
      notificationKey = notificationKey.split(':')[1];
    }
    notificationKey = notificationKey.replaceFirst(fromAtsign, '').trim();
    print('notificationKey = $notificationKey');
    if ((notificationKey.startsWith(storageKey) && toAtsign == currentAtSign)) {
      var message = atNotification.value ?? '';
      print('value = $message');
      var decryptedMessage = await atClient.encryptionService!
          .decrypt(message, fromAtsign)
          .catchError((e) {
        //   print('error in decrypting notify $e');
      });
      print('notify message => $decryptedMessage $fromAtsign');
    }
  }

  /// Get Note List from AtClient
  Future<void> getNotes({String? atsign}) async {
    try {
      notes = [];
      var key = AtKey()
        ..key = storageKey + (atsign ?? currentAtSign ?? ' ').substring(1)
        ..sharedBy = currentAtSign
        ..sharedWith = sendToAtSign
        ..metadata = Metadata();

      var keyValue = await atClient.get(key).catchError((e) {
        print('error in get ${e.errorCode} ${e.errorMessage}');
      });

      // ignore: unnecessary_null_comparison
      if (keyValue != null && keyValue.value != null) {
        notesJson = json.decode((keyValue.value) as String) as List?;

        if (notesJson != null) {
          for (int i = 0; i < notesJson!.length; i++) {
            if (notesJson![i] != null) {
              var note = Note.fromJson((notesJson![i]));

              String? keyImage = '';
              bool hasGetImageNote = false;
              for (var item in note.items!) {
                if (item.type == 'image') {
                  if (item.value != null && item.value!.isNotEmpty) {
                    if (!hasGetImageNote) {
                      keyImage = item.value!;
                      hasGetImageNote = true;
                    }
                    var uInt8List = await getImage(item.value!);
                    item.image = uInt8List;
                  }
                }
              }
              if (keyImage != null && keyImage.isNotEmpty) {
                var uInt8List = await getImage(keyImage);
                note.image = uInt8List;
              }
              notes.add(note);
            }
          }
        }
        noteSink.add(notes);
      } else {
        notesJson = [];
        noteSink.add(notes);
      }
    } catch (error) {
      print('Error in getting note -> $error');
    }
  }

  void setSendToAtSign(String? sendToAtSign) {
    this.sendToAtSign = sendToAtSign!;
  }

  /// Search Note
  Future<bool> searchNote(String text) async {
    var searchNotes = notes.where((element) {
      if (element.title != null) {
        return element.title!.toLowerCase().contains(text.toLowerCase());
      } else {
        return false;
      }
    }).toList();
    noteSink.add(searchNotes);
    return true;
  }

  /// Save Image In Note to atClient
  Future<String> addImage(String name, Uint8List uint8list) async {
    try {
      print('name = $name');
      var metadata = Metadata();
      metadata.isBinary = true;
      var key = AtKey()
        ..key = storageKey + (currentAtSign ?? ' ').substring(1) + '.$name'
        ..sharedBy = currentAtSign
        ..metadata = metadata;
      bool isSuccess = await atClient.put(key, uint8list);
      print('Add Image Success $isSuccess');

      KeyModel newKey = KeyModel(
        value: key.key,
        sharedBy: key.sharedBy,
        isBinary: true,
      );
      return newKey.toJson();
    } catch (e) {
      print('Error in setting image => $e');
      return '';
    }
  }

  /// Get Image from Key from atClient
  Future<Uint8List?> getImage(String keyImage) async {
    try {
      KeyModel newKey = KeyModel.fromJson(keyImage);

      var metaData = Metadata();
      metaData.isBinary = true;

      var key = AtKey()
        ..key = newKey.value
        ..sharedBy = newKey.sharedBy
        ..metadata = metaData;
      var keyValue = await atClient.get(key).catchError((e) {
        print('error in get ${e.errorCode} ${e.errorMessage}');
      });

      // ignore: unnecessary_null_comparison
      if (keyValue != null && keyValue.value != null) {
        List<int> intList = keyValue.value.cast<int>();
        Uint8List image = Uint8List.fromList(intList);
        return image;
      } else {
        return null;
      }
    } catch (e) {
      print('Error in getting image => $e');
      return null;
    }
  }

  /// Add Note to AtClient
  Future<bool> addNote(Note note) async {
    try {
      var key = AtKey()
        ..key = storageKey + (currentAtSign ?? ' ').substring(1)
        ..sharedBy = currentAtSign
        ..sharedWith = sendToAtSign
        ..metadata = Metadata();

      Note newNote = await addImageToNote(note);
      notes.add(newNote);
      noteSink.add(notes);
      notesJson!.add(note.toJson());
      bool isSuccess = await atClient.put(key, json.encode(notesJson));
      print('Add Note Success $isSuccess');
      return true;
    } catch (e) {
      print('Error in setting note => $e');
      return false;
    }
  }

  /// Edit Note to AtClient
  Future<bool> editNote(Note note, int index) async {
    try {
      var key = AtKey()
        ..key = storageKey + (currentAtSign ?? ' ').substring(1)
        ..sharedBy = currentAtSign
        ..sharedWith = sendToAtSign
        ..metadata = Metadata();

      Note newNote = await addImageToNote(note);
      notes[index] = newNote;
      noteSink.add(notes);

      notesJson!.clear();
      notes.forEach((value) {
        var note = value.toJson();
        notesJson!.add(note);
      });
      bool isSuccess = await atClient.put(key, json.encode(notesJson));
      print('Edit Note Success $isSuccess');
      return true;
    } catch (e) {
      print('Error in setting note => $e');
      return false;
    }
  }

  /// Remove Note to atClient
  Future<bool> removeNote(int index) async {
    try {
      var key = AtKey()
        ..key = storageKey + (currentAtSign ?? ' ').substring(1)
        ..sharedBy = currentAtSign
        ..sharedWith = sendToAtSign
        ..metadata = Metadata();

      notes.removeAt(index);
      noteSink.add(notes);

      notesJson!.clear();
      notes.forEach((value) {
        var note = value.toJson();
        notesJson!.add(note);
      });

      bool isSuccess = await atClient.put(key, json.encode(notesJson));
      print('Remove Note Success $isSuccess');
      return true;
    } catch (e) {
      print('Error in setting note => $e');
      return false;
    }
  }

  /// Add Image to show in Note List
  Future<Note> addImageToNote(Note note) async {
    String keyImage = '';
    bool hasGetImageNote = false;
    for (var item in note.items!) {
      if (item.type == 'image') {
        if (item.value != null && item.value!.isNotEmpty) {
          if (!hasGetImageNote) {
            keyImage = item.value!;
            hasGetImageNote = true;
          }
          var uInt8List = await getImage(item.value!);
          item.image = uInt8List;
        }
      }
    }
    if (keyImage != null && keyImage.isNotEmpty) {
      var uInt8List = await getImage(keyImage);
      note.image = uInt8List;
    }
    return note;
  }

  /// Handle Drag and Drop Note
  Future<bool> reorderNote(int oldIndex, int newIndex) async {
    try {
      Note oldNote = notes[oldIndex];
      Note newNote = notes[newIndex];

      notes[newIndex] = oldNote;
      notes[oldIndex] = newNote;
      noteSink.add(notes);
      print('ReOrder Note Success');
      return true;
    } catch (e) {
      print('Error in setting note => $e');
      return false;
    }
  }

  /// Update New Order of Notes after Drag and Drop
  Future<bool> updateNotes() async {
    try {
      var key = AtKey()
        ..key = storageKey + (currentAtSign ?? ' ').substring(1)
        ..sharedBy = currentAtSign
        ..sharedWith = sendToAtSign
        ..metadata = Metadata();

      notesJson!.clear();
      notes.forEach((value) {
        var note = value.toJson();
        notesJson!.add(note);
      });
      bool isSuccess = await atClient.put(key, json.encode(notesJson));
      print('Update Notes Success $isSuccess');
      return true;
    } catch (e) {
      print('Error in setting note => $e');
      return false;
    }
  }

  /// Crop and compress image get from device
  Future<Uint8List?> cropImage(BuildContext context, String path) async {
    try {
      var _cropped = await ImageCropper.cropImage(
          sourcePath: path,
          aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
          compressQuality: 100,
          maxHeight: 700,
          maxWidth: 700,
          compressFormat: ImageCompressFormat.jpg,
          androidUiSettings: AndroidUiSettings(
              toolbarColor: Colors.white,
              toolbarTitle: Strings.cropImage,
              statusBarColor: Colors.grey[700],
              backgroundColor: Colors.white));
      try {
        List<int> croppedImageData = await _cropped!.readAsBytes();
        var decodedCroppedImage = img.decodeImage(croppedImageData);
        var compressedImage = img.copyResize(
          decodedCroppedImage!,
          width: 200,
          height: 200,
        );
        List<int> compressedImageData = img.encodeJpg(compressedImage);
        var compressedImageSize = compressedImage.length;
        if (compressedImageSize > AtClientPreference().maxDataSize) {
          showAlertDialog(context, 'Image exceeds the maximum limit of 512KB');
          print('Image exceeds the maximum limit of 512KB');
          return null;
        } else {
          return Uint8List.fromList(compressedImageData);
        }
      } catch (ex) {
        print('${ex.toString()}');
        return null;
      }
    } on Exception catch (ex) {
      print('${ex.toString()}');
      return null;
    }
  }
}
