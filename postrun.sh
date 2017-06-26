#!/bin/bash
set -euo pipefail

if [ -z "${SCRIPT_DIR:-}" ]; then
	SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
	if [ -f "$SCRIPT_DIR/config.sh" ]; then
		. "$SCRIPT_DIR/config.sh"
	fi
fi

if [ -n "${1:-}" ]; then
	OUTPUT_DIR="$1"
fi

if [ -e "/tmp/provo-ssh.pid" ]; then
	kill `cat /tmp/provo-ssh.pid` || true
fi

BUCKET="zotero-translator-tests"

pushd "$OUTPUT_DIR" > /dev/null
	outputDirName="`basename $OUTPUT_DIR`"
	
	shopt -s nullglob
	
	# Gzip
	for file in testResults*json; do
		rm -f "$file.gz"
		gzip -f "$file"
	done
	# Upload and gunzip
	for file in testResults*gz; do
		base=${file%.gz}
		aws s3 cp --content-encoding=gzip "$file" "s3://$BUCKET/$outputDirName/$base"
		gunzip "$file"
	done
	sleep 1
	
	# Build index
	aws s3 ls "s3://$BUCKET/$outputDirName/" | grep -o 'testResults.*\.json' | \
		awk ' BEGIN { ORS = ""; print "["; } { print "/@"$0"/@"; } END { print "]"; }' | \
		sed "s^\"^\\\\\"^g;s^\/\@\/\@^\", \"^g;s^\/\@^\"^g" > index.json
	aws s3 cp index.json "s3://$BUCKET/$outputDirName/index.json"
popd > /dev/null
