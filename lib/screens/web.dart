import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:fwfh_webview/fwfh_webview.dart';

class WebGame extends StatefulWidget {
  final String gameUrl;
  const WebGame({super.key, required this.gameUrl});

  @override
  State<WebGame> createState() => _WebGameState();
}

class _WebGameState extends State<WebGame> {
  final bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: (defaultTargetPlatform == TargetPlatform.android ||
                  defaultTargetPlatform == TargetPlatform.iOS ||
                  defaultTargetPlatform == TargetPlatform.windows)
                  ? InAppWebView(
                      initialUrlRequest: URLRequest(
                        url: WebUri.uri(Uri.parse(widget.gameUrl)),
                      ),
                      onReceivedError: (controller, request, error) {
                        setState(() {
                          _hasError = true;
                          _errorMessage = 'خطأ في تحميل اللعبة: ${error.description}';
                        });
                      },
                      onReceivedHttpError: (controller, request, errorResponse) {
                        setState(() {
                          _hasError = true;
                          _errorMessage = 'خطأ في الاتصال: ${errorResponse.statusCode}';
                        });
                      },
                    )
                  : HtmlWidget(
                    '''
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
    html, body {
        margin: 0;
        padding: 0;
        height: 100%;
        overflow: hidden;
        background-color: #f5f5f5;
    }
    .fullscreen-iframe {
        width: 100vw;
        height: 100vh;
        border: none;
        border-radius: 0;
        margin: 0;
        padding: 0;
        display: block;
    }
    </style>
</head>
<body style="margin:0;padding:0;overflow:hidden;height:100vh;width:100vw;">
    <iframe 
        src="${widget.gameUrl}" 
        class="fullscreen-iframe"
        allowfullscreen
        style="width:100vw;height:100vh;">
    </iframe>
</body>
</html>
                    ''',
                    factoryBuilder: () => MyWidgetFactory(),
                    onErrorBuilder: (context, element, error) {
                      setState(() {
                        _hasError = true;
                        _errorMessage = 'خطأ في تحميل اللعبة';
                      });
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: colorScheme.error,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'خطأ في تحميل اللعبة',
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class MyWidgetFactory extends WidgetFactory with WebViewFactory {
  @override
  bool get webViewMediaPlaybackAlwaysAllow => true;
  @override
  String? get webViewUserAgent => 'AshurGames';
}
