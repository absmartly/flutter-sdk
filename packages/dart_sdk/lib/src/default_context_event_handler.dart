import 'default_context_publisher.dart';
import 'client.dart';

@Deprecated('Use DefaultContextPublisher instead.')
class DefaultContextEventHandler extends DefaultContextPublisher {
  DefaultContextEventHandler(Client client) : super(client);
}
