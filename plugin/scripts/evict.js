// evict.js — make downloaded files online-only.
//
//   printf '%s\n' PATH... | osascript -l JavaScript evict.js
//
// Reads one path per line from stdin and calls -[NSFileManager
// evictUbiquitousItemAtURL:error:] on each, printing "ok PATH" or "fail PATH". The
// local copy is removed; the copy in the cloud stays and is downloaded again on the
// next read. Verified for iCloud Drive and Dropbox on macOS 27.3 (see the change's
// design.md); disk-space.sh online-only refuses every other location.
ObjC.import('Foundation');

function run() {
  var data = $.NSFileHandle.fileHandleWithStandardInput.readDataToEndOfFile;
  var text = ObjC.unwrap($.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding)) || '';
  var out = [];
  text.split('\n').forEach(function (p) {
    if (p === '') { return; }
    var err = Ref();
    var done = $.NSFileManager.defaultManager.evictUbiquitousItemAtURLError($.NSURL.fileURLWithPath(p), err);
    out.push((done ? 'ok ' : 'fail ') + p);
  });
  return out.join('\n');
}
