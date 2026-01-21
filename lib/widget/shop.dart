import 'dart:convert';
import 'package:flutter/material.dart';
import 'color_theme.dart';

Widget buildHallCard(Map<String, dynamic> hall) {
  return Container(
    padding: const EdgeInsets.all(16),
    height: 95,
    decoration: BoxDecoration(
      color: royal,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: royal, width: 1.5),
      boxShadow: [
        BoxShadow(
          color: royal.withValues(alpha: 0.15),
          blurRadius: 6,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Row(
      children: [
        ClipOval(child: _shopLogo(hall['logo'])),
        const SizedBox(width: 12),
        Expanded(child: _shopName(hall['name'])),
      ],
    ),
  );
}

Widget _shopLogo(String? logo) {
  if (logo == null || logo.isEmpty) {
    return _defaultLogo();
  }

  try {
    return Image.memory(
      base64Decode(logo),
      width: 70,
      height: 70,
      fit: BoxFit.cover,
    );
  } catch (_) {
    return _defaultLogo();
  }
}

Widget _defaultLogo() {
  return Container(
    width: 70,
    height: 70,
    color: Colors.white,
    child: Icon(
      Icons.business_rounded,
      color: royal,
      size: 35,
    ),
  );
}

Widget _shopName(String? name) {
  return Center(
    child: Text(
      name?.toUpperCase() ?? 'SHOP NAME',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
      ),
    ),
  );
}
