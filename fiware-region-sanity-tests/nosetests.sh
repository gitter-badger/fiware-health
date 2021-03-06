#!/bin/sh
#
# Copyright 2013-2015 Telefónica I+D
# All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
#

#
# Launch testcase execution and generate reports
#
# Usage:
#     $0 [options] [region ...]
#     $0 --help
#
# Options:
#     -h, --help			show this help message
#     -v, --verbose			enable logging with verbose details
#     -o, --output-name=NAME		basename for generated report files
#     -t, --template-name=NAME		filename of the HTML report template
#     -e, --phonehome-endpoint=URL	optional PhoneHome service endpoint
#     -l, --os-auth-url=URL		optional OpenStack auth_url (see below)
#     -u, --os-username=STRING		optional OpenStack username
#     -p, --os-password=STRING		optional OpenStack password
#     -i, --os-tenant-id=ID		optional OpenStack tenant_id
#     -n, --os-tenant-name=NAME		optional OpenStack tenant_name
#     -d, --os-user-domain-name=NAME	optional OpenStack user_domain_name (to
#					replace the former if Identity API v3)
#
# Environment:
#     TEST_PHONEHOME_ENDPOINT		default value for --phonehome-endpoint
#     OS_AUTH_URL			default value for --os-auth-url
#     OS_USERNAME			default value for --os-username
#     OS_PASSWORD			default value for --os-password
#     OS_TENANT_ID			default value for --os-tenant-id
#     OS_TENANT_NAME			default value for --os-tenant-name
#     OS_USER_DOMAIN_NAME		default value for --os-user-domain-name
#
# Requirements:
#     python2.7				Python 2.7 interpreter (found in path)
#
# OpenStack credentials and PhoneHome service endpoint:
#     Override values defined in 'settings.json' configuration file.
#
# Regions:
#     Valid regions are those included in 'settings.json':
#     $REGIONS
#

NAME=$(basename $0)
OPTS=`tr -d '\n ' <<END
      h(help)
      v(verbose)
      o(output-name):
      t(template-name):
      e(phonehome-endpoint):
      l(os-auth-url):
      u(os-username):
      p(os-password):
      i(os-tenant-id):
      n(os-tenant-name):
      d(os-user-domain-name):
END`

# Command line options (default values)
OUTPUT_NAME=test_results
TEMPLATE_NAME=test_report_template.html

# Environment variables for nosetests
export TEST_PHONEHOME_ENDPOINT
export OS_AUTH_URL OS_USERNAME OS_PASSWORD
export OS_TENANT_ID OS_TENANT_NAME OS_USER_DOMAIN_NAME

# Options for nosetests
TESTS=
NOSEOPTS="--logging-filter=TestCase,novaclient,neutronclient --logging-level=ERROR"

# Available regions
REGIONS=$(sed -n '/"external_network_name"/,/}/ p' resources/settings.json \
	| awk -F\" 'NF==5 {print $2}')
REGIONS_PATTERN='^\('$(echo $REGIONS | sed 's/ /\\|/g')'\)$'

# Process command line
OPTERR=
OPTSTR=$(echo :-:$OPTS | sed 's/([a-zA-Z0-9]*)//g')
OPTHLP=$(sed -n '20,/^$/ { s/$0/'$NAME'/; s/^#[ ]\?//p }' $0 | head -n -2;
	for i in $REGIONS; do printf "    \"%s\"\n" $i; done)
while getopts $OPTSTR OPT; do while [ -z "$OPTERR" ]; do
case $OPT in
'v')	NOSEOPTS="$NOSEOPTS --logging-level=DEBUG";;
'e')	TEST_PHONEHOME_ENDPOINT=$OPTARG;;
't')	TEMPLATE_NAME=$OPTARG;;
'o')	OUTPUT_NAME=$OPTARG;;
'l')	OS_AUTH_URL=$OPTARG;;
'u')	OS_USERNAME=$OPTARG;;
'p')	OS_PASSWORD=$OPTARG;;
'i')	OS_TENANT_ID=$OPTARG;;
'n')	OS_TENANT_NAME=$OPTARG;;
'd')	OS_USER_DOMAIN_NAME=$OPTARG;;
'h')	OPTERR="$OPTHLP";;
'?')	OPTERR="Unknown option -$OPTARG";;
':')	OPTERR="Missing value for option -$OPTARG";;
'-')	OPTLONG="${OPTARG%=*}";
	OPT=$(expr $OPTS : ".*\(.\)($OPTLONG):.*" '|' '?');
	if [ "$OPT" = '?' ]; then
		OPT=$(expr $OPTS : ".*\(.\)($OPTLONG).*" '|' '?')
		OPTARG=-$OPTLONG
	else
		OPTARG=$(echo =$OPTARG | cut -d= -f3)
		[ -z "$OPTARG" ] && { OPTARG=-$OPTLONG; OPT=':'; }
	fi;
	continue;;
esac; break; done; done
shift $(expr $OPTIND - 1)
while [ -z "$OPTERR" -a -n "$1" ]; do
	REGION=$(expr "$1" : "$REGIONS_PATTERN" | sed 's/.*/\L&/')
	[ -z "$REGION" ] && OPTERR="Invalid region '$1'"
	TESTS="$TESTS tests.regions.test_$REGION"
	shift
done
[ -n "$OPTERR" ] && {
	[ "$OPTERR" != "$OPTHLP" ] && OPTERR="${OPTERR}\nTry \`$NAME --help'"
	TAB=4; LEN=$(echo "$OPTERR" | awk -F'\t' '/ .+\t/ {print $1}' | wc -L)
	TABSTOPS=$TAB,$(((2+LEN/TAB)*TAB)); WIDTH=${COLUMNS:-$(tput cols)}
	printf "$OPTERR" | tr -s '\t' | expand -t$TABSTOPS | fmt -$WIDTH -s 1>&2
	exit 1
}
TESTS=${TESTS:-tests/regions}

# Main
nosetests $TESTS $NOSEOPTS -v --exe \
	--with-xunit --xunit-file=$OUTPUT_NAME.xml \
	--with-html --html-report=$OUTPUT_NAME.html \
	--html-report-template=resources/templates/$TEMPLATE_NAME

commons/results_analyzer.py $OUTPUT_NAME.xml > $OUTPUT_NAME.txt
