import 'dart:convert';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:at_commons/at_commons.dart';
import 'package:at_contact/at_contact.dart';
import 'package:at_location_flutter/common_components/custom_toast.dart';
import 'package:at_location_flutter/common_components/location_prompt_dialog.dart';
import 'package:at_location_flutter/location_modal/location_notification.dart';
import 'package:at_location_flutter/service/key_stream_service.dart';
import 'package:at_location_flutter/utils/constants/constants.dart';
import 'package:at_location_flutter/utils/constants/init_location_service.dart';
import 'at_location_notification_listener.dart';
import 'package:at_client/src/service/notification_service.dart';

class SharingLocationService {
  static final SharingLocationService _singleton =
      SharingLocationService._internal();
  SharingLocationService._internal();

  factory SharingLocationService() {
    return _singleton;
  }

  List checkForAlreadyExisting(String? atsign) {
    var index = KeyStreamService().allLocationNotifications.indexWhere((e) =>
        ((e.locationNotificationModel!.receiver == atsign) &&
            (e.locationNotificationModel!.key!
                .contains(MixedConstants.SHARE_LOCATION))));
    if (index > -1) {
      return [
        true,
        KeyStreamService()
            .allLocationNotifications[index]
            .locationNotificationModel
      ];
    } else {
      return [false];
    }
  }

  bool checkIfEventIsRejected(
      LocationNotificationModel locationNotificationModel) {
    if ((!locationNotificationModel.isAccepted) &&
        (locationNotificationModel.isExited)) {
      return true;
    }

    return false;
  }

  Future<void> sendShareLocationToGroup(List<AtContact> selectedContacts,
      {int? minutes}) async {
    await Future.forEach(selectedContacts, (AtContact selectedContact) async {
      var _state = await sendShareLocationEvent(selectedContact.atSign!, false,
          minutes: minutes);
      if (_state == true) {
        CustomToast().show(
            'Share Location Request sent to ${selectedContact.atSign!}',
            AtLocationNotificationListener().navKey.currentContext!,
            isSuccess: true);
      } else if (_state == false) {
        CustomToast().show(
            'Something went wrong for ${selectedContact.atSign!}',
            AtLocationNotificationListener().navKey.currentContext!,
            isError: true);
      }
    });
  }

  /// Sends a 'sharelocation' key to [atsign] with duration of [minutes] minute
  Future<bool?> sendShareLocationEvent(String? atsign, bool isAcknowledgment,
      {int? minutes}) async {
    try {
      var alreadyExists = checkForAlreadyExisting(atsign);

      if (alreadyExists[0]) {
        var newLocationNotificationModel = LocationNotificationModel.fromJson(
            jsonDecode(
                LocationNotificationModel.convertLocationNotificationToJson(
                    alreadyExists[1])));

        var isRejected = checkIfEventIsRejected(newLocationNotificationModel);

        if (minutes != null) {
          newLocationNotificationModel.to =
              DateTime.now().add(Duration(minutes: minutes));
        } else {
          newLocationNotificationModel.to = null;
        }

        if (isRejected) {
          newLocationNotificationModel.rePrompt = true;
        }

        var msg = isRejected
            ? 'Your share location request has been rejected by $atsign. Would you like to prompt them again & update your request ?'
            : 'You already are sharing your location with $atsign. Would you like to update it ?';

        await locationPromptDialog(
            text: msg,
            locationNotificationModel: newLocationNotificationModel,
            isShareLocationData: true,
            isRequestLocationData: false,
            yesText: isRejected ? 'Yes! Re-Prompt' : 'Yes! Update',
            noText: 'No');
        return null;
      }

      AtKey atKey, atKeyForPut;
      var _microsecondsSinceEpoch = DateTime.now().microsecondsSinceEpoch;

      if (minutes != null) {
        atKey = newAtKey(
            (minutes * 60000), 'sharelocation-$_microsecondsSinceEpoch', atsign,
            ttl: (minutes * 60000),
            expiresAt: DateTime.now().add(Duration(minutes: minutes)));
        atKeyForPut = newAtKey(
            (minutes * 60000), 'sharelocation-$_microsecondsSinceEpoch', null,
            ttl: (minutes * 60000),
            expiresAt: DateTime.now().add(Duration(minutes: minutes)));
      } else {
        atKey = newAtKey(
          60000,
          'sharelocation-$_microsecondsSinceEpoch',
          atsign,
        );
        atKeyForPut = newAtKey(
          60000,
          'sharelocation-$_microsecondsSinceEpoch',
          null,
        );
      }

      var locationNotificationModel = LocationNotificationModel()
        ..atsignCreator = AtLocationNotificationListener().currentAtSign
        ..key = atKey.key
        ..lat = 12
        ..long = 12
        ..receiver = atsign
        ..from = DateTime.now()
        ..isAcknowledgment = isAcknowledgment;

      if ((minutes != null)) {
        locationNotificationModel.to =
            DateTime.now().add(Duration(minutes: minutes));
      }

      var result = await AtClientManager.getInstance()
          .notificationService
          .notify(
            NotificationParams.forUpdate(
              atKey,
              value:
                  LocationNotificationModel.convertLocationNotificationToJson(
                      locationNotificationModel),
            ),
          );

      if (result.notificationStatusEnum == NotificationStatusEnum.delivered) {
        await AtLocationNotificationListener().atClientInstance!.put(
              atKeyForPut,
              LocationNotificationModel.convertLocationNotificationToJson(
                  locationNotificationModel),
            );
      }

      print(
          'atClientException: ${result.atClientException}, sendLocationNotification:$result');

      if (result.notificationStatusEnum == NotificationStatusEnum.delivered) {
        await KeyStreamService().addDataToList(locationNotificationModel);
      }
      return (result.notificationStatusEnum ==
          NotificationStatusEnum.delivered);
    } catch (e) {
      print('sending share location failed $e');
      return false;
    }
  }

  /// Sends a 'sharelocationacknowledged' key to [originalLocationNotificationModel].atsignCreator with isAccepted as [isAccepted]
  Future<bool> shareLocationAcknowledgment(
      LocationNotificationModel originalLocationNotificationModel,
      bool isAccepted) async {
    try {
      var locationNotificationModel = LocationNotificationModel.fromJson(
          jsonDecode(
              LocationNotificationModel.convertLocationNotificationToJson(
                  originalLocationNotificationModel)));
      var atkeyMicrosecondId = locationNotificationModel.key!
          .split('sharelocation-')[1]
          .split('@')[0];
      var atKey = newAtKey(-1, 'sharelocationacknowledged-$atkeyMicrosecondId',
          locationNotificationModel.atsignCreator);
      var atKeyForPut =
          newAtKey(-1, 'sharelocationacknowledged-$atkeyMicrosecondId', null);

      locationNotificationModel.isAccepted = isAccepted;
      locationNotificationModel.isExited = !isAccepted;

      var result = await AtClientManager.getInstance()
          .notificationService
          .notify(
            NotificationParams.forUpdate(
              atKey,
              value:
                  LocationNotificationModel.convertLocationNotificationToJson(
                      locationNotificationModel),
            ),
          );

      if (result.notificationStatusEnum == NotificationStatusEnum.delivered) {
        await AtLocationNotificationListener().atClientInstance!.put(
              atKeyForPut,
              LocationNotificationModel.convertLocationNotificationToJson(
                  locationNotificationModel),
            );
      }

      print(
          'sendLocationNotificationAcknowledgment:$result, atClientException: ${result.atClientException}');
      if (result.notificationStatusEnum == NotificationStatusEnum.delivered) {
        CustomToast().show('Request to update data is submitted',
            AtLocationNotificationListener().navKey.currentContext,
            isSuccess: true);
        KeyStreamService().updatePendingStatus(locationNotificationModel);
      } else {
        CustomToast().show('Something went wrong , please try again.',
            AtLocationNotificationListener().navKey.currentContext,
            isError: true);
      }
      return (result.notificationStatusEnum ==
          NotificationStatusEnum.delivered);
    } catch (e) {
      CustomToast().show('Something went wrong , please try again.',
          AtLocationNotificationListener().navKey.currentContext,
          isError: true);

      print('sending share awk failed $e');
      return false;
    }
  }

  int val = 0;

  /// Updates originally created [locationNotificationModel] with [originalLocationNotificationModel] data
  Future<bool> updateWithShareLocationAcknowledge(
      LocationNotificationModel originalLocationNotificationModel,
      {bool? isSharing,
      bool rePrompt = false}) async {
    try {
      print('updateWithShareLocationAcknowledge called $val');
      val = val + 1;
      var locationNotificationModel = LocationNotificationModel.fromJson(
          jsonDecode(
              LocationNotificationModel.convertLocationNotificationToJson(
                  originalLocationNotificationModel)));

      var atkeyMicrosecondId = locationNotificationModel.key!
          .split('sharelocation-')[1]
          .split('@')[0];

      print('atkeyMicrosecondId $atkeyMicrosecondId');

      var response2 =
          await AtLocationNotificationListener().atClientInstance!.getKeys(
                regex: 'sharelocation',
              );

      response2.forEach((element) {
        print('response2: $element');
      });

      var response =
          await AtLocationNotificationListener().atClientInstance!.getKeys(
                regex: 'sharelocation-$atkeyMicrosecondId',
              );

      response.forEach((element) {
        print('response: $element');
      });

      var key = getAtKey(response[0]);

      locationNotificationModel.isAcknowledgment = true;
      locationNotificationModel.rePrompt =
          rePrompt; // Dont show dialog box again

      if (isSharing != null) locationNotificationModel.isSharing = isSharing;

      var notification =
          LocationNotificationModel.convertLocationNotificationToJson(
              locationNotificationModel);

      if ((locationNotificationModel.from != null) &&
          (locationNotificationModel.to != null)) {
        key.metadata!.ttl = locationNotificationModel.to!
                .difference(locationNotificationModel.from!)
                .inMinutes *
            60000;
        key.metadata!.ttr = locationNotificationModel.to!
                .difference(locationNotificationModel.from!)
                .inMinutes *
            60000;
        key.metadata!.expiresAt = locationNotificationModel.to;
      }

      if (locationNotificationModel.atsignCreator!.contains('@')) {
        key.sharedBy = locationNotificationModel.atsignCreator;
      } else {
        key.sharedBy = '@' + locationNotificationModel.atsignCreator!;
      }

      if (locationNotificationModel.receiver!.contains('@')) {
        key.sharedWith = locationNotificationModel.receiver;
      } else {
        key.sharedWith = '@' + locationNotificationModel.receiver!;
      }

      // key.sharedWith = locationNotificationModel.receiver;
      // !.replaceAll('@', '');

      print('key.sharedWith ${key.sharedWith}');
      print('key ${key}');

      var result =
          await AtClientManager.getInstance().notificationService.notify(
                NotificationParams.forUpdate(
                  key,
                  value: notification,
                ),
              );

      if (result.notificationStatusEnum == NotificationStatusEnum.delivered) {
        key.sharedWith = null;
        await AtLocationNotificationListener().atClientInstance!.put(
              key,
              notification,
            );
      }

      if (result.notificationStatusEnum == NotificationStatusEnum.delivered) {
        KeyStreamService()
            .mapUpdatedLocationDataToWidget(locationNotificationModel);
      }

      print('update result - $result ${result.atClientException}');
      return (result.notificationStatusEnum ==
          NotificationStatusEnum.delivered);
    } catch (e) {
      print('update share location failed $e');

      return false;
    }
  }

  Future removePerson(
      LocationNotificationModel locationNotificationModel) async {
    var result;
    if (locationNotificationModel.atsignCreator ==
        AtLocationNotificationListener().currentAtSign) {
      locationNotificationModel.isAccepted = false;
      locationNotificationModel.isExited = true;
      result =
          await updateWithShareLocationAcknowledge(locationNotificationModel);
    } else {
      result =
          await shareLocationAcknowledgment(locationNotificationModel, false);
    }
    return result;
  }

  /// Deletes originally created [locationNotificationModel] notification
  Future<bool> deleteKey(
      LocationNotificationModel locationNotificationModel) async {
    try {
      var atkeyMicrosecondId = locationNotificationModel.key!
          .split('sharelocation-')[1]
          .split('@')[0];

      var response =
          await AtLocationNotificationListener().atClientInstance!.getKeys(
                regex: 'sharelocation-$atkeyMicrosecondId',
              );

      var key = getAtKey(response[0]);

      locationNotificationModel.isAcknowledgment = true;

      var result =
          await AtLocationNotificationListener().atClientInstance!.delete(
                key,
              );
      if (result) {
        KeyStreamService().removeData(key.key);
      }
      return result;
    } catch (e) {
      print('error in deleting key $e');
      return false;
    }
  }

  Future<void> deleteAllKey() async {
    var response =
        await AtLocationNotificationListener().atClientInstance!.getKeys(
              regex: '',
            );
    await Future.forEach(response, (dynamic key) async {
      if (!'@$key'.contains('cached')) {
        // the keys i have created
        var atKey = getAtKey(key);
        var result =
            await AtLocationNotificationListener().atClientInstance!.delete(
                  atKey,
                );
        print('$key is deleted ? $result');
      }
    });
  }

  AtKey newAtKey(int ttr, String key, String? sharedWith,
      {int? ttl, DateTime? expiresAt}) {
    var atKey = AtKey()
      ..metadata = Metadata()
      ..metadata!.ttr = ttr
      ..metadata!.ccd = true
      ..key = key
      ..sharedWith = sharedWith
      ..sharedBy = AtLocationNotificationListener().currentAtSign;
    if (ttl != null) atKey.metadata!.ttl = ttl;
    if (expiresAt != null) atKey.metadata!.expiresAt = expiresAt;
    return atKey;
  }
}
