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

S3_PREFIX="zotero-translator-tests/output"

pushd "$OUTPUT_DIRECTORY"
	outputDirName="`dirname $OUTPUT_DIRECTORY`"
	s3cmd put index.json "s3://$S3_PREFIX/$outputDirName/index.json"
	for testResults in testResults*json; do
		gzip "$testResults"
		s3cmd put --add-header="Content-Encoding:gzip" "$testResults.gz" \
			"s3://$S3_PREFIX/$outputDirName/testResults.gz"
	done
popd