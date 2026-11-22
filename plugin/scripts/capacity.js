// capacity.js — the two volume capacities of / that give the purgeable total.
//
//   osascript -l JavaScript capacity.js
//
// Prints two lines: available=<bytes> (NSURLVolumeAvailableCapacityKey, the same as
// df) and important=<bytes> (NSURLVolumeAvailableCapacityForImportantUsageKey, which
// counts space the system can reclaim from purgeable data). Nothing is written.
ObjC.import('Foundation');

function value(url, key) {
  var ref = Ref();
  if (!url.getResourceValueForKeyError(ref, $(key), null)) { return null; }
  var v = ObjC.unwrap(ref[0]);
  return (typeof v === 'number') ? v : null;
}

function run() {
  var url = $.NSURL.fileURLWithPath('/');
  var a = value(url, 'NSURLVolumeAvailableCapacityKey');
  var i = value(url, 'NSURLVolumeAvailableCapacityForImportantUsageKey');
  var lines = [];
  if (a !== null) { lines.push('available=' + a.toFixed(0)); }
  if (i !== null) { lines.push('important=' + i.toFixed(0)); }
  return lines.join('\n');
}
