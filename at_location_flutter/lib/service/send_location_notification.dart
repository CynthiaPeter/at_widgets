import 'dart:async';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:at_commons/at_commons.dart';
import 'package:at_location_flutter/location_modal/location_notification.dart';
import 'package:at_location_flutter/service/my_location.dart';
import 'package:at_location_flutter/utils/constants/init_location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong/latlong.dart';

import 'key_stream_service.dart';

class SendLocationNotification {
  SendLocationNotification._();
  static SendLocationNotification _instance = SendLocationNotification._();
  factory SendLocationNotification() => _instance;
  Timer timer;
  final String locationKey = 'locationnotify';
  List<LocationNotificationModel> atsignsToShareLocationWith = [];
  StreamSubscription<Position> positionStream;

  AtClientImpl atClient;

  init(AtClientImpl newAtClient) {
    if ((timer != null) && (timer.isActive)) timer.cancel();
    atClient = newAtClient;
    atsignsToShareLocationWith = [];
    print(
        'atsignsToShareLocationWith length - ${atsignsToShareLocationWith.length}');
    if (positionStream != null) positionStream.cancel();
    findAtSignsToShareLocationWith();
  }

  findAtSignsToShareLocationWith() {
    atsignsToShareLocationWith = [];
    KeyStreamService().allLocationNotifications.forEach((notification) {
      if ((notification.locationNotificationModel.atsignCreator ==
              atClient.currentAtSign) &&
          (notification.locationNotificationModel.isSharing) &&
          (notification.locationNotificationModel.isAccepted) &&
          (!notification.locationNotificationModel.isExited)) {
        atsignsToShareLocationWith.add(notification.locationNotificationModel);
      }
    });

    sendLocation();
  }

  addMember(LocationNotificationModel notification) async {
    if (atsignsToShareLocationWith
            .indexWhere((element) => element.key == notification.key) >
        -1) {
      return;
    }

    LatLng myLocation = await getMyLocation();
    prepareLocationDataAndSend(notification, myLocation);

    // add
    atsignsToShareLocationWith.add(notification);
    print(
        'after adding atsignsToShareLocationWith length ${atsignsToShareLocationWith.length}');
  }

  removeMember(String key) async {
    LocationNotificationModel locationNotificationModel;
    atsignsToShareLocationWith.removeWhere((element) {
      if (key.contains(element.key)) locationNotificationModel = element;
      return key.contains(element.key);
    });
    if (locationNotificationModel != null) sendNull(locationNotificationModel);

    print(
        'after deleting atsignsToShareLocationWith length ${atsignsToShareLocationWith.length}');
  }

  sendLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (((permission == LocationPermission.always) ||
        (permission == LocationPermission.whileInUse))) {
      positionStream = Geolocator.getPositionStream(distanceFilter: 100)
          .listen((myLocation) async {
        atsignsToShareLocationWith.forEach((notification) async {
          prepareLocationDataAndSend(
              notification, LatLng(myLocation.latitude, myLocation.longitude));
        });
      });
    }
  }

  prepareLocationDataAndSend(
      LocationNotificationModel notification, LatLng myLocation) async {
    bool isSend = false;

    if (notification.to == null) {
      isSend = true;
    } else if ((DateTime.now().difference(notification.from) >
            Duration(seconds: 0)) &&
        (notification.to.difference(DateTime.now()) > Duration(seconds: 0))) {
      isSend = true;
    }
    if (isSend) {
      String atkeyMicrosecondId = notification.key.split('-')[1].split('@')[0];
      AtKey atKey = newAtKey(
          5000, "locationnotify-$atkeyMicrosecondId", notification.receiver,
          ttl: (notification.to != null)
              ? notification.to.difference(DateTime.now()).inMilliseconds
              : null);

      LocationNotificationModel newLocationNotificationModel =
          LocationNotificationModel()
            ..atsignCreator = notification.atsignCreator
            ..receiver = notification.receiver
            ..isAccepted = notification.isAccepted
            ..isAcknowledgment = notification.isAcknowledgment
            ..isExited = notification.isExited
            ..isRequest = notification.isRequest
            ..isSharing = notification.isSharing
            ..from = DateTime.now()
            ..to = notification.to != null ? notification.to : null
            ..lat = myLocation.latitude
            ..long = myLocation.longitude
            ..key = "locationnotify-$atkeyMicrosecondId";
      try {
        await atClient.put(
            atKey,
            LocationNotificationModel.convertLocationNotificationToJson(
                newLocationNotificationModel));
      } catch (e) {
        print('error in sending location: $e');
      }
    }
  }

  sendNull(LocationNotificationModel locationNotificationModel) async {
    String atkeyMicrosecondId =
        locationNotificationModel.key.split('-')[1].split('@')[0];
    AtKey atKey = newAtKey(-1, "locationnotify-$atkeyMicrosecondId",
        locationNotificationModel.receiver);
    var result = await atClient.delete(atKey);
    print('$atKey delete operation $result');
    return result;
  }

  deleteAllLocationKey() async {
    List<String> response = await atClient.getKeys(
      regex: '$locationKey',
    );
    response.forEach((key) async {
      if (!'@$key'.contains('cached')) {
        // the keys i have created
        AtKey atKey = getAtKey(key);
        var result = await atClient.delete(atKey);
        print('$key is deleted ? $result');
      }
    });
  }

  AtKey newAtKey(int ttr, String key, String sharedWith, {int ttl}) {
    AtKey atKey = AtKey()
      ..metadata = Metadata()
      ..metadata.ttr = ttr
      ..metadata.ccd = true
      ..key = key
      ..sharedWith = sharedWith
      ..sharedBy = atClient.currentAtSign;
    if (ttl != null) atKey.metadata.ttl = ttl;
    return atKey;
  }
}