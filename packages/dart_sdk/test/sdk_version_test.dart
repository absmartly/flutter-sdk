import 'dart:io';

import 'package:absmartly_dart/src/client.dart';
import 'package:absmartly_dart/src/client_config.dart';
import 'package:absmartly_dart/src/sdk_version.dart';
import 'package:test/test.dart';

import 'client_test.mocks.dart';

void main() {
  Client client({String? applicationVersion}) {
    final config = ClientConfig()
        .setEndpoint('https://example.com')
        .setAPIKey('key')
        .setApplication('website')
        .setEnvironment('dev');
    if (applicationVersion != null) {
      config.setApplicationVersion(applicationVersion);
    }
    return Client(config, MockHTTPClient());
  }

  test('SdkVersion.version matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version =
        RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec)!;
    expect(SdkVersion.version, version.group(1));
  });

  test('X-Agent is "<name>/<version>"', () {
    final c = client();
    expect(SdkVersion.agent, 'absmartly-dart-sdk/${SdkVersion.version}');
    expect(c.headers_['X-Agent'], SdkVersion.agent);
    expect(c.getAgent(), SdkVersion.agent);
    expect(c.getAgentName(), 'absmartly-dart-sdk');
    expect(c.getAgentVersion(), SdkVersion.version);
  });

  test('application version defaults to "0"', () {
    final c = client();
    expect(c.getApplicationVersion(), '0');
    expect(c.headers_['X-Application-Version'], '0');
  });

  test('whole-number application version is sent as the header', () {
    final c = client(applicationVersion: '1042');
    expect(c.getApplicationVersion(), '1042');
    expect(c.headers_['X-Application-Version'], '1042');
  });

  test('non-numeric application version is kept but sends header "0"', () {
    for (final version in ['2.4.1', 'v3', '-1', ' 12', '١٢', '']) {
      final c = client(applicationVersion: version);
      expect(c.getApplicationVersion(), version);
      expect(c.headers_['X-Application-Version'], '0', reason: version);
    }
  });

  test('application version over 18 digits sends header "0"', () {
    expect(
        client(applicationVersion: '1' * 18).headers_['X-Application-Version'],
        '1' * 18);
    expect(
        client(applicationVersion: '1' * 19).headers_['X-Application-Version'],
        '0');
  });

  test('applicationVersion is read from properties', () {
    final config = ClientConfig.createFromProperties(
        {'applicationVersion': '7', 'application': 'website'});
    expect(config.getApplicationVersion(), '7');
  });
}
