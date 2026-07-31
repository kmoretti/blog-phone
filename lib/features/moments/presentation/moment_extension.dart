import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

sealed class MomentExtension {
  const MomentExtension({required this.type, required this.payload, required this.isKnown});

  final String type;
  final Map<String, dynamic> payload;
  final bool isKnown;

  static MomentExtension? fromJsonString(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) return null;
      final type = decoded['type'];
      final rawPayload = decoded['payload'];
      if (type is! String || rawPayload is! Map) return null;
      final payload = Map<String, dynamic>.from(rawPayload);
      return switch (type) {
        'github' => _parseGithub(payload),
        'website' => _parseWebsite(payload),
        'location' => _parseLocation(payload),
        'music' => _parseMusic(payload),
        'tweet' => _parseTweet(payload),
        _ => UnknownMomentExtension(type: type, payload: payload),
      };
    } catch (_) {
      return null;
    }
  }

  static GithubMomentExtension? _parseGithub(Map<String, dynamic> payload) {
    final repoUrl = _httpUrlValue(payload, 'repo_url');
    return repoUrl == null ? null : GithubMomentExtension(repoUrl, payload: payload);
  }

  static WebsiteMomentExtension? _parseWebsite(Map<String, dynamic> payload) {
    final title = _stringValue(payload, 'title');
    final site = _httpUrlValue(payload, 'site');
    return title == null || site == null ? null : WebsiteMomentExtension(title: title, site: site, payload: payload);
  }

  static LocationMomentExtension? _parseLocation(Map<String, dynamic> payload) {
    final placeholder = _stringValue(payload, 'placeholder');
    final latitude = _numberValue(payload, 'latitude');
    final longitude = _numberValue(payload, 'longitude');
    return placeholder == null || latitude == null || longitude == null
        ? null
        : LocationMomentExtension(placeholder: placeholder, latitude: latitude, longitude: longitude, payload: payload);
  }

  static MusicMomentExtension? _parseMusic(Map<String, dynamic> payload) {
    final url = _httpUrlValue(payload, 'url');
    return url == null ? null : MusicMomentExtension(url, title: _firstString(payload, ['title', 'song', 'name']), artist: _firstString(payload, ['artist', 'singer']), payload: payload);
  }

  static TweetMomentExtension? _parseTweet(Map<String, dynamic> payload) {
    final url = _httpUrlValue(payload, 'url');
    final username = _firstString(payload, ['username', 'user_name', 'screen_name']);
    final statusId = _firstString(payload, ['status_id', 'id']);
    return url == null || username == null || statusId == null
        ? null
        : TweetMomentExtension(url: url, username: username, statusId: statusId, text: _firstString(payload, ['text', 'content', 'status_text']), payload: payload);
  }

  static String? _stringValue(Map<String, dynamic> payload, String key) {
    final value = payload[key];
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  static String? _firstString(Map<String, dynamic> payload, List<String> keys) {
    for (final key in keys) {
      final value = _stringValue(payload, key);
      if (value != null) return value;
    }
    return null;
  }

  static String? _httpUrlValue(Map<String, dynamic> payload, String key) {
    final value = _stringValue(payload, key);
    return value != null && isHttpUrl(value) ? value : null;
  }

  static double? _numberValue(Map<String, dynamic> payload, String key) {
    final value = payload[key];
    return value is num ? value.toDouble() : double.tryParse('$value');
  }
}

class GithubMomentExtension extends MomentExtension {
  const GithubMomentExtension(this.repoUrl, {required super.payload}) : super(type: 'github', isKnown: true);
  final String repoUrl;
}

class WebsiteMomentExtension extends MomentExtension {
  const WebsiteMomentExtension({required this.title, required this.site, required super.payload}) : super(type: 'website', isKnown: true);
  final String title;
  final String site;
}

class LocationMomentExtension extends MomentExtension {
  const LocationMomentExtension({required this.placeholder, required this.latitude, required this.longitude, required super.payload}) : super(type: 'location', isKnown: true);
  final String placeholder;
  final double latitude;
  final double longitude;
}

class MusicMomentExtension extends MomentExtension {
  const MusicMomentExtension(this.url, {this.title, this.artist, required super.payload}) : super(type: 'music', isKnown: true);
  final String url;
  final String? title;
  final String? artist;
}

class TweetMomentExtension extends MomentExtension {
  const TweetMomentExtension({required this.url, required this.username, required this.statusId, this.text, required super.payload}) : super(type: 'tweet', isKnown: true);
  final String url;
  final String username;
  final String statusId;
  final String? text;
}

class UnknownMomentExtension extends MomentExtension {
  const UnknownMomentExtension({required super.type, required super.payload}) : super(isKnown: false);
}

MomentExtension? parseMomentExtension(String? value) => MomentExtension.fromJsonString(value);

bool isHttpUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  final scheme = uri?.scheme.toLowerCase();
  return uri != null && (scheme == 'http' || scheme == 'https') && uri.host.isNotEmpty;
}

class MomentMarkdown extends StatelessWidget {
  const MomentMarkdown({super.key, required this.content});
  final String content;
  @override
  Widget build(BuildContext context) => MarkdownBody(data: content, selectable: true);
}

class MomentExtensionCard extends StatelessWidget {
  const MomentExtensionCard({super.key, required this.extension});
  final MomentExtension extension;
  @override
  Widget build(BuildContext context) {
    final child = switch (extension) {
      GithubMomentExtension(:final repoUrl) => _LinkCard(icon: Icons.code, title: 'GitHub 仓库', subtitle: repoUrl, url: repoUrl),
      WebsiteMomentExtension(:final title, :final site) => _LinkCard(icon: Icons.link, title: title, subtitle: site, url: site),
      LocationMomentExtension(:final placeholder, :final latitude, :final longitude) => _LocationCard(placeholder: placeholder, latitude: latitude, longitude: longitude),
      MusicMomentExtension(:final url, :final title, :final artist) => _LinkCard(icon: Icons.headphones, title: title ?? '收听音乐', subtitle: artist ?? url, url: url),
      TweetMomentExtension(:final url, :final username, :final text) => _LinkCard(icon: Icons.chat_bubble_outline, title: text ?? '@$username', subtitle: url, url: url),
      UnknownMomentExtension() => const SizedBox.shrink(),
    };
    return Card(margin: const EdgeInsets.only(top: 12), child: child);
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({required this.icon, required this.title, required this.subtitle, required this.url});
  final IconData icon;
  final String title;
  final String subtitle;
  final String url;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
    trailing: const Icon(Icons.open_in_new, size: 18),
    onTap: isHttpUrl(url) ? () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication) : null,
  );
}

class _LocationCard extends StatefulWidget {
  const _LocationCard({required this.placeholder, required this.latitude, required this.longitude});
  final String placeholder;
  final double latitude;
  final double longitude;
  @override
  State<_LocationCard> createState() => _LocationCardState();
}

class _LocationCardState extends State<_LocationCard> {
  bool open = false;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        leading: const Icon(Icons.location_on_outlined),
        title: Text(widget.placeholder),
        subtitle: Text('${widget.latitude.toStringAsFixed(2)}°, ${widget.longitude.toStringAsFixed(2)}°'),
        trailing: Icon(open ? Icons.expand_less : Icons.expand_more),
        onTap: () => setState(() => open = !open),
      ),
      if (open) SizedBox(
        height: 180,
        child: Center(child: Text('坐标：${widget.latitude}, ${widget.longitude}')),
      ),
    ],
  );
}
