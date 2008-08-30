#! /bin/bash -e
# Copyright 2006 by Steinar H. Gunderson
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 (only) of the GNU General Public License
# as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

PROGNAME=`basename $0`
MODIFIED_CONF_MSG='Default settings modified by devscripts configuration files:'

usage () {
    echo \
"Usage: $PROGNAME
  Generate a diff for an NMU and mail it to the BTS.
  $PROGNAME options:
    --new             Submit a new bug report rather than sending messages
                      to the fixed bugs (default if more than one bug being
                      closed or no bugs being closed)
    --old             Send reports to the bugs which are being closed rather
                      than submit a new bug (default if only one bug being
                      closed)
    --sendmail=SENDMAILCMD
                      Use SENDMAILCMD instead of \"/usr/sbin/sendmail -t\"
    --mutt            Use mutt to mail the message (default)
    --no-mutt         Mail the message directly, don't use mutt
    --from=EMAIL      Use EMAIL address for message to BTS; defaults to
                      value of DEBEMAIL or EMAIL
    --no-conf, --noconf
                      Don't read devscripts config files;
                      must be the first option given
    --help, -h        Show this help information.
    --version         Show version and copyright information.

$MODIFIED_CONF_MSG"
}

version () {
	cat <<EOF
This is $PROGNAME, from the Debian devscripts package, version ###VERSION###
This code is copyright 2006 by Steinar H. Gunderson, with modifications
copyright 2006 by Julian Gilbey <jdg@debian.org>.
The software may be freely redistributed under the terms and conditions
of the GNU General Public License, version 2.
EOF
}

# Boilerplate: set config variables
DEFAULT_NMUDIFF_MUTT="yes"
DEFAULT_NMUDIFF_NEWREPORT="maybe"
DEFAULT_BTS_SENDMAIL_COMMAND="/usr/sbin/sendmail"
VARS="NMUDIFF_MUTT NMUDIFF_NEWREPORT BTS_SENDMAIL_COMMAND"
# Don't think it's worth including this stuff
# DEFAULT_DEVSCRIPTS_CHECK_DIRNAME_LEVEL=1
# DEFAULT_DEVSCRIPTS_CHECK_DIRNAME_REGEX='PACKAGE(-.*)?'
# VARS="BTS_SENDMAIL_COMMAND DEVSCRIPTS_CHECK_DIRNAME_LEVEL DEVSCRIPTS_CHECK_DIRNAME_REGEX"

if [ "$1" = "--no-conf" -o "$1" = "--noconf" ]; then
    shift
    MODIFIED_CONF_MSG="$MODIFIED_CONF_MSG
  (no configuration files read)"

    # set defaults
    for var in $VARS; do
	eval "$var=\$DEFAULT_$var"
    done
else
    # Run in a subshell for protection against accidental errors
    # in the config files
    eval $(
	set +e
	for var in $VARS; do
	    eval "$var=\$DEFAULT_$var"
	done

	for file in /etc/devscripts.conf ~/.devscripts
	  do
	  [ -r $file ] && . $file
	done

	set | egrep '^(NMUDIFF|BTS|DEVSCRIPTS)_')

    # check sanity
    case "$BTS_SENDMAIL_COMMAND" in
	"") BTS_SENDMAIL_COMMAND=/usr/sbin/sendmail ;;
	*) ;;
    esac
    case "$NMUDIFF_MUTT" in
	yes|no) ;;
	*) NMUDIFF_MUTT=yes ;;
    esac
    case "$NMUDIFF_NEWREPORT" in
	yes|no|maybe) ;;
	*) NMUDIFF_NEWREPORT=maybe ;;
    esac
#    case "$DEVSCRIPTS_CHECK_DIRNAME_LEVEL" in
#	0|1|2) ;;
#	*) DEVSCRIPTS_CHECK_DIRNAME_LEVEL=1 ;;
#    esac

    # set config message
    MODIFIED_CONF=''
    for var in $VARS; do
	eval "if [ \"\$$var\" != \"\$DEFAULT_$var\" ]; then
	    MODIFIED_CONF_MSG=\"\$MODIFIED_CONF_MSG
  $var=\$$var\";
	MODIFIED_CONF=yes;
	fi"
    done

    if [ -z "$MODIFIED_CONF" ]; then
	MODIFIED_CONF_MSG="$MODIFIED_CONF_MSG
  (none)"
    fi
fi

# # synonyms
# CHECK_DIRNAME_LEVEL="$DEVSCRIPTS_CHECK_DIRNAME_LEVEL"
# CHECK_DIRNAME_REGEX="$DEVSCRIPTS_CHECK_DIRNAME_REGEX"

