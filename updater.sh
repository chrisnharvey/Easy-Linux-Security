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
##

. /usr/local/els/variables.sh

latestversionfunc LATESTVERSION els-core

$WGET -q --output-document=$INSTALLDIR/versions $MIRROR/versions

# Checking for versions file
if [ "`$GREP els-core $INSTALLDIR/versions`" = "" ]; then
   echo "Failed to download versions file."
   echo "Aborting."
   $RM -f $INSTALLDIR/versions
   exit
fi

if [ "$CURRENTVERSION" = "$LATESTVERSION" ]; then
   echo "ELS $CURRENTVERSION is the latest release, there is no need to update."
else
   echo "Updating ELS $CURRENTVERSION to $LATESTVERSION..."
   # Downloading
   echo "Downloading ELS $LATESTVERSION..."
   $WGET -q --output-document=$INSTALLDIR/src/els-$LATESTVERSION.tar.gz $MIRROR/els-$LATESTVERSION.tar.gz
   echo "Done."
   CURRENTMD5="`$GREP -m1 els-core $INSTALLDIR/versions | $CUT -d ':' -f 3`"
   if [ "`$MD5SUM $INSTALLDIR/src/els-$LATESTVERSION.tar.gz | $CUT -d ' ' -f 1`" = "$CURRENTMD5" ]; then
           echo "MD5 valid."
   else
           echo "MD5 invalid. Aborting."
           exit
   fi
   cd $INSTALLDIR/src
   echo "Extracting..."
   $TAR -zxf els-$LATESTVERSION.tar.gz
   cd els/
   mv --force * $INSTALLDIR
   chmod -R 700 $INSTALLDIR
   cd $INSTALLDIR/src
   echo "Done."
   rm -rf els-$LATESTVERSION.tar.gz els/
   rm -f $INSTALLDIR/versions
   echo
   echo "Easy Linux Security successfully updated to $LATESTVERSION."
fi

exit 0