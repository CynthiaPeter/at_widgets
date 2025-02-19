/// A customized circular avatar to display the profile picture with a small border
/// takes in @param [image] for the [asset image]
/// @param [size] to define the size of the avatar
/// @param [nonAsset] if the image is coming over the network
/// @param [byteImage] to display the image from the netwok

import 'dart:typed_data';
import 'package:flutter/material.dart';
// ignore: import_of_legacy_library_into_null_safe
import 'package:at_common_flutter/services/size_config.dart';

class CustomCircleAvatar extends StatelessWidget {
  /// Asset image path
  final String? image;

  /// Size of the avatar
  final double size;

  /// Boolean indicator if the image is not in assets
  final bool nonAsset;

  /// Image data
  final Uint8List? byteImage;

  const CustomCircleAvatar({
    Key? key,
    this.image,
    this.size = 50,
    this.nonAsset = false,
    this.byteImage,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(
      height: size.toFont,
      width: size.toFont,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size.toWidth),
      ),
      child: CircleAvatar(
        radius: (size - 5).toFont,
        backgroundColor: Colors.transparent,
        backgroundImage: nonAsset
            ? Image.memory(byteImage!).image
            : AssetImage(image!, package: 'at_contacts_flutter'),
      ),
    );
  }
}
