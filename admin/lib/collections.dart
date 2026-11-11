import 'package:flutter/material.dart';

enum FieldKind { text, number, boolFlag, day, period, file }

class FieldDef {
  const FieldDef({
    required this.key,
    required this.label,
    required this.kind,
    this.required = false,
    this.hint,
  });

  final String key;
  final String label;
  final FieldKind kind;
  final bool required;
  final String? hint;
}

class CollectionDef {
  const CollectionDef({
    required this.id,
    required this.title,
    required this.icon,
    required this.fields,
    this.sort = '-created',
    this.titleField,
  });

  final String id;
  final String title;
  final IconData icon;
  final List<FieldDef> fields;
  final String sort;
  final String? titleField;
}

const arabicDays = [
  'الاحد',
  'الاثنين',
  'الثلاثاء',
  'الاربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
];

const periodOptions = ['morning', 'evening', 'all'];

const collections = <CollectionDef>[
  CollectionDef(
    id: 'Schedules',
    title: 'الجداول',
    icon: Icons.calendar_month_rounded,
    sort: 'day,stage,start_time',
    titleField: 'subject',
    fields: [
      FieldDef(key: 'day', label: 'اليوم', kind: FieldKind.day, required: true),
      FieldDef(key: 'stage', label: 'المرحلة', kind: FieldKind.number, required: true, hint: '1–20'),
      FieldDef(key: 'section', label: 'الشعبة', kind: FieldKind.text, required: true, hint: 'A / B / مسائي'),
      FieldDef(key: 'subject', label: 'المادة', kind: FieldKind.text, required: true),
      FieldDef(key: 'hall', label: 'القاعة', kind: FieldKind.text, required: true),
      FieldDef(key: 'start_time', label: 'البداية', kind: FieldKind.text, required: true, hint: '8:00 AM'),
      FieldDef(key: 'end_time', label: 'النهاية', kind: FieldKind.text, required: true, hint: '9:30 AM'),
      FieldDef(key: 'is_exam', label: 'امتحان', kind: FieldKind.boolFlag),
    ],
  ),
  CollectionDef(
    id: 'Stages',
    title: 'المراحل',
    icon: Icons.layers_rounded,
    sort: 'display_order,number',
    titleField: 'title',
    fields: [
      FieldDef(key: 'number', label: 'الرقم', kind: FieldKind.number, required: true),
      FieldDef(key: 'title', label: 'العنوان', kind: FieldKind.text, hint: 'فارغ = المرحلةN'),
      FieldDef(key: 'display_order', label: 'الترتيب', kind: FieldKind.number),
    ],
  ),
  CollectionDef(
    id: 'Sections',
    title: 'الشعب',
    icon: Icons.view_column_rounded,
    sort: 'stage,display_order',
    titleField: 'label',
    fields: [
      FieldDef(key: 'stage', label: 'المرحلة', kind: FieldKind.number, required: true),
      FieldDef(key: 'key', label: 'المفتاح', kind: FieldKind.text, required: true, hint: 'A'),
      FieldDef(key: 'label', label: 'التسمية', kind: FieldKind.text, required: true),
      FieldDef(key: 'period', label: 'الفترة', kind: FieldKind.period, required: true),
      FieldDef(key: 'display_order', label: 'الترتيب', kind: FieldKind.number),
    ],
  ),
  CollectionDef(
    id: 'TickerBar',
    title: 'الشريط',
    icon: Icons.view_stream_rounded,
    titleField: 'text',
    fields: [
      FieldDef(key: 'text', label: 'النص', kind: FieldKind.text, required: true),
    ],
  ),
  CollectionDef(
    id: 'Professors',
    title: 'الأساتذة',
    icon: Icons.school_rounded,
    sort: 'display_order',
    titleField: 'name',
    fields: [
      FieldDef(key: 'name', label: 'الاسم', kind: FieldKind.text, required: true),
      FieldDef(key: 'role', label: 'المنصب', kind: FieldKind.text),
      FieldDef(key: 'bio', label: 'نبذة', kind: FieldKind.text),
      FieldDef(key: 'display_order', label: 'الترتيب', kind: FieldKind.number),
      FieldDef(key: 'image', label: 'الصورة', kind: FieldKind.file),
    ],
  ),
  CollectionDef(
    id: 'Notices',
    title: 'الإعلانات',
    icon: Icons.campaign_rounded,
    sort: 'display_order',
    titleField: 'text',
    fields: [
      FieldDef(key: 'text', label: 'النص', kind: FieldKind.text, required: true),
      FieldDef(key: 'duration', label: 'المدة (ث)', kind: FieldKind.number),
      FieldDef(key: 'display_order', label: 'الترتيب', kind: FieldKind.number),
      FieldDef(key: 'image', label: 'صورة', kind: FieldKind.file),
    ],
  ),
  CollectionDef(
    id: 'Media',
    title: 'الوسائط',
    icon: Icons.perm_media_rounded,
    sort: 'display_order',
    titleField: 'file',
    fields: [
      FieldDef(key: 'file', label: 'الملف', kind: FieldKind.file, required: true),
      FieldDef(key: 'duration', label: 'المدة (ث)', kind: FieldKind.number, hint: 'للصور'),
      FieldDef(key: 'main_only', label: 'الرئيسي فقط', kind: FieldKind.boolFlag),
      FieldDef(key: 'display_order', label: 'الترتيب', kind: FieldKind.number),
    ],
  ),
];
