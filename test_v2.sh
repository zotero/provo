#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "$SCRIPT_DIR/config.sh"
TRANSLATORS_DIR="$SCRIPT_DIR/zotero-translators"

if [ "`uname`" = "Darwin" ]; then
	MAC_NATIVE=1
else
	MAC_NATIVE=0
fi
if [ "`uname -o 2> /dev/null`" = "Cygwin" ]; then
	WIN_NATIVE=1
else
	WIN_NATIVE=0
fi

# Run tests
function runTests {
	# Test server
	if [ $TEST_SERVER == 1 ]; then
		if [ ! -d "$TRANSLATION_SERVER_DIR" ]; then
			echo "$TRANSLATION_SERVER_DIR does not exist; not testing translation-server"
		else
			echo "Running translation-server tests"
			suffix="translation-server.SOURCE.`git log -n 1 --pretty='format:%h'`"
			outputFile="$OUTPUT_DIR/testResults-v-$suffix.json"
			
			cd "$TRANSLATION_SERVER_DIR"
			nodejs ./test/testTranslators/testTranslators.js -o "$outputFile" -g "PubMed" > /dev/null
		fi
	fi
}

# Make sure translators directory exists and is up-to-date
echo "Updating translators"
if [ ! -d "$TRANSLATORS_DIR" ]; then
	git clone "$TRANSLATORS_REPO" "$TRANSLATORS_DIR"
else
	cd "$TRANSLATORS_DIR"
	git pull origin master
fi
echo

# Create translation-server directory if it doesn't exist, or else update it
echo "Updating translation-server"
if [ ! -d "$TRANSLATION_SERVER_DIR" ]; then
	git clone "$TRANSLATION_SERVER_REPO" "$TRANSLATION_SERVER_DIR"
	cd "$TRANSLATION_SERVER_DIR"
	git submodule update --init modules/zotero
	# Link translators for the translation-server
	rm -rf "modules/translators"
	ln -s "$TRANSLATORS_DIR" "modules/translators"
	npm i
else
	cd "$TRANSLATION_SERVER_DIR"
	git pull origin master
	git submodule update modules/zotero
	npm i
fi
echo

# Make output directory
mkdir -p "$OUTPUT_DIR"

# Run prerun.sh if it exists
if [ -e "$SCRIPT_DIR/prerun.sh" ]; then
	. "$SCRIPT_DIR/prerun.sh"
fi

# Test
runTests

# Run postrun.sh if it exists
if [ -e "$SCRIPT_DIR/postrun.sh" ]; then
	. "$SCRIPT_DIR/postrun.sh"
fi
