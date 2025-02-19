import 'package:at_contacts_flutter/utils/colors.dart';
import 'package:at_contacts_flutter/utils/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:at_common_flutter/services/size_config.dart';

class ContactInitial extends StatelessWidget {
  /// Size of the circular profile placeholder
  final double size;
  final double? maxSize, minSize;

  /// Initials of the atsign
  final String initials;

  /// Index in the list of atsigns
  int? index;
  Key? key;

  ContactInitial(
      {this.size = 40,
      this.key,
      required this.initials,
      this.index,
      this.maxSize,
      this.minSize});
  @override
  Widget build(BuildContext context) {
    var encodedInitials = initials.runes;
    if (encodedInitials.length < 3) {
      index = encodedInitials.length;
    } else {
      index = 3;
    }

    return Container(
      height: size.toFont,
      width: size.toFont,
      constraints: BoxConstraints(
        minHeight: minSize ?? double.infinity,
        minWidth: minSize ?? double.infinity,
        maxHeight: maxSize ?? double.infinity,
        maxWidth: maxSize ?? double.infinity,
      ),
      decoration: BoxDecoration(
        color: ContactInitialsColors.getColor(initials),
        borderRadius: BorderRadius.circular((size.toFont)),
      ),
      child: Center(
        child: Text(
          String.fromCharCodes(encodedInitials, (index == 1) ? 0 : 1, index)
              .toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.toFont,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
