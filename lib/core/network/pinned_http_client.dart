import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint, kDebugMode;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// ISRG Root X1 — Let's Encrypt root CA used by Supabase (supabase.co).
/// Valid until 2035-06-04. Pin the root for stability across leaf rotations.
const _isrgRootX1Pem = '''
-----BEGIN CERTIFICATE-----
MIIFazCCA1OgAwIBAgIRAIIQz7DSQONZRGPgu2OCiwAwDQYJKoZIhvcNAQELBQAw
TzELMAkGA1UEBhMCVVMxKTAnBgNVBAoTIEludGVybmV0IFNlY3VyaXR5IFJlc2Vh
cmNoIEdyb3VwMRUwEwYDVQQDEwxJU1JHIFJvb3QgWDEwHhcNMTUwNjA0MTEwNDM4
WhcNMzUwNjA0MTEwNDM4WjBPMQswCQYDVQQGEwJVUzEpMCcGA1UEChMgSW50ZXJu
ZXQgU2VjdXJpdHkgUmVzZWFyY2ggR3JvdXAxFTATBgNVBAMTDElTUkcgUm9vdCBY
MTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAK3oJHP0FDfzm54rVygc
h77ct984kIxuPOZXoHj3dcKi/vVqbvYATyjb3miGbESTtrFj/RQSa78f0uoxmyF+
0TM8ukj13Xnfs7j/EvEhmkvBioZxaUpmZmyPfjxwv60pIgbz5MDmgK7iS4+3mX6
UA5/TR5d8mUgjU+g4rk8Kb4Mu0UlXjIB0ttov0DiNewNwIRt18jA8+o+u3dpjq+s
WT8KOEUt+zwvo/7V3LvSye0rgTBIlDHCNAymg4VMk7BPZ7hm/ELNKjD+Jo2FR3q
yHB5T0Y3HsLuJvW5iB4YlcNHlsdu87kGJ55tukmi8mxdAQ4Q7e2RCOFvu396j3x
+UCB5iPNgiV5+I3lg02dZ77DnKxHZu8A/lJBdiB3QW0KtZB6awBdpUKD9jf1b0SH
zUvKBds0pjBqAlkd25HN7rOrFleaJ1/ctaJxQZBKT5ZPt0m9STJEadao0xAH0ahm
bWnOlFuhjuefXKnEgV2He9tpAxdgBZvPIQoqAVaSmIWBjJhJGl/GW0EPRWuA4MVd
zVEZQE359duonta0CRGQo/aNKXZAiIEFEO2hlx0g0EfOhx7j6GOApEIhEoBPcyEf
HYq4yMEbYBpBdrJv5+DFYBsV5wUMEinXT/36Z4KNgn+CEriBrQ09bmpS6Ehw8VGw
mrIdl7mSreOqk4KUqseJCuCTAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNV
HRMBAf8EBTADAQH/MB0GA1UdDgQWBBR5tFnme7bl5AFzgAiIyBpY9umbbjANBgkq
hkiG9w0BAQsFAAOCAgEAVR9YqbyyqFDQDLHYGmkgJykIrGF1XIpu+ILlaS/V9lZL
nBhbCPE4bvT6oUDBtO2U596j/AcHkgp9e52BCGCZE1ZfWIsqYdJV3V0lhHMR7X8g
fRDnoZ6P/s9IhJNfpfBVDv/r7RBiES2Drx+dvB0KOE0I9hykPDjaHnLQ06v30wJJ
UV8qMcV/rPWJBJG/dMkD/wa73PYQ2dfSEB+sBCf6P7yHAbp7XGarYqgeIGTuXYhv
/GcRE1ub3tnCOyMHaDMDOZjszhnjq3/XMnMXE8nOYQvUb/LsrBenVXYfO1HOsFbC
Rk93VsBSCOPjVPTiF/5u4mjpTWGvvPApPbav6CfkHXNPCYMk7b/GrGlMDNyC/bCe
E/Pzp+fp5mBuOt5vv98GJQB2bFd+vYLe2eL9IHYUNP3bpMuwRcFRad+pvbUOW+sJ
RJ6X5eIM7SdVGDUiXMWWsbIG3+Rl1JJUHhUfBMoc7TKMqj5F82zcGHMZIHxUzqMb
vGH5h7r/y6R1CkU+Z9NY7GicZ6FMawfm+zDSYDHMZBxL/Hb+8HKr+tZj0qiabgd
RXPOLKn/JaQtALDVdiMrVlMBUtPkv4YL1MaeVkMJrDgYHBaGbvv7F77F8aCehxj5
cA37ZVU6n0gME0/bgVVqHfJCCaJD0LlMA11f9FAWb7BRYqaGhILRA/b0p+k=
-----END CERTIFICATE-----
''';

/// Creates an [http.Client] with certificate pinning for Supabase.
/// On web, returns a plain [http.Client] (no native TLS control).
http.Client createPinnedHttpClient() {
  if (kIsWeb) return http.Client();

  final context = SecurityContext(withTrustedRoots: false);
  context.setTrustedCertificatesBytes(_isrgRootX1Pem.codeUnits);

  final ioClient = HttpClient(context: context);

  ioClient.badCertificateCallback = (X509Certificate cert, String host, int port) {
    if (kDebugMode) {
      debugPrint('[TLS] Certificate rejected for $host:$port');
    }
    return false;
  };

  return IOClient(ioClient);
}