# Need -o option to getopt or else it doesn't work
# Removed: --long check-dirname-level:,check-dirname-regex: \
TEMP=$(getopt -s bash -o "h" \
	--long sendmail:,from:,new,old,mutt,no-mutt,nomutt \
	--long no-conf,noconf \
	--long help,version -n "$PROGNAME" -- "$@")
if [ $? != 0 ] ; then exit 1 ; fi

eval set -- $TEMP

# Process Parameters
while [ "$1" ]; do
    case $1 in
#     --check-dirname-level)
# 	shift
#         case "$1" in
# 	0|1|2) CHECK_DIRNAME_LEVEL=$1 ;;
# 	*) echo "$PROGNAME: unrecognised --check-dirname-level value (allowed are 0,1,2)" >&2
# 	   exit 1 ;;
#         esac
# 	;;
#     --check-dirname-regex)
# 	shift; 	CHECK_DIRNAME_REGEX="$1" ;;
    --mutt)
	NMUDIFF_MUTT=yes ;;
    --nomutt|--no-mutt)
	NMUDIFF_MUTT=no ;;
    --new)
	NMUDIFF_NEWREPORT=yes ;;
    --old)
	NMUDIFF_NEWREPORT=no ;;
    --sendmail)
	shift
	case "$1" in
	    "") echo "$PROGNAME: SENDMAIL command cannot be empty, using default" >&2
		;;
	    *) BTS_SENDMAIL_COMMAND="$1" ;;
        esac
        ;;
    --from)
	shift
	FROM="$1"
	;;
    --no-conf|--noconf)
	echo "$PROGNAME: $1 is only acceptable as the first command-line option!" >&2
	exit 1 ;;
    --help|-h) usage; exit 0 ;;
    --version) version; exit 0 ;;
    --)	shift; break ;;
    *) echo "$PROGNAME: bug in option parser, sorry!" >&2 ; exit 1 ;;
    esac
    shift
done

