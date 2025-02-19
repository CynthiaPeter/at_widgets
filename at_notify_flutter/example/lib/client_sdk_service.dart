import 'dart:async';
import 'dart:io';
import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:flutter_keychain/flutter_keychain.dart';
import 'constants.dart';

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
    Directory? downloadDirectory;
    if (Platform.isIOS) {
      downloadDirectory =
          await path_provider.getApplicationDocumentsDirectory();
    } else {
      downloadDirectory = await path_provider.getExternalStorageDirectory();
    }

    final appSupportDirectory =
        await path_provider.getApplicationSupportDirectory();
    var path = appSupportDirectory.path;
    atClientPreference = AtClientPreference();

    atClientPreference.isLocalStoreRequired = true;
    atClientPreference.commitLogPath = path;
    atClientPreference.syncStrategy = SyncStrategy.IMMEDIATE;
    atClientPreference.rootDomain = MixedConstants.ROOT_DOMAIN;
    atClientPreference.hiveStoragePath = path;
    atClientPreference.downloadPath = downloadDirectory!.path;
    atClientPreference.namespace = MixedConstants.nameSpace;

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

  deleteKey() async {
    FlutterKeychain.remove(key: '@atsign');
    print('after delete');
  }
}
