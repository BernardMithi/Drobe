// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lookbookItem.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LookbookItemAdapter extends TypeAdapter<LookbookItem> {
  @override
  final int typeId = 2;

  @override
  LookbookItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LookbookItem(
      id: fields[0] as String?,
      name: fields[1] as String,
      createdAt: fields[2] as DateTime,
      imageUrl: fields[3] as String?,
      tags: (fields[4] as List?)?.cast<String>(),
      notes: fields[5] as String?,
      source: fields[6] as String?,
      userId: fields[8] as String?,
    )..colorCodes = (fields[7] as List).cast<int>();
  }

  @override
  void write(BinaryWriter writer, LookbookItem obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.imageUrl)
      ..writeByte(4)
      ..write(obj.tags)
      ..writeByte(5)
      ..write(obj.notes)
      ..writeByte(6)
      ..write(obj.source)
      ..writeByte(7)
      ..write(obj.colorCodes)
      ..writeByte(8)
      ..write(obj.userId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LookbookItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
