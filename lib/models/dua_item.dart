import 'package:flutter/material.dart';

class DuaItem {
  const DuaItem({
    required this.id,
    required this.title,
    required this.category,
    required this.icon,
    required this.arabic,
    required this.transliteration,
    required this.translation,
    required this.reference,
  });

  final String id;
  final String title;
  final String category;
  final IconData icon;
  final String arabic;
  final String transliteration;
  final String translation;
  final String reference;
}
