import 'dart:async';
import 'context_data_provider.dart';
import 'client.dart';
import 'json/context_data.dart';

class DefaultContextDataProvider implements ContextDataProvider {
  DefaultContextDataProvider(this.client_);

  @override
  Completer<ContextData> getContextData() {
    return client_.getContextData();
  }

  final Client client_;
}