# Still going?
if [ $# -gt 0 ]; then
    echo "$PROGNAME takes no non-option arguments;" >&2
    echo "try $PROGNAME --help for usage information" >&2
    exit 1
fi

if [ "$NMUDIFF_MUTT" = yes ] && ! command -v mutt > /dev/null 2>&1; then
    echo "$PROGNAME: can't find mutt, falling back to sendmail instead" >&2
    NMUDIFF_MUTT=no
fi

if [ "$NMUDIFF_MUTT" = no ]; then
    if [ -z "$FROM" ]; then
	: ${FROMNAME:="$DEBFULLNAME"}
	: ${FROMNAME:="$NAME"}
    fi
    : ${FROM:="$DEBEMAIL"}
    : ${FROM:="$EMAIL"}
    if [ -z "$FROM" ]; then
	echo "$PROGNAME: must set email address either with DEBEMAIL environment variable" >&2
	echo "or EMAIL environment variable or using --from command line option." >&2
	exit 1
    fi
    if [ -n "$FROMNAME" ]; then
	FROM="$FROMNAME <$FROM>"
    fi
fi

if ! [ -f debian/changelog ]; then
    echo "nmudiff: must be run from top of NMU build tree!" >&2
    exit 1
fi

SOURCE=$( dpkg-parsechangelog | grep ^Source: | cut -d" " -f2 )
if [ -z "$SOURCE" ]; then
    echo "nmudiff: could not determine source package name from changelog!" >&2
    exit 1
fi

VERSION=$( dpkg-parsechangelog | grep ^Version: | cut -d" " -f2 )
if [ -z "$VERSION" ]; then
    echo "nmudiff: could not determine source package version from changelog!" >&2
    exit 1
fi

CLOSES=$( dpkg-parsechangelog | grep ^Closes: | cut -d" " -f2- )

if [ -z "$CLOSES" ]; then
    # no bug reports, so make a new report in any event
    NMUDIFF_NEWREPORT=yes
fi

if [ "$NMUDIFF_NEWREPORT" = "maybe" ]; then
    if $(expr match "$CLOSES" ".* " > /dev/null); then
	# multiple bug reports, so make a new report
	NMUDIFF_NEWREPORT=yes
    else
	NMUDIFF_NEWREPORT=no
    fi
fi

OLDVERSION=$( sed -n "s/^[^ .][^ ]* (\(.*\)).*$/\1/p" debian/changelog | \
  head -2 | tail -1 )
if [ -z "$OLDVERSION" ]; then
    echo "nmudiff: could not determine previous package version from changelog!" >&2
    exit 1
fi

VERSION_NO_EPOCH=$( echo "$VERSION" | sed "s/^[0-9]\+://" )
OLDVERSION_NO_EPOCH=$( echo "$OLDVERSION" | sed "s/^[0-9]\+://" )

if [ ! -r ../${SOURCE}_${OLDVERSION_NO_EPOCH}.dsc ]; then
    echo "nmudiff: could not read ../${SOURCE}_${OLDVERSION_NO_EPOCH}.dsc" >&2
    exit 1
fi
if [ ! -r ../${SOURCE}_${VERSION_NO_EPOCH}.dsc ]; then
    echo "nmudiff: could not read ../${SOURCE}_${VERSION_NO_EPOCH}.dsc" >&2
    exit 1
fi

debdiff ../${SOURCE}_${OLDVERSION_NO_EPOCH}.dsc \
  ../${SOURCE}_${VERSION_NO_EPOCH}.dsc \
  > ../${SOURCE}-${VERSION_NO_EPOCH}-nmu.diff
if [ $? -ne 0 ]; then
    echo "nmudiff: debdiff failed, aborting." >&2
    rm -f ../${SOURCE}-${VERSION_NO_EPOCH}-nmu.diff
    exit 1
fi

if [ "$NMUDIFF_NEWREPORT" = "yes" ]; then
    TO_ADDRESSES_SENDMAIL="submit@bugs.debian.org"
    TO_ADDRESSES_MUTT="submit@bugs.debian.org"
    BCC_ADDRESS_SENDMAIL=""
    BCC_ADDRESS_MUTT=""
    TAGS="Package: $SOURCE
Version: $OLDVERSION
Severity: normal
Tags: patch"
else
    TO_ADDRESSES_SENDMAIL=""
    TO_ADDRESSES_MUTT=""
    BCC_ADDRESS_SENDMAIL="control@bugs.debian.org"
    BCC_ADDRESS_MUTT="-b control@bugs.debian.org"
    TAGS=""
    for b in $CLOSES; do
	TO_ADDRESSES_SENDMAIL="$TO_ADDRESSES_SENDMAIL,
  $b@bugs.debian.org"
	TO_ADDRESSES_MUTT="$TO_ADDRESSES_MUTT $b@bugs.debian.org"
	TAGS="$TAGS
tags $b + patch"
    done
    TO_ADDRESSES_SENDMAIL=$(echo "$TO_ADDRESSES_SENDMAIL" | tail -n +2)
    TAGS=$(echo "$TAGS" | tail -n +2)
    TAGS="$TAGS
thanks"
fi

TMPNAM="$( tempfile )"

if [ "$NMUDIFF_MUTT" = no ]; then
    cat <<EOF > "$TMPNAM"
From: $FROM
To: $TO_ADDRESSES_SENDMAIL
Cc: 
Bcc: $BCC_ADDRESS_SENDMAIL
Subject: $SOURCE: diff for NMU version $VERSION
Date: `date -R`
X-NMUDIFF-Version: ###VERSION###

$TAGS

Hi,

The following is the diff for my $SOURCE $VERSION NMU.

EOF

    cat ../${SOURCE}-${VERSION_NO_EPOCH}-nmu.diff >> "$TMPNAM"
    sensible-editor "$TMPNAM"
    if [ $? -ne 0 ]; then
	echo "nmudiff: sensible-editor exited with error, aborting." >&2
	rm -f ../${SOURCE}-${VERSION_NO_EPOCH}-nmu.diff "$TMPNAM"
	exit 1
    fi

    echo -n "Do you want to go ahead and submit the bug report now? (y/n) "
    read response
    case "$response" in
	y*) ;;
	*)  echo "OK, then, aborting." >&2
	    rm -f ../${SOURCE}-${VERSION_NO_EPOCH}-nmu.diff "$TMPNAM"
	    exit 1
	    ;;
    esac

    case "$BTS_SENDMAIL_COMMAND" in
	/usr/sbin/sendmail*|/usr/sbin/exim*)
	    BTS_SENDMAIL_COMMAND="$BTS_SENDMAIL_COMMAND -t" ;;
	*)  ;;
    esac

    $BTS_SENDMAIL_COMMAND < "$TMPNAM"

else # NMUDIFF_MUTT=yes
    cat <<EOF > "$TMPNAM"
$TAGS

Hi,

Attached is the diff for my $SOURCE $VERSION NMU.
EOF

    mutt -s "$SOURCE: diff for NMU version $VERSION" -i "$TMPNAM" \
	-a ../${SOURCE}-${VERSION_NO_EPOCH}-nmu.diff \
	-e "my_hdr X-NMUDIFF-Version: ###VERSION###" \
	$BCC_ADDRESS_MUTT $TO_ADDRESSES_MUTT

fi

rm -f ../${SOURCE}-${VERSION_NO_EPOCH}-nmu.diff "$TMPNAM"
