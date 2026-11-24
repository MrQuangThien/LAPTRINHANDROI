import 'dart:js_interop';

@JS('window.location.assign')
external void _assignLocation(String url);

void redirectToUrl(String url) => _assignLocation(url);
