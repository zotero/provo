#!/bin/bash
SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "$SCRIPT_DIRECTORY/config.sh"
TRANSLATORS_DIRECTORY="$ZSA_DIRECTORY/modules/zotero/translators"
ZOTERO_DIRECTORY="$ZSA_DIRECTORY/modules/zotero"

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

# Start provo
function runProvo {
	APP_DIRECTORY="$1"
	SUFFIX="$2"
	
	# Make profile
	rm -rf "$TEMP_PROFILE_DIRECTORY"
	mkdir -p "$TEMP_PROFILE_DIRECTORY/extensions"
	mkdir "$TEMP_PROFILE_DIRECTORY/zotero"
	cp "$SCRIPT_DIRECTORY/prefs.js" "$TEMP_PROFILE_DIRECTORY"
	cp -r "$SCRIPT_DIRECTORY/provo@zotero.org" "$TEMP_PROFILE_DIRECTORY/extensions"
	
	# Run
	if [ $MAC_NATIVE == 1 ]; then
		"$APP_DIRECTORY/Contents/MacOS/zotero" -profile "$TEMP_PROFILE_DIRECTORY" \
		-provooutputdir "$OUTPUT_DIRECTORY" -provobrowsers "g" -provosuffix "$SUFFIX" -jsconsole
	elif [ $WIN_NATIVE == 1 ]; then
		"$APP_DIRECTORY/zotero.exe" -profile "`cygpath -w \"$TEMP_PROFILE_DIRECTORY\"`" \
		-provooutputdir "`cygpath -w \"$OUTPUT_DIRECTORY\"`" -provobrowsers "g" -provosuffix "$SUFFIX"
	else
		"$APP_DIRECTORY/zotero" -profile "$TEMP_PROFILE_DIRECTORY" \
		-provooutputdir "$OUTPUT_DIRECTORY" -provobrowsers "g" -provosuffix "$SUFFIX"
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
	runProvo "$RELEASE_DIRECTORY" "$SUFFIX"
}

# Test a branch from git
function testBranch {
	BRANCH="$1"
	
	pushd "$ZOTERO_DIRECTORY"
	git checkout "$BRANCH"
	git pull
	SUFFIX="$BRANCH.`git log -n 1 --pretty='format:%h'`"
	popd
	
	# Build from directory
	pushd "$ZSA_DIRECTORY"
	./build.sh -s "$ZOTERO_DIRECTORY" -p "$PLATFORMS"
	runProvo "$ZSA_STAGE_DIRECTORY" "$SUFFIX"
	popd
}

# Make sure zotero-standalone-build directory exists, or else clone it
if [ ! -d "$ZSA_DIRECTORY" ]; then
	if [ -e "$ZSA_DIRECTORY" ]; then
		echo "Specified zotero-standalone-build exists but is not a directory. Exiting." 1>&2
		exit 1
	fi
	git clone --recursive "$ZSA_REPOSITORY" "$ZSA_DIRECTORY"
	pushd "$ZSA_DIRECTORY"
	./fetch_xulrunner.sh -p "$PLATFORMS"
	popd
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
