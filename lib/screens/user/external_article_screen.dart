import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ExternalArticleScreen extends StatefulWidget {
  final String title;
  final String url;

  const ExternalArticleScreen({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<ExternalArticleScreen> createState() => _ExternalArticleScreenState();
}

class _ExternalArticleScreenState extends State<ExternalArticleScreen> {
  late final WebViewController _controller;

  /// 0–100 loading progress; null means fully loaded.
  double? _loadingProgress;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(true)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _loadingProgress = progress < 100 ? progress / 100.0 : null;
                if (progress < 100) _hasError = false;
              });
            }
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _hasError = false);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loadingProgress = null);
          },
          onWebResourceError: (error) {
            // Ignore sub-resource errors (ads, trackers, etc.)
            if (error.isForMainFrame ?? true) {
              if (mounted) {
                setState(() {
                  _hasError = true;
                  _loadingProgress = null;
                  _errorMessage = error.description;
                });
              }
            }
          },
          onNavigationRequest: (request) {
            // Block javascript: URIs and unrecognised schemes.
            // All http / https navigations (including CDN redirects) are allowed
            // so existing article functionality is fully preserved.
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;
            final scheme = uri.scheme.toLowerCase();
            if (scheme != 'https' && scheme != 'http') {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _refresh() async {
    setState(() {
      _hasError = false;
      _loadingProgress = 0.0;
    });
    await _controller.reload();
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(widget.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open browser.')),
        );
      }
    }
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: widget.url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareUrl() {
    Share.share(widget.url, subject: widget.title);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        actions: [
          PopupMenuButton<_MenuAction>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'More options',
            onSelected: (action) {
              switch (action) {
                case _MenuAction.refresh:
                  _refresh();
                case _MenuAction.share:
                  _shareUrl();
                case _MenuAction.copyLink:
                  _copyLink();
                case _MenuAction.openInBrowser:
                  _openInBrowser();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _MenuAction.refresh,
                child: _MenuTile(Icons.refresh_rounded, 'Refresh'),
              ),
              PopupMenuItem(
                value: _MenuAction.share,
                child: _MenuTile(Icons.share_rounded, 'Share'),
              ),
              PopupMenuItem(
                value: _MenuAction.copyLink,
                child: _MenuTile(Icons.link_rounded, 'Copy Link'),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: _MenuAction.openInBrowser,
                child: _MenuTile(Icons.open_in_browser_rounded, 'Open in Browser'),
              ),
            ],
          ),
        ],
        // Linear progress bar that sits right below the AppBar
        bottom: _loadingProgress != null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: _loadingProgress,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                  minHeight: 3,
                ),
              )
            : null,
      ),
      body: _hasError ? _buildErrorView(colorScheme) : _buildWebView(),
    );
  }

  Widget _buildWebView() {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        // Initial load spinner (before the progress bar kicks in)
        if (_loadingProgress != null && _loadingProgress! < 0.15)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _buildErrorView(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.signal_wifi_statusbar_connected_no_internet_4_rounded,
              size: 72,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 20),
            Text(
              'Unable to load article',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage != null
                  ? 'The page could not be loaded. Please check your internet connection and try again.'
                  : 'Something went wrong. Please try again.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openInBrowser,
              icon: const Icon(Icons.open_in_browser_rounded),
              label: const Text('Open in Browser'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

enum _MenuAction { refresh, share, copyLink, openInBrowser }

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MenuTile(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}
