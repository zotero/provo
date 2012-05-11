# Provo: The Zotero unit test automator

## Requirements
Requirements are the same as for [building Zotero Standalone](http://www.zotero.org/support/dev/client_coding/building_the_standalone_client) plus the following:

* python
* [s3cmd](http://s3tools.org/s3cmd)

### Connector Tests
* [Google Chrome](https://www.google.com/chrome) (for Chrome connector tests)
  * Chrome certificate
* [Safari](http://www.apple.com/safari/) (for Safari connector tests)
  * [xar](https://code.google.com/p/xar/issues/detail?id=76) modified to build safariextz archives
  * libxml2 and openssl (for xar)
  * xxd
  * Safari certificate, dumped to pem and der following the instructions on the xar page above

### Bookmarklet Tests
* [JDK](http://www.oracle.com/technetwork/java/javase/downloads/index.html)
* [ant](http://ant.apache.org/bindownload.cgi) ([Windows installer](http://code.google.com/p/winant/))
* [Firefox](http://www.mozilla.org/en-US/firefox/fx/) (for Gecko bookmarklet tests)
* [Google Chrome](https://www.google.com/chrome) (for Chrome bookmarklet tests)
* IE 9 (for IE bookmarklet tests)

## Running
Edit config.sh. Run test.sh.