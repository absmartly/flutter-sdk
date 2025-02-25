import 'dart:ui';

class Attribute {
  late String name;
  late dynamic value;
  late int setAt;

  Attribute({required this.name, required this.value, required this.setAt});

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        other is Attribute &&
            setAt == other.setAt &&
            name == other.name &&
            value == other.value;
  }

  @override
  int get hashCode => Object.hash(name, value, setAt);

  @override
  String toString() {
    return 'Attribute{name: $name, value: $value, setAt: $setAt}';
  }

  Attribute.fromMap(Map<String, dynamic> data){
    name = data["name"];
    value = data["value"];
    setAt = data["setAt"];
  }
  Map<String, dynamic> toMap(){
    return{
      "name" : name,
      "value" : value,
      "setAt" : setAt,
    };
  }

}
