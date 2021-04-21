import 'package:at_contacts_group_flutter/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class CustomToast {
  CustomToast._();
  static CustomToast _instance = CustomToast._();
  factory CustomToast() => _instance;

  show(String text, BuildContext context,
      {Color bgColor, Color textColor, int duration = 3, int gravity = 0}) {
    Fluttertoast.showToast(
        msg: text,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: bgColor ?? AllColors().ORANGE,
        textColor: textColor ?? Colors.white,
        fontSize: 16.0);
  }
}
