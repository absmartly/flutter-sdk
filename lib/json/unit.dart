import 'dart:ui';

class Unit {
  late String type;
  late String uid;

  Unit({required this.type, required this.uid});

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Unit && type == other.type && uid == other.uid;
  }

  @override
  int get hashCode => hashValues(type, uid);

  @override
  String toString() {
    return 'Unit{type: $type, uid: $uid}';
  }

  Unit.fromMap(Map<String, dynamic> data){
    type = data["type"];
    uid = data["uid"];
  }
  Map<String, dynamic> toMap(){
    return {
      "type" : type,
      "uid" : uid,
    };
  }
}
