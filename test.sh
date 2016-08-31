#!/bin/bash
set -euo pipefail

# Copyright (c) 2012-2016  Zotero
#                          Center for History and New Media
#                          George Mason University, Fairfax, Virginia, USA
#                          http://zotero.org
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "$SCRIPT_DIR/config.sh"
TRANSLATORS_DIR="$SCRIPT_DIR/zotero-translators"

BRANCH=4.0
REBUILD=1

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
	

# Get platform and build directory
if [ $MAC_NATIVE == 1 ]; then
	PLATFORMS=m
	STANDALONE_STAGE_DIR="$STANDALONE_BUILD_DIR/staging/Zotero.app"
elif [ $WIN_NATIVE == 1 ]; then
	PLATFORMS=w
	STANDALONE_STAGE_DIR="$STANDALONE_BUILD_DIR/staging/Zotero_win32"
else
	PLATFORMS=l
	STANDALONE_STAGE_DIR="$STANDALONE_BUILD_DIR/staging/Zotero_linux-`arch`"
fi

# Make sure temp profile directory is specified, so we don't rm -rf /
if [ -z "$TEMP_PROFILE_DIR" ]; then
	echo "No temporary profile directory specified. Exiting." 1>&2
	exit 1
fi

#
# Functions
#

# Make bookmarklet config
function testBookmarklet {
	CONNECTOR_DIR="$1"
	BROWSER="$2"
	VERSION="$3"
	
	configFile="$TEMP_PROFILE_DIR/bookmarklet_config.json"
	outputFile="$OUTPUT_DIR/testResults-${BROWSER}b-$VERSION.json"
	translatorsDirectory="$TRANSLATORS_DIR"
	if [ $BROWSER == "i" ]; then
		testPayload="$CONNECTOR_DIR/build/bookmarklet/tests/inject_ie_test.js"
		nConcurrentTests=1
	else
		testPayload="$CONNECTOR_DIR/build/bookmarklet/tests/inject_test.js"
		nConcurrentTests=2
	fi
	if [ $WIN_NATIVE == 1 ]; then
		translatorsDirectory="`cygpath -w \"$translatorsDirectory\" | sed 's/\\\\/\\\\\\\\/g'`"
		configFile="`cygpath -w \"$configFile\"`"
		outputFile="`cygpath -w \"$outputFile\"`"
	fi
	
	cat > "$configFile" <<DONE
{
	"translatorsDirectory":"$translatorsDirectory",
	"concurrentTests":$nConcurrentTests,
	"browser":"$BROWSER",
	"version":"$VERSION"
}
DONE
	cd "$CONNECTOR_DIR/src/bookmarklet/tests"
	ruby -E UTF-8:UTF-8 test.rb "$configFile" "$outputFile"
}

# Wait for $OUTPUT_DIR to change
function waitForTestResults {
	LS_OUTPUT="`ls -lad \"$OUTPUT_DIR/*.json\"`"
	while [ "`ls -lad \"$OUTPUT_DIR/*.json\"`" == "$LS_OUTPUT" ]; do
		sleep 10
	done
}

