/// A service to handle save and retrieve operation on notify

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:at_client/at_client.dart';
import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:at_commons/at_commons.dart';
import 'package:at_notify_flutter/models/notify_model.dart';
import 'package:at_notify_flutter/utils/notify_utils.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ignore: implementation_imports
import 'package:at_client/src/service/notification_service.dart';

class NotifyService {
  NotifyService._();

  static final NotifyService _instance = NotifyService._();

  factory NotifyService() => _instance;

  late FlutterLocalNotificationsPlugin _notificationsPlugin;
  late InitializationSettings initializationSettings;

  final String storageKey = 'notify.';
  final String notifyKey = 'notifyKey';

  String sendToAtSign = '';

  late AtClientManager atClientManager;
  late AtClient atClient;

  String? rootDomain;
  int? rootPort;
  String? currentAtSign;

  List<Notify> notifies = [];
  List<dynamic>? notifiesJson = [];

  StreamController<List<Notify>> notifyStreamController =
      StreamController<List<Notify>>.broadcast();

  Sink get notifySink => notifyStreamController.sink;

  Stream<List<Notify>> get notifyStream => notifyStreamController.stream;

  void disposeControllers() {
    notifyStreamController.close();
  }

  void initNotifyService(
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
        currentAtSignFromApp, atClientPreference.namespace, atClientPreference);
    atClient = atClientManager.atClient;
    _notificationsPlugin = FlutterLocalNotificationsPlugin();

    atClientManager.notificationService
        .subscribe(regex: '.${atClientPreference.namespace}')
        .listen((notification) {
      _notificationCallback(notification);
    });

    if (Platform.isIOS) {
      _requestIOSPermission();
    }
    await initializePlatformSpecifics();
  }

  /// Initialized Notification Settings
  initializePlatformSpecifics() async {
    var initializationSettingsAndroid =
        AndroidInitializationSettings('ic_launcher');
    var initializationSettingsIOS = IOSInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: false,
      onDidReceiveLocalNotification: (id, title, body, payload) async {
        var receivedNotification = ReceivedNotification(
          id: id,
          title: title!,
          body: body!,
          payload: payload!,
        );
        print('receivedNotification: ${receivedNotification?.toString()}');
        //     didReceivedLocalNotificationSubject.add(receivedNotification);
      },
    );
    initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid, iOS: initializationSettingsIOS);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onSelectNotification: (payload) async {},
    );
  }

  /// Request Alert, Badge, Sound Permission for IOS
  _requestIOSPermission() {
    _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()!
        .requestPermissions(
          alert: false,
          badge: true,
          sound: true,
        );
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
      print('notify message => $message $fromAtsign');
      if (message.isNotEmpty && message != 'null') {
        var decryptedMessage = await atClient.encryptionService!
            .decrypt(message, fromAtsign)
            .catchError((e) {
          //   print('error in decrypting notify $e');
        });
        print('notify decryptedMessage => $decryptedMessage $fromAtsign');
        await showNotification(decryptedMessage);
      }
    }
  }

  /// Get Notify List From AtClient
  Future<void> getNotifies({String? atsign}) async {
    try {
      notifies = [];
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
        notifiesJson = json.decode((keyValue.value) as String) as List?;
        notifiesJson!.forEach((value) {
          var notify = Notify.fromJson((value));
          notifies.insert(0, notify);
        });
        notifySink.add(notifies);
      } else {
        notifiesJson = [];
        notifySink.add(notifies);
      }
    } catch (error) {
      print('Error in getting bug Report -> $error');
    }
  }

  void setSendToAtSign(String? sendToAtSign) {
    if (sendToAtSign != null && sendToAtSign[0] != '@') {
      sendToAtSign = '@' + sendToAtSign;
    }
    this.sendToAtSign = sendToAtSign!;
  }

  /// Create new notify to AtClient
  Future<bool> addNotify(Notify notify, {NotifyEnum? notifyType}) async {
    var metadata = Metadata();
    metadata.ttr = -1;
    var key = AtKey()
      ..key = storageKey + (currentAtSign ?? ' ').substring(1)
      ..sharedBy = currentAtSign
      ..sharedWith = sendToAtSign
      ..metadata = metadata;
    try {
      notifies.insert(0, notify);
      notifySink.add(notifies);
      notifiesJson!.add(notify.toJson());
      await atClient.put(key, json.encode(notifiesJson));
    } catch (e) {
      print('Error in setting notify => $e');
    }
    await sendNotify(key, notify, notifyType ?? NotifyEnum.notifyForUpdate);
    return true;
  }

  /// Call Notify in NotificationService
  Future<bool> sendNotify(
    AtKey key,
    Notify notify,
    NotifyEnum notifyType,
  ) async {
    var notificationResponse;
    if (notifyType == NotifyEnum.notifyForDelete) {
      notificationResponse = await atClientManager.notificationService.notify(
        NotificationParams.forDelete(key),
      );
    } else if (notifyType == NotifyEnum.notifyText) {
      notificationResponse = await atClientManager.notificationService.notify(
          NotificationParams.forText(notify.message ?? '', sendToAtSign));
    } else {
      notificationResponse = await atClientManager.notificationService.notify(
        NotificationParams.forUpdate(key, value: notify.toJson()),
        // onSuccess: _onSuccessCallback,
        // onError: _onErrorCallback,
      );
    }

    if (notificationResponse.notificationStatusEnum ==
        NotificationStatusEnum.delivered) {
      print(notificationResponse.toString());
    } else {
      print(notificationResponse.atClientException.toString());
      return false;
    }
    return true;
  }

  void _onSuccessCallback(notificationResult) {
    print(notificationResult);
  }

  void _onErrorCallback(notificationResult) {
    print(notificationResult.atClientException.toString());
  }

  /// Show Local Notification in Device
  Future<void> showNotification(String decryptedMessage) async {
    List<dynamic>? valuesJson = [];
    Notify notify = Notify.fromJson((decryptedMessage));
    print('showNotification => ${notify.message} ${notify.atSign}');

    var androidChannelSpecifics = AndroidNotificationDetails(
      'notify_id',
      'notify',
      "notify_description",
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      timeoutAfter: 50000,
      styleInformation: DefaultStyleInformation(true, true),
    );
    var iosChannelSpecifics = IOSNotificationDetails();

    var platformChannelSpecifics = NotificationDetails(
        android: androidChannelSpecifics, iOS: iosChannelSpecifics);
    await _notificationsPlugin.show(
      0,
      '${notify.atSign}',
      '${notify.message}',
      platformChannelSpecifics,
      payload: notify.toJson(),
    );
  }

  /// Cancel All notification
  void cancelNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}

class ReceivedNotification {
  final int id;
  final String title;
  final String body;
  final String payload;

  ReceivedNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
  });
}
