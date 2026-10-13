/// Saves [content] to the user's device as [filename]. Only the web app can do
/// this; other platforms throw so the caller can say so instead of silently failing.
void downloadTextFile(String filename, String content,
    {String mimeType = 'text/csv;charset=utf-8'}) {
  throw UnsupportedError('Downloading files is only available in the web app.');
}