# Start provo
function runProvo {
	APP_DIR="$1"
	CONNECTOR_DIR="$2"
	SUFFIX="$3"
	
	# Make profile
	FIREFOX_PROFILE_DIR="$TEMP_PROFILE_DIR/firefox"
	CHROME_PROFILE_DIR="$TEMP_PROFILE_DIR/chrome"
	BOOKMARKLET_PAYLOAD_DIR="$CONNECTOR_DIR/build/bookmarklet/"
	rm -rf "$TEMP_PROFILE_DIR"
	mkdir -p "$FIREFOX_PROFILE_DIR/extensions"
	mkdir "$FIREFOX_PROFILE_DIR/zotero"
	cp "$SCRIPT_DIR/prefs.js" "$FIREFOX_PROFILE_DIR"
	cp -R "$SCRIPT_DIR/provo@zotero.org" "$FIREFOX_PROFILE_DIR/extensions"
	
	if [ $TEST_GECKO == 1 ]; then
		provorun="-provorun"
	else
		provorun=""
	fi
	
	# Start Zotero Standalone and test Gecko if requested
	if [ $MAC_NATIVE == 1 ]; then
		"$APP_DIR/Contents/MacOS/zotero-bin" -app \
			"$APP_DIR/Contents/Resources/application.ini" \
			-profile "$FIREFOX_PROFILE_DIR" \
			-provooutputdir "$OUTPUT_DIR" \
			-provopayloaddir "$BOOKMARKLET_PAYLOAD_DIR" \
			-jsconsole \
			$provorun -provosuffix "$SUFFIX" &
	elif [ $WIN_NATIVE == 1 ]; then
		"$APP_DIR/zotero.exe" \
			-profile "`cygpath -w \"$FIREFOX_PROFILE_DIR\"`" \
			-provooutputdir "`cygpath -w \"$OUTPUT_DIR\"`" \
			-provopayloaddir "`cygpath -w \"$BOOKMARKLET_PAYLOAD_DIR\"`" \
			$provorun -provosuffix "$SUFFIX" &
	else
		"$APP_DIR/zotero" \
			-profile "$FIREFOX_PROFILE_DIR" \
			-provooutputdir "$OUTPUT_DIR" \
			-provopayloaddir "$BOOKMARKLET_PAYLOAD_DIR" \
			$provorun -provosuffix "$SUFFIX" &
	fi
	ZOTERO_PID=$!
	
	if [ $TEST_GECKO == 1 ]; then
		# Wait until Fx output is written to a file
		waitForTestResults
	else
		# Wait for startup
		sleep 60;
	fi
	
	# Test bookmarklets
	if [ $TEST_BOOKMARKLET_IE == 1 ]; then
		testBookmarklet "$CONNECTOR_DIR" "i" "$SUFFIX"
	fi
	if [ $TEST_BOOKMARKLET_CHROME == 1 ]; then
		testBookmarklet "$CONNECTOR_DIR" "c" "$SUFFIX"
	fi
	if [ $TEST_BOOKMARKLET_GECKO == 1 ]; then
		testBookmarklet "$CONNECTOR_DIR" "g" "$SUFFIX"
	fi
	
	if [ $TEST_CHROME == 1 ]; then
		# Test Chrome
		if [ $MAC_NATIVE == 1 ]; then
			"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
				--user-data-dir="$CHROME_PROFILE_DIR" \
				--load-extension="$CONNECTOR_DIR/build/chrome" \
				--new-window "http://127.0.0.1:23119/provo/run" &
		elif [ $WIN_NATIVE == 1 ]; then
			"`cygpath \"$LOCALAPPDATA\"`"/Google/Chrome/Application/chrome \
				--user-data-dir="`cygpath -w \"$CHROME_PROFILE_DIR\"`" \
				--load-extension="`cygpath -w \"$CONNECTOR_DIR/build/chrome\"`" \
				--new-window "http://127.0.0.1:23119/provo/run" &
		else
			chromium --user-data-dir="$CHROME_PROFILE_DIR" \
				--load-extension="$CONNECTOR_DIR/build/chrome" \
				--new-window "http://127.0.0.1:23119/provo/run" &
		fi
		CHROME_PID=$!
		
		# Wait until Chrome output is written to a file
		waitForTestResults
		kill $CHROME_PID
	fi
	
	# Test Safari
	if [ $TEST_SAFARI == 1 ]; then
		# Clear cache
		rm -rf "$SAFARI_CACHE_DIR"
		# Update extension
		cp -R "$CONNECTOR_DIR/dist/Zotero_Connector.safariextz" "$SAFARI_EXTENSION_LOCATION"
		# Launch Safari to run tests
		if [ $MAC_NATIVE == 1 ]; then
			"/Applications/Safari.app/Contents/MacOS/Safari" &
		elif [ $WIN_NATIVE == 1 ]; then
			if [ -e "/cygdrive/c/Program Files/Safari/Safari.exe" ]; then
				"/cygdrive/c/Program Files/Safari/Safari.exe" &
			else
				"/cygdrive/c/Program Files (x86)/Safari/Safari.exe" &
			fi
		fi
		SAFARI_PID=$!
		
		waitForTestResults
		kill $SAFARI_PID
	fi
	
	kill $ZOTERO_PID
	
	# Test server
	if [ $TEST_SERVER == 1 ]; then
		if [ ! -d "$TRANSLATION_SERVER_DIR" ]; then
			echo "$TRANSLATION_SERVER_DIR does not exist; not testing translation-server"
		else
			outputFile="$OUTPUT_DIR/testResults-v-$SUFFIX.json"
			if [ $WIN_NATIVE == 1 ]; then
				outputFile="`cygpath -w \"$outputFile\"`"
			fi
			
			cd "$TRANSLATION_SERVER_DIR"
			./build.sh
			"$TRANSLATION_SERVER_DIR/build/run_translation-server.sh" -test "$outputFile"
		fi
	fi
}

# Test an unpacked release
function testRelease {
	RELEASE_DIR="$1"
	SUFFIX="$2"
	
	rm -rf "$RELEASE_DIR/translators.zip" \
		"$RELEASE_DIR/translators.index" \
		"$RELEASE_DIR/translators"
	mkdir "$RELEASE_DIR/translators"
	cp -R "$TRANSLATORS_DIR/"*.js "$RELEASE_DIR/translators"
	runProvo "$RELEASE_DIR" "$CONNECTORS_DIR" "$SUFFIX"
}

# Test a branch from git
function testBranch {
	local branch="$1"
	if [ $REBUILD = "1" ]; then
		buildXPI $branch
	fi
	
	cd "$ZOTERO_BUILD_DIR/xpi/build/zotero"
	local version="$branch.SOURCE.`git log -n 1 --pretty='format:%h'`"
	
	if [ $REBUILD = "1" ]; then
		# Build connectors
		cd "$CONNECTORS_DIR"
		cp src/bookmarklet/tests/zotero_config.js src/bookmarklet/zotero_config.js
		./build.sh -d
		
		# Build Zotero Standalone
		cd "$STANDALONE_BUILD_DIR"
		./build.sh -f "$ZOTERO_BUILD_DIR/xpi/build/zotero-build.xpi" -d -p "$PLATFORMS"
	fi
	
	runProvo "$STANDALONE_STAGE_DIR" "$CONNECTORS_DIR" "$version"
}

function buildXPI {
	echo "Building XPI"
	
	local branch=$1
	
	# Build Zotero XPI
	if [ $branch = 4.0 ]; then
		"$ZOTERO_BUILD_DIR/xpi/build_xpi_4.0" $branch test
	else
		"$ZOTERO_BUILD_DIR/xpi/build_xpi" -b $branch -c test
	fi
	
	# Replace URLs for bookmarklet
	cd "$ZOTERO_BUILD_DIR/xpi/build/zotero"
	perl -pi -e "s/((?:HTTP_)?BOOKMARKLET_ORIGIN *: *)'[^']*/\$1'"'http:\/\/127.0.0.1:23119'"/g" \
		resource/config.js
	perl -pi -e 's/https:\/\/www\.zotero\.org\/bookmarklet\//http:\/\/127.0.0.1:23119\/provo\/bookmarklet\//g' \
		resource/config.js
	zip ../zotero-build.xpi resource/config.js
}

#
# Main
#

# Create zotero-build directory if it doesn't exist, or else update it
echo "Updating Zotero build directory"
if [ ! -d "$ZOTERO_BUILD_DIR" ]; then
	git clone --recursive "$ZOTERO_BUILD_REPO" "$ZOTERO_BUILD_DIR"
	buildXPI $BRANCH
else
	cd "$ZOTERO_BUILD_DIR"
	git pull origin master
	git submodule update
fi
echo

# Create zotero-standalone-build directory if it doesn't exist, or else update it
echo "Updating Standalone build directory"
if [ ! -d "$STANDALONE_BUILD_DIR" ]; then
	git clone --recursive "$STANDALONE_BUILD_REPO" "$STANDALONE_BUILD_DIR"
	
	cd "$STANDALONE_BUILD_DIR"
	./fetch_xulrunner.sh -p "$PLATFORMS"
else
	cd "$STANDALONE_BUILD_DIR"
	git pull origin master
	git submodule update
	if [ "`git pull origin master`" != "Already up-to-date." ]; then
		./fetch_xulrunner.sh -p "$PLATFORMS"
	fi
fi
echo

# Create zotero-connectors directory if it doesn't exist, or else update it
echo "Updating connectors"
if [ ! -d "$CONNECTORS_DIR" ]; then
	git clone --recursive "$CONNECTORS_REPO" "$CONNECTORS_DIR"
else
	cd "$CONNECTORS_DIR"
	git pull origin master
	git submodule update
fi
echo

# Make sure translators directory exists and is up-to-date
echo "Updating translators"
if [ ! -d "$TRANSLATORS_DIR" ]; then
	git clone $TRANSLATORS_REPO "$TRANSLATORS_DIR"
else
	cd "$TRANSLATORS_DIR"
	git pull origin master
fi
echo

# Make output directory
mkdir -p "$OUTPUT_DIR"

# Start Xvfb on *NIX
XVFB_PID=
if [ $MAC_NATIVE != 1 -a $WIN_NATIVE != 1 -a -z ${DISPLAY:-""} ]; then
	export DISPLAY=":137"
	Xvfb "$DISPLAY" &
	XVFB_PID=$!
	echo "No available display; starting Xvfb on $DISPLAY"
fi

# Run prerun.sh if it exists
if [ -e "$SCRIPT_DIR/prerun.sh" ]; then
	. "$SCRIPT_DIR/prerun.sh"
fi

# Test
testBranch $BRANCH

# Clean up
if [ -n "$XVFB_PID" ]; then
	kill "$XVFB_PID"
fi

rm -rf "$TEMP_PROFILE_DIR"

# Run postrun.sh if it exists
if [ -e "$SCRIPT_DIR/postrun.sh" ]; then
	. "$SCRIPT_DIR/postrun.sh"
fi
