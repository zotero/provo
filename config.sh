#!/bin/bash
ZSA_REPOSITORY="git://github.com/zotero/zotero-standalone-build.git"
ZSA_DIRECTORY="$SCRIPT_DIRECTORY/zotero-standalone-build"

ZC_REPOSITORY="git://github.com/zotero/zotero-connectors.git"
ZC_DIRECTORY="$SCRIPT_DIRECTORY/zotero-connectors"

TEMP_PROFILE_DIRECTORY="$SCRIPT_DIRECTORY/tmp_profile"
OUTPUT_DIRECTORY="$SCRIPT_DIRECTORY/output/`date -u +%Y-%m-%d`"

# Safari extension directory
# Safari homepage must be set to http://127.0.0.1:23119/provo/run for testing
if [ "`uname`" == "Darwin" ]; then
	SAFARI_CACHE_DIRECTORY="$HOME/Library/Caches/com.apple.Safari"
	SAFARI_EXTENSION_LOCATION="$HOME/Library/Caches/Safari/Extensions/Zotero Connector for Safari.safariextz"
elif [ "`uname -o 2> /dev/null`" == "Cygwin" ]; then
	SAFARI_CACHE_DIRECTORY="`cygpath -u \"$LOCALAPPDATA\"`/Apple Computer/Safari"
	SAFARI_EXTENSION_LOCATION="`cygpath -u \"$APPDATA\"`/Apple Computer/Safari/Extensions/Zotero Connector for Safari.safariextz"
fi