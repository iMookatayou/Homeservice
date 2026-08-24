import 'package:json_annotation/json_annotation.dart';

part 'medicine_item.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
class MedicineItem {
  final String id;
  final String name;

  /// เช่น tablet, syrup
  final String? form;

  /// เช่น tab, ml
  final String? unit;

  /// เช่น painkiller
  final String? category;

  /// คงเหลือรวมทั้งหมด (จาก ItemSummary.total_qty)
  final double stockQty;

  /// วันหมดอายุถัดไปของล็อตที่ใกล้ที่สุด (ItemSummary.next_expiry)
  final DateTime? nextExpiryDate;

  /// ชื่อที่เก็บ (อาจเป็น null; ฝั่ง backend ตอนนี้ส่งมาเฉพาะ location_id)
  final String? locationName;

  /// สถานะ (คำนวณ/แปลงจาก low_stock, expiring, next_expiry)
  final MedicineItemStatus? status;

  MedicineItem({
    required this.id,
    required this.name,
    this.form,
    this.unit,
    this.category,
    required this.stockQty,
    this.nextExpiryDate,
    this.locationName,
    this.status,
  });

  factory MedicineItem.fromJson(Map<String, dynamic> json) =>
      _$MedicineItemFromJson(json);
  Map<String, dynamic> toJson() => _$MedicineItemToJson(this);

  /// ✅ แปลงจาก DTO แบบ ItemSummary ของ backend
  factory MedicineItem.fromItemSummaryJson(Map<String, dynamic> json) {
    final item = (json['item'] as Map).cast<String, dynamic>();
    final next = json['next_expiry'] as String?;
    final nextDt = next == null ? null : DateTime.parse(next);

    final lowStock = json['low_stock'] == true;
    final expiring = json['expiring'] == true;
    final expired = nextDt != null && nextDt.isBefore(DateTime.now());

    return MedicineItem(
      id: item['id'] as String,
      name: item['name'] as String,
      form: item['form'] as String?,
      unit: item['unit'] as String?,
      category: item['category'] as String?,
      stockQty: (json['total_qty'] as num?)?.toDouble() ?? 0.0,
      nextExpiryDate: nextDt,
      // ถ้าอยากโชว์ชื่อที่เก็บ ต้องให้ backend join/เติม field เพิ่มเอง
      locationName: null,
      status: MedicineItemStatus(
        low: lowStock,
        expirySoon: expiring,
        expired: expired,
      ),
    );
  }
}

@JsonSerializable(fieldRename: FieldRename.snake)
class MedicineItemStatus {
  final bool low;
  final bool expirySoon;
  final bool expired;

  const MedicineItemStatus({
    required this.low,
    required this.expirySoon,
    required this.expired,
  });

  factory MedicineItemStatus.fromJson(Map<String, dynamic> json) =>
      _$MedicineItemStatusFromJson(json);
  Map<String, dynamic> toJson() => _$MedicineItemStatusToJson(this);
}
