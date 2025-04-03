import 'context_data_provider.dart';
import 'client.dart';
import 'json/context_data.dart';

class DefaultContextDataProvider implements ContextDataProvider {
  DefaultContextDataProvider(this.client_);

  @override
  Future<ContextData?> getContextData() {
    return client_.getContextData();
  }

  final Client client_;
}
