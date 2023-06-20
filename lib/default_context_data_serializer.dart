import 'dart:convert';

import 'package:flutter/cupertino.dart';

import 'context_data_deserializer.dart';
import 'json/context_data.dart';

import 'package:mockito/annotations.dart';
@GenerateNiceMocks([MockSpec<DefaultContextDataDeserializer>()])

 class DefaultContextDataDeserializer implements ContextDataDeserializer {

   @override
  ContextData? deserialize(final List<int> bytes, final int offset, final int length) {
     try {
       var data = utf8.decode(bytes);
       var contextData = ContextData.fromMap(jsonDecode(data));
       debugPrint("context data : ${contextData}");
       return contextData;
     } catch (e) {
       print("error is ${e.toString()}");
       return null;
     }
   }

 }