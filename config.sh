#!/bin/bash
STANDALONE_BUILD_REPO="git://github.com/zotero/zotero-standalone-build.git"
STANDALONE_BUILD_DIR="$SCRIPT_DIR/zotero-standalone-build"

ZOTERO_BUILD_REPO="git://github.com/zotero/zotero-build.git"
ZOTERO_BUILD_DIR="$SCRIPT_DIR/zotero-build"

CONNECTORS_REPO="git://github.com/zotero/zotero-connectors.git"
CONNECTORS_DIR="$SCRIPT_DIR/zotero-connectors"

TRANSLATORS_REPO="git://github.com/zotero/translators.git"
TRANSLATORS_DIR="$SCRIPT_DIR/translators"

TRANSLATION_SERVER_REPO="git@github.com:zotero/translation-server.git"
TRANSLATION_SERVER_DIR="$SCRIPT_DIR/translation-server"

TEMP_PROFILE_DIR="$SCRIPT_DIR/tmp_profile"
OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/output/`date -u +%Y-%m-%d`}"

TEST_GECKO=0
TEST_BOOKMARKLET_IE=0
TEST_BOOKMARKLET_CHROME=0
TEST_BOOKMARKLET_GECKO=0
TEST_CHROME=0
TEST_SAFARI=0
TEST_SERVER=1

# Safari extension directory
# Safari homepage must be set to http://127.0.0.1:23119/provo/run for testing
if [ "`uname`" == "Darwin" ]; then
	SAFARI_CACHE_DIR="$HOME/Library/Caches/com.apple.Safari"
	SAFARI_EXTENSION_LOCATION="$HOME/Library/Caches/Safari/Extensions/Zotero Connector for Safari.safariextz"
elif [ "`uname -o 2> /dev/null`" == "Cygwin" ]; then
	SAFARI_CACHE_DIR="`cygpath -u \"$LOCALAPPDATA\"`/Apple Computer/Safari"
	SAFARI_EXTENSION_LOCATION="`cygpath -u \"$APPDATA\"`/Apple Computer/Safari/Extensions/Zotero Connector for Safari.safariextz"
fi