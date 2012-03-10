#!/bin/bash

# Copyright (c) 2012  Zotero
#                     Center for History and New Media
#                     George Mason University, Fairfax, Virginia, USA
#                     http://zotero.org
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

SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "$SCRIPT_DIRECTORY/config.sh"
TRANSLATORS_DIRECTORY="$ZSA_DIRECTORY/modules/zotero/translators"

[ "`uname`" != "Darwin" ]
MAC_NATIVE=$?
[ "`uname -o 2> /dev/null`" != "Cygwin" ]
WIN_NATIVE=$?

# Get platform and build directory
if [ $MAC_NATIVE == 1 ]; then
	PLATFORMS=m
	ZSA_STAGE_DIRECTORY="$ZSA_DIRECTORY/staging/Zotero.app"
elif [ $WIN_NATIVE == 1 ]; then
	PLATFORMS=w
	ZSA_STAGE_DIRECTORY="$ZSA_DIRECTORY/staging/Zotero_win32"
else
	PLATFORMS=l
	ZSA_STAGE_DIRECTORY="$ZSA_DIRECTORY/staging/Zotero_linux-`arch`"
fi

# Make sure temp profile directory is specified, so we don't rm -rf /
if [ -z "$TEMP_PROFILE_DIRECTORY" ]; then
	echo "No temporary profile directory specified. Exiting." 1>&2
	exit 1
fi

# Make bookmarklet config
function testBookmarklet {
	CONNECTOR_DIRECTORY="$1"
	BROWSER="$2"
	VERSION="$3"
	
	configFile="$TEMP_PROFILE_DIRECTORY/bookmarklet_config.json"
	outputFile="$OUTPUT_DIRECTORY/testResults-${BROWSER}b-$VERSION.json"
	translatorsDirectory="$TRANSLATORS_DIRECTORY"
	testPayload="$CONNECTOR_DIRECTORY/bookmarklet/tests/inject_test.js"
	jarFile="$CONNECTOR_DIRECTORY/bookmarklet/tests/test.jar"
	if [ $WIN_NATIVE == 1 ]; then
		translatorsDirectory="`cygpath -w \"$translatorsDirectory\" | sed 's/\\\\/\\\\\\\\/g'`"
		testPayload="`cygpath -w \"$testPayload\" | sed 's/\\\\/\\\\\\\\/g'`"
		configFile="`cygpath -w \"$configFile\"`"
		outputFile="`cygpath -w \"$outputFile\"`"
		jarFile="`cygpath -w \"$jarFile\"`"
	fi
	
	cat > "$configFile" <<DONE
{
	"translatorsDirectory":"$translatorsDirectory",
	"testPayload":"$testPayload",
	"concurrentTests":4,
	"browser":"$BROWSER",
	"version":"$VERSION",
	"exclude":[]
}
DONE
	java -jar "$jarFile" "$configFile" "$outputFile"
}

# Start provo
function runProvo {
	APP_DIRECTORY="$1"
	CONNECTOR_DIRECTORY="$2"
	SUFFIX="$3"
	
	# Make profile
	FIREFOX_PROFILE_DIRECTORY="$TEMP_PROFILE_DIRECTORY/firefox"
	CHROME_PROFILE_DIRECTORY="$TEMP_PROFILE_DIRECTORY/chrome"
	rm -rf "$TEMP_PROFILE_DIRECTORY"
	mkdir -p "$FIREFOX_PROFILE_DIRECTORY/extensions"
	mkdir "$FIREFOX_PROFILE_DIRECTORY/zotero"
	cp "$SCRIPT_DIRECTORY/prefs.js" "$FIREFOX_PROFILE_DIRECTORY"
	cp -r "$SCRIPT_DIRECTORY/provo@zotero.org" "$FIREFOX_PROFILE_DIRECTORY/extensions"
	
	# Test Firefox
	if [ $MAC_NATIVE == 1 ]; then
		"$APP_DIRECTORY/Contents/MacOS/zotero" -profile "$FIREFOX_PROFILE_DIRECTORY" \
		-provooutputdir "$OUTPUT_DIRECTORY" -provobrowsers "g,c,s" -provosuffix "$SUFFIX" &
	elif [ $WIN_NATIVE == 1 ]; then
		"$APP_DIRECTORY/zotero.exe" -profile "`cygpath -w \"$FIREFOX_PROFILE_DIRECTORY\"`" \
		-provooutputdir "`cygpath -w \"$OUTPUT_DIRECTORY\"`" -provobrowsers "g,c,s" -provosuffix "$SUFFIX" &
	else
		"$APP_DIRECTORY/zotero" -profile "$FIREFOX_PROFILE_DIRECTORY" \
		-provooutputdir "$OUTPUT_DIRECTORY" -provobrowsers "g,c" -provosuffix "$SUFFIX" &
	fi
	ZOTERO_PID=$!
	
	# Wait until Fx output is written to a file
	LS_OUTPUT="`ls -lad \"$OUTPUT_DIRECTORY\"`"
	while [ "`ls -lad \"$OUTPUT_DIRECTORY\"`" == "$LS_OUTPUT" ]; do
		sleep 10
	done
	
	# Test bookmarklets
	#testBookmarklet "$CONNECTOR_DIRECTORY" "g" "$SUFFIX"
	
	# Test Chrome
	if [ $MAC_NATIVE == 1 ]; then
		"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
		--user-data-dir="$CHROME_PROFILE_DIRECTORY" \
		--load-extension="$CONNECTOR_DIRECTORY/chrome" \
		--new-window "http://127.0.0.1:23119/provo/run" &
	elif [ $WIN_NATIVE == 1 ]; then
		"`cygpath \"$LOCALAPPDATA\"`"/Google/Chrome/Application/chrome \
		--user-data-dir="`cygpath -w \"$CHROME_PROFILE_DIRECTORY\"`" \
		--load-extension="`cygpath -w \"$CONNECTOR_DIRECTORY/chrome\"`" \
		--new-window "http://127.0.0.1:23119/provo/run" &
	else
		chromium --user-data-dir="$CHROME_PROFILE_DIRECTORY" \
		--load-extension="$CONNECTOR_DIRECTORY/chrome" \
		--new-window "http://127.0.0.1:23119/provo/run" &
	fi
	CHROME_PID=$!
	
	# Wait until Chrome output is written to a file
	LS_OUTPUT="`ls -lad \"$OUTPUT_DIRECTORY\"`"
	while [ "`ls -lad \"$OUTPUT_DIRECTORY\"`" == "$LS_OUTPUT" ]; do
		sleep 10
	done
	kill $CHROME_PID
	
	# Test Safari
	if [ $MAC_NATIVE == 1 -o $WIN_NATIVE == 1 ]; then
		# Clear cache
		rm -rf "$SAFARI_CACHE_DIRECTORY"
		# Update extension
		cp -r "$CONNECTOR_DIRECTORY/Zotero_Connector.safariextz" "$SAFARI_EXTENSION_LOCATION"
		# Launch Safari to run tests
		if [ $MAC_NATIVE == 1 ]; then
			"/Applications/Safari.app/Contents/MacOS/Safari" &
		elif [ $WIN_NATIVE == 1 ]; then
			"/cygdrive/c/Program Files/Safari/Safari.exe" &
		fi
		SAFARI_PID=$!
	fi
	
	wait $ZOTERO_PID
	if [ $MAC_NATIVE == 1 -o $WIN_NATIVE == 1 ]; then
		kill $SAFARI_PID
	fi
}

# Test an unpacked release
function testRelease {
	RELEASE_DIRECTORY="$1"
	SUFFIX="$2"
	
	rm -rf "$RELEASE_DIRECTORY/translators.zip" \
		"$RELEASE_DIRECTORY/translators.index" \
		"$RELEASE_DIRECTORY/translators"
	mkdir "$RELEASE_DIRECTORY/translators"
	cp -r "$TRANSLATORS_DIRECTORY/"*.js "$RELEASE_DIRECTORY/translators"
	runProvo "$RELEASE_DIRECTORY" "$ZC_DIRECTORY" "$SUFFIX"
}

# Test a branch from git
function testBranch {
	BRANCH="$1"
	
	ZSA_ZOTERO_DIRECTORY="$ZSA_DIRECTORY/modules/zotero"
	ZC_ZOTERO_DIRECTORY="$ZC_DIRECTORY/modules/zotero"
	
	pushd "$ZSA_ZOTERO_DIRECTORY"
	git checkout "$BRANCH"
	git pull
	SUFFIX="$BRANCH.SOURCE.`git log -n 1 --pretty='format:%h'`"
	popd
	
	pushd "$ZC_ZOTERO_DIRECTORY"
	git checkout "$BRANCH"
	git pull
	popd
	
	# Build connectors
	pushd "$ZC_DIRECTORY"
	git reset --hard
	git pull
	./build.sh debug
	popd
	
	# Build bookmarklet tester
	pushd "$ZC_DIRECTORY/bookmarklet/tests"
	ant
	popd
	
	# Build Zotero Standalone
	pushd "$ZSA_DIRECTORY"
	./build.sh -s "$ZSA_ZOTERO_DIRECTORY" -p "$PLATFORMS"
	runProvo "$ZSA_STAGE_DIRECTORY" "$ZC_DIRECTORY" "$SUFFIX"
	popd
}

# Make sure zotero-standalone-build directory exists, or else clone it
if [ ! -d "$ZSA_DIRECTORY" ]; then
	if [ -e "$ZSA_DIRECTORY" ]; then
		echo "Specified ZSA_DIRECTORY exists but is not a directory. Exiting." 1>&2
		exit 1
	fi
	git clone --recursive "$ZSA_REPOSITORY" "$ZSA_DIRECTORY"
	pushd "$ZSA_DIRECTORY"
	./fetch_xulrunner.sh -p "$PLATFORMS"
	popd
fi

# Make sure zotero-connectors directory exists, or else clone it
if [ ! -d "$ZC_DIRECTORY" ]; then
	if [ -e "$ZC_DIRECTORY" ]; then
		echo "Specified ZC_DIRECTORY directory exists but is not a directory. Exiting." 1>&2
		exit 1
	fi
	git clone --recursive "$ZC_REPOSITORY" "$ZC_DIRECTORY"
fi

# Make output directory
mkdir -p "$OUTPUT_DIRECTORY"

# Update translators
pushd "$TRANSLATORS_DIRECTORY"
git pull origin master
popd

# Test
testBranch 3.0

# Clean up
rm -rf "$TEMP_PROFILE_DIRECTORY"

# Run postrun.sh if it exists
if [ -e "$SCRIPT_DIRECTORY/postrun.sh" ]; then
	"$SCRIPT_DIRECTORY/postrun.sh"
fi