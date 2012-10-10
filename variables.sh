#!/bin/sh
#
# Copyright (C) 2005-2007 Martynas Bendorius and Richard Gannon.  All Rights Reserved.
#
# Author: Martynas Bendorius <martynas@e-vaizdas.net> and Richard Gannon <rich@servermonkeys.com>
#
# For questions, comments, and support, please visit:
# www.servermonkeys.com
#
# Easy Linux Security (ELS), v. 3.0.0.0
#
########################################################################################
#    Easy Linux Security (ELS) is free software; you can redistribute it and/or modify #
#    it under the terms of the GNU General Public License as published by              #
#    the Free Software Foundation; either version 2 of the License, or                 #
#    (at your option) any later version.                                               #
#                                                                                      #
#    This program is distributed in the hope that it will be useful,                   #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of                    #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                     #
#    GNU General Public License for more details.                                      #
#                                                                                      #
#    You should have received a copy of the GNU General Public License                 #
#    along with this program; if not, write to the Free Software                       #
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA        #
########################################################################################

## Script version, installation directory, and mirror
CURRENTVERSION=3.0.0.3
INSTALLDIR=/usr/local/els
MIRROR=http://servermonkeys.com/projects/els

## Binary locations
WGET=/usr/bin/wget
REPLACE=/usr/bin/replace
GREP=/bin/grep
if [ -e /etc/debian_version ]; then
   CUT=/usr/bin/cut
else
   CUT=/bin/cut
fi
TAR=/bin/tar
CAT=/bin/cat
MD5SUM=/usr/bin/md5sum
TAIL=/usr/bin/tail
if [ -e /etc/debian_version ]; then
   AWK=/usr/bin/awk
else
   AWK=/bin/awk
fi
HEAD=/usr/bin/head
MKE2FS=/sbin/mke2fs
RPM=/bin/rpm
DPKG=/usr/bin/dpkg
RM=/bin/rm
MKDIR=/bin/mkdir

## Not so mandatory (but recommended atleast have one) binary location
YUM=/usr/bin/yum
UP2DATE=/usr/bin/up2date
APTGET=/usr/bin/apt-get

## Architecture, Number of CPUs, and RAM
if [ -e /etc/debian_version ]; then
   UNAMED=`uname -m`
   if [ "${UNAMED}" = "i686" ]; then
      ARCH=i386
   else
      ARCH=x86_64
   fi
else
   ARCH=`uname -i`
fi

CPUTOTAL=`$GREP processor /proc/cpuinfo | wc -l | $AWK '{ print $1 }'`
MEMTOTAL=`expr \`$GREP MemTotal /proc/meminfo | $AWK '{ print $2 }'\` / 1024`

## Get info for current and latest versions of software
latestversionfunc() {
   export $1=`$GREP -m1 $2 $INSTALLDIR/versions | $CUT -d ':' -f 2`
}
latestmd5func() {
   export $1=`$GREP -m1 $2 $INSTALLDIR/versions | $CUT -d ':' -f 3`
}