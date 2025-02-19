import 'dart:async';
import 'dart:io';
import 'package:at_contacts_group_flutter_example/constants.dart';
import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:path_provider/path_provider.dart' as path_provider;

class ClientSdkService {
  static final ClientSdkService _singleton = ClientSdkService._internal();
  ClientSdkService._internal();

  factory ClientSdkService.getInstance() {
    return _singleton;
  }
  AtClientService? atClientServiceInstance;

  late AtClientPreference atClientPreference;
  String? _atsign;
  String? get currentAtsign => _atsign;
  set setAtsign(String atSign) {
    _atsign = atSign;
  }

  Future<bool> onboard({String? atsign}) async {
    atClientServiceInstance = AtClientService();

    final appSupportDirectory =
        await path_provider.getApplicationSupportDirectory();
    var path = appSupportDirectory.path;
    atClientPreference = AtClientPreference();

    atClientPreference.isLocalStoreRequired = true;
    atClientPreference.commitLogPath = path;
    atClientPreference.syncStrategy = SyncStrategy.IMMEDIATE;
    atClientPreference.rootDomain = MixedConstants.ROOT_DOMAIN;
    atClientPreference.hiveStoragePath = path;
    var result = await atClientServiceInstance!
        .onboard(atClientPreference: atClientPreference, atsign: atsign)
        .catchError((e) {
      print('Error in Onboarding: $e');
    });
    return result;
  }

  ///Fetches atsign from device keychain.
  Future<String?> getAtSign() async {
    return atClientServiceInstance!.atClientManager.atClient.getCurrentAtSign();
  }
}
