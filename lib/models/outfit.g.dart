// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'outfit.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OutfitAdapter extends TypeAdapter<Outfit> {
  @override
  final int typeId = 1;

  @override
  Outfit read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Outfit(
      id: fields[0] as String?,
      name: fields[1] as String,
      clothes: (fields[3] as Map).cast<String, String?>(),
      accessories: (fields[4] as List).cast<dynamic>(),
      date: fields[2] as DateTime,
      colorPaletteStrings: (fields[6] as List?)?.cast<String>(),
    )..colorCodes = (fields[5] as List).cast<int>();
  }

  @override
  void write(BinaryWriter writer, Outfit obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.clothes)
      ..writeByte(4)
      ..write(obj.accessories)
      ..writeByte(5)
      ..write(obj.colorCodes)
      ..writeByte(6)
      ..write(obj.colorPaletteStrings);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OutfitAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
