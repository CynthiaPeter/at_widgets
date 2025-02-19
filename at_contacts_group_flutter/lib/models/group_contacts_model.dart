import 'dart:convert';

// ignore: import_of_legacy_library_into_null_safe
import 'package:at_contact/at_contact.dart';

/// Model to contain group details with associated contact
class GroupContactsModel {
  final AtContact? contact;
  final AtGroup? group;

  final ContactsType? contactType;
  GroupContactsModel({
    this.contact,
    this.group,
    this.contactType,
  });

  GroupContactsModel copyWith({
    AtContact? contact,
    AtGroup? group,
    ContactsType? contactType,
  }) {
    return GroupContactsModel(
      contact: contact ?? this.contact,
      group: group ?? this.group,
      contactType: contactType ?? this.contactType,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'contact': contact?.toJson(),
      'group': group?.toJson(),
      'contactType': contactType,
    };
  }

  factory GroupContactsModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) return GroupContactsModel();

    return GroupContactsModel(
      contact: AtContact.fromJson(map['contact']),
      group: AtGroup.fromJson(map['group']),
      contactType: map['contactType'],
    );
  }

  String toJson() => json.encode(toMap());

  factory GroupContactsModel.fromJson(String source) =>
      GroupContactsModel.fromMap(json.decode(source));

  @override
  String toString() =>
      'GroupContactsModel(contact: $contact, group: $group, contactType: $contactType)';

  @override
  bool operator ==(Object o) {
    if (identical(this, o)) return true;

    return o is GroupContactsModel &&
        o.contact == contact &&
        o.group == group &&
        o.contactType == contactType;
  }

  @override
  int get hashCode => contact.hashCode ^ group.hashCode ^ contactType.hashCode;
}

/// Enum for contact types
enum ContactsType { CONTACT, GROUP }
enum ContactTabs { RECENT, FAVS, ALL }
