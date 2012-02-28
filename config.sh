#!/bin/bash
ZSA_REPOSITORY="git://github.com/zotero/zotero-standalone-build.git"
ZSA_DIRECTORY="$SCRIPT_DIRECTORY/zotero-standalone-build"

ZC_REPOSITORY="git://github.com/zotero/zotero-connectors.git"
ZC_DIRECTORY="$SCRIPT_DIRECTORY/zotero-connectors"

TEMP_PROFILE_DIRECTORY="$SCRIPT_DIRECTORY/tmp_profile"
OUTPUT_DIRECTORY="$SCRIPT_DIRECTORY/output/`date -u +%Y-%m-%d`"
