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

if [ -z "$SCRIPT_DIRECTORY" ]; then
	SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
	. "$SCRIPT_DIRECTORY/config.sh"
fi

if [ -e "/tmp/provo-ssh.pid" ]; then
	kill `cat /tmp/provo-ssh.pid`
fi

BUCKET="zotero-translator-tests"

pushd "$OUTPUT_DIRECTORY"
	outputDirName="`basename $OUTPUT_DIRECTORY`"
	
	# Upload
	for testResults in testResults*json; do
		gzip "$testResults"
		s3cmd put --add-header="Content-Encoding:gzip" "$testResults.gz" \
			"s3://$BUCKET/$outputDirName/$testResults"
		gunzip "$testResults.gz"
	done
	sleep 1
	
	# Build index
	s3cmd ls "s3://$BUCKET/$outputDirName/" | grep -o 'testResults.*\.json' | \
		awk ' BEGIN { ORS = ""; print "["; } { print "/@"$0"/@"; } END { print "]"; }' | \
		sed "s^\"^\\\\\"^g;s^\/\@\/\@^\", \"^g;s^\/\@^\"^g" > index.json
	s3cmd put index.json "s3://$BUCKET/$outputDirName/index.json"
popd