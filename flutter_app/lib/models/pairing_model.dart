/// Model untuk data pairing dari Firebase Realtime Database.
///
/// Membaca dari node `pairings/`.
class PairingModel {
  final String id;
  final String? senderId;
  final String? receiverId;
  final bool paired;
  final int? timestamp;
  final String? status;
  final String? senderBattery;
  final String? receiverBattery;
  final bool? senderOnline;
  final bool? receiverOnline;

  const PairingModel({
    required this.id,
    this.senderId,
    this.receiverId,
    this.paired = false,
    this.timestamp,
    this.status,
    this.senderBattery,
    this.receiverBattery,
    this.senderOnline,
    this.receiverOnline,
  });

  factory PairingModel.fromMap(Map<dynamic, dynamic> map,
      {required String id}) {
    return PairingModel(
      id: id,
      senderId: map['senderId']?.toString(),
      receiverId: map['receiverId']?.toString(),
      paired: map['paired'] == true || map['status'] == 'paired',
      timestamp: _parseInt(map['timestamp']),
      status: map['status']?.toString(),
      senderBattery: map['senderBattery']?.toString(),
      receiverBattery: map['receiverBattery']?.toString(),
      senderOnline: map['senderOnline'] == true,
      receiverOnline: map['receiverOnline'] == true,
    );
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString());
  }
}
