import 'default_context_publisher.dart';
import 'client.dart';

/// The 2.1 name of [DefaultContextPublisher], and the publisher
/// [ABSmartlyConfig] creates by default.
class DefaultContextEventHandler extends DefaultContextPublisher {
  DefaultContextEventHandler(Client client) : super(client);
}
