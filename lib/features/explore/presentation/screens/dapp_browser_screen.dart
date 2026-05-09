import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class DappBrowserScreen extends StatefulWidget {
  final String initialUrl;
  final String? title;

  const DappBrowserScreen({
    super.key,
    required this.initialUrl,
    this.title,
  });

  @override
  State<DappBrowserScreen> createState() => _DappBrowserScreenState();
}

class _DappBrowserScreenState extends State<DappBrowserScreen> {
  late final WebViewController _controller;
  String _currentUrl = '';
  String _pageTitle = '';
  bool _isLoading = true;
  double _loadingProgress = 0;
  bool _canGoBack = false;
  bool _canGoForward = false;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl;
    _pageTitle = widget.title ?? '';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {
          setState(() {
            _currentUrl = url;
            _isLoading = true;
          });
        },
        onProgress: (progress) {
          setState(() => _loadingProgress = progress / 100);
        },
        onPageFinished: (url) async {
          _currentUrl = url;
          _isLoading = false;
          _canGoBack = await _controller.canGoBack();
          _canGoForward = await _controller.canGoForward();

          final title = await _controller.getTitle();
          setState(() {
            if (title != null && title.isNotEmpty) _pageTitle = title;
          });
        },
      ))
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  String _displayUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0b12),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Browser toolbar
            _buildToolbar(),

            // Loading bar
            if (_isLoading)
              LinearProgressIndicator(
                value: _loadingProgress,
                backgroundColor: Colors.transparent,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.yellow),
                minHeight: 2,
              ),

            // WebView
            Expanded(
              child: WebViewWidget(controller: _controller),
            ),

            // Bottom navigation bar
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Row(
        children: [
          // MW avatar
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                'MW',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontFamily: 'FKGrotesk',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // URL bar
          Expanded(
            child: GestureDetector(
              onTap: _showUrlInputSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1F26),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _pageTitle.isNotEmpty ? _pageTitle : _displayUrl(_currentUrl),
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                          fontFamily: 'FKGrotesk',
                          fontWeight: FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _showMoreMenu(),
                      child: Icon(Icons.more_horiz, color: Colors.grey[500], size: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Home button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.home_outlined, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).padding.bottom + 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0a0b12),
        border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Back
          GestureDetector(
            onTap: _canGoBack ? () => _controller.goBack() : null,
            child: Icon(
              Icons.arrow_back_ios,
              color: _canGoBack ? Colors.white : Colors.grey[700],
              size: 18,
            ),
          ),

          // Forward
          GestureDetector(
            onTap: _canGoForward ? () => _controller.goForward() : null,
            child: Icon(
              Icons.arrow_forward_ios,
              color: _canGoForward ? Colors.white : Colors.grey[700],
              size: 18,
            ),
          ),

          // Reload
          GestureDetector(
            onTap: () => _controller.reload(),
            child: const Icon(Icons.refresh, color: Colors.white, size: 20),
          ),

          // Close
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.close, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  void _showMoreMenu() {
    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(200, 60, 20, 0),
      color: const Color(0xFF1C1F26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem(
          onTap: () => _controller.reload(),
          child: const Row(
            children: [
              Icon(Icons.refresh, color: Colors.white, size: 16),
              SizedBox(width: 10),
              Text('Reload', style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'FKGrotesk')),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: () {
            // Copy URL
          },
          child: const Row(
            children: [
              Icon(Icons.copy, color: Colors.white, size: 16),
              SizedBox(width: 10),
              Text('Copy URL', style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'FKGrotesk')),
            ],
          ),
        ),
      ],
    );
  }

  void _showUrlInputSheet() {
    final controller = TextEditingController(text: _currentUrl);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          decoration: const BoxDecoration(
            color: Color(0xFF0E1014),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // URL input
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: controller,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontFamily: 'FKGrotesk',
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search or type URL',
                    hintStyle: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                      fontFamily: 'FKGrotesk',
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[500], size: 18),
                  ),
                  autofocus: true,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (value) {
                    Navigator.pop(context);
                    _navigateToUrl(value);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToUrl(String input) {
    String url = input.trim();
    if (url.isEmpty) return;

    // Add https:// if not present
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      if (url.contains('.')) {
        url = 'https://$url';
      } else {
        // Treat as search
        url = 'https://www.google.com/search?q=${Uri.encodeComponent(url)}';
      }
    }

    _controller.loadRequest(Uri.parse(url));
  }
}
