import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'eats_file_helper.dart';

/// Helper for loading, compressing, and resolving Lua scripts and songs from
/// URLs, GitHub Gists (URLs & IDs), and compressed URL query parameters.
class UrlScriptHelper {
  /// Resolves Lua script content from a user input string or URL param.
  /// Handles:
  /// - Pure Gist ID: `b785e0cc352b9aa3ece5dfd3c29c134c`
  /// - Prefixed Gist ID: `gist+<id>`, `gist:<id>`, `gist/<id>`, `gist <id>`
  /// - GitHub Gist URL: `https://gist.github.com/.../<id>`
  /// - Raw HTTP/HTTPS URL
  /// - Compressed/Encoded payloads: `gz+<base64>`, `lz+<base64>`, `b64+<base64>`
  static Future<String?> resolveScript(String rawInput) async {
    final input = rawInput.trim();
    if (input.isEmpty) return null;

    // 1. Check for compressed data payload (gz+<base64>, lz+<base64>, b64+<base64>)
    if (input.startsWith('gz+') || input.startsWith('gz:') || input.startsWith('lz+') || input.startsWith('lz:')) {
      final payload = input.substring(3).trim();
      final decompressed = decompressPayload(payload);
      if (decompressed != null && decompressed.isNotEmpty) return decompressed;
    }
    if (input.startsWith('b64+') || input.startsWith('b64:')) {
      final payload = input.substring(4).trim();
      try {
        final bytes = base64Url.decode(base64.normalize(payload));
        return utf8.decode(bytes);
      } catch (_) {}
    }

    // 2. Extract Gist ID if input is prefixed or a raw hex ID
    String? gistId;
    if (input.toLowerCase().startsWith('gist+') ||
        input.toLowerCase().startsWith('gist:') ||
        input.toLowerCase().startsWith('gist/') ||
        input.toLowerCase().startsWith('gist ')) {
      gistId = input.substring(5).trim();
    } else {
      // Check if the input is a standalone 20-40 char hex Gist ID
      final hexRegex = RegExp(r'^[a-fA-F0-9]{20,40}$');
      if (hexRegex.hasMatch(input)) {
        gistId = input;
      } else {
        // Check for full GitHub Gist web URL
        final gistUrlRegex = RegExp(r'gist\.github\.com/(?:[a-zA-Z0-9_-]+/)?([a-f0-9]+)');
        final match = gistUrlRegex.firstMatch(input);
        if (match != null && !input.contains('raw')) {
          gistId = match.group(1);
        }
      }
    }

    // 3. Fetch from GitHub Gist via API or raw URL if Gist ID found
    if (gistId != null && gistId.isNotEmpty) {
      final content = await fetchGistContent(gistId);
      if (content != null && content.isNotEmpty) return content;
    }

    // 4. Fallback: Fetch as direct HTTP/HTTPS URL
    if (input.startsWith('http://') || input.startsWith('https://')) {
      try {
        final bytes = await EatsFileHelper.fetchUrlBytes(input);
        if (bytes != null && bytes.isNotEmpty) {
          return utf8.decode(bytes);
        }
      } catch (e) {
        debugPrint('UrlScriptHelper: Error fetching URL $input: $e');
      }
    }

    return null;
  }

  /// Fetches Gist content given a Gist ID via GitHub API or raw fallback.
  static Future<String?> fetchGistContent(String gistId) async {
    try {
      final apiUrl = 'https://api.github.com/gists/$gistId';
      final bytes = await EatsFileHelper.fetchUrlBytes(apiUrl);
      if (bytes != null && bytes.isNotEmpty) {
        final jsonStr = utf8.decode(bytes);
        final data = json.decode(jsonStr) as Map<String, dynamic>;
        if (data.containsKey('files')) {
          final files = data['files'] as Map<String, dynamic>;
          // Prefer .lua or .eats.lua files
          for (final f in files.values) {
            final fileName = (f['filename'] ?? '').toString().toLowerCase();
            if (fileName.endsWith('.lua') || fileName.endsWith('.eats.lua')) {
              final content = f['content'] as String?;
              if (content != null && content.isNotEmpty) return content;
              final rawUrl = f['raw_url'] as String?;
              if (rawUrl != null) {
                final rawBytes = await EatsFileHelper.fetchUrlBytes(rawUrl);
                if (rawBytes != null && rawBytes.isNotEmpty) return utf8.decode(rawBytes);
              }
            }
          }
          // Fallback to first file in Gist
          if (files.isNotEmpty) {
            final firstFile = files.values.first as Map<String, dynamic>;
            final content = firstFile['content'] as String?;
            if (content != null && content.isNotEmpty) return content;
            final rawUrl = firstFile['raw_url'] as String?;
            if (rawUrl != null) {
              final rawBytes = await EatsFileHelper.fetchUrlBytes(rawUrl);
              if (rawBytes != null && rawBytes.isNotEmpty) return utf8.decode(rawBytes);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('UrlScriptHelper: GitHub API error for Gist $gistId: $e');
    }

    // Direct raw gist fallback
    try {
      final rawUrl = 'https://gist.githubusercontent.com/raw/$gistId';
      final bytes = await EatsFileHelper.fetchUrlBytes(rawUrl);
      if (bytes != null && bytes.isNotEmpty) {
        return utf8.decode(bytes);
      }
    } catch (_) {}

    return null;
  }

  /// Compresses Lua script code into a URL-safe Base64 payload prefixed with 'gz+'.
  static String compressScriptToPayload(String luaScript) {
    try {
      final utf8Bytes = utf8.encode(luaScript);
      final compressed = GZipEncoder().encode(utf8Bytes);
      if (compressed != null) {
        final b64 = base64Url.encode(compressed);
        return 'gz+$b64';
      }
    } catch (e) {
      debugPrint('UrlScriptHelper: Compression error: $e');
    }
    return 'b64+${base64Url.encode(utf8.encode(luaScript))}';
  }

  /// Decompresses a GZip / Zlib / Base64 payload.
  static String? decompressPayload(String payload) {
    try {
      final normalized = base64.normalize(payload);
      final bytes = base64Url.decode(normalized);
      try {
        final decompressed = GZipDecoder().decodeBytes(bytes);
        return utf8.decode(decompressed);
      } catch (_) {
        try {
          final decompressed = ZLibDecoder().decodeBytes(bytes);
          return utf8.decode(decompressed);
        } catch (_) {
          return utf8.decode(bytes);
        }
      }
    } catch (e) {
      debugPrint('UrlScriptHelper: Decompression error: $e');
      return null;
    }
  }

  /// Builds a complete shareable web URL for the given Lua script.
  static String buildShareableUrl(String luaScript, {String baseUrl = 'https://eatsbeats.app'}) {
    final payload = compressScriptToPayload(luaScript);
    final encodedParam = Uri.encodeQueryComponent(payload);
    return '$baseUrl/?script=$encodedParam';
  }
}
