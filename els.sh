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
##################################################################
# Easy Linux Security (ELS) is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version
#
# This program is distributed in the hope that it will be useful
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
#
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
##################################################################
##
##################################################################
## Set common variables
##################################################################

. /usr/local/els/variables.sh

if [ -e /usr/local/bin/php ]; then
  PHPBINARY=/usr/local/bin/php
elif [ -e /usr/bin/php ]; then
  PHPBINARY=/usr/bin/php
else
  PHPBINARY=php
fi

##################################################################
## Define shared functions
##################################################################

## Ensures an RPM is installed.  If not, try to install it with up2date, apt-get or yum
ensurerpm() {
   if [ "`${RPM} -q $1`" = "package $1 is not installed" ]; then
      echo "Trying to install $1..."
      if [ -f ${YUM} ]; then
         ${YUM} -y install $1
      elif [ -f ${UP2DATE} ]; then
         ${UP2DATE} -uf $1
      else
         echo "Unable to install $1."
         export $2=1
      fi
   fi
}

ensuredeb(){
   if [ "`${DPKG} -S $1`" = "dpkg: *$1* not found." ]; then
      if [ -f ${APTGET} ]; then
         ${APTGET} -y install $1
      else
         echo "Unable to install $1."
         export $2=1
      fi
   fi
}

## Our proceed prompt function
proceedfunc() {
   echo -n "Proceed? (y/n): "
   read PROCEEDASK
   until [ "${PROCEEDASK}" = "y" ] || [ "${PROCEEDASK}" = "n" ]; do
      echo -n "Please enter 'y' or 'n': "
      read PROCEEDASK
   done
}

##################################################################
## Define main program functions
##################################################################

## Make sure the script is being executed as root
rootcheck() {
   if [ "${UID}" != "0" ]; then
      echo "This program must be run as root.  Exiting."
      exit 0
   fi
}

## Make sure the necessary binaries are present
binarycheckfunc() {
   if [ ! -f $1 ]; then
      echo " >>> $1 NOT FOUND!  Aborting."
      exit
   fi
}

docheckall(){
   binarycheckfunc ${WGET}
   binarycheckfunc ${GREP}
   binarycheckfunc ${TAR}
   binarycheckfunc ${CAT}
   binarycheckfunc ${TAIL}
   if [ -e /etc/debian_version ]; then
      binarycheckfunc ${DPKG}
   else
      binarycheckfunc ${RPM}
   fi
   binarycheckfunc ${HEAD}
   binarycheckfunc ${MD5SUM}
   binarycheckfunc ${RM}
   binarycheckfunc ${MKDIR}
   if [ "${SKIPMKE2FS}" != "1" ]; then
      binarycheckfunc ${MKE2FS}
   fi

## Make sure the directories required for ELS are present
   if [ ! -d ${INSTALLDIR} ]; then
      echo "${INSTALLDIR} does not exist. Creating."
      ${MKDIR} ${INSTALLDIR}
   fi
   if [ ! -d ${INSTALLDIR}/src ]; then
      echo "${INSTALLDIR}/src does not exist. Creating."
      ${MKDIR} ${INSTALLDIR}/src
   fi
   if [ ! -d ${INSTALLDIR}/bakfiles ]; then
      echo "${INSTALLDIR}/bakfiles does not exist. Creating."
      ${MKDIR} ${INSTALLDIR}/bakfiles
   fi

   ## Let's put a link to the ELS binary in the user's PATH to make it easier to call
   if [ ! -e /usr/local/bin/els ]; then
      ln -s /usr/local/els/els.sh /usr/local/bin/els
      NEWBINSYM=1
   fi

   echo "If you got no errors then everything is okay."
}

supporteddistros(){
## Make sure this is a supported distribution
   if [ -e /etc/redhat-release ]; then
      if [ "`${CAT} /etc/redhat-release | ${AWK} '{ print $1, $2, $3, $7 }'`" = "Red Hat Enterprise 3" ]; then
         DISTRO=RHEL3
      elif [ "`${CAT} /etc/redhat-release | ${AWK} '{ print $1, $2, $3, $7 }'`" = "Red Hat Enterprise 4" ]; then
         DISTRO=RHEL4
      elif [ "`${CAT} /etc/redhat-release | ${AWK} '{ print $1, $3 }' | ${CUT} -d '.' -f1`" = "CentOS 3" ]; then
         DISTRO=CENTOS3
      elif [ "`${CAT} /etc/redhat-release | ${AWK} '{ print $1, $3 }' | ${CUT} -d '.' -f1`" = "CentOS 4" ]; then
         DISTRO=CENTOS4
      elif [ "`${CAT} /etc/redhat-release | ${AWK} '{ print $1, $3 }' | ${CUT} -d '.' -f1`" = "CentOS 5" ]; then
         DISTRO=CENTOS5
      elif [ "`${CAT} /etc/redhat-release | ${AWK} '{ print $1, $2 }'`" = "Fedora Core" ]; then
         DISTRO=FC`${CAT} /etc/redhat-release | ${AWK} '{ print $4 }'`
      elif [ "`${CAT} /etc/redhat-release | ${AWK} '{ print $1, $2 }'`" = "Fedora release" ]; then
         DISTRO=FC`${CAT} /etc/redhat-release | ${AWK} '{ print $3 }'`
      elif [ "`${CAT} /etc/redhat-release | ${AWK} '{ print $1, $2, $5 }'`" = "Red Hat 9" ]; then
         DISTRO=RH9
      elif [ "`${CAT} /etc/redhat-release | ${AWK} '{ print $1, $2, $5 }' | ${CUT} -d '.' -f1`" = "Red Hat 7" ]; then
         DISTRO=RH7
      fi
   elif [ -e /etc/debian_version ]; then
      if [ "`${CAT} /etc/debian_version`" = "3.1" ] || [ "`${CAT} /etc/debian_version`" = "3.0" ]; then
         DISTRO=DEBIAN3
      fi
   elif [ ! -e /etc/redhat-release ] || [ ! -e /etc/debian_version ]; then
      echo "FAILED"
      echo "Can not determine your Linux distribution."
      echo "To prevent complications, this script will stop now."
      echo "Please contact an experienced adminstrator to do this for you."
      exit
   fi
}

dodistrocheck(){
   if [ -e /etc/redhat-release ]; then
      if [ "`${CAT} /etc/redhat-release | ${AWK} '{ print $1, $2, $3, $7 }'`" = "Red Hat Enterprise 3" ]; then
         echo "Your OS is: RedHat Enterprise Linux 3"
      elif [ "`${CAT} /etc/redhat-release | ${AWK} '{ print $1, $2, $3, $7 }'`" = "Red Hat Enterprise 4" ]; then
         echo "Your OS is: RedHat Enterprise Linux 4"
      elif [ "`${CAT} /etc/redhat-release | ${AWK} '{ print $1, $3 }' | ${CUT} -d '.' -f1`" = "CentOS 3" ]; then
         echo "Your OS is: CentOS 3"
      elif [ "`${CAT} /etc/redhat-release | ${AWK} '{ print $1, $3 }' | ${CUT} -d '.' -f1`" = "CentOS 4" ]; then
         echo "Your OS is: CentOS 4"
      elif [ "`${CAT} /etc/redhat-release | ${AWK} '{ print $1, $3 }' | ${CUT} -d '.' -f1`" = "CentOS 5" ]; then
         echo "Your OS is: CentOS 5"
      elif [ "`${CAT} /etc/redhat-release | ${AWK} '{ print $1, $2 }'`" = "Fedora Core" ]; then
         echo "Your OS is: Fedora Core `${CAT} /etc/redhat-release | ${AWK} '{ print $4 }'`"
      elif [ "`${CAT} /etc/redhat-release | ${AWK} '{ print $1, $2 }'`" = "Fedora release" ]; then
         echo "Your OS is: Fedora Core `${CAT} /etc/redhat-release | ${AWK} '{ print $3 }'`"
      elif [ "`${CAT} /etc/redhat-release | ${AWK} '{ print $1, $2, $5 }'`" = "Red Hat 9" ]; then
         echo "Your OS is: RedHat Linux 9"
      elif [ "`${CAT} /etc/redhat-release | ${AWK} '{ print $1, $2, $5 }' | ${CUT} -d '.' -f1`" = "Red Hat 7" ]; then
         echo "Your OS is: RedHat Linux 7"
      elif [ "`${CAT} /etc/debian_version`" = "3.0" ]; then
         echo "Your OS is: Debian linux 3.0"
      fi
   elif [ -e /etc/debian_version ]; then
      if [ "`${CAT} /etc/debian_version`" = "3.1" ]; then
         echo "Your OS is: Debian linux 3.1"
      fi
   fi
}

## Check to see if cPanel, Plesk, or DirectAdmin is installed
controlpanelcheck() {
   if [ -f /usr/local/cpanel/cpanel ]; then
      CONTROLPANEL=1
      PHPINI=/usr/local/lib/php.ini
   elif [ -f /usr/local/psa/version ]; then
      CONTROLPANEL=2
      PHPINI=/etc/php.ini
   elif [ -f /usr/local/directadmin/conf/directadmin.conf ]; then
      CONTROLPANEL=3
      PHPINI=/usr/local/lib/php.ini
   else
      CONTROLPANEL=0
      PHPINI=/etc/php.ini
   fi
}

## Check to see if cPanel, Plesk, or DirectAdmin is installed
docontrolpanelvcheck() {
   if [ -f /usr/local/cpanel/cpanel ]; then
      echo "cPanel is installed. [ Version: `/usr/local/cpanel/cpanel -V` ]"
   elif [ -f /usr/local/psa/version ]; then
      PLESKVERS=`${CAT} /usr/local/psa/version`
      echo "PLESK is installed. [ Version: ${PLESKVERS} ]"
   elif [ -f /usr/local/directadmin/conf/directadmin.conf ]; then
      echo "DirectAdmin is installed. [ `/usr/local/directadmin/directadmin v` ]"
   else
      echo "cPanel, Plesk, or DirectAdmin not detected."
   fi
}

checkversionsdown(){
   ${WGET} -q --output-document=${INSTALLDIR}/versions ${MIRROR}/versions
   if [ "`${GREP} els-core ${INSTALLDIR}/versions`" = "" ]; then
      echo "Failed to download versions file."
      echo "Aborting."
      ${RM} -f ${INSTALLDIR}/versions
      exit
   else
      latestversionfunc LATESTVERSION els-core
   fi
   PHPINSTALLED=0
   if [ "${SKIPCURRENTS}" != "1" ]; then
      if [ "`${PHPBINARY} -v | ${HEAD} -1 | ${AWK} '{ print $1 }'`" = "PHP" ]; then
         PHPINSTALLED=1
      fi
   fi
}

##################################################################
# End of checks
##################################################################

## Get the administrator's email address (used for several program installations)
adminemail() {
   if [ "${ADMINEMAIL}" = "" ]; then
   echo
   echo "Admin (your) E-Mail Address (this should NOT be on this server):"
   read ADMINEMAIL
     if [ "${ADMINEMAIL}" = "" ]; then
        echo "You entered no email address"
     else
        echo "You entered: ${ADMINEMAIL}"
     fi
   echo "Ensure this is correct."
   proceedfunc
     if [ "${PROCEEDASK}" = "y" ]; then
        echo "Using ${ADMINEMAIL}."
     else
      adminemail
   fi
   fi
}

## Get that administrator's IP address (used for APF and BFD installations)
adminip() {
   if [ "${ADMINIP}CHK" = "" ] || [ "$1" = "0" ]; then
   echo
   echo "If an admin attempts to login too many times with a bad password"
   echo "BFD will ban the IP address, leaving the admin locked out of his/her"
   echo "own server.  To prevent this, please enter your home or work IP address."
   echo "Allowed IP Address (blank for none):"
   read ADMINIP
   ADMINIPCHK=1
   if [ "${ADMINIP}" = "" ]; then
      echo "You entered no IP address"
   else
      echo "You entered: ${ADMINIP}"
   fi
   echo "Ensure this is correct."
   proceedfunc
   if [ "${PROCEEDASK}" = "y" ]; then
      echo "Using ${ADMINIP} for Admin IP."
   else
      adminip 0
   fi
   fi
}

doversioncheck(){
   if [ "${CURRENTVERSION}" = "${LATESTVERSION}" ]; then
      echo "ELS version is ${CURRENTVERSION}. It is the latest release, there is no need to update."
   else
      echo "ELS version is: ${CURRENTVERSION}. The latest version is ${LATESTVERSION}."
   fi
}

## See if we want to modify up2date's configuration file
up2dateconfig() {
   if [ "${CONTROLPANEL}" = "1" ] || [ "${CONTROLPANEL}" = "3" ] && [ -f $UP2DATE ]; then
      echo
      if [ "`${GREP} "Modified by ELS" /etc/sysconfig/rhn/up2date`" = "" ]; then
         echo "Several packages from Red Hat Network may not be compatable or may cause"
         echo "problems with DirectAdmin or cPanel.  To help prevent complications, ELS can add special"
         echo "packages to be skipped when running up2date."
         echo "These packages can still be updated using the force '-f' option with up2date."
         proceedfunc
         if [ "${PROCEEDASK}" = "y" ]; then
            GREPPED="`${GREP} pkgSkipList= /etc/sysconfig/rhn/up2date`"
            perl -pi -e "s/${GREPPED}/pkgSkipList=kernel*;php*;*httpd*;perl*;mysql*;mod_*;imap*;squirrelmail*;spamassassin*;caching-nameserver*;/" /etc/sysconfig/rhn/up2date
            echo 'Done.'
            echo "#Modified by ELS" >> /etc/sysconfig/rhn/up2date
         else
            echo "Skipping up2date configuration editor."
         fi
      else
         echo "up2date configuration already modified by ELS."
      fi
   fi
}

## See if we want to modify yum's configuration file
yumconfig() {
   if [ "${CONTROLPANEL}" = "1" ] || [ "${CONTROLPANEL}" = "3" ] && [ -f $YUM ]; then
      echo
      if [ "`${GREP} "Modified by ELS" /etc/yum.conf`" = "" ]; then
         echo "Several packages installed by yum may not be compatable or may cause"
         echo "problems with DirectAdmin or cPanel.  To help prevent complications, ELS can add special"
         echo "packages to be skipped when running yum."
         echo "These packages can still be updated manually with yum."
         proceedfunc
         if [ "${PROCEEDASK}" = "y" ]; then
            if [ "`${GREP} exclude= /etc/yum.conf`" = "" ]; then
               perl -pi -e "s/\[main]/\[main]\nexclude=kernel* php* exim* courier* httpd* perl* mysql* mod_* imap* squirrelmail* spamassassin* caching-nameserver*/" /etc/yum.conf
            else
               GREPPED="`${GREP} exclude= /etc/yum.conf`"
               perl -pi -e "s/${GREPPED}/exclude=kernel* php* exim* courier* apache* httpd* perl* mysql* mod_* imap* squirrelmail* spamassassin* caching-nameserver*/" /etc/yum.conf
            fi
            echo "Done."
            echo "#Modified by ELS" >> /etc/yum.conf
         else
            echo "Skipping yum configuration editor."
         fi
      else
         echo "yum configuration already modified by ELS."
      fi
   fi
}


doupdateda(){
   if [ "${CONTROLPANEL}" = "3" ]; then
      echo
      echo "This feature can update your DirectAdmin version."
      proceedfunc
      if [ "${PROCEEDASK}" = "y" ]; then
        if [ -f /usr/local/directadmin/conf/directadmin.conf ]; then
          echo "[ `/usr/local/directadmin/directadmin v` ] found"
        else
          echo "DirectAdmin not found!"
          exit 0
        fi
        if [ -f /usr/local/directadmin/scripts/setup.txt ]; then
         echo "Downloading a new version of DirectAdmin..."
         cd /usr/local/directadmin
         ${WGET} -O update.tar.gz https://www.directadmin.com/cgi-bin/daupdate?uid=`${GREP} uid= /usr/local/directadmin/scripts/setup.txt | ${CUT} -d= -f2`\&lid=`${GREP} lid= /usr/local/directadmin/scripts/setup.txt | ${CUT} -d= -f2`
         echo "Extracting a new version of DirectAdmin..."
         tar xzf update.tar.gz
         ${RM} -rf update.tar.gz
         ./directadmin p
         cd scripts
         ./update.sh
         echo "Restarting DirectAdmin..."
         service directadmin restart
         echo "Update done."
        else
         echo "/usr/local/directadmin/scripts/setup.txt not found."
        fi
      else
         echo "Not updating DirectAdmin."
      fi
   else
      echo "DirectAdmin is not installed."
   fi
}

## Uninstall LAuS if installed (Thanks to chirpy on the cPanel forums for the instructions)
doremovelaus() {
   if [ "${SKIPCURRENTS}" != "1" ]; then
      if [ "${DISTRO}" != "DEBIAN3" ]; then
        if [ "`${RPM} -q laus`" != "package laus is not installed" ]; then
           LAUSINSTALL=1
        fi
      fi
   fi
   if [ "${CONTROLPANEL}" = "1" ] && [ "${LAUSINSTALL}" = "1" ]; then
      echo
      echo "LAuS often causes an excessive amount of audit logs on a cPanel server."
      echo "This can sometimes cause high CPU usage and large usage of space in /var."
      echo "This feature will uninstall LAuS for you."
      proceedfunc
      if [ "${PROCEEDASK}" = "y" ]; then
         echo "Uninstalling LAuS..."
         ${RPM} -ev laus
         echo "alias char-major-10-224 off" >> /etc/modules.conf
         echo "Done."
         echo "Restarting the CRON deamon..."
         /etc/init.d/crond stop
         rmmod audit
         /etc/init.d/crond start
         echo "Done."
         echo "Deleting old audit.d logs..."
         sleep 1
         ${RM} -Rfv /var/log/audit.d/
         echo "Done."
      else
         echo "Not uninstalling LAuS."
      fi
   fi
   if [ "${DOALL}" != "1" ]; then
      ${RM} -f ${INSTALLDIR}/versions
   fi
}

## Disable SELinux (for DirectAdmin or cPanel servers)
dodisableselinux() {
   if [ "${CONTROLPANEL}" = "1" ] || [ "${CONTROLPANEL}" = "3" ] && [ -e /etc/sysconfig/selinux ]; then
      echo
      if [ ! -e /usr/sbin/sestatus ]; then
         echo "Can not find /usr/sbin/sestatus"
      elif [ "`/usr/sbin/sestatus -v | ${AWK} '{print $3}'`" != "disabled" ]; then
         echo "SELinux is currently enabled.  DirectAdmin and cPanel does not work well with"
         echo "SELinux enabled.  ELS can now disable SELinux so cPanel or DirectAdmin"
         echo "and related programs can run properly."
         proceedfunc
         if [ "${PROCEEDASK}" = "y" ]; then
            echo "Disabling SELinux..."
            GREPPED1="`${GREP} 'SELINUX=' /etc/sysconfig/selinux | ${TAIL} -n1`"
            GREPPED2="`${GREP} 'SELINUX=' /etc/selinux/config | ${TAIL} -n1`"
            perl -pi -e "s/$GREPPED1/SELINUX=disabled/" /etc/sysconfig/selinux
            perl -pi -e "s/$GREPPED2/SELINUX=disabled/" /etc/selinux/config
            setenforce 0
            echo "Done"
         else
            echo "Not disabling SELinux."
         fi
      else
         echo "SELinux already disabled."
      fi
   fi
}

## See if we want to harden sysctl.conf
dohardensysctl() {
   sysctldo() {
      latestmd5func SYSCTLMD5 sysctl.conf
      proceedfunc
      if [ "${PROCEEDASK}" = "y" ]; then
         ${WGET} -q --output-document=${INSTALLDIR}/src/sysctl.conf ${MIRROR}/sysctl/sysctl.conf
         if [ "`${MD5SUM} ${INSTALLDIR}/src/sysctl.conf | ${CUT} -d ' ' -f 1`" = $SYSCTLMD5 ]; then
            echo "Download Successful!"
            echo "MD5 matches."
            echo "Extracting..."
         else
            echo "Download Failed."
            echo "Invalid MD5."
            echo "Aborting."
            exit
         fi
         if [ -f /etc/sysctl.conf ]; then
            mv --force /etc/sysctl.conf ${INSTALLDIR}/bakfiles/sysctl.conf
         fi
         mv --force ${INSTALLDIR}/src/sysctl.conf /etc/sysctl.conf
         chown root:root /etc/sysctl.conf
         chmod 644 /etc/sysctl.conf
         echo "Applying changes..."
         /sbin/sysctl -p
         echo "Done."
         echo "Errors with 'unknown keys' can be ignored."
      else
         echo "Not hardening kernel with sysctl."
      fi
   }
   echo
   if [ -f /etc/sysctl.conf ]; then
      echo "/etc/sysctl.conf exists."
      if [ "`${GREP} nsobuild /etc/sysctl.conf`" != "" ]; then
         echo "sysctl already hardened by ELS."
      else
         echo "sysctl is used to harden the kernel.  If you have not hardened your"
         echo "kernel with sysctl or do not know how to, it is recommended to have"
         echo "ELS do it for you.  Your current /etc/sysctl.conf will be backed up to"
         echo "${INSTALLDIR}/bakfiles/sysctl.conf."
         sysctldo
      fi
   else
      echo "/etc/sysctl.conf does not exist.  It is usually a"
      echo "good idea to use sysctl to harden your kernel."
      echo "I can import a commonly used and tested sysctl.conf"
      echo "to harden and slightly optimize your kernel."
      sysctldo
   fi
   if [ "${DOALL}" != "1" ]; then
      ${RM} -f ${INSTALLDIR}/versions
   fi
}

## See if we want to run cPanel's update scripts
docpanelupdate() {
   if [ "${CONTROLPANEL}" = "1" ]; then
      echo
      echo "This will only run cPanel's pre-installed scripts to update itself."
      echo "updatenow, upcp, sysup, and serveral other software updaters will be executed."
      if [ "$MYSQL41UPDATE" = "1" ]; then
         PROCEEDASK=y
      else
         proceedfunc
      fi
      if [ "${PROCEEDASK}" = "y" ]; then
         /scripts/upcp
      else
         echo "Skipping cPanel updates."
      fi
   fi
}

## Fix RNDC if not already configured
dofixrndc() {
   if [ "${CONTROLPANEL}" = "1" ]; then
      echo
      echo "Checking rndc..."
      if [ "`${GREP} 'key \"rndckey\" {' /etc/named.conf`" = "" ] && [ "`${GREP} '/etc/rndc.key' /etc/named.conf`" = "" ]; then
         echo "rndc is not configured, but I can fix that!"
         proceedfunc
         if [ "${PROCEEDASK}" = "y" ]; then
            /scripts/fixnamed
            /scripts/fixndc
            /etc/init.d/named restart
            echo "Done."
            echo "If still failed, run /scripts/fixndc manually."
         else
            echo "Not fixing RNDC."
         fi
      else
         echo "rndc already configured."
      fi
   fi
}

## Tweak cPanel's Tweak Settings file
dotweakcpsettings() {
   if [ "${CONTROLPANEL}" = "1" ]; then
      echo
      echo "ELS can tweak several cPanel/WHM settings for you to further"
      echo "optimize and secure your server."
      proceedfunc
      if [ "${PROCEEDASK}" = "y" ]; then
         if [ "`${GREP} defaultmailaction /var/cpanel/cpanel.config`" = "" ]; then
            echo "Setting Default Mail Action to FAIL..."
            echo "defaultmailaction=fail" >> /var/cpanel/cpanel.config
            echo "Done."
         elif [ "`${GREP} defaultmailaction /var/cpanel/cpanel.config | ${CUT} -d '=' -f 2`" != "fail" ]; then
            echo "Setting Default Mail Action to FAIL..."
            GREPPED="`${GREP} defaultmailaction /var/cpanel/cpanel.config`"
            perl -pi -e "s/${GREPPED}/defaultmailaction=fail/" /var/cpanel/cpanel.config
            echo "Done."
         else
            echo "Default Mail Action already set to FAIL."
         fi
         if [ "`${GREP} cycle /var/cpanel/cpanel.config`" = "" ]; then
            echo "Setting stats programs to run every 12 hours..."
            echo "cycle=0.5" >> /var/cpanel/cpanel.config
            echo "Done."
         elif [ ! "`${GREP} cycle /var/cpanel/cpanel.config | ${CUT} -d '=' -f 2`" = "0.5" ]; then
            echo "Setting stats programs to run every 12 hours..."
            GREPPED="`${GREP} cycle /var/cpanel/cpanel.config`"
            perl -pi -e "s/${GREPPED}/cycle=0.5/" /var/cpanel/cpanel.config
            echo "Done."
         else
            echo "Stats programs already set to run every 12 hours (or less)."
         fi
         if [ "`${GREP} jaildefaultshell /var/cpanel/cpanel.config`" = "" ]; then
            echo "Setting jailshell as default shell..."
            echo "jaildefaultshell=1" >> /var/cpanel/cpanel.config
            echo "Done."
         elif [ "`${GREP} jaildefaultshell /var/cpanel/cpanel.config | ${CUT} -d '=' -f 2`" != "1" ]; then
            echo "Setting jailshell as default shell..."
            GREPPED="`${GREP} jaildefaultshell /var/cpanel/cpanel.config`"
            perl -pi -e "s/${GREPPED}/jaildefaultshell=1/" /var/cpanel/cpanel.config
            echo "Done."
         else
            echo "Jailshell already set as default shell."
         fi
         if [ "`${GREP} resetpass /var/cpanel/cpanel.config`" = "" ]; then
            echo "Disabling ability for cPanel users to reser pass via email..."
            echo "resetpass=0" >> /var/cpanel/cpanel.config
            echo "Done."
         elif [ "`${GREP} resetpass /var/cpanel/cpanel.config | ${CUT} -d '=' -f 2`" != "0" ]; then
            echo "Disabling ability for cPanel users to reser pass via email..."
            GREPPED="`${GREP} resetpass /var/cpanel/cpanel.config`"
            perl -pi -e "s/${GREPPED}/resetpass=0/" /var/cpanel/cpanel.config
            echo "Done."
         else
            echo "cPanel password reset over email already disabled."
         fi
         if [ "`${GREP} maxmem /var/cpanel/cpanel.config`" = "" ]; then
            echo "Setting max memory usage to 512MB..."
            echo "maxmem=512" >> /var/cpanel/cpanel.config
            echo "Done."
         elif [ "`${GREP} maxmem /var/cpanel/cpanel.config | ${CUT} -d '=' -f 2`" -lt "512" ]; then
            echo "Setting max memory usage to 512MB..."
            GREPPED="`${GREP} maxmem /var/cpanel/cpanel.config`"
            perl -pi -e "s/${GREPPED}/maxmem=512/" /var/cpanel/cpanel.config
            echo "Done."
         else
            echo "Max memory usage already set to 512 (or more) MB."
         fi
         if [ "`${GREP} dumplogs /var/cpanel/cpanel.config`" = "" ]; then
            echo "Setting domain logs to be deleted after logrunner executes..."
            echo "dumplogs=1" >> /var/cpanel/cpanel.config
            echo "Done."
         elif [ "`${GREP} dumplogs /var/cpanel/cpanel.config | ${CUT} -d '=' -f 2`" != "1" ]; then
            echo "Setting domain logs to be deleted after logrunner executes..."
            GREPPED="`${GREP} dumplogs /var/cpanel/cpanel.config`"
            perl -pi -e "s/${GREPPED}/dumplogs=1/" /var/cpanel/cpanel.config
            echo "Done."
         else
            echo "Domain logs already set to be deleted after logrunner executes."
         fi
         if [ "`${GREP} phpopenbasedirhome /var/cpanel/cpanel.config`" = "" ]; then
            echo "Enabling PHP open_basedir Protection..."
            echo "phpopenbasedirhome=1" >> /var/cpanel/cpanel.config
            /scripts/phpopenbasectl on
            echo "Done."
         elif [ "`${GREP} phpopenbasedirhome /var/cpanel/cpanel.config | ${CUT} -d '=' -f 2`" != "1" ]; then
            echo "Enabling PHP open_basedir Protection..."
            GREPPED="`${GREP} phpopenbasedirhome /var/cpanel/cpanel.config`"
            perl -pi -e "s/${GREPPED}/phpopenbasedirhome=1/" /var/cpanel/cpanel.config
            /scripts/phpopenbasectl on
            echo "Done."
         else
            echo "PHP open_basedir Protection already enabled."
         fi
         if [ "`${GREP} userdirprotect /var/cpanel/cpanel.config`" = "" ]; then
            echo "Enabling mod_userdir Protection..."
            echo "userdirprotect=1" >> /var/cpanel/cpanel.config
            /scripts/userdirctl on
            echo "Done."
         elif [ "`${GREP} userdirprotect /var/cpanel/cpanel.config | ${CUT} -d '=' -f 2`" != "1" ]; then
            echo "Enabling mod_userdir Protection..."
            GREPPED="`${GREP} userdirprotect /var/cpanel/cpanel.config`"
            perl -pi -e "s/${GREPPED}/userdirprotect=1/" /var/cpanel/cpanel.config
            /scripts/userdirctl on
            echo "Done."
         else
            echo "mod_userdir Protection already enabled."
         fi
         if [ -f /var/cpanel/smtpgidonlytweak ]; then
            echo "SMTP Tweak already enabled."
         else
            echo "Enabling SMTP Tweak..."
            /scripts/smtpmailgidonly --allowlocalhost on
            echo "Done."
         fi
         if [ "`/scripts/compilers | ${GREP} disabled`" = "" ]; then
            echo "Disabling compilers for unprivileged users..."
            /scripts/compilers off
            echo "Done."
         else
            echo "Compilers already disabled for unprivileged users."
         fi
      else
         echo "Skipping WHM Tweak Settings tweaks."
      fi
   fi
}

## Add an alert for root login to /root/.bash_profile
dorootloginemail() {
   echo
   if [ "`${GREP} ALERT /root/.bash_profile`" = "" ]; then
      if [ "${ADMINEMAIL}" != "" ]; then
         echo "ELS can have an alert email sent to you each time someone logs in as root."
         proceedfunc
         if [ "${PROCEEDASK}" = "y" ]; then
           chattr -i /root/.bash_profile
            echo >> /root/.bash_profile
            echo "# Email admin when user logs in as root" >> /root/.bash_profile
            echo "rootalert() {" >> /root/.bash_profile
            echo "  echo 'ALERT - Root Shell Login'" >> /root/.bash_profile
            echo "  echo" >> /root/.bash_profile
            echo "  echo 'Server: '\`hostname\`" >> /root/.bash_profile
            echo "  echo 'Time: '\`date\`" >> /root/.bash_profile
            echo "  echo 'User: '\`who | awk '{ print \$1 }'\`" >> /root/.bash_profile
            echo "  echo 'TTY: '\`who | awk '{ print \$2 }'\`" >> /root/.bash_profile
            echo "  echo 'Source: '\`who | awk '{ print \$5 }' | ${CUT} -d '(' -f 2 | ${CUT} -d ')' -f 1\`" >> /root/.bash_profile
            echo "  echo" >> /root/.bash_profile
            echo "  echo" >> /root/.bash_profile
            echo "  echo 'This email is an alert automatically created by your server telling you that someone, even if it is you, logged into SSH as the root user.  If you or someone you know and trust logged in as root, disregard this email.  If you or someone you know and trust did not login to the server as root, then you may have a hack attempt in progress on your server.'" >> /root/.bash_profile
            echo "}" >> /root/.bash_profile
            echo "rootalert | mail -s \"Alert: Root Login [\`hostname\`]\" ${ADMINEMAIL}" >> /root/.bash_profile
            chattr +i /root/.bash_profile
            echo "Root login alerts enabled."
         else
            echo "Not enabling root login alerts."
         fi
      else
         echo "Must provide Admin Email Address to enable Root Login Alerts."
      fi
   else
      echo "Root login alerts already enabled."
   fi
}

## Install/Update RKHunter
dorkhunter() {
   echo
   if [ "${SKIPCURRENTS}" != "1" ]; then
         latestversionfunc LATESTRKH rkh-latest
         latestmd5func RKHMD5 rkh-latest
      if [ -f /usr/local/bin/rkhunter ]; then
         CURRENTRKH=`/usr/local/bin/rkhunter --version | ${AWK} '{ print $3 }'`
      fi
   fi
   if [ "${CURRENTRKH}" != "${LATESTRKH}" ]; then
      if [ -d /usr/local/rkhunter ]; then
         echo "RKHunter is out of date.  Installed: ${CURRENTRKH} Latest: ${LATESTRKH}"
         echo "ELS can now update RKHunter."
      else
         echo "ELS can now install RKHunter."
      fi
      proceedfunc
      if [ "${PROCEEDASK}" = "y" ]; then
         cd ${INSTALLDIR}/src
         ${RM} -rf rkhunter*
         echo "Downloading RKHunter..."
         ${WGET} -q ${MIRROR}/rkhunter/rkhunter-${LATESTRKH}.tar.gz
         if [ "`${MD5SUM} rkhunter-${LATESTRKH}.tar.gz | ${CUT} -d ' ' -f 1`" = "${RKHMD5}" ]; then
            echo "Download Successful!"
            echo "MD5 matches."
            echo "Extracting..."
         else
            echo "Download Failed."
            echo "Invalid MD5."
            echo "Aborting."
            exit
         fi
         ${TAR} xzf rkhunter-${LATESTRKH}.tar.gz
         ${RM} -f rkhunter-${LATESTRKH}.tar.gz
         cd rkhunter-${LATESTRKH}
         if [ -f ./installer.sh ]; then
            echo "Extraction Successful!"
         else
            echo "Extraction failed."
            echo "Aborting."
            exit
         fi
         echo "Installing..."
         ./installer.sh --layout /usr/local --install
         cd ${INSTALLDIR}/src
         ${RM} -rf rkhunter*
         echo "RKHunter Install Completed Successfully!"
         echo "Updating databases..."
         /usr/local/bin/rkhunter --update
      else
         echo "Not installing/updating RKHunter"
      fi
   else
      echo "RKHunter is up to date [ Version: ${CURRENTRKH} ]"
      echo "Updating RKHunter database files..."
      /usr/local/bin/rkhunter --update
   fi
   if [ "${DOALL}" != "1" ]; then
      ${RM} -f ${INSTALLDIR}/versions
   fi
}

## Install a RKHunter cronjob (to run nightly)
dorkhuntercron() {
   if [ -e /usr/local/bin/rkhunter ]; then
      echo
      if [ -f /etc/cron.daily/rkhunter.sh ]; then
         echo "RKHunter Cronjob already installed."
      else
         if [ "${ADMINEMAIL}" != "" ]; then
            echo "Would you like for RKHunter to run and send you scan details"
            echo "to your admin email address nightly? (y/n):"
            proceedfunc
            if [ "${PROCEEDASK}" = "y" ]; then
               echo '#!/bin/bash'$'\n''(/usr/local/bin/rkhunter --update && /usr/local/bin/rkhunter -c --cronjob 2>&1 | mail -s "RKhunter Scan Details"' ${ADMINEMAIL}')' > /etc/cron.daily/rkhunter.sh
               chmod 700 /etc/cron.daily/rkhunter.sh
            else
               echo "RKHunter will not run nightly.  You can execute manually with"
               echo "/usr/local/bin/rkhunter -c"
            fi
         else
            echo "Must provide Admin Email Address to install RKHunter Cronjob."
         fi
      fi
   fi
}

## Install/Update CHKROOTKIT
dochkrootkit() {
   echo
   if [ "${SKIPCURRENTS}" != "1" ]; then
      latestversionfunc LATESTCRK chkrootkit-latest
      latestmd5func CRKMD5 chkrootkit-latest
      if [ -f /usr/local/chkrootkit/chkrootkit ]; then
         CURRENTCRK=`${GREP} 'CHKROOTKIT_VERSION=' /usr/local/chkrootkit/chkrootkit | ${CUT} -d "'" -f 2`
      fi
   fi
   if [ "${CURRENTCRK}" != "${LATESTCRK}" ]; then
      if [ -d /usr/local/chkrootkit ]; then
         echo "CHKROOTKIT is out of date.  Installed: ${CURRENTCRK} Latest: ${LATESTCRK}"
         echo "ELS can now update CHKROOTKIT."
      else
         echo "ELS can now install CHKROOTKIT."
      fi
      proceedfunc
      if [ "${PROCEEDASK}" = "y" ]; then
         cd ${INSTALLDIR}/src
            ${RM} -rf chkrootkit*
         echo "Downloading CHKROOTKIT..."
         ${WGET} -q  ${MIRROR}/chkrootkit/chkrootkit-${LATESTCRK}.tar.gz
         if [ "`${MD5SUM} chkrootkit-${LATESTCRK}.tar.gz | ${CUT} -d ' ' -f 1`" = ${CRKMD5} ]; then
            echo "Download Successful!"
            echo "MD5 matches."
            echo "Extracting..."
         else
            echo "Download Failed."
            echo "Invalid MD5."
            echo "Aborting."
            exit
         fi
         ${TAR} xzf chkrootkit-${LATESTCRK}.tar.gz
         ${RM} -f chkrootkit-${LATESTCRK}.tar.gz
         cd chkrootkit-*
         if [ -f ./chkrootkit ]; then
            echo "Extraction Successful!"
         else
            echo "Extraction failed."
            echo "Aborting."
            exit
         fi
         echo "Installing..."
         ${RM} -rf /usr/local/chkrootkit
         ${MKDIR} /usr/local/chkrootkit
         mv ${INSTALLDIR}/src/chkrootkit*/* /usr/local/chkrootkit
         cd /usr/local/chkrootkit
         make sense > /dev/null
         cd ${INSTALLDIR}/src
         ${RM} -rf chkrootkit*
         echo "CHKROOTKIT Install Completed Successfully!"
      else
         echo "Not installing/updating CHKROOTKIT"
      fi
   else
      echo "CHKROOTKIT is up to date [ Version: ${CURRENTCRK} ]"
   fi
   if [ "${DOALL}" != "1" ]; then
      ${RM} -f ${INSTALLDIR}/versions
   fi
}

## Install a CHKROOTKIT cronjob (to run nightly)
dochkrootkitcron() {
   if [ -d /usr/local/chkrootkit ]; then
      echo
      if [ -f /etc/cron.daily/chkrootkit.sh ]; then
         echo "CHKROOTKIT Cronjob already installed."
      else
         if [ "${ADMINEMAIL}" != "" ]; then
            echo "Would you like for CHKROOTKIT to run and send you scan details"
            echo "to your admin email address nightly? (y/n):"
            proceedfunc
            if [ "${PROCEEDASK}" = "y" ]; then
               echo '#!/bin/bash'$'\n''(cd /usr/local/chkrootkit; ./chkrootkit 2>&1 | mail -s "CHKROOTKIT Scan Details"' ${ADMINEMAIL}')' > /etc/cron.daily/chkrootkit.sh
               chmod 700 /etc/cron.daily/chkrootkit.sh
            else
               echo "CHKROOTKIT will not run nightly.  You can execute manually with"
               echo "/usr/local/chkrootkit/chkrootkit"
            fi
         else
            echo "Must provide Admin Email Address to install CHKROOTKIT Cronjob."
         fi
      fi
   fi
}

# Install/Update APF Firewall
doapf() {
   echo
   if [ "${SKIPCURRENTS}" != "1" ]; then
      if [ -f /etc/apf/apf ]; then
         CURRENTAPF=`${GREP} 'VER=' /etc/apf/apf | ${CUT} -d '"' -f 2`
      fi
      latestversionfunc LATESTAPF apf-latest
      latestmd5func APFMD5 apf-latest
      latestmd5func APFCONFIGSMD5 apfconfigs
   fi
   if [ "${CURRENTAPF}" != "${LATESTAPF}" ]; then
      if [ -d /etc/apf ]; then
         echo "APF is out of date.  Installed: ${CURRENTAPF} Latest: ${LATESTAPF}"
         echo "ELS can now update APF."
         APFBAK=1
      else
         echo "ELS can now install APF."
      fi
      proceedfunc
      if  [ "${PROCEEDASK}" = "y" ]; then
         cd ${INSTALLDIR}/src
         ${RM} -rf apf*
         echo "Downloading APF..."
         ${WGET} -q  ${MIRROR}/apf/apf-${LATESTAPF}.tar.gz
         if [ "`${MD5SUM} apf-${LATESTAPF}.tar.gz | ${CUT} -d ' ' -f 1`" = "$APFMD5" ]; then
            echo "Download Successful!"
            echo "MD5 matches."
            echo "Extracting..."
            else
               echo "Download Failed."
               echo "Invalid MD5."
               echo "Aborting."
               exit
         fi
         ${TAR} xzf apf-${LATESTAPF}.tar.gz
         ${RM} -f apf-${LATESTAPF}.tar.gz
         cd apf*
         if [ -f ./install.sh ]; then
            echo "Extraction Successful!"
         else
            echo "Extraction failed."
            echo "Aborting."
            exit
         fi
         echo "Installing..."
         ./install.sh > /dev/null
         if [ "$APFBAK" != "1" ]; then
            if [ "${CONTROLPANEL}" = "1" ]; then
               echo "cPanel installed. Using default configuration for cPanel."
               echo "Downloading configuration tarball..."
               cd ${INSTALLDIR}/src
               ${WGET} -q ${MIRROR}/apf/apfconfigs.tar.gz
               if [ "`${MD5SUM} apfconfigs.tar.gz | ${CUT} -d ' ' -f 1`" = "${APFCONFIGSMD5}" ]; then
                  echo "Download Successful!"
                  echo "MD5 matches."
                  echo "Extracting..."
               else
                  echo "Download Failed."
                  echo "Invalid MD5."
                  echo "Aborting."
                  exit
               fi
               cd ${INSTALLDIR}/src
               ${TAR} xzf apfconfigs.tar.gz > /dev/null
               ${RM} -f apfconfigs.tar.gz
               echo "Done."
               echo "Moving new configation to /etc/apf..."
               cd ${INSTALLDIR}/src/apfconfigs
               mv /etc/apf/conf.apf /etc/apf/conf.apf.default
               cp conf.apf.cpanel.default /etc/apf
               cp /etc/apf/conf.apf.cpanel.default /etc/apf/conf.apf
               echo "Looking for primary ethernet interface..."
               if [ "`${GREP} ETHDEV /etc/wwwacct.conf | ${CUT} -d ' ' -f 2`" = "" ] || [ "`${GREP} ethernet_dev /usr/local/directadmin/conf/directadmin.conf | ${CUT} -d= -f2`" = "eth0" ]; then
                  echo "Found primary ethernet device to be eth0."
               elif [ -e /etc/wwwacct.conf ] && [ "`${GREP} ETHDEV /etc/wwwacct.conf | ${CUT} -d ' ' -f 2`" != "" ]; then
                  GREPPED="`${GREP} ETHDEV /etc/wwwacct.conf | ${CUT} -d ' ' -f 2`"
                  perl -pi -e "s/IFACE_IN=\"eth0\"/IFACE_IN=\"${GREPPED}\"/" /etc/apf/conf.apf
                  perl -pi -e "s/IFACE_OUT=\"eth0\"/IFACE_OUT=\"${GREPPED}\"/" /etc/apf/conf.apf
                  echo "Found primary ethernet device to be ${GREPPED}."
               elif [ -e /etc/wwwacct.conf ] && [ "`${GREP} ethernet_dev /usr/local/directadmin/conf/directadmin.conf | ${CUT} -d= -f2`" != "eth0" ]; then
                  GREPPED="`${GREP} ethernet_dev /usr/local/directadmin/conf/directadmin.conf | ${CUT} -d= -f2`"
                  perl -pi -e "s/IFACE_IN=\"eth0\"/IFACE_IN=\"${GREPPED}\"/" /etc/apf/conf.apf
                  perl -pi -e "s/IFACE_OUT=\"eth0\"/IFACE_OUT=\"${GREPPED}\"/" /etc/apf/conf.apf
                  echo "Found primary ethernet device to be ${GREPPED}."
               else
                  echo "Failed to find primary ethernet interface."
                  echo "This is not bad, just did not automatically set this in conf.apf."
                  echo "You must edit IFACE_IN and IFACE_OUT manually in /etc/apf/conf/apf as necessary."
               fi
               echo "Default configuration saved as /etc/apf/conf.apf.default"
               echo "cPanel default config saved as /etc/apf/conf.apf.cpanel.default"
               echo "and copied to /etc/conf.apf."
               echo "Default CPANEL configuration setup successfully."
            elif [ "${CONTROLPANEL}" = "2" ]; then
               echo "Plesk installed. Using default configuration for Plesk."
               echo "Downloading configuration tarball..."
               cd ${INSTALLDIR}/src
               ${WGET} -q ${MIRROR}/apf/apfconfigs.tar.gz
               if [ "`${MD5SUM} apfconfigs.tar.gz | ${CUT} -d ' ' -f 1`" = "${APFCONFIGSMD5}" ]; then
                  echo "Download Successful!"
                  echo "MD5 matches."
                  echo "Extracting..."
               else
                  echo "Download Failed."
                  echo "Invalid MD5."
                  echo "Aborting."
                  exit
               fi
               cd ${INSTALLDIR}/src
               ${TAR} xzf apfconfigs.tar.gz
               ${RM} -f apfconfigs.tar.gz
               echo "Done."
               echo "Moving new configation to /etc/apf..."
               cd ${INSTALLDIR}/src/apfconfigs
               mv /etc/apf/conf.apf /etc/apf/conf.plesk.default
               cp conf.apf.plesk.default /etc/apf
               cp /etc/apf/conf.apf.plesk.default /etc/apf/conf.apf
               echo "Default configuration saved as /etc/apf/conf.plesk.default"
               echo "Plesk default config saved as /etc/apf/conf.apf.plesk.default"
               echo "and copied to /etc/conf.apf."
               echo "Default PLESK configuration setup successfully."
            elif [ "${CONTROLPANEL}" = "3" ]; then
               echo "DirectAdmin installed. Using default configuration for DirectAdmin."
               echo "Downloading configuration tarball..."
               cd ${INSTALLDIR}/src
               ${WGET} -q ${MIRROR}/apf/apfconfigs.tar.gz
               if [ "`${MD5SUM} apfconfigs.tar.gz | ${CUT} -d ' ' -f 1`" = "${APFCONFIGSMD5}" ]; then
                  echo "Download Successful!"
                  echo "MD5 matches."
                  echo "Extracting..."
               else
                  echo "Download Failed."
                  echo "Invalid MD5."
                  echo "Aborting."
                  exit
               fi
               cd ${INSTALLDIR}/src
               ${TAR} xzf apfconfigs.tar.gz
               ${RM} -f apfconfigs.tar.gz
               echo "Done."
               echo "Moving new configation to /etc/apf..."
               cd ${INSTALLDIR}/src/apfconfigs
               mv /etc/apf/conf.apf /etc/apf/conf.directadmin.default
               cp conf.apf.directadmin.default /etc/apf
               cp /etc/apf/conf.apf.directadmin.default /etc/apf/conf.apf
               echo "Default configuration saved as /etc/apf/conf.directadmin.default"
               echo "DirectAdmin default config saved as /etc/apf/conf.apf.directadmin.default"
               echo "and copied to /etc/conf.apf."
               echo "Default DirectAdmin configuration setup successfully."
            fi
            cd ${INSTALLDIR}/src
            ${RM} -rf apf*
            if [ "${ADMINIP}" != "" ]; then
               if [ "`${GREP} ${ADMINIP} /etc/apf/allow_hosts.rules`" = "" ]; then
                  echo "${ADMINIP}" >> /etc/apf/allow_hosts.rules
               fi
            fi
         fi
         echo "APF Install Completed Successfully!"
         APFCONFIGNOTICE=1
      else
         echo "Not installing APF"
      fi
   else
      echo "APF is up to date [ Version: ${CURRENTAPF} ]"
   fi
   if [ "${DOALL}" != "1" ]; then
      ${RM} -f ${INSTALLDIR}/versions
   fi
}

## Install/Update Brute Force Detection
dobfd() {
   echo
   if [ "${SKIPCURRENTS}" != "1" ]; then
      latestversionfunc LATESTBFD bfd-latest
      latestmd5func BFDMD5 bfd-latest
      if [ -f /usr/local/bfd/bfd ]; then
         CURRENTBFD=`${GREP} 'V=' /usr/local/bfd/bfd | ${CUT} -d '"' -f 2`
      fi
   fi
   if [ "$CURRENTBFD" != "$LATESTBFD" ]; then
      if [ -d /usr/local/bfd ]; then
         echo "BFD is out of date.  Installed: $CURRENTBFD Latest: $LATESTBFD"
         echo "ELS can now update BFD."
         BFDBAK=1
      else
         echo "ELS can now install BFD."
      fi
      proceedfunc
      if [ "${PROCEEDASK}" = "y" ]; then
         if [ "$BFDBAK" = "1" ]; then
            /usr/local/bfd/bfd -q
            mv --force /usr/local/bfd ${INSTALLDIR}/bakfiles/bfd
         fi
         cd ${INSTALLDIR}/src
         ${RM} -rf bfd*
         echo "Downloading BFD..."
         ${WGET} -q ${MIRROR}/bfd/bfd-$LATESTBFD.tar.gz
         if [ "`${MD5SUM} bfd-$LATESTBFD.tar.gz | ${CUT} -d ' ' -f 1`" = "$BFDMD5" ]; then
            echo "Download Successful!"
            echo "MD5 matches."
            echo "Extracting..."
         else
            echo "Download Failed."
            echo "Invalid MD5."
            echo "Aborting."
            exit
         fi
         ${TAR} xzf bfd-$LATESTBFD.tar.gz
         ${RM} -f bfd-$LATESTBFD.tar.gz
         cd bfd*
         if [ -f ./install.sh ]; then
            echo "Extraction Successful!"
         else
            echo "Extraction failed."
            echo "Aborting."
            exit
         fi
         echo "Installing..."
         ./install.sh > /dev/null
         cd ${INSTALLDIR}/src
         ${RM} -rf bfd*
         if [ "$BFDBAK" = "1" ]; then
            cp --force ${INSTALLDIR}/bakfiles/bfd/ignore.hosts /usr/local/bfd/ignore.hosts
         fi
         if [ "`${GREP} ALERT_USR /usr/local/bfd/conf.bfd | ${CUT} -d '\"' -f 2`" != "1" ]; then
            perl -pi -e "s/ALERT_USR=\"0\"/ALERT_USR=\"1\"/" /usr/local/bfd/conf.bfd
         fi
         if [ "`${GREP} EMAIL_USR /usr/local/bfd/conf.bfd | ${CUT} -d '"' -f 2`" = "root" ]; then
            perl -pi -e "s/EMAIL_USR=root/EMAIL_USR=\"${ADMINEMAIL}\"/" /usr/local/bfd/conf.bfd
         fi
         if [ "${ADMINIP}" != "" ]; then
            if [ "`${GREP} ${ADMINIP} /usr/local/bfd/ignore.hosts`" = "" ]; then
               echo "${ADMINIP}" >> /usr/local/bfd/ignore.hosts
            fi
         fi
         /usr/local/bfd/bfd -s
         echo "BFD Install Completed Successfully!"
      else
         echo "Not installing/updating BFD"
      fi
   else
      echo "BFD is up to date [ Version: $CURRENTBFD ]"
   fi
   if [ "${DOALL}" != "1" ]; then
      ${RM} -f ${INSTALLDIR}/versions
   fi
}

## Install/Update Libsafe
dolibsafe() {
   echo
   if [ "${SKIPCURRENTS}" != "1" ]; then
      latestversionfunc LATESTLIBSAFE libsafe-latest
      latestmd5func LIBSAFEMD5 libsafe-latest
      if [ "`${RPM} -q libsafe`" != "package libsafe is not installed" ]; then
         CURRENTLIBSAFE=`${RPM} -q libsafe | ${CUT} -d '-' -f 2,3`
      fi
   fi
   if [ "$ARCH" = "i386" ]; then
      if [ "$CURRENTLIBSAFE" != "$LATESTLIBSAFE" ]; then
         if [ "$CURRENTLIBSAFE" = "" ]; then
            echo "ELS can now install Libsafe."
         else
            echo "Libsafe is out of date.  Installed: $CURRENTLIBSAFE Latest: $LATESTLIBSAFE"
            echo "ELS can now update Libsafe."
         fi
         proceedfunc
         if [ "${PROCEEDASK}" = "y" ]; then
            ${WGET} -q --output-document=${INSTALLDIR}/src/libsafe-$LATESTLIBSAFE.i386.rpm ${MIRROR}/libsafe/libsafe-$LATESTLIBSAFE.i386.rpm
            if [ "`${MD5SUM} ${INSTALLDIR}/src/libsafe-$LATESTLIBSAFE.i386.rpm | ${CUT} -d ' ' -f 1`" = "$LIBSAFEMD5" ]; then
               echo "Download Successful!"
               echo "MD5 matches."
               echo "Installing..."
            else
               echo "Download Failed."
               echo "Invalid MD5."
               echo "Aborting."
               exit
            fi
            ${RPM} -Uvh ${INSTALLDIR}/src/libsafe-$LATESTLIBSAFE.i386.rpm
            ${RM} -f ${INSTALLDIR}/src/libsafe-$LATESTLIBSAFE.i386.rpm
            echo "Done."
         else
            echo "Not installing/updating Libsafe"
         fi
      else
         echo "Libsafe us up to date [ Version: $CURRENTLIBSAFE ]"
      fi
   else
      echo "Libsafe only available on i386 based architectures."
   fi
   if [ "${DOALL}" != "1" ]; then
      ${RM} -f ${INSTALLDIR}/versions
   fi
}

# Install MyTOP
domytop() {
   echo
   latestversionfunc LATESTMYTOP mytop-latest
   latestmd5func MYTOPMD5 mytop-latest
   if [ "$CURRENTMYTOP" != "$LATESTMYTOP" ]; then
      if [ "$CURRENTMYTOP" = "" ]; then
         echo "ELS can now install MyTOP."
      else
         echo "MyTOP is out of date.  Installed: $CURRENTMYTOP Latest: $LATESTMYTOP"
         echo "ELS can now update MyTOP."
      fi
      proceedfunc
      if [ "${PROCEEDASK}" = "y" ]; then
         ${WGET} -q --output-document=${INSTALLDIR}/src/mytop-$LATESTMYTOP.tar.gz ${MIRROR}/mytop/mytop-$LATESTMYTOP.tar.gz
         if [ "`${MD5SUM} ${INSTALLDIR}/src/mytop-$LATESTMYTOP.tar.gz | ${CUT} -d ' ' -f 1`" = "$MYTOPMD5" ]; then
            echo "Download Successful!"
            echo "MD5 matches."
            echo "Installing..."
         else
            echo "Download Failed."
            echo "Invalid MD5."
            echo "Aborting."
            exit
         fi
         cd ${INSTALLDIR}/src
         tar -zxvf mytop-$LATESTMYTOP.tar.gz
         cd mytop-$LATESTMYTOP
         perl Makefile.PL
         make
         make install
         echo "$LATESTMYTOP" > ${INSTALLDIR}/mytop_version
         cd ${INSTALLDIR}/src
         ${RM} -rf mytop*
         echo "Setting default database to 'mysql'."
         echo "db=mysql" > /root/.mytop
         echo "Done."
      else
         echo "Not installing/updating MyTOP"
      fi
   else
      echo "MyTOP is up to date [ Version: $CURRENTMYTOP ]"
   fi
   if [ "${DOALL}" != "1" ]; then
      ${RM} -f ${INSTALLDIR}/versions
   fi
}

## Disable telnet
dodisabletelnet() {
   if [ -f /etc/xinetd.d/telnet ]; then
      echo
      if [ "`${GREP} disable /etc/xinetd.d/telnet | ${CUT} -d '=' -f 2`" = " yes" ]; then
         echo "Telnet is already disabled."
      else
         echo "Telnet is currently enabled.  Telnet is not very secure and should"
         echo "be disabled, especially if you don't even use it."
         echo "This feature will disable the Telnet service."
         proceedfunc
         if [ "${PROCEEDASK}" = "y" ]; then
            if [ "`${GREP} disable /etc/xinetd.d/telnet | ${CUT} -d '=' -f 2`" = " no" ]; then
               echo "Backing up Telnet configuration..."
               cp /etc/xinetd.d/telnet ${INSTALLDIR}/bakfiles/xinetd-telnet.bak
               if [ -f ${INSTALLDIR}/bakfiles/xinetd-telnet.bak ]; then
                  echo "Successfully backed up as ${INSTALLDIR}/xinetd-telnet.bak!"
               else
                  echo "Backup failed."
                  echo "Aborting."
                  exit
               fi
               echo "Editing file..."
               ${GREP} disable /etc/xinetd.d/telnet > ${INSTALLDIR}/disabletelnet-secure.tmp
               perl -pi -e "s/no/yes/" ${INSTALLDIR}/disabletelnet-secure.tmp
               GREPPED="`${GREP} disable /etc/xinetd.d/telnet`"
               CATTED="`${CAT} ${INSTALLDIR}/disabletelnet-secure.tmp`"
               perl -pi -e "s/${GREPPED}/${CATTED}/" /etc/xinetd.d/telnet
               ${RM} -f ${INSTALLDIR}/disabletelnet-secure.tmp
               echo "Restarting service..."
               /etc/rc.d/init.d/xinetd restart
               echo "Done."
            elif [ "`${GREP} disable /etc/xinetd.d/telnet`" = "" ]; then
               echo "Editing file..."
               perl -pi -e "s/}/        disable                 = yes\n}/" /etc/xinetd.d/telnet
               echo "Restarting service..."
               /etc/init.d/xinetd restart
               echo "Done"
            else
               echo "Could not disable Telnet."
            fi
         else
            echo "Not disabling Telnet."
         fi
      fi
   fi
}

## Chmod dangerous files only to root
dochmodfiles() {
   echo
   echo "This feature can chmod dangerous files only to root"
   proceedfunc
   if [ "${PROCEEDASK}" = "y" ]; then
     if [ -f /usr/bin/rcp ]; then
        chmod 750 /usr/bin/rcp
        echo "Chmoded /usr/bin/rcp to 750."
     fi
     if [ -f /usr/bin/wget ]; then
        chmod 750 /usr/bin/wget
        echo "Chmoded /usr/bin/wget to 750."
     fi
     if [ -f /usr/bin/lynx ]; then
        chmod 750 /usr/bin/lynx
        echo "Chmoded /usr/bin/lynx to 750."
     fi
     if [ -f /usr/bin/links ]; then
        chmod 750 /usr/bin/links
        echo "Chmoded /usr/bin/links to 750."
     fi
     if [ -f /usr/bin/scp ]; then
        chmod 750 /usr/bin/scp
        echo "Chmoded /usr/bin/scp to 750."
     fi
     if [ -d /etc/httpd/proxy ]; then
        chmod 000 /etc/httpd/proxy/
        echo "Chmoded /etc/httpd/proxy/ to 000."
     fi
     if [ -d /var/spool/samba ]; then
        chmod 000 /var/spool/samba/
        echo "Chmoded /var/spool/samba/ to 000."
     fi
     if [ -d /var/mail/vbox ]; then
        chmod 000 /var/mail/vbox/
        echo "Chmoded /var/mail/vbox/ to 000."
     fi
     echo "All files chmoded"
   else
        echo "Not chmoding dangerous files to root."
   fi
}

## Force SSH protocol 2
doforcessh2() {
   echo
   if [ -f /etc/ssh/sshd_config ]&& [ "`${GREP} Protocol /etc/ssh/sshd_config`" = "Protocol 2" ]; then
      echo "SSHd already forcing Protocol 2."
   else
      echo "This feature can make the SSH deamon force SSH Protocl 2"
      proceedfunc
      if [ "${PROCEEDASK}" = "y" ]; then
         echo "Backing up current configuration file..."
         cp /etc/ssh/sshd_config ${INSTALLDIR}/bakfiles/sshd_config.bak
         if [ -f ${INSTALLDIR}/bakfiles/sshd_config.bak ]; then
            echo "Successfully backed up as ${INSTALLDIR}/bakfiles/sshd_config.bak!"
         else
            echo "Backup failed."
            echo "Aborting."
            exit
         fi
         echo "Modifying configuration file..."
         perl -pi -e "s/#Protocol 2,1/Protocol 2/" /etc/ssh/sshd_config
         if [ "`${GREP} Protocol /etc/ssh/sshd_config`" = "Protocol 2" ]; then
            echo "Edit successful!"
            echo "Restarting SSHd service..."
            /etc/init.d/sshd restart
            echo "Done. SSH now forces Protocol 2."
         else
            echo "Edit failed!"
            echo "Restoring backup..."
            mv --force ${INSTALLDIR}/bakfiles/sshd_config.bak /etc/ssh/sshd_config
            echo "Backup restored."
            echo "SSH is NOT forcing Protocol 2."
         fi
      else
         echo "Not forcing SSH Protocol 2"
      fi
   fi
}

## Enable PHP register_globals
doenablephprg() {
   if [ "`${GREP} \"^register_globals =\" ${PHPINI}`" = "register_globals = On" ]; then
      echo
      echo "PHP has already register_globals mode on."
   else
      echo
      echo "This feature can enable PHP register_globals."
      proceedfunc
      if [ "${PROCEEDASK}" = "y" ]; then
         echo "Backing up current configuration file..."
         cp --force ${PHPINI} ${INSTALLDIR}/bakfiles/php.ini-register-globals.bak
         if [ -f ${INSTALLDIR}/bakfiles/php.ini-register-globals.bak ]; then
            echo "Successfully backed up as ${INSTALLDIR}/bakfiles/php.ini-register-globals.bak!"
         else
            echo "Backup failed."
            echo "Aborting."
            exit
         fi
         echo "Modifying configuration file..."
         GREPPED="`${GREP} \"^register_globals =\" ${PHPINI}`"
         perl -pi -e "s/${GREPPED}/register_globals = On/" ${PHPINI}
         if [ "`${GREP} \"^register_globals =\" ${PHPINI}`" = "register_globals = On" ]; then
            echo "Edit successful!"
            echo "Restarting httpd service..."
            /etc/init.d/httpd restart
            echo "Done. register_globals for PHP enabled."
         else
            echo "Edit failed!"
            echo "Restoring backup..."
            mv --force ${INSTALLDIR}/bakfiles/php.ini-register-globals.bak ${PHPINI}
            echo "Backup restored."
            echo "PHP is NOT enabling PHP register_globals."
         fi
      else
         echo "Not setting PHP register_globals."
      fi
   fi
}

## Disable PHP register_globals
dodisablephprg() {
   if [ "`${GREP} \"^register_globals =\" ${PHPINI}`" = "register_globals = Off" ]; then
      echo
      echo "PHP has already register_globals mode off."
   else
      echo
      echo "This feature can disable PHP register_globals."
      proceedfunc
      if [ "${PROCEEDASK}" = "y" ]; then
         echo "Backing up current configuration file..."
         cp --force ${PHPINI} ${INSTALLDIR}/bakfiles/php.ini-register-globals.bak
         if [ -f ${INSTALLDIR}/bakfiles/php.ini-register-globals.bak ]; then
            echo "Successfully backed up as ${INSTALLDIR}/bakfiles/php.ini-register-globals.bak!"
         else
            echo "Backup failed."
            echo "Aborting."
            exit
         fi
         echo "Modifying configuration file..."
         GREPPED="`${GREP} \"^register_globals =\" ${PHPINI}`"
         perl -pi -e "s/${GREPPED}/register_globals = Off/" ${PHPINI}
         if [ "`${GREP} \"^register_globals =\" ${PHPINI}`" = "register_globals = Off" ]; then
            echo "Edit successful!"
            echo "Restarting httpd service..."
            /etc/init.d/httpd restart
            echo "Done. register_globals for PHP disabled."
         else
            echo "Edit failed!"
            echo "Restoring backup..."
            mv --force ${INSTALLDIR}/bakfiles/php.ini-register-globals.bak ${PHPINI}
            echo "Backup restored."
            echo "PHP is NOT disabling PHP register_globals."
         fi
      else
         echo "Not disabling PHP register_globals."
      fi
   fi
}

## Disable dangerous PHP functions
dodisablephpfunc() {
   COUNT=`${GREP} -c -e ^disable_functions ${PHPINI}`
   if [ "`${GREP} ^disable_functions ${PHPINI}`" = "disable_functions = symlink,shell_exec,exec,proc_close,proc_open,popen,system,dl,passthru,escapeshellarg,escapeshellcmd" ]; then
      echo
      echo "PHP is already disabling dangerous PHP functions."
   else
      echo
      echo "This feature can disable dangerous PHP functions."
      proceedfunc
      if [ "${PROCEEDASK}" = "y" ]; then
         echo "Backing up current configuration file..."
         cp --force ${PHPINI} ${INSTALLDIR}/bakfiles/php.ini-disable-functions.bak
         if [ -f ${INSTALLDIR}/bakfiles/php.ini-disable-functions.bak ]; then
            echo "Successfully backed up as ${INSTALLDIR}/bakfiles/php.ini-disable-functions.bak!"
         else
            echo "Backup failed."
            echo "Aborting."
            exit
         fi
         if [ "$COUNT" = "0" ]; then
            echo "Modifying configuration file, disable_functions not found..."
            echo "Adding disable_functions to ${PHPINI}"
            echo "" >> ${PHPINI}
            echo ";Modified by ELS (Easy Linux Security)" >> ${PHPINI}
            echo "disable_functions = symlink,shell_exec,exec,proc_close,proc_open,popen,system,dl,passthru,escapeshellarg,escapeshellcmd" >> ${PHPINI}
         else
            echo "Modifying configuration file, disable_functions found..."
            GREPPED="`${GREP} \"^disable_functions\" ${PHPINI}`"
            perl -pi -e "s/${GREPPED}/disable_functions = symlink,shell_exec,exec,proc_close,proc_open,popen,system,dl,passthru,escapeshellarg,escapeshellcmd/" ${PHPINI}
         fi
         if [ "`${GREP} ^disable_functions ${PHPINI}`" = "disable_functions = symlink,shell_exec,exec,proc_close,proc_open,popen,system,dl,passthru,escapeshellarg,escapeshellcmd" ]; then
            echo "Edit successful!"
            echo "Restarting httpd service..."
            /etc/init.d/httpd restart
            echo "Done. Now PHP has dangerous functions disabled."
         else
            echo "Edit failed!"
            echo "Restoring backup..."
            mv --force ${INSTALLDIR}/bakfiles/php.ini-disable-functions.bak ${PHPINI}
            echo "Backup restored."
            echo "PHP is NOT disabling dangerous PHP functions."
         fi
      else
         echo "Not disabling dangerous PHP functions."
      fi
   fi
}

## Enable dangerous PHP functions
doenablephpfunc() {
   if [ "`${GREP} ^disable_functions ${PHPINI}`" = "disable_functions = " ]; then
      echo
      echo "PHP has already enabled dangerous PHP functions."
   else
      echo
      echo "This feature can enable dangerous PHP functions."
      proceedfunc
      if [ "${PROCEEDASK}" = "y" ]; then
         echo "Backing up current configuration file..."
         cp --force ${PHPINI} ${INSTALLDIR}/bakfiles/php.ini-enable-functions.bak
         if [ -f ${INSTALLDIR}/bakfiles/php.ini-enable-functions.bak ]; then
            echo "Successfully backed up as ${INSTALLDIR}/bakfiles/php.ini-enable-functions.bak!"
         else
            echo "Backup failed."
            echo "Aborting."
            exit
         fi
         echo "Modifying configuration file..."
         GREPPED="`${GREP} \"^disable_functions\" ${PHPINI}`"
         perl -pi -e "s/${GREPPED}/disable_functions =/" ${PHPINI} 
         if [ "`${GREP} ^disable_functions ${PHPINI}`" = "disable_functions = " ]; then
            echo "Edit successful!"
            echo "Restarting httpd service..."
            /etc/init.d/httpd restart
            echo "Done. Now PHP has dangerous PHP functions enabled."
         else
            echo "Edit failed!"
            echo "Restoring backup..."
            mv --force ${INSTALLDIR}/bakfiles/php.ini-enable-functions.bak ${PHPINI}
            echo "Backup restored."
            echo "PHP is NOT enabling dangerous PHP functions."
         fi
      else
         echo "Not enabling dangerous PHP functions."
      fi
   fi
}

## Secure /tmp, /var/tmp, and /dev/shm partitions (whether in /etc/fstab or not)
dosecurepartitions() {
   echo
if [ ${DISTRO} = "CENTOS5" ]; then
	echo "Secure /tmp function is temporary disabled on CentOS 5."
	exit 1
fi
   if [ "`mount | grep noexec | wc -l | awk '{print $1}'`" -lt "3" ]; then
      echo "ELS can secure your /tmp, /var/tmp, and /dev/shm partitions."
      proceedfunc
      if [ "${PROCEEDASK}" = "y" ]; then
         if [ "`${GREP} /tmp /etc/fstab`" = "" ]; then
            echo "No /tmp partition in /etc/fstab."
            if [ "`${GREP} /tmp /etc/mtab`" = "" ]; then
               echo "No /tmp partition mounted."
               echo "Backing up current fstab..."
               cp /etc/fstab ${INSTALLDIR}/bakfiles/fstab.bak
               if [ -f ${INSTALLDIR}/bakfiles/fstab.bak ]; then
                  echo "Successfully backed up as '${INSTALLDIR}/bakfiles/fstab.bak'!"
               else
                  echo "Backup failed."
                  echo "Aborting."
                  exit
               fi
            echo "Making extended filesystem for /tmp... (this may take a few moments)"
            # Create about 500MB partition
            cd /var
            dd if=/dev/zero of=/var/tmpFS bs=1024 count=524288
            echo "Please press \"y\" when prompted..."
            ${MKE2FS} -j /var/tmpFS
            if [ "${CONTROLPANEL}" = "1" ]; then
               /etc/init.d/chkservd stop
            fi
            /etc/init.d/mysql* stop
            ${MKDIR} /tmp_backup
            mv /tmp/* /tmp_backup/
            mv /tmp/.* /tmp_backup/
            echo "/var/tmpFS /tmp ext3 loop,rw,noexec,nosuid,nodev 0 0" >> /etc/fstab
            echo "Mounting /tmp..."
            ${RM} -rf /tmp
            ${MKDIR} /tmp
            mount /var/tmpFS
            chmod 1777 /tmp
            mv /tmp_backup/* /tmp/
            mv /tmp_backup/.* /tmp/
            ${RM} -rf /tmp_backup
            echo "Done."
            /etc/init.d/mysql* start
            if [ "${CONTROLPANEL}" = "1" ]; then
               /etc/init.d/chkservd start
            fi
            echo "Done. /tmp has been secured."
         else
            echo "/tmp already seems to be mounted (cPanel's securetmp script maybe?)"
         fi
      else
         echo "Found /tmp partition in /etc/fstab."
         if [ "`${GREP} -m1 /tmp /etc/fstab | ${AWK} '{ print $4 }'`" = "rw,noexec,nosuid,nodev" ] || [ "`${GREP} -m1 /tmp /etc/fstab | ${AWK} '{ print $4 }'`" = "loop,rw,noexec,nosuid,nodev" ]; then
            echo "The /tmp partition is already secured."
         else
            if [ -f ${INSTALLDIR}/bakfiles/fstab.bak ]; then
               echo "/etc/fstab already backed up as ${INSTALLDIR}/bakfiles/fstab.bak"
            else
               echo "Backing up current fstab..."
               cp /etc/fstab ${INSTALLDIR}/bakfiles/fstab.bak
               if [ -f ${INSTALLDIR}/bakfiles/fstab.bak ]; then
                  echo "Successfully backed up as '${INSTALLDIR}/bakfiles/fstab.bak'!"
               else
                  echo "Backup failed."
                  echo "Aborting."
                  exit
               fi
            fi
            echo "Modifying /etc/fstab..."
            ${GREP} -m1 /tmp /etc/fstab > ${INSTALLDIR}/fstab-edit.tmp
            if [ "`${GREP} /var/tmpFS /etc/fstab `" = "" ]; then
               GREPPED="`${GREP} -m1 /tmp /etc/fstab | ${AWK} '{ print $4 }'`"
               perl -pi -e "s#${GREPPED}#rw,noexec,nosuid,nodev#" ${INSTALLDIR}/fstab-edit.tmp
            else
               GREPPED="`${GREP} -m1 /tmp /etc/fstab | ${AWK} '{ print $4 }'`"
               perl -pi -e "s#${GREPPED}#loop,rw,noexec,nosuid,nodev#" ${INSTALLDIR}/fstab-edit.tmp
            fi
            GREPPED="`${GREP} -m1 /tmp /etc/fstab`"
            CATTED="`${CAT} ${INSTALLDIR}/fstab-edit.tmp`"
            perl -pi -e "s#${GREPPED}#${CATTED}#" /etc/fstab
            ${RM} -f ${INSTALLDIR}/fstab-edit.tmp
            echo "Done."
            echo "Remounting /tmp..."
            mount -o remount `${GREP} -m1 /tmp /etc/fstab | ${AWK} '{ print $1 }'`
            chmod 1777 /tmp
            echo "Done."
            echo "You should check '/etc/fstab' before you reboot your system!!!"
         fi
      fi
      echo
      if [ "`${GREP} /var/tmp /etc/fstab`" = "" ]; then
         if [ "`${GREP} /var/tmp /etc/mtab`" = "" ]; then
            echo "/var/tmp currently not mounted."
            echo "I'll mount it ontop of /tmp and secure it..."
            if [ -f ${INSTALLDIR}/bakfiles/fstab.bak ]; then
               echo "/etc/fstab already backed up as ${INSTALLDIR}/bakfiles/fstab.bak"
            else
               echo "Backing up current fstab..."
               cp /etc/fstab ${INSTALLDIR}/bakfiles/fstab.bak
               if [ -f ${INSTALLDIR}/bakfiles/fstab.bak ]; then
                  echo "Successfully backed up as '${INSTALLDIR}/bakfiles/fstab.bak'!"
               else
                  echo "Backup failed."
                  echo "Aborting."
                  exit
               fi
            fi
            echo "/tmp /var/tmp ext3 rw,noexec,nosuid,nodev,bind 0 0" >> /etc/fstab
            if [ -e /var/tmp/mysql.sock ]; then
               unlink /var/tmp/mysql.sock
            fi
            mount /var/tmp
            chmod 1777 /var/tmp
            if [ "${CONTROLPANEL}" = "1" ]; then
               /etc/init.d/chkservd restart
            fi
            echo "Done."
         else
            echo "/var/tmp already seems to be mounted (cPanel's securetmp script maybe?)"
         fi
      else
         echo "Found /var/tmp partition in /etc/fstab."
         if [ "`${GREP} -m1 /var/tmp /etc/fstab | ${AWK} '{ print $4 }'`" = "rw,noexec,nosuid,nodev,bind" ]; then
            echo "The /var/tmp partition is already secured."
         else
            if [ -f ${INSTALLDIR}/bakfiles/fstab.bak ]; then
               echo "/etc/fstab already backed up as ${INSTALLDIR}/bakfiles/fstab.bak"
            else
               echo "Backing up current fstab..."
               cp /etc/fstab ${INSTALLDIR}/bakfiles/fstab.bak
               if [ -f ${INSTALLDIR}/bakfiles/fstab.bak ]; then
                  echo "Successfully backed up as '${INSTALLDIR}/bakfiles/fstab.bak'!"
               else
                  echo "Backup failed."
                  echo "Aborting."
                  exit
               fi
            fi
               echo "Modifying /etc/fstab..."
               ${GREP} -m1 /var/tmp /etc/fstab > ${INSTALLDIR}/fstab-edit.tmp
               GREPPED="`${GREP} -m1 /var/tmp /etc/fstab | ${AWK} '{ print $4 }'`"
               perl -pi -e "s#${GREPPED}#rw,noexec,nosuid,nodev,bind#" ${INSTALLDIR}/fstab-edit.tmp
               CATTED="`${CAT} ${INSTALLDIR}/fstab-edit.tmp`"
               perl -pi -e "s#${GREPPED}#${CATTED}#" /etc/fstab
               ${RM} -f ${INSTALLDIR}/fstab-edit.tmp
               echo "Done."
               echo "Remounting /var/tmp..."
               mount -o remount /var/tmp
               chmod 1777 /var/tmp
               echo "Done."
               echo "You should check '/etc/fstab' before you reboot your system!!!"
            fi
         fi
         echo
         if [ "`${GREP} /dev/shm /etc/fstab`" = "" ]; then
            echo "No /dev/shm partition found in /etc/fstab."
            echo "Adding to fstab and mounting now."
            if [ -f ${INSTALLDIR}/bakfiles/fstab.bak ]; then
               echo "/etc/fstab already backed up as ${INSTALLDIR}/bakfiles/fstab.bak"
            else
               echo "Backing up current fstab..."
               cp /etc/fstab ${INSTALLDIR}/bakfiles/fstab.bak
               if [ -f ${INSTALLDIR}/bakfiles/fstab.bak ]; then
                  echo "Successfully backed up as '${INSTALLDIR}/bakfiles/fstab.bak'!"
               else
                  echo "Backup failed."
                  echo "Aborting."
                  exit
               fi
            fi
            echo "none /dev/shm tmpfs rw,noexec,nosuid,nodev 0 0" >> /etc/fstab
            mount /dev/shm
            echo "Done.  /dev/shm is mounted and secure."
         else
            echo "Found /dev/shm partition in /etc/fstab."
            if [ "`${GREP} -m1 /dev/shm /etc/fstab | ${AWK} '{ print $4 }'`" = "rw,noexec,nosuid,nodev" ]; then
               echo "The /dev/shm partition is already secured."
            else
               echo "Backing up current configuration file..."
               if [ -f ${INSTALLDIR}/bakfiles/fstab.bak ]; then
                  echo "/etc/fstab already backed up as ${INSTALLDIR}/bakfiles/fstab.bak "
               else
                  echo "Backing up current fstab..."
                  cp /etc/fstab ${INSTALLDIR}/bakfiles/fstab.bak
                  if [ -f ${INSTALLDIR}/bakfiles/fstab.bak ]; then
                     echo "Successfully backed up as '${INSTALLDIR}/bakfiles/fstab.bak'!"
                  else
                     echo "Backup failed."
                     echo "Aborting."
                     exit
                  fi
               fi
               echo "Modifying /etc/fstab..."
               ${GREP} /dev/shm /etc/fstab > ${INSTALLDIR}/fstab-edit2.tmp
               GREPPED1="`${GREP} -m1 /dev/shm /etc/fstab | ${AWK} '{ print $4 }'`"
               perl -pi -e "s#${GREPPED1}#rw,noexec,nosuid,nodev#" ${INSTALLDIR}/fstab-edit2.tmp
               GREPPED2="`${GREP} /dev/shm /etc/fstab`"
               CATTED="`${CAT} ${INSTALLDIR}/fstab-edit2.tmp`"
               perl -pi -e "s#${GREPPED1}#${CATTED}#" /etc/fstab
               ${RM} -f ${INSTALLDIR}/fstab-edit2.tmp
               echo "Done."
               echo "Remounting /dev/shm..."
               umount /dev/shm -l
               mount /dev/shm
               echo "Done."
               echo "You should check '/etc/fstab' before you reboot your system!!!"
            fi
         fi
      else
         echo "Not securing partitions"
      fi
   else
      echo "Partitions already secured"
   fi
}

## Create an entirely new MySQL configuration file based on amount of RAM and # of CPUs
## Options to activate MySQL logging, and disable MySQL networking (TCP connections) are here, too
mysqlconfigedit() {
   echo "Modifying MySQL configuration based on system information..."
   echo "Found $CPUTOTAL processor(s)"
   echo "Found $MEMTOTAL MB of RAM"
   if [ "$MEMTOTAL" -ge "7500" ]; then
      RAMGB=8
   elif [ "$MEMTOTAL" -ge "6500" ]; then
      RAMGB=7
   elif [ "$MEMTOTAL" -ge "5500" ]; then
      RAMGB=6
   elif [ "$MEMTOTAL" -ge "4500" ]; then
      RAMGB=5
   elif [ "$MEMTOTAL" -ge "3500" ]; then
      RAMGB=4
   elif [ "$MEMTOTAL" -ge "2500" ]; then
      RAMGB=3
   elif [ "$MEMTOTAL" -ge "1500" ]; then
      RAMGB=2
   else
      RAMGB=1
   fi
   GREPPED1="`${GREP} -m1 query_cache_size= /etc/my.cnf | ${CUT} -d ' ' -f 1 | ${CUT} -d '=' -f 2`"
   GREPPED2="`${GREP} -m1 key_buffer= /etc/my.cnf | ${CUT} -d ' ' -f 1 | ${CUT} -d '=' -f 2`"
   GREPPED3="`${GREP} -m1 sort_buffer_size= /etc/my.cnf | ${CUT} -d ' ' -f 1 | ${CUT} -d '=' -f 2`"
   GREPPED4="`${GREP} -m1 read_buffer_size= /etc/my.cnf | ${CUT} -d ' ' -f 1 | ${CUT} -d '=' -f 2`"
   GREPPED5="`${GREP} -m1 read_rnd_buffer_size= /etc/my.cnf | ${CUT} -d ' ' -f 1 | ${CUT} -d '=' -f 2`"
   GREPPED6="`${GREP} -m1 thread_concurrency= /etc/my.cnf | ${CUT} -d ' ' -f 1 | ${CUT} -d '=' -f 2`"
   EXPRRAMGB=`expr $RAMGB`
   EXPRCPU=`expr $CPUTOTAL \* 2`
   EXPRRAMGB128=`expr $RAMGB \* 128`
   EXPRRAMGB32=`expr $RAMGB \* 32`
   perl -pi -e "s/query_cache_size=${GREPPED1}M/query_cache_size=${EXPRRAMGB32}M/" /etc/my.cnf
   echo "Set 'query_cache_size' to ${EXPRRAMGB32}M"
   perl -pi -e "s/key_buffer=${GREPPED2}M/key_buffer=${EXPRRAMGB128}M/" /etc/my.cnf
   echo "Set 'key_buffer' to ${EXPRRAMGBM}M"
   perl -pi -e "s/sort_buffer_size=${GREPPED3}M/sort_buffer_size=${EXPRRAMGBM}M/" /etc/my.cnf
   echo "Set 'sort_buffer_size' to ${EXPRRAMGBM}M"
   perl -pi -e "s/read_buffer_size=${GREPPED4}M/read_buffer_size=${EXPRRAMGBM}M/" /etc/my.cnf
   echo "Set 'read_buffer_size' to ${EXPRRAMGBM}M"
   perl -pi -e "s/read_rnd_buffer_size=${GREPPED5}M/read_rnd_buffer_size=${EXPRRAMGBM}M/" /etc/my.cnf
   echo "Set 'read_rnd_buffer_size' to ${EXPRRAMGBM}M"
   perl -pi -e "s/thread_concurrency=${GREPPED6}/thread_concurrency=$EXPRCPU/" /etc/my.cnf
   echo "Set 'thread_concurrency' to ${EXPRCPU}"
   echo "Done."
   echo
   echo "Slow Queries are queries that take a noticable time to process.  By logging"
   echo "slow queries, you can determine if a program's code is at fault and fix"
   echo "the problem.  If you have alot of slow queres, consider further optimization"
   echo "and/or getting better hardware (SCSI drives and dual processors recommended)."
   echo "This will enable the logging of MySQL Slow Queries."
   proceedfunc
   if [ "${PROCEEDASK}" = "y" ]; then
      perl -pi -e "s/server-id=1/server-id=1\nlog_slow_queries=/var/log/mysql-slow-queries.log\nlong_query_time=2/" /etc/my.cnf
      touch /var/log/mysql-slow-queries.log
      chown mysql:mysql /var/log/mysql-slow-queries.log
   else
      echo "Not logging sloq queries."
   fi
   echo
   echo "By default, MySQL listens on TCP port 3306 for incoming connections."
   echo "Normally, this is not needed unless you connect to the MySQL server"
   echo "from your work/home, or from another server, and should be disabled if"
   echo "not being used over the network as it can be a security risk."
   echo "This will disable MySQL Networking."
   proceedfunc
   if [ "${PROCEEDASK}" = "y" ]; then
      echo "MySQL Networking disabled."
   else
      echo "MySQL Networking enabled."
      perl -pi -e "s/skip-networking/#skip-networking/" /etc/my.cnf
   fi
   ${RM} -rf ${INSTALLDIR}/src/mysqlconfig*
}

# Optimize MySQL configuration file (/etc/my.cnf)
dooptimizemysqlconf() {
   echo
   if [ "${CONTROLPANEL}" = "1" ] || [ "${CONTROLPANEL}" = "3" ]; then
      MYSQLVERSION=`${RPM} -q MySQL-server | ${CUT} -d '-' -f 3 | ${CUT} -d '.' -f 1,2`
      if [ "`${GREP} els-build /etc/my.cnf`" != "" ] && [ "`${GREP} els-build /etc/my.cnf | ${CUT} -d '=' -f2`" != "$MYSQLVERSION" ]; then
         FORCEMYSQLCONFIG=1
      fi
      if [ "`${GREP} els-build /etc/my.cnf`" != "" ] && [ "$FORCEMYSQLCONFIG" != "1" ]; then
         echo "MySQL Security and Optimization already performed."
      else
         if [ "$FORCEMYSQLCONFIG" = "1" ]; then
            echo " >>> IMPORTANT: This function is being forced because your MySQL configuration"
            echo "                file does not match the installed MySQL version series (4.0,"
            echo "                4.1, 5.0). It is HIGHLY recommended you select 'yes' to prevent"
            echo "                conflicts in the configuration files.  You can edit it again"
            echo "                afterwards, if necessary."
            echo
         fi
         echo "This feature can secure and optimize your MySQL configuration."
         proceedfunc
         if [ "${PROCEEDASK}" = "y" ]; then
            echo "Checking MySQL version.  This may take a few seconds..."
            if [ "$MYSQLVERSION" = "4.0" ] || [ "$MYSQLVERSION" = "4.1" ] || [ "$MYSQLVERSION" = "5.0" ]; then
               echo "MySQL $MYSQLVERSION detected.  [`${RPM} -q MySQL-server | ${CUT} -d '-' -f 3,4  | ${CUT} -d '.' -f 1,2,3`]"
               echo "Backing up current configuration file..."
               if [ -f /etc/my.cnf ]; then
                  mv --force /etc/my.cnf ${INSTALLDIR}/bakfiles/my.cnf
                  if [ -f ${INSTALLDIR}/bakfiles/my.cnf ]; then
                     echo "Successfully backed up as ${INSTALLDIR}/bakfiles/my.cnf!"
                  else
                     echo "Backup failed."
                     echo "Aborting."
                     exit
                  fi
               else
                  echo "/etc/my.cnf does not exist.  Backup skipped."
               fi
               echo "Building new configuration file..."
               ${WGET} -q --output-document=/etc/my.cnf ${MIRROR}/mysql/configs/my.cnf-$MYSQLVERSION
               mysqlconfigedit
               echo "Restarting MySQL..."
               /etc/init.d/mysql restart
               echo "MySQL restarted."
            elif [ "$MYSQLVERSION" = "3.23" ]; then
               echo "You are currently running MySQL version `${RPM} -qa | ${GREP} -i mysql-server | ${CUT} -d '-' -f 3`"
               echo "We do not recommend using a MySQL version older than 5.x."
               echo "This script will not change any configuration for MySQL 3."
               echo "We suggest you manually upgrade MySQL to 5.x."
            else
               echo "MySQL was not detected."
               echo "Please ensure the MySQL-server RPM package is installed."
            fi
         else
            echo "Skipping MySQL configuration editor."
         fi
      fi
   fi
}

## Renice MySQL to -20 for highest priority
domysqlrenice() {
   if  ( [ -f /usr/bin/safe_mysqld ] && [ "`${GREP} niceness= /usr/bin/safe_mysqld`" != "" ] ) || ( [ -f /usr/bin/mysqld_safe ] && [ "`${GREP} niceness= /usr/bin/mysqld_safe`" != "" ] ); then
      echo
      if ( [ -f /usr/bin/safe_mysqld ] && [ "`${GREP} niceness=0 /usr/bin/safe_mysqld`" != "" ] ) || ( [ -f /usr/bin/mysqld_safe ] && [ "`${GREP} niceness=0 /usr/bin/mysqld_safe`" != "" ] ); then
         echo "You can now renice MySQL to -10 (higher CPU priority)."
         echo "In MySQL intensive environments, overall performance can"
         echo "increase dramatically by using highest CPU priority,"
         echo "however in a few cases, this may offer no performance"
         echo "gain or even decrease performance slightly."
         echo "If you wish to undo this, use the following command:"
         echo "    els --undomysqlrenice"
         proceedfunc
         if [ "${PROCEEDASK}" = "y" ]; then
            echo -n "Applying changes to MySQL daemon..."
            if [ -f /usr/bin/safe_mysqld ]; then
               perl -pi -e "s/niceness=0/niceness=-10/" /usr/bin/safe_mysqld
            fi
            if [ -f /usr/bin/mysqld_safe ]; then
               perl -pi -e "s/niceness=0/niceness=-10/" /usr/bin/mysqld_safe
            fi
            echo "Done."
            echo "Restarting MySQL..."
            /etc/init.d/mysql* restart
            echo "Done."
         else
            echo "Not renicing MySQL to highest CPU priority."
         fi
      else
         echo "MySQL already reniced to -10 (higher CPU priority)."
      fi
   fi
}

## Undo renice for MySQL
doundomysqlrenice() {
   echo
   if ( [ -f /usr/bin/safe_mysqld ] && [ "`${GREP} niceness=0 /usr/bin/safe_mysqld`" = "" ] ) && ( [ -f /usr/bin/mysqld_safe ] && [ "`${GREP} niceness=0 /usr/bin/mysqld_safe`" = "" ] ); then
      echo "Are you sure you want to set MySQL back to normal CPU priority?"
      proceedfunc
      if [ "${PROCEEDASK}" = "y" ]; then
         echo -n "Undoing changes to MySQL daemon..."
         if [ -f /usr/bin/safe_mysqld ]; then
            perl -pi -e "s/niceness=-10/niceness=0/" /usr/bin/safe_mysqld
         fi
         if [ -f /usr/bin/mysqld_safe ]; then
            perl -pi -e "s/niceness=-10/niceness=0/" /usr/bin/mysqld_safe
         fi
         echo "Done."
         echo "Restarting MySQL..."
         /etc/init.d/mysql* restart
         echo "Done."
      else
         echo "Not undoing MySQL renicing."
      fi
   else
      echo "MySQL does not appear to be reniced or unable to find safe_mysqld"
      echo "or mysqld_safe."
      echo "Unable to undo MySQL renice."
   fi
}

dormchkrootkitcron(){
   echo
   echo "This feature can remove chkrootkit cronjob."
   proceedfunc
   if [ "${PROCEEDASK}" = "y" ]; then
     if [ -f /etc/cron.daily/chkrootkit.sh ]; then
       ${RM} -rf /etc/cron.daily/chkrootkit.sh
       echo "Chkrootkit cronjob removed."
     else
       echo "Chkrootkit cronjob does not exist."
     fi
   else
     echo "Not removing chkrootkit cronjob."
   fi
}

dormrkhuntercron(){
   echo
   echo "This feature can remove rootkithunter cronjob."
   proceedfunc
   if [ "${PROCEEDASK}" = "y" ]; then
     if [ -f /etc/cron.daily/rkhunter.sh ]; then
       ${RM} -rf /etc/cron.daily/rkhunter.sh
       echo "Rkhunter cronjob removed"
     else
       echo "Not removing rhkunter cronjob."
     fi
   else
     echo "Rhkunter cronjob does not exist."
   fi
}

doremoveapf(){
   echo
   echo "This feature can remove APF firewall."
   proceedfunc
   if [ "${PROCEEDASK}" = "y" ]; then
     if [ -e /etc/apf ]; then
       chkconfig --del apf
       ${RM} -rf /etc/init.d/apf /etc/cron.d/fw /etc/apf
       echo "APF firewall removed."
     else
       echo "APF firewall is not installed."
     fi
   else
     echo "Not removing APF firewall."
   fi
}

doremovebfd(){
   echo
   echo "This feature can remove BFD (Brute Force Detection)."
   proceedfunc
   if [ "${PROCEEDASK}" = "y" ]; then
     if [ -e /usr/local/bfd ]; then
         ${RM} -rf /usr/local/bfd /usr/local/sbin/bfd /etc/cron.d/bfd /etc/logrotate.d/bfd /var/log/bfd_log
         echo "BFD removed."
     else
         echo "BFD is not installed".
     fi
   else
         echo "Not removing BFD (Brute Force Detection)."
   fi
}

## Run a simple MySQL table optimization and repairing command
domysqloptimizedb() {
   echo
   echo "This feature can optimize and repair all the MySQL database tables."
   proceedfunc
   if [ "${PROCEEDASK}" = "y" ]; then
      if [ -f /root/.my.cnf ]; then
         mysqlcheck --optimize --repair --all-databases
      elif [ "${CONTROLPANEL}" = "2" ]; then
         mysqlcheck --user=admin --password=`cat /etc/psa/.psa.shadow` --optimize --repair --all-databases
      elif [ "${CONTROLPANEL}" = "3" ]; then
         mysqlcheck --user=`${GREP} user /usr/local/directadmin/conf/mysql.conf | ${CUT} -d '=' -f2` --password=`${GREP} passwd /usr/local/directadmin/conf/mysql.conf | ${CUT} -d '=' -f2` --optimize --repair --all-databases
      else
         echo -n "MySQL root password: "
         read MYSQLROOTPASSWORD
         mysqlcheck --user=root --password=$MYSQLROOTPASSWORD --optimize --repair --all-databases
      fi
      echo "Done."
   else
      echo "Skipping MySQL database tables optimization."
   fi
}

## Install/Update eAccelerator
doeaccelerator() {
   echo
   if [ "${SKIPCURRENTS}" != "1" ]; then
            latestversionfunc LATESTEACCEL eaccelerator-latest
            latestmd5func EACCELMD5 eaccelerator-latest
         if [ "`${PHPBINARY} -v | ${GREP} -i ioncube`" != "" ]; then
            IONCUBEINSTALL=1
         fi
         if [ "$PHPINSTALLED" = "1" ]; then
         CURRENTEACCEL=`${PHPBINARY} -v | ${GREP} -i 'eaccelerator' | ${AWK} '{ print $3 }' | ${CUT} -d 'v' -f 2 | ${CUT} -d ',' -f 1`
         CURRENTXCACHE=`${PHPBINARY} -v | ${GREP} -i 'xcache' | ${AWK} '{ print $3 }' | ${CUT} -d 'v' -f 2 | ${CUT} -d ',' -f 1`
         fi
   fi
   if [ "${CURRENTEACCEL}" != "${LATESTEACCEL}" ]; then
    if [ ! "${CURRENTXCACHE}" = "" ]; then
      echo "XCache is installed, can not install eAccelerator"
      exit 1
    fi
      if [ "${IONCUBEINSTALL}" = "" ]; then
         if [ "${CURRENTEACCEL}" = "" ]; then
            echo "ELS can now install eAccelerator."
         else
            echo "eAccelerator is out of date. [ Installed: ${CURRENTEACCEL} Latest: ${LATESTEACCEL} ]"
            echo "ELS can now update eAccelerator."
         fi
         proceedfunc
         if [ "${PROCEEDASK}" = "y" ]; then
            if [ "`${RPM} -q php-eaccelerator`" != "package php-eaccelerator is not installed" ]; then
               echo "Uninstalling php-eaccelerator RPM..."
               ${RPM} -ev php-eaccelerator
               echo "Done."
            fi
            if [ "${DISTRO}" != "DEBIAN3" ]; then
               ensurerpm autoconf EACCELCANCEL
               ensurerpm automake EACCELCANCEL
               ensurerpm gcc EACCELCANCEL
               ensurerpm gcc-c++ EACCELCANCEL
            else
               ensuredeb autoconf EACCELCANCEL
               ensuredeb automake EACCELCANCEL
               ensuredeb gcc EACCELCANCEL
               ensuredeb g++ EACCELCANCEL
            fi
            if [ "${CONTROLPANEL}" = "1" ] || [ "${CONTROLPANEL}" = "3" ]; then
               echo "" #Do nothing
            else
               if [ "${DISTRO}" != "DEBIAN3" ]; then
                  ensurerpm php-devel EACCELCANCEL
               else
                  ensuredeb php-devel EACCELCANCEL
               fi
            fi
            if [ "${EACCELCANCEL}" = "1" ]; then
               echo "Skipping eAccelerator install/update due to dependency errors."
            else
               echo "Downloading eAccelerator..."
               cd ${INSTALLDIR}/src
               ${RM} -rf eaccelerator*
               ${WGET} -q ${MIRROR}/eaccelerator/eaccelerator-${LATESTEACCEL}.tar.gz
               if [ "`${MD5SUM} eaccelerator-${LATESTEACCEL}.tar.gz | ${CUT} -d ' ' -f 1`" = "${EACCELMD5}" ]; then
                  echo "Download Successful!"
                  echo "MD5 matches."
                  echo "Extracting..."
               else
                  echo "Download Failed."
                  echo "Invalid MD5."
                  echo "Aborting."
                  exit
               fi
               ${TAR} xzf eaccelerator-${LATESTEACCEL}.tar.gz
               ${RM} -f eaccelerator-${LATESTEACCEL}.tar.gz
               cd eaccelerator*
               if [ -f ./README ]; then
                  echo "Extraction Successful!"
               else
                  echo "Extraction failed."
                  echo "Aborting."
                  exit
               fi
               if [ -f /usr/bin/phpize ] && [ "`${PHPBINARY} -v | ${HEAD} -n1 | ${AWK} {'print $2'} | ${CUT} -d '.' -f2`" != "1" ]; then
                  PHPPREFIX=/usr
               else
                  PHPPREFIX=/usr/local
               fi
               ${PHPPREFIX}/bin/phpize
               ./configure --enable-eaccelerator=shared --with-php-config=${PHPPREFIX}/bin/php-config
               make
               if [ ! -d ${PHPPREFIX}/lib/php/eaccelerator ]; then
                  ${MKDIR} ${PHPPREFIX}/lib/php/eaccelerator
               fi
               mv --force ./modules/eaccelerator.so ${PHPPREFIX}/lib/php/eaccelerator/eaccelerator.so
               cd ${INSTALLDIR}
               if [ "${CONTROLPANEL}" = "1" ] || [ "${CONTROLPANEL}" = "3" ]; then
                  echo "" #Do nothing
               else
                  PHPINI=/etc/php.d/eaccelerator.ini
               fi
               ${RM} -rf ${INSTALLDIR}/src/eaccelerator*
               if [ "`${GREP} eaccelerator.enable ${PHPINI}`" = "" ] ; then
                  if [ ! -d /tmp/eaccelerator ]; then
                     ${MKDIR} /tmp/eaccelerator
                  fi
                  chmod 777 /tmp/eaccelerator
                  cp --force ${PHPINI} ${INSTALLDIR}/bakfiles/php.ini-eaccelerator-install.bak
                  echo "${PHPINI} backed up as ${INSTALLDIR}/bakfiles/php.ini-eaccelerator-install.bak."
                  echo >> ${PHPINI}
                  echo "[eAccelerator]" >> ${PHPINI}
                  echo "zend_extension=\"${PHPPREFIX}/lib/php/eaccelerator/eaccelerator.so\"" >> ${PHPINI}
                  echo "eaccelerator.shm_size=\"32\"" >> ${PHPINI}
                  echo "eaccelerator.cache_dir=\"/tmp/eaccelerator\"" >> ${PHPINI}
                  echo "eaccelerator.enable=\"1\"" >> ${PHPINI}
                  echo "eaccelerator.optimizer=\"1\"" >> ${PHPINI}
                  echo "eaccelerator.check_mtime=\"1\"" >> ${PHPINI}
                  echo "eaccelerator.debug=\"0\"" >> ${PHPINI}
                  echo "eaccelerator.filter=\"\"" >> ${PHPINI}
                  echo "eaccelerator.shm_max=\"0\"" >> ${PHPINI}
                  echo "eaccelerator.shm_ttl=\"0\"" >> ${PHPINI}
                  echo "eaccelerator.shm_prune_period=\"0\"" >> ${PHPINI}
                  echo "eaccelerator.shm_only=\"0\"" >> ${PHPINI}
                  echo "eaccelerator.compress=\"1\"" >> ${PHPINI}
                  echo "eaccelerator.compress_level=\"9\"" >> ${PHPINI}
                  echo "eaccelerator.keys=\"shm_and_disk\"" >> ${PHPINI}
                  echo "eaccelerator.sessions=\"shm_and_disk\"" >> ${PHPINI}
                  echo "eaccelerator.content=\"shm_and_disk\"" >> ${PHPINI}
                  CURRENTZENDOPT=""
                  if [ "$PHPINSTALLED" = "1" ]; then
                     CURRENTZENDOPT=`${PHPBINARY} -v | ${GREP} -i 'zend optimizer' | ${AWK} '{ print $4 }' | ${CUT} -d 'v' -f 2 | ${CUT} -d ',' -f1`
                  fi
                  if [ "${CURRENTZENDOPT}" != "" ]; then
                     echo "Because this is a new eAccelerator install, Zend Optimizer must be reinstalled."
                     echo "Zend Optimizer and Zend Extension Manager will now be uninstalled."
                     echo "Simply run the Zend Optimizer installer after the eAccelerator install is"
                     echo "complete if you wish for Zend Optimizer and Zend Extension Manager to be"
                     echo "reinstalled."
                     FORCEZENDOPTINSTALL=1
                     if [ "`${GREP} zend_optimizer.optimization_level ${PHPINI}`" != "" ]; then
                        ${GREP} zend_optimizer.optimization_level ${PHPINI} > ${INSTALLDIR}/disablezend.tmp
                        if [ "`${GREP} \";\" ${INSTALLDIR}/disablezend.tmp`" != "" ]; then
                           GREPPED="`${GREP} \";\" ${INSTALLDIR}/disablezend.tmp`"
                           perl -pi -e "s/${GREPPED}//" ${INSTALLDIR}/disablezend.tmp
                        fi
                        GREPPED="`${GREP} zend_optimizer.optimization_level ${INSTALLDIR}/disablezend.tmp`"
                        perl -pi -e "s/${GREPPED}//" ${PHPINI}
                        ${RM} -f ${INSTALLDIR}/disablezend.tmp
                     fi
                     if [ "`${GREP} zend_extension_manager.optimizer_ts ${PHPINI}`" != "" ]; then
                        ${GREP} zend_extension_manager.optimizer_ts ${PHPINI} > ${INSTALLDIR}/disablezend.tmp
                        if [ "`${GREP} \";\" ${INSTALLDIR}/disablezend.tmp`" != "" ]; then
                           GREPPED="`${GREP} \";\" ${INSTALLDIR}/disablezend.tmp`"
                           perl -pi -e "s/${GREPPED}//" ${INSTALLDIR}/disablezend.tmpl
                        fi
                        GREPPED="`${GREP} zend_extension_manager.optimizer_ts ${INSTALLDIR}/disablezend.tmp`"
                        perl -pi -e "s/${GREPPED}//" ${PHPINI}
                        ${RM} -f ${INSTALLDIR}/disablezend.tmp
                     fi
                     if [ "`${GREP} zend_extension_manager.optimizer ${PHPINI}`" != "" ]; then
                        ${GREP} zend_extension_manager.optimizer ${PHPINI} > ${INSTALLDIR}/disablezend.tmp
                        if [ "`${GREP} \";\" ${INSTALLDIR}/disablezend.tmp`" != "" ]; then
                           GREPPED="`${GREP} \";\" ${INSTALLDIR}/disablezend.tmp`"
                           perl -pi -e "s/${GREPPED}//" ${INSTALLDIR}/disablezend.tmp
                        fi
                        GREPPED="`${GREP} zend_extension_manager.optimizer ${INSTALLDIR}/disablezend.tmp`"
                        perl -pi -e "s/${GREPPED}//" ${PHPINI}
                        ${RM} -f ${INSTALLDIR}/disablezend.tmp
                     fi
                     if [ "`${GREP} zend_optimizer.version ${PHPINI}`" != "" ]; then
                        ${GREP} zend_optimizer.version ${PHPINI} > ${INSTALLDIR}/disablezend.tmp
                        if [ "`${GREP} \";\" ${INSTALLDIR}/disablezend.tmp`" != "" ]; then
                           GREPPED="`${GREP} \";\" ${INSTALLDIR}/disablezend.tmp`"
                           perl -pi -e "s/${GREPPED}//" ${INSTALLDIR}/disablezend.tmp
                        fi
                        GREPPED="`${GREP} zend_optimizer.version ${INSTALLDIR}/disablezend.tmp`"
                        perl -pi -e "s/${GREPPED}//" ${PHPINI}
                        ${RM} -f ${INSTALLDIR}/disablezend.tmp
                     fi
                     if [ "`${GREP} zend_extension=\"/usr/local/Zend/lib/ZendOptimizer.so\" ${PHPINI}`" != "" ]; then
                        GREPPED="`${GREP} zend_extension=\"/usr/local/Zend/lib/ZendOptimizer.so\" ${INSTALLDIR}/disablezend.tmp`"
                        perl -pi -e "s/${GREPPED}//" ${PHPINI}
                        ${RM} -f ${INSTALLDIR}/disablezend.tmp
                     fi
                     if [ "`${GREP} zend_extension=/usr/local/Zend/lib/ZendExtensionManager.so ${PHPINI}`" != "" ]; then
                        perl -pi -e "s/zend_extension=\/usr\/local\/Zend\/lib\/ZendExtensionManager.so//" ${PHPINI}
                     fi
                     if [ "`${GREP} zend_extension_ts=/usr/local/Zend/lib/ZendExtensionManager_TS.so ${PHPINI}`" != "" ]; then
                        perl -pi -e "s/zend_extension_ts=\/usr\/local\/Zend\/lib\/ZendExtensionManager_TS.so//" ${PHPINI}
                     fi
                     if [ "`${GREP} [Zend] ${PHPINI}`" != "" ]; then
                        perl -pi -e "s/\[Zend]//" ${PHPINI}
                     fi
                  fi
               else
                  if [ "`${GREP} eaccelerator.so ${PHPINI} | ${CUT} -d '=' -f2 | ${CUT} -d '"' -f2 | ${CUT} -d '/' -f3`" = "lib" ] && [ "${PHPPREFIX}" = "/usr/local" ]; then
                     GREPPED="`${GREP} eaccelerator.so ${PHPINI} | ${CUT} -d '=' -f2 | ${CUT} -d '"' -f2`"
                     perl -pi -e "s/${GREPPED}/eaccelerator\/eaccelerator.so/" ${PHPINI}
                  fi
                  if [ "`${GREP} eaccelerator.so ${PHPINI} | ${CUT} -d '=' -f2 | ${CUT} -d '"' -f2 | ${CUT} -d '/' -f3`" = "local" ] && [ "${PHPPREFIX}" = "/usr" ]; then
                     GREPPED="`${GREP} eaccelerator.so ${PHPINI} | ${CUT} -d '=' -f2 | ${CUT} -d '"' -f2`"
                     perl -pi -e "s/${GREPPED}/eaccelerator\/eaccelerator.so/" ${PHPINI}
                  fi
               fi
               echo "eAccelerator installation/update complete."
               echo "Restarting Apache..."
               /etc/init.d/httpd restart
               echo "Done."
            fi
         else
            echo "Not installing/updating eAccelerator."
         fi
      else
         echo "ionCube Loaders are installed.  eAccelerator is not compatable"
         echo "with ionCube.  Uninstall ioncube and try again to install eAccelerator."
      fi
   else
      echo "eAccelerator is up to date [ Version: ${LATESTEACCEL} ]"
   fi
   if [ "${DOALL}" != "1" ]; then
      ${RM} -f ${INSTALLDIR}/versions
   fi
}

## Install/Update APC
doapc() {
   echo
   if [ "${SKIPCURRENTS}" != "1" ]; then
            latestversionfunc LATESTAPC APC-latest
            latestmd5func APCMD5 APC-latest
         if [ "$PHPINSTALLED" = "1" ]; then
         CURRENTAPC=`${PHPBINARY} -v | ${GREP} -i 'apc' | ${AWK} '{ print $3 }' | ${CUT} -d 'v' -f 2 | ${CUT} -d ',' -f 1`
         CURRENTEACCEL=`${PHPBINARY} -v | ${GREP} -i 'apc' | ${AWK} '{ print $3 }' | ${CUT} -d 'v' -f 2 | ${CUT} -d ',' -f 1`
         CURRENTXCACHE=`${PHPBINARY} -v | ${GREP} -i 'xcache' | ${AWK} '{ print $3 }' | ${CUT} -d 'v' -f 2 | ${CUT} -d ',' -f 1`
         fi
   fi
   if [ "${CURRENTAPC}" != "${LATESTAPC}" ]; then
    if [ ! "${CURRENTXCACHE}" = "" ] || [ ! "${CURRENTEACCEL}" = "" ]; then
      echo "XCache or eAccelerator is installed, can not install APC"
      exit 1
    fi
         if [ "${CURRENTAPC}" = "" ]; then
            echo "ELS can now install APC."
         else
            echo "APC is out of date. [ Installed: ${CURRENTAPC} Latest: ${LATESTAPC} ]"
            echo "ELS can now update APC."
         fi
         proceedfunc
         if [ "${PROCEEDASK}" = "y" ]; then
            if [ "`${RPM} -q php-apc`" != "package php-apc is not installed" ]; then
               echo "Uninstalling php-apc RPM..."
               ${RPM} -ev php-apc
               echo "Done."
            fi
            if [ "${DISTRO}" != "DEBIAN3" ]; then
               ensurerpm autoconf APCCANCEL
               ensurerpm automake APCCANCEL
               ensurerpm gcc APCCANCEL
               ensurerpm gcc-c++ APCCANCEL
            else
               ensuredeb autoconf APCCANCEL
               ensuredeb automake APCCANCEL
               ensuredeb gcc APCCANCEL
               ensuredeb g++ APCCANCEL
            fi
            if [ "${CONTROLPANEL}" = "1" ] || [ "${CONTROLPANEL}" = "3" ]; then
               echo "" #Do nothing
            else
               if [ "${DISTRO}" != "DEBIAN3" ]; then
                  ensurerpm php-devel APCCANCEL
               else
                  ensuredeb php-devel APCCANCEL
               fi
            fi
            if [ "$APCCANCEL" = "1" ]; then
               echo "Skipping APC install/update due to dependency errors."
            else
               echo "Downloading APC..."
               cd ${INSTALLDIR}/src
               ${RM} -rf APC*
               ${WGET} -q ${MIRROR}/APC/APC-${LATESTAPC}.tgz
               if [ "`${MD5SUM} APC-${LATESTAPC}.tgz | ${CUT} -d ' ' -f 1`" = "$APCMD5" ]; then
                  echo "Download Successful!"
                  echo "MD5 matches."
                  echo "Extracting..."
               else
                  echo "Download Failed."
                  echo "Invalid MD5."
                  echo "Aborting."
                  exit
               fi
               ${TAR} xzf APC-${LATESTAPC}.tgz
               ${RM} -f APC-${LATESTAPC}.tgz
               cd APC*
               if [ -f ./INSTALL ]; then
                  echo "Extraction Successful!"
               else
                  echo "Extraction failed."
                  echo "Aborting."
                  exit
               fi
               if [ -f /usr/bin/phpize ] && [ "`${PHPBINARY} -v | ${HEAD} -n1 | ${AWK} {'print $2'} | ${CUT} -d '.' -f2`" != "1" ]; then
                  PHPPREFIX=/usr
               else
                  PHPPREFIX=/usr/local
               fi
               ${PHPPREFIX}/bin/phpize
               ./configure --enable-apc --enable-apc-mmap --with-php-config=${PHPPREFIX}/bin/php-config
               make
               if [ ! -d ${PHPPREFIX}/lib/php/apc ]; then
                  ${MKDIR} ${PHPPREFIX}/lib/php/apc
               fi
               mv --force ./modules/apc.so ${PHPPREFIX}/lib/php/apc/apc.so
               cd ${INSTALLDIR}
               if [ "${CONTROLPANEL}" = "1" ] || [ "${CONTROLPANEL}" = "3" ]; then
                  echo "" #Do nothing
               else
                  PHPINI=/etc/php.d/apc.ini
               fi
               ${RM} -rf ${INSTALLDIR}/src/APC*
               if [ "`${GREP} apc.shm_size ${PHPINI}`" = "" ] ; then
                  cp --force ${PHPINI} ${INSTALLDIR}/bakfiles/php.ini-apc-install.bak
                  echo "${PHPINI} backed up as ${INSTALLDIR}/bakfiles/php.ini-apc-install.bak."
                  echo >> ${PHPINI}
                  echo "[APC]" >> ${PHPINI}
                  echo "extension=\"apc/apc.so\"" >> ${PHPINI}
                  echo "apc.enabled=1" >> ${PHPINI}
                  echo "apc.shm_segments=1" >> ${PHPINI}
                  echo "apc.shm_size=128" >> ${PHPINI}
                  echo "apc.ttl=7200" >> ${PHPINI}
                  echo "apc.user_ttl=7200" >> ${PHPINI}
                  echo "apc.num_files_hint=1024" >> ${PHPINI}
                  echo "apc.mmap_file_mask=/tmp/apc.XXXXXX" >> ${PHPINI}
                  echo "apc.enable_cli=1" >> ${PHPINI}
                  if [ "`grep \"extension_dir =\" | cut -d= -f2`" != " \"${PHPPREFIX}/lib/php/\"" ]; then
                     GREPPED="`${GREP} \"extension_dir\" ${PHPINI}`"
                     perl -pi -e "s/${GREPPED}/extension_dir = \"${PHPPREFIX}\/lib\/php\/\"/" ${PHPINI}
                  fi
                  if [ "`grep \"extension_dir =\" | cut -d= -f2`" != " \"${PHPPREFIX}/lib/php/\"" ]; then
                     echo "extension_dir = \"${PHPPREFIX}/lib/php/\"" >> ${PHPINI}
                  fi
                  CURRENTZENDOPT=""
                  if [ "$PHPINSTALLED" = "1" ]; then
                     CURRENTZENDOPT=`${PHPBINARY} -v | ${GREP} -i 'zend optimizer' | ${AWK} '{ print $4 }' | ${CUT} -d 'v' -f 2 | ${CUT} -d ',' -f1`
                  fi
                  if [ "${CURRENTZENDOPT}" != "" ]; then
                     echo "Because this is a new APC install, Zend Optimizer must be uninstalled."
                     echo "Zend Optimizer and Zend Extension Manager will now be uninstalled."
                     FORCEZENDOPTINSTALL=1
                     if [ "`${GREP} zend_optimizer.optimization_level ${PHPINI}`" != "" ]; then
                        ${GREP} zend_optimizer.optimization_level ${PHPINI} > ${INSTALLDIR}/disablezend.tmp
                        if [ "`${GREP} \";\" ${INSTALLDIR}/disablezend.tmp`" != "" ]; then
                           GREPPED="`${GREP} \";\" ${INSTALLDIR}/disablezend.tmp`"
                           perl -pi -e "s/${GREPPED}//" ${INSTALLDIR}/disablezend.tmp
                        fi
                        GREPPED="`${GREP} zend_optimizer.optimization_level ${INSTALLDIR}/disablezend.tmp`"
                        perl -pi -e "s/${GREPPED}//" ${PHPINI}
                        ${RM} -f ${INSTALLDIR}/disablezend.tmp
                     fi
                     if [ "`${GREP} zend_extension_manager.optimizer_ts ${PHPINI}`" != "" ]; then
                        ${GREP} zend_extension_manager.optimizer_ts ${PHPINI} > ${INSTALLDIR}/disablezend.tmp
                        if [ "`${GREP} \";\" ${INSTALLDIR}/disablezend.tmp`" != "" ]; then
                           GREPPED="`${GREP} \";\" ${INSTALLDIR}/disablezend.tmp`"
                           perl -pi -e "s/${GREPPED}//" ${INSTALLDIR}/disablezend.tmpl
                        fi
                        GREPPED="`${GREP} zend_extension_manager.optimizer_ts ${INSTALLDIR}/disablezend.tmp`"
                        perl -pi -e "s/${GREPPED}//" ${PHPINI}
                        ${RM} -f ${INSTALLDIR}/disablezend.tmp
                     fi
                     if [ "`${GREP} zend_extension_manager.optimizer ${PHPINI}`" != "" ]; then
                        ${GREP} zend_extension_manager.optimizer ${PHPINI} > ${INSTALLDIR}/disablezend.tmp
                        if [ "`${GREP} \";\" ${INSTALLDIR}/disablezend.tmp`" != "" ]; then
                           GREPPED="`${GREP} \";\" ${INSTALLDIR}/disablezend.tmp`"
                           perl -pi -e "s/${GREPPED}//" ${INSTALLDIR}/disablezend.tmp
                        fi
                        GREPPED="`${GREP} zend_extension_manager.optimizer ${INSTALLDIR}/disablezend.tmp`"
                        perl -pi -e "s/${GREPPED}//" ${PHPINI}
                        ${RM} -f ${INSTALLDIR}/disablezend.tmp
                     fi
                     if [ "`${GREP} zend_optimizer.version ${PHPINI}`" != "" ]; then
                        ${GREP} zend_optimizer.version ${PHPINI} > ${INSTALLDIR}/disablezend.tmp
                        if [ "`${GREP} \";\" ${INSTALLDIR}/disablezend.tmp`" != "" ]; then
                           GREPPED="`${GREP} \";\" ${INSTALLDIR}/disablezend.tmp`"
                           perl -pi -e "s/${GREPPED}//" ${INSTALLDIR}/disablezend.tmp
                        fi
                        GREPPED="`${GREP} zend_optimizer.version ${INSTALLDIR}/disablezend.tmp`"
                        perl -pi -e "s/${GREPPED}//" ${PHPINI}
                        ${RM} -f ${INSTALLDIR}/disablezend.tmp
                     fi
                     if [ "`${GREP} zend_extension=\"/usr/local/Zend/lib/ZendOptimizer.so\" ${PHPINI}`" != "" ]; then
                        GREPPED="`${GREP} zend_extension=\"/usr/local/Zend/lib/ZendOptimizer.so\" ${INSTALLDIR}/disablezend.tmp`"
                        perl -pi -e "s/${GREPPED}//" ${PHPINI}
                        ${RM} -f ${INSTALLDIR}/disablezend.tmp
                     fi
                     if [ "`${GREP} zend_extension=/usr/local/Zend/lib/ZendExtensionManager.so ${PHPINI}`" != "" ]; then
                        perl -pi -e "s/zend_extension=\/usr\/local\/Zend\/lib\/ZendExtensionManager.so//" ${PHPINI}
                     fi
                     if [ "`${GREP} zend_extension_ts=/usr/local/Zend/lib/ZendExtensionManager_TS.so ${PHPINI}`" != "" ]; then
                        perl -pi -e "s/zend_extension_ts=\/usr\/local\/Zend\/lib\/ZendExtensionManager_TS.so//" ${PHPINI}
                     fi
                     if [ "`${GREP} [Zend] ${PHPINI}`" != "" ]; then
                        perl -pi -e "s/\[Zend]//" ${PHPINI}
                     fi
                  fi
               else
                  if [ "`${GREP} apc.so ${PHPINI} | ${CUT} -d '=' -f2 | ${CUT} -d '"' -f2 | ${CUT} -d '/' -f3`" = "lib" ] && [ "${PHPPREFIX}" = "/usr/local" ]; then
                     GREPPED="`${GREP} apc.so ${PHPINI} | ${CUT} -d '=' -f2 | ${CUT} -d '"' -f2`"
                     perl -pi -e "s/${GREPPED}/apc\/apc.so/" ${PHPINI}
                  fi
                  if [ "`${GREP} apc.so ${PHPINI} | ${CUT} -d '=' -f2 | ${CUT} -d '"' -f2 | ${CUT} -d '/' -f3`" = "local" ] && [ "${PHPPREFIX}" = "/usr" ]; then
                     GREPPED="`${GREP} apc.so ${PHPINI} | ${CUT} -d '=' -f2 | ${CUT} -d '"' -f2`"
                     perl -pi -e "s/${GREPPED}/apc\/apc.so/" ${PHPINI}
                  fi
               fi
               echo "APC installation/update complete."
               echo "Restarting Apache..."
               /etc/init.d/httpd restart
               echo "Done."
            fi
         else
            echo "Not installing/updating APC."
         fi
   else
      echo "APC is up to date [ Version: ${LATESTAPC} ]"
   fi
   if [ "${DOALL}" != "1" ]; then
      ${RM} -f ${INSTALLDIR}/versions
   fi
}

## Install/Update XCache
doxcache() {
   echo
   if [ "${SKIPCURRENTS}" != "1" ]; then
            latestversionfunc LATESTXCACHE xcache-latest
            latestmd5func XCACHEMD5 xcache-latest
         if [ "`${PHPBINARY} -v | ${GREP} -i ioncube`" != "" ]; then
            IONCUBEINSTALL=1
         fi
         if [ "$PHPINSTALLED" = "1" ]; then
         CURRENTXCACHE=`${PHPBINARY} -v | ${GREP} -i 'xcache' | ${AWK} '{ print $3 }' | ${CUT} -d 'v' -f 2 | ${CUT} -d ',' -f 1`
         CURRENTEACCEL=`${PHPBINARY} -v | ${GREP} -i 'eaccelerator' | ${AWK} '{ print $3 }' | ${CUT} -d 'v' -f 2 | ${CUT} -d ',' -f 1`
         fi
   fi
   if [ "${CURRENTXCACHE}" != "${LATESTXCACHE}" ]; then
    if [ ! "${CURRENTXCACHE}" = "" ]; then
      echo "eAccelerator is installed, can not install XCache"
      exit 1
    fi
      if [ "${IONCUBEINSTALL}" = "" ]; then
         if [ "${CURRENTXCACHE}" = "" ]; then
            echo "ELS can now install XCache."
         else
            echo "eAccelerator is out of date. [ Installed: ${CURRENTXCACHE} Latest: ${LATESTXCACHE} ]"
            echo "ELS can now update XCache."
         fi
         proceedfunc
         if [ "${PROCEEDASK}" = "y" ]; then
            if [ "`${RPM} -q php-xcache`" != "package php-xcache is not installed" ]; then
               echo "Uninstalling php-xcache RPM..."
               ${RPM} -ev php-xcache
               echo "Done."
            fi
            if [ "${DISTRO}" != "DEBIAN3" ]; then
               ensurerpm autoconf XCACHECANCEL
               ensurerpm automake XCACHECANCEL
               ensurerpm gcc XCACHECANCEL
               ensurerpm gcc-c++ XCACHECANCEL
            else
               ensuredeb autoconf XCACHECANCEL
               ensuredeb automake XCACHECANCEL
               ensuredeb gcc XCACHECANCEL
               ensuredeb g++ XCACHECANCEL
            fi
            if [ "${CONTROLPANEL}" = "1" ] || [ "${CONTROLPANEL}" = "3" ]; then
               echo "" #Do nothing
            else
               if [ "${DISTRO}" != "DEBIAN3" ]; then
                  ensurerpm php-devel XCACHECANCEL
               else
                  ensuredeb php-devel XCACHECANCEL
               fi
            fi
            if [ "$XCACHECANCEL" = "1" ]; then
               echo "Skipping XCache install/update due to dependency errors."
            else
               echo "Downloading XCache..."
               cd ${INSTALLDIR}/src
               ${RM} -rf excache*
               ${WGET} -q ${MIRROR}/xcache/xcache-${LATESTXCACHE}.tar.gz
               if [ "`${MD5SUM} xcache-${LATESTXCACHE}.tar.gz | ${CUT} -d ' ' -f 1`" = "$XCACHEMD5" ]; then
                  echo "Download Successful!"
                  echo "MD5 matches."
                  echo "Extracting..."
               else
                  echo "Download Failed."
                  echo "Invalid MD5."
                  echo "Aborting."
                  exit
               fi
               ${TAR} xzf xcache-${LATESTXCACHE}.tar.gz
               ${RM} -f xcache-${LATESTXCACHE}.tar.gz
               cd xcache*
               if [ -f ./README ]; then
                  echo "Extraction Successful!"
               else
                  echo "Extraction failed."
                  echo "Aborting."
                  exit
               fi
               if [ -f /usr/bin/phpize ] && [ "`${PHPBINARY} -v | ${HEAD} -n1 | ${AWK} {'print $2'} | ${CUT} -d '.' -f2`" != "1" ]; then
                  PHPPREFIX=/usr
               else
                  PHPPREFIX=/usr/local
               fi
               ${PHPPREFIX}/bin/phpize
               ./configure --enable-xcache --enable-xcache-optimizer --with-php-config=${PHPPREFIX}/bin/php-config
               make
               if [ ! -d ${PHPPREFIX}/lib/php/xcache ]; then
                  ${MKDIR} ${PHPPREFIX}/lib/php/xcache
               fi
               mv --force ./modules/xcache.so ${PHPPREFIX}/lib/php/xcache/xcache.so
               cd ${INSTALLDIR}
               if [ "${CONTROLPANEL}" = "1" ] || [ "${CONTROLPANEL}" = "3" ]; then
                  echo "" #Do nothing
               else
                  PHPINI=/etc/php.d/xcache.ini
               fi
               ${RM} -rf ${INSTALLDIR}/src/xcache*
               if [ "`${GREP} xcache.optimizer ${PHPINI}`" = "" ] ; then
                  if [ ! -d /tmp/xcache ]; then
                     ${MKDIR} /tmp/xcache
                  fi
                  chmod 777 /tmp/xcache
                  cp --force ${PHPINI} ${INSTALLDIR}/bakfiles/php.ini-xcache-install.bak
                  echo "${PHPINI} backed up as ${INSTALLDIR}/bakfiles/php.ini-xcache-install.bak."
                  echo >> ${PHPINI}
                  echo >> ${PHPINI}
                  echo "[xcache-common]" >> ${PHPINI}
                  echo "zend_extension = ${PHPPREFIX}/lib/php/xcache/xcache.so" >> ${PHPINI}
                  echo >> ${PHPINI}
                  echo "[xcache.admin]" >> ${PHPINI}
                  echo "xcache.admin.user = \"xcache_admin\"" >> ${PHPINI}
                  echo "xcache.admin.pass = \"e92d45b3212d79b19d044133504dc9d4\"" >> ${PHPINI}
                  echo >> ${PHPINI}
                  echo "[xcache]" >> ${PHPINI}
                  echo "xcache.shm_scheme =        \"mmap\"" >> ${PHPINI}
                  echo "xcache.size  =                64M" >> ${PHPINI}
                  echo "xcache.count =                 1" >> ${PHPINI}
                  echo "xcache.slots =                8K" >> ${PHPINI}
                  echo "xcache.ttl   =                 0" >> ${PHPINI}
                  echo "xcache.gc_interval =           0" >> ${PHPINI}
                  echo "xcache.var_size  =            0M" >> ${PHPINI}
                  echo "xcache.var_count =             1" >> ${PHPINI}
                  echo "xcache.var_slots =            8K" >> ${PHPINI}
                  echo "xcache.var_ttl   =             0" >> ${PHPINI}
                  echo "xcache.var_maxttl   =          0" >> ${PHPINI}
                  echo "xcache.var_gc_interval =     300" >> ${PHPINI}
                  echo "xcache.test =                Off" >> ${PHPINI}
                  echo "xcache.readonly_protection = Off" >> ${PHPINI}
                  echo "xcache.mmap_path =    \"/dev/zero\"" >> ${PHPINI}
                  echo "xcache.coredump_directory =   \"/tmp/xcache\"" >> ${PHPINI}
                  echo "xcache.cacher =               On" >> ${PHPINI}
                  echo "xcache.stat   =               On" >> ${PHPINI}
                  echo "xcache.optimizer =           Off" >> ${PHPINI}
                  echo >> ${PHPINI}
                  echo "[xcache.coverager]" >> ${PHPINI}
                  echo "xcache.coverager =          Off" >> ${PHPINI}
                  echo "xcache.coveragedump_directory = \"\"" >> ${PHPINI}
                  if [ "`grep \"extension_dir =\" | cut -d= -f2`" != " \"${PHPPREFIX}/lib/php/\"" ]; then
                     GREPPED="`${GREP} \"extension_dir\" ${PHPINI}`"
                     perl -pi -e "s/${GREPPED}/extension_dir = \"${PHPPREFIX}\/lib\/php\/\"/" ${PHPINI}
                  fi
                  if [ "`grep \"extension_dir =\" | cut -d= -f2`" != " \"${PHPPREFIX}/lib/php/\"" ]; then
                     echo "extension_dir = \"${PHPPREFIX}/lib/php/\"" >> ${PHPINI}
                  fi
                  CURRENTZENDOPT=""
                  if [ "$PHPINSTALLED" = "1" ]; then
                     CURRENTZENDOPT=`${PHPBINARY} -v | ${GREP} -i 'zend optimizer' | ${AWK} '{ print $4 }' | ${CUT} -d 'v' -f 2 | ${CUT} -d ',' -f1`
                  fi
                  if [ "${CURRENTZENDOPT}" != "" ]; then
                     echo "Because this is a new XCache install, Zend Optimizer must be uninstalled."
                     echo "Zend Optimizer and Zend Extension Manager will now be uninstalled."
                     echo "Zend Optimizer isn't compatible with XCache."
                     FORCEZENDOPTINSTALL=1
                     if [ "`${GREP} zend_optimizer.optimization_level ${PHPINI}`" != "" ]; then
                        ${GREP} zend_optimizer.optimization_level ${PHPINI} > ${INSTALLDIR}/disablezend.tmp
                        if [ "`${GREP} \";\" ${INSTALLDIR}/disablezend.tmp`" != "" ]; then
                           GREPPED="`${GREP} \";\" ${INSTALLDIR}/disablezend.tmp`"
                           perl -pi -e "s/${GREPPED}//" ${INSTALLDIR}/disablezend.tmp
                        fi
                        GREPPED="`${GREP} zend_optimizer.optimization_level ${INSTALLDIR}/disablezend.tmp`"
                        perl -pi -e "s/${GREPPED}//" ${PHPINI}
                        ${RM} -f ${INSTALLDIR}/disablezend.tmp
                     fi
                     if [ "`${GREP} zend_extension_manager.optimizer_ts ${PHPINI}`" != "" ]; then
                        ${GREP} zend_extension_manager.optimizer_ts ${PHPINI} > ${INSTALLDIR}/disablezend.tmp
                        if [ "`${GREP} \";\" ${INSTALLDIR}/disablezend.tmp`" != "" ]; then
                           GREPPED="`${GREP} \";\" ${INSTALLDIR}/disablezend.tmp`"
                           perl -pi -e "s/${GREPPED}//" ${INSTALLDIR}/disablezend.tmpl
                        fi
                        GREPPED="`${GREP} zend_extension_manager.optimizer_ts ${INSTALLDIR}/disablezend.tmp`"
                        perl -pi -e "s/${GREPPED}//" ${PHPINI}
                        ${RM} -f ${INSTALLDIR}/disablezend.tmp
                     fi
                     if [ "`${GREP} zend_extension_manager.optimizer ${PHPINI}`" != "" ]; then
                        ${GREP} zend_extension_manager.optimizer ${PHPINI} > ${INSTALLDIR}/disablezend.tmp
                        if [ "`${GREP} \";\" ${INSTALLDIR}/disablezend.tmp`" != "" ]; then
                           GREPPED="`${GREP} \";\" ${INSTALLDIR}/disablezend.tmp`"
                           perl -pi -e "s/${GREPPED}//" ${INSTALLDIR}/disablezend.tmp
                        fi
                        GREPPED="`${GREP} zend_extension_manager.optimizer ${INSTALLDIR}/disablezend.tmp`"
                        perl -pi -e "s/${GREPPED}//" ${PHPINI}
                        ${RM} -f ${INSTALLDIR}/disablezend.tmp
                     fi
                     if [ "`${GREP} zend_optimizer.version ${PHPINI}`" != "" ]; then
                        ${GREP} zend_optimizer.version ${PHPINI} > ${INSTALLDIR}/disablezend.tmp
                        if [ "`${GREP} \";\" ${INSTALLDIR}/disablezend.tmp`" != "" ]; then
                           GREPPED="`${GREP} \";\" ${INSTALLDIR}/disablezend.tmp`"
                           perl -pi -e "s/${GREPPED}//" ${INSTALLDIR}/disablezend.tmp
                        fi
                        GREPPED="`${GREP} zend_optimizer.version ${INSTALLDIR}/disablezend.tmp`"
                        perl -pi -e "s/${GREPPED}//" ${PHPINI}
                        ${RM} -f ${INSTALLDIR}/disablezend.tmp
                     fi
                     if [ "`${GREP} zend_extension=\"/usr/local/Zend/lib/ZendOptimizer.so\" ${PHPINI}`" != "" ]; then
                        GREPPED="`${GREP} zend_extension=\"/usr/local/Zend/lib/ZendOptimizer.so\" ${INSTALLDIR}/disablezend.tmp`"
                        perl -pi -e "s/${GREPPED}//" ${PHPINI}
                        ${RM} -f ${INSTALLDIR}/disablezend.tmp
                     fi
                     if [ "`${GREP} zend_extension=/usr/local/Zend/lib/ZendExtensionManager.so ${PHPINI}`" != "" ]; then
                        perl -pi -e "s/zend_extension=\/usr\/local\/Zend\/lib\/ZendExtensionManager.so//" ${PHPINI}
                     fi
                     if [ "`${GREP} zend_extension_ts=/usr/local/Zend/lib/ZendExtensionManager_TS.so ${PHPINI}`" != "" ]; then
                        perl -pi -e "s/zend_extension_ts=\/usr\/local\/Zend\/lib\/ZendExtensionManager_TS.so//" ${PHPINI}
                     fi
                     if [ "`${GREP} [Zend] ${PHPINI}`" != "" ]; then
                        perl -pi -e "s/\[Zend]//" ${PHPINI}
                     fi
                  fi
               else
                  if [ "`${GREP} xcache.so ${PHPINI} | ${CUT} -d '=' -f2 | ${CUT} -d '"' -f2 | ${CUT} -d '/' -f3`" = "lib" ] && [ "${PHPPREFIX}" = "/usr/local" ]; then
                     GREPPED="`${GREP} xcache.so ${PHPINI} | ${CUT} -d '=' -f2 | ${CUT} -d '"' -f2`"
                     perl -pi -e "s/${GREPPED}/xcache\/xcache.so/" ${PHPINI}
                  fi
                  if [ "`${GREP} xcache.so ${PHPINI} | ${CUT} -d '=' -f2 | ${CUT} -d '"' -f2 | ${CUT} -d '/' -f3`" = "local" ] && [ "${PHPPREFIX}" = "/usr" ]; then
                     GREPPED="`${GREP} xcache.so ${PHPINI} | ${CUT} -d '=' -f2 | ${CUT} -d '"' -f2`"
                     perl -pi -e "s/${GREPPED}/xcache\/xcache.so/" ${PHPINI}
                  fi
               fi
               echo "XCache installation/update complete."
               echo "Restarting Apache..."
               /etc/init.d/httpd restart
               echo "Done."
            fi
         else
            echo "Not installing/updating XCache."
         fi
      else
         echo "ionCube Loaders are installed. XCache is not compatable"
         echo "with ionCube. Uninstall ioncube and try again to install XCache."
      fi
   else
      echo "eAccelerator is up to date [ Version: ${LATESTXCACHE} ]"
   fi
   if [ "${DOALL}" != "1" ]; then
      ${RM} -f ${INSTALLDIR}/versions
   fi
}

## Install/Update suhosin
dosuhosin() {
   echo
   if [ "${SKIPCURRENTS}" != "1" ]; then
            latestversionfunc LATESTSUHOSIN suhosin-latest
            latestmd5func SUHOSINMD5 suhosin-latest
         if [ "$PHPINSTALLED" = "1" ]; then
         CURRENTSUHOSIN=`cat ${PHPINI} | ${GREP} -i 'suhosin.version' | ${CUT} -d= -f 2`
         fi
   fi
   if [ "${CURRENTSUHOSIN}" != "${LATESTSUHOSIN}" ]; then
         if [ "${CURRENTSUHOSIN}" = "" ]; then
            echo "ELS can now install suhosin."
         else
            echo "suhosin is out of date. [ Installed: ${CURRENTSUHOSIN} Latest: ${LATESTSUHOSIN} ]"
            echo "ELS can now update suhosin."
         fi
         proceedfunc
         if [ "${PROCEEDASK}" = "y" ]; then
            if [ "${DISTRO}" != "DEBIAN3" ]; then
               ensurerpm autoconf SUHOSINCANCEL
               ensurerpm automake SUHOSINCANCEL
               ensurerpm gcc SUHOSINCANCEL
               ensurerpm gcc-c++ SUHOSINCANCEL
            else
               ensuredeb autoconf SUHOSINCANCEL
               ensuredeb automake SUHOSINCANCEL
               ensuredeb gcc SUHOSINCANCEL
               ensuredeb g++ SUHOSINCANCEL
            fi
            if [ "${CONTROLPANEL}" = "1" ] || [ "${CONTROLPANEL}" = "3" ]; then
               echo "" #Do nothing
            else
               if [ "${DISTRO}" != "DEBIAN3" ]; then
                  ensurerpm php-devel SUHOSINCANCEL
               else
                  ensuredeb php-devel SUHOSINCANCEL
               fi
            fi
            if [ "${SUHOSINCANCEL}" = "1" ]; then
               echo "Skipping suhosin install/update due to dependency errors."
            else
               echo "Downloading suhosin..."
               cd ${INSTALLDIR}/src
               ${RM} -rf suhosin*
               ${WGET} -q ${MIRROR}/suhosin/suhosin-${LATESTSUHOSIN}.tgz
               if [ "`${MD5SUM} suhosin-${LATESTSUHOSIN}.tgz | ${CUT} -d ' ' -f 1`" = "${SUHOSINMD5}" ]; then
                  echo "Download Successful!"
                  echo "MD5 matches."
                  echo "Extracting..."
               else
                  echo "Download Failed."
                  echo "Invalid MD5."
                  echo "Aborting."
                  exit
               fi
               ${TAR} xzf suhosin-${LATESTSUHOSIN}.tgz
               ${RM} -f suhosin-${LATESTSUHOSIN}.tgz
               cd suhosin*
               if [ -f ./Changelog ]; then
                  echo "Extraction Successful!"
               else
                  echo "Extraction failed."
                  echo "Aborting."
                  exit
               fi
               if [ -f /usr/bin/phpize ] && [ "`${PHPBINARY} -v | ${HEAD} -n1 | ${AWK} {'print $2'} | ${CUT} -d '.' -f2`" != "1" ]; then
                  PHPPREFIX=/usr
               else
                  PHPPREFIX=/usr/local
               fi
               ${PHPPREFIX}/bin/phpize
               ./configure --with-php-config=${PHPPREFIX}/bin/php-config
               make
               if [ ! -d ${PHPPREFIX}/lib/php/suhosin ]; then
                  ${MKDIR} ${PHPPREFIX}/lib/php/suhosin
               fi
               mv --force ./modules/suhosin.so ${PHPPREFIX}/lib/php/suhosin/suhosin.so
               cd ${INSTALLDIR}
               cd ${INSTALLDIR}
               if [ "${CONTROLPANEL}" = "1" ] || [ "${CONTROLPANEL}" = "3" ]; then
                  echo "" #Do nothing
               else
                  PHPINI=/etc/php.d/suhosin.ini
               fi
               ${RM} -rf ${INSTALLDIR}/src/suhosin*
               if [ "`${GREP} suhosin.so ${PHPINI}`" = "" ] ; then
                  cp --force ${PHPINI} ${INSTALLDIR}/bakfiles/php.ini-suhosin-install.bak
                  echo "${PHPINI} backed up as ${INSTALLDIR}/bakfiles/php.ini-suhosin-install.bak."
                  echo >> ${PHPINI}
                  echo "[suhosin]" >> ${PHPINI}
                  echo "extension=\"suhosin/suhosin.so\"" >> ${PHPINI}
                  echo ";suhosin.version=${LATESTSUHOSIN}" >> ${PHPINI}
                  if [ "`grep \"extension_dir =\" | cut -d= -f2`" != " \"${PHPPREFIX}/lib/php/\"" ]; then
                     GREPPED="`${GREP} \"extension_dir\" ${PHPINI}`"
                     perl -pi -e "s/${GREPPED}/extension_dir = \"${PHPPREFIX}\/lib\/php\/\"/" ${PHPINI}
                  fi
                  if [ "`grep \"extension_dir =\" | cut -d= -f2`" != " \"${PHPPREFIX}/lib/php/\"" ]; then
                     echo "extension_dir = \"${PHPPREFIX}/lib/php/\"" >> ${PHPINI}
                  fi
                  CURRENTZENDOPT=""
                  if [ "$PHPINSTALLED" = "1" ]; then
                     CURRENTZENDOPT=`${PHPBINARY} -v | ${GREP} -i 'zend optimizer' | ${AWK} '{ print $4 }' | ${CUT} -d 'v' -f 2 | ${CUT} -d ',' -f1`
                  fi
                  if [ "${CURRENTZENDOPT}" != "" ]; then
                     echo "Because this is a new suhosin install, Zend Optimizer must be reinstalled."
                     echo "Zend Optimizer and Zend Extension Manager will now be uninstalled."
                     echo "Simply run the Zend Optimizer installer after the suhosin install is"
                     echo "complete if you wish for Zend Optimizer and Zend Extension Manager to be"
                     echo "reinstalled."
                     FORCEZENDOPTINSTALL=1
                     if [ "`${GREP} zend_optimizer.optimization_level ${PHPINI}`" != "" ]; then
                        ${GREP} zend_optimizer.optimization_level ${PHPINI} > ${INSTALLDIR}/disablezend.tmp
                        if [ "`${GREP} \";\" ${INSTALLDIR}/disablezend.tmp`" != "" ]; then
                           GREPPED="`${GREP} \";\" ${INSTALLDIR}/disablezend.tmp`"
                           perl -pi -e "s/${GREPPED}//" ${INSTALLDIR}/disablezend.tmp
                        fi
                        GREPPED="`${GREP} zend_optimizer.optimization_level ${INSTALLDIR}/disablezend.tmp`"
                        perl -pi -e "s/${GREPPED}//" ${PHPINI}
                        ${RM} -f ${INSTALLDIR}/disablezend.tmp
                     fi
                     if [ "`${GREP} zend_extension_manager.optimizer_ts ${PHPINI}`" != "" ]; then
                        ${GREP} zend_extension_manager.optimizer_ts ${PHPINI} > ${INSTALLDIR}/disablezend.tmp
                        if [ "`${GREP} \";\" ${INSTALLDIR}/disablezend.tmp`" != "" ]; then
                           GREPPED="`${GREP} \";\" ${INSTALLDIR}/disablezend.tmp`"
                           perl -pi -e "s/${GREPPED}//" ${INSTALLDIR}/disablezend.tmpl
                        fi
                        GREPPED="`${GREP} zend_extension_manager.optimizer_ts ${INSTALLDIR}/disablezend.tmp`"
                        perl -pi -e "s/${GREPPED}//" ${PHPINI}
                        ${RM} -f ${INSTALLDIR}/disablezend.tmp
                     fi
                     if [ "`${GREP} zend_extension_manager.optimizer ${PHPINI}`" != "" ]; then
                        ${GREP} zend_extension_manager.optimizer ${PHPINI} > ${INSTALLDIR}/disablezend.tmp
                        if [ "`${GREP} \";\" ${INSTALLDIR}/disablezend.tmp`" != "" ]; then
                           GREPPED="`${GREP} \";\" ${INSTALLDIR}/disablezend.tmp`"
                           perl -pi -e "s/${GREPPED}//" ${INSTALLDIR}/disablezend.tmp
                        fi
                        GREPPED="`${GREP} zend_extension_manager.optimizer ${INSTALLDIR}/disablezend.tmp`"
                        perl -pi -e "s/${GREPPED}//" ${PHPINI}
                        ${RM} -f ${INSTALLDIR}/disablezend.tmp
                     fi
                     if [ "`${GREP} zend_optimizer.version ${PHPINI}`" != "" ]; then
                        ${GREP} zend_optimizer.version ${PHPINI} > ${INSTALLDIR}/disablezend.tmp
                        if [ "`${GREP} \";\" ${INSTALLDIR}/disablezend.tmp`" != "" ]; then
                           GREPPED="`${GREP} \";\" ${INSTALLDIR}/disablezend.tmp`"
                           perl -pi -e "s/${GREPPED}//" ${INSTALLDIR}/disablezend.tmp
                        fi
                        GREPPED="`${GREP} zend_optimizer.version ${INSTALLDIR}/disablezend.tmp`"
                        perl -pi -e "s/${GREPPED}//" ${PHPINI}
                        ${RM} -f ${INSTALLDIR}/disablezend.tmp
                     fi
                     if [ "`${GREP} zend_extension=\"/usr/local/Zend/lib/ZendOptimizer.so\" ${PHPINI}`" != "" ]; then
                        GREPPED="`${GREP} zend_extension=\"/usr/local/Zend/lib/ZendOptimizer.so\" ${INSTALLDIR}/disablezend.tmp`"
                        perl -pi -e "s/${GREPPED}//" ${PHPINI}
                        ${RM} -f ${INSTALLDIR}/disablezend.tmp
                     fi
                     if [ "`${GREP} zend_extension=/usr/local/Zend/lib/ZendExtensionManager.so ${PHPINI}`" != "" ]; then
                        perl -pi -e "s/zend_extension=\/usr\/local\/Zend\/lib\/ZendExtensionManager.so//" ${PHPINI}
                     fi
                     if [ "`${GREP} zend_extension_ts=/usr/local/Zend/lib/ZendExtensionManager_TS.so ${PHPINI}`" != "" ]; then
                        perl -pi -e "s/zend_extension_ts=\/usr\/local\/Zend\/lib\/ZendExtensionManager_TS.so//" ${PHPINI}
                     fi
                     if [ "`${GREP} [Zend] ${PHPINI}`" != "" ]; then
                        perl -pi -e "s/\[Zend]//" ${PHPINI}
                     fi
                  fi
               else
                  if [ "`${GREP} suhosin.so ${PHPINI} | ${CUT} -d '=' -f2 | ${CUT} -d '"' -f2 | ${CUT} -d '/' -f3`" = "lib" ] && [ "${PHPPREFIX}" = "/usr/local" ]; then
                     GREPPED="`${GREP} suhosin.so ${PHPINI} | ${CUT} -d '=' -f2 | ${CUT} -d '"' -f2`"
                     perl -pi -e "s/${GREPPED}/suhosin\/suhosin.so/" ${PHPINI}
                  fi
                  if [ "`${GREP} suhosin.so ${PHPINI} | ${CUT} -d '=' -f2 | ${CUT} -d '"' -f2 | ${CUT} -d '/' -f3`" = "local" ] && [ "${PHPPREFIX}" = "/usr" ]; then
                     GREPPED="`${GREP} suhosin.so ${PHPINI} | ${CUT} -d '=' -f2 | ${CUT} -d '"' -f2`"
                     perl -pi -e "s/${GREPPED}/suhosin\/suhosin.so/" ${PHPINI} 
                  fi
                  GREPPED="`${GREP} suhosin.version ${PHPINI}`"
                  perl -pi -e "s/${GREPPED}/;suhosin.version=${LATESTSUHOSIN}/" ${PHPINI}
               fi
               echo "suhosin installation/update complete."
               echo "Restarting Apache..."
               /etc/init.d/httpd restart
               echo "Done."
            fi
         else
            echo "Not installing/updating suhosin."
         fi
   else
      echo "suhosin is up to date [ Version: ${LATESTSUHOSIN} ]"
   fi
   if [ "${DOALL}" != "1" ]; then
      ${RM} -f ${INSTALLDIR}/versions
   fi
}

## Install/Update Zend Optimizer
dozendopt() {
   echo
   if [ "${SKIPCURRENTS}" != "1" ]; then
      if [ "$ARCH" = "i386" ]; then
         latestversionfunc LATESTZENDOPT zendopt-i386
         latestmd5func ZENDOPTMD5 zendopt-i386
      else
         latestversionfunc LATESTZENDOPT zendopt-x86_64
         latestmd5func ZENDOPTMD5 zendopt-x86_64
      fi
      CURRENTZENDOPT=""
      if [ "$PHPINSTALLED" = "1" ]; then
         CURRENTZENDOPT=`${PHPBINARY} -v | ${GREP} -i 'zend optimizer' | ${AWK} '{ print $4 }' | ${CUT} -d 'v' -f 2 | ${CUT} -d ',' -f1`
      fi
   fi
   if [ "$ARCH" = "i386" ] || [ "$ARCH" = "x86_64" ]; then
      echo
      if [ "${FORCEZENDOPTINSTALL}" = "1" ]; then
         echo "Forcing Zend Optimizer Install."
         CURRENTZENDOPT=NONE
      fi
      if [ "${CURRENTZENDOPT}" != "${LATESTZENDOPT}" ]; then
         if [ "${CURRENTZENDOPT}" = "" ]; then
            echo "ELS can now install Zend Optimizer."
         else
            echo "Zend Optimizer is out of date. [ Installed: ${CURRENTZENDOPT} Latest: ${LATESTZENDOPT} ]"
            echo "ELS can now update Zend Optimizer."
         fi
         proceedfunc
         if [ "${PROCEEDASK}" = "y" ]; then
            cd ${INSTALLDIR}/src
               ${RM} -rf Zend*
            echo "Downloading Zend Optimizer..."
            if [ "$ARCH" = "i386" ]; then
               ${WGET} -q ${MIRROR}/zendoptimizer/ZendOptimizer-${LATESTZENDOPT}-linux-glibc21-i386.tar.gz
            else
               ${WGET} -q ${MIRROR}/zendoptimizer/ZendOptimizer-${LATESTZENDOPT}-linux-glibc23-x86_64.tar.gz
            fi
            if [ "$ARCH" = "i386" ]; then
                  if [ "`${MD5SUM} ZendOptimizer-$LATESTZENDOPT-linux-glibc21-i386.tar.gz | ${CUT} -d ' ' -f 1`" = "${ZENDOPTMD5}" ]; then
                  echo "Download Successful!"
                  echo "MD5 matches."
                     echo "Extracting..."
               else
                  echo "Download Failed."
                  echo "Invalid MD5."
                  echo "Aborting."
                  exit
                   fi
            else
               if [ "`${MD5SUM} ZendOptimizer-${LATESTZENDOPT}-linux-glibc23-x86_64.tar.gz | ${CUT} -d ' ' -f 1`" = "${ZENDOPTMD5}" ]; then
                  echo "Download Successful!"
                  echo "MD5 matches."
                     echo "Extracting..."
               else
                  echo "Download Failed."
                  echo "Invalid MD5."
                  echo "Aborting."
                  exit
                     fi
            fi
            if [ "$ARCH" = "i386" ]; then
               ${TAR} xzf ZendOptimizer-${LATESTZENDOPT}-linux-glibc21-i386.tar.gz
            else
               ${TAR} xzf ZendOptimizer-${LATESTZENDOPT}-linux-glibc23-x86_64.tar.gz
            fi
            ${RM} -f ZendOptimizer-${LATESTZENDOPT}-*.tar.gz
            cd ZendOptimizer-${LATESTZENDOPT}-linux-*
            if [ -f ./install.sh ]; then
               echo "Extraction Successful!"
            else
               echo "Extraction failed."
               echo "Aborting."
               exit
            fi
            echo "Running installer now..."
            sh install.sh
            cd ${INSTALLDIR}/src
            ${RM} -rf Zend*
            /etc/init.d/httpd restart
         else
            echo "Not installing/updating Zend Optimizer."
         fi
      else
         echo "Zend Optimizer is up to date [ Version: ${LATESTZENDOPT} ]"
      fi
   else
      echo "This version of Zend Optimizer only works on i386 and x86_64 machines."
      echo "You can download other versions of Zend Optimizer and install"
      echo "manually from www.zend.com."
   fi
   if [ "${DOALL}" != "1" ]; then
      ${RM} -f ${INSTALLDIR}/versions
   fi
}

## Update ImageMagick
doimagemagick() {
   echo
   if [ "${SKIPCURRENTS}" != "1" ]; then
      latestversionfunc LATESTIMAGEMAGICK imagemagick-latest
      latestmd5func IMAGEMAGICKMD5 imagemagick-latest
         if [ -f /usr/bin/convert ] || [ -f /usr/local/bin/convert ]; then
            CURRENTIMAGEMAGICK=`convert -v | ${HEAD} -n1 | ${AWK} '{ print $3 }'`
         if [ -f ${INSTALLDIR}/imagemagic_version ]; then
            CURRENTIMAGEMAGICK=`${CAT} ${INSTALLDIR}/imagemagic_version`
         fi
      fi
   fi
   if [ "${CURRENTIMAGEMAGICK}" != "${LATESTIMAGEMAGICK}" ]; then
      if [ "${CURRENTIMAGEMAGICK}" = "" ]; then
         echo "ImageMagick is not installed."
         echo "ELS can now install ImageMagick."
      else
         echo "ImageMagick is out of date. Installed: ${CURRENTIMAGEMAGICK} Latest: ${LATESTIMAGEMAGICK}"
         echo "ELS can now update ImageMagick."
      fi
      proceedfunc
      if [ "${PROCEEDASK}" = "y" ]; then
         if [ "${DISTRO}" != "DEBIAN3" ]; then
            ensurerpm gcc IMAGEMAGICKCANCEL
         else
            ensuredeb gcc IMAGEMAGICKCANCEL
         fi
         if [ "${IMAGEMAGICKCANCEL}" = "1" ]; then
            echo "Skipping ImageMagick install/update due to dependency errors."
         else
            if [ -f /usr/local/bin/convert ]; then
               IMAGEMAGICKPREFIX=/usr/local
            else
               IMAGEMAGICKPREFIX=/usr
            fi
            if [ "`${RPM} -q ImageMagick`" != "package ImageMagick is not installed" ]; then
               echo
               echo "This will uninstall the ImageMagick RPM currently installed."
               echo "Are you still sure you want to have ImageMagick compiled from source?"
               echo "If you want security and stability, stick with the distribution RPM,"
               echo "but if you want the latest release of ImageMagick, continue on."
               echo "Uninstall RPM and continue? (y/n):"
               proceedfunc
               if [ "${PROCEEDASK}" = "y" ]; then
                  echo "Uninstalling ImageMagick RPM..."
                  ${RPM} -ev --nodeps ImageMagick
                  echo "Done."
               else
                  echo "Good choice.  Skipping ImageMagick update."
                  SKIPIMAGEMAGICK=1
               fi
            fi
            if [ "${SKIPIMAGEMAGICK}" != "1" ]; then
               cd ${INSTALLDIR}/src
               ${RM} -rf ImageMagick*
               ${WGET} -q ${MIRROR}/imagemagick/ImageMagick-${LATESTIMAGEMAGICK}.tar.gz
               if [ "`${MD5SUM} ImageMagick-${LATESTIMAGEMAGICK}.tar.gz | ${CUT} -d ' ' -f 1`" = "$IMAGEMAGICKMD5" ]; then
                  echo "Download Successful!"
                  echo "MD5 matches."
                  echo "Extracting..."
               else
                  echo "Download Failed."
                  echo "Invalid MD5."
                  echo "Aborting."
                  exit
               fi
               ${TAR} xzf ImageMagick-${LATESTIMAGEMAGICK}.tar.gz
               ${RM} -f ImageMagick-${LATESTIMAGEMAGICK}.tar.gz
               cd ImageMagick-*
                  if [ -f ./configure ]; then
                  echo "Extraction Successful!"
               else
                  echo "Extraction failed."
                  echo "Aborting."
                  exit
               fi
               echo "Installing..."
               ./configure --prefix=${IMAGEMAGICKPREFIX}
               make
               make install
               cd PerlMagick
               perl Makefile.PL
               make
               make install
               cd ${INSTALLDIR}/src
               ${RM} -rf ImageMagick-*
               echo ${LATESTIMAGEMAGICK} > ${INSTALLDIR}/imagemagic_version
               if [ "${CONTROLPANEL}" = "1" ]; then
                  /scripts/perlinstaller --force Image::Magick
               fi
               echo "Done."
            fi
         fi
      else
         echo "Not updating ImageMagick."
      fi
   else
      echo "ImageMagick is up to date [ Version: ${LATESTIMAGEMAGICK} ]"
   fi
   if [ "${DOALL}" != "1" ]; then
      ${RM} -f ${INSTALLDIR}/versions
   fi
}

## The Exim Dictionary Attack ACL for cPanel is created by Chirpy at www.configservers.com.
## The following installer uses the steps provided at the website and all credit to Chirpy.
## Information and instructions at http://www.configserver.com/free/eximdeny.html
doeximdictatk() {
   if [ "${CONTROLPANEL}" = "1" ]; then
      echo
      if [ -f /etc/exim_deny.pl ]; then
         echo "Exim Dictionary Attack ACL already installed"
      else
         echo "ELS can install the Exim Dictionary Attack ACL"
         echo "Created by Chirpy from www.configservers.com"
         proceedfunc
         if [ "${PROCEEDASK}" = "y" ]; then
            ${WGET} -q --output-document=${INSTALLDIR}/exin_deny.txt http://www.configserver.com/free/exim_deny.txt
            mv --force ${INSTALLDIR}/exin_deny.txt /etc/exim_deny.pl
            touch /etc/exim_deny
            touch /etc/exim_deny_whitelist
            chown mailnull:mail /etc/exim_deny /etc/exim_deny.pl /etc/exim_deny_whitelist
            chmod 700 /etc/exim_deny.pl
            chmod 600 /etc/exim_deny /etc/exim_deny_whitelist
            if [ "`${GREP} 'drop hosts = /etc/exim_deny' /etc/exim.conf.mailman2.dist`" = "" ]; then
               GREPPED="`grep "accept  hosts = :" /etc/exim.conf.mailman2.dist`"
               perl -pi -e "s/${GREPPED}/accept  hosts = :\n\ndrop hosts = /etc/exim_deny\n    !hosts = /etc/exim_deny_whitelist\n    message = Connection denied after dictionary attack\n    log_message = Connection denied from \$sender_host_address after dictionary attack\n    !hosts = +relay_hosts\n    !authenticated = *\n\ndrop message = Appears to be a dictionary attack\n    log_message = Dictionary attack (after \$rcpt_fail_count failures)\n    condition = \${if > {\${eval:\$rcpt_fail_count}}{3}{yes}{no}}\n    condition = \${run{/etc/exim_deny.pl \$sender_host_address }{yes}{no}}\n    !verify = recipient\n    !hosts = /etc/exim_deny_whitelist\n    !hosts = +relay_hosts\n    !authenticated = */" /etc/exim.conf.mailman2.dist
            fi
            if [ "`${GREP} 'drop hosts = /etc/exim_deny' /etc/exim.conf`" = "" ]; then
               GREPPED="`grep "accept  hosts = :" /etc/exim.conf`"
               perl -pi -e "s/${GREPPED}/accept  hosts = :\n\ndrop hosts = /etc/exim_deny\n    !hosts = /etc/exim_deny_whitelist\n    message = Connection denied after dictionary attack\n    log_message = Connection denied from \$sender_host_address after dictionary attack\n    !hosts = +relay_hosts\n    !authenticated = *\n\ndrop message = Appears to be a dictionary attack\n    log_message = Dictionary attack (after \$rcpt_fail_count failures)\n    condition = \${if > {\${eval:\$rcpt_fail_count}}{3}{yes}{no}}\n    condition = \${run{/etc/exim_deny.pl \$sender_host_address }{yes}{no}}\n    !verify = recipient\n    !hosts = /etc/exim_deny_whitelist\n    !hosts = +relay_hosts\n    !authenticated = */" /etc/exim.conf
            fi
            /etc/init.d/exim restart
            perl -pi -e "s/:blackhole:/:fail:/" /etc/valiases/*
            ln -s /etc/exim_deny.pl /etc/cron.hourly/
         else
            echo "Not installing Exim Dictionary Attack ACL."
         fi
      fi
   fi
}

## Change the port the SSH deamon is listening on (also modifies APF configuration to use new port)
dosshport() {
   if [ -f /etc/ssh/sshd_config ]; then
      echo
      if [ "`${GREP} -m1 -i 'port 22' /etc/ssh/sshd_config`" != "" ]; then
         echo "Changing SSH to use a non-default port helps prevent"
         echo "against Brute Force attacks and potential hackers."
         echo "If you choose to change the SSH port, ensure the port is"
         echo "not already in use by another program.  There is a chance"
         echo "of locking yourself out of SSH, so it is recommended to"
         echo "add your Desktop's IP address to /etc/apf/allow_hosts.rules."
         echo "ELS can now change your SSH port for you."
         proceedfunc
         if [ "${PROCEEDASK}" = "y" ]; then
            echo "Which port would you like to use for the SSH Deamon?"
            read SSHTCPPORT
            echo "You chose '$SSHTCPPORT'.  Ensure this is correct before continuing."
            proceedfunc
            if [ "${PROCEEDASK}" = "y" ]; then
               GREPPED="`${GREP} -i 'port 22' /etc/ssh/sshd_config`"
               perl -pi -e "s/${GREPPED}/Port $SSHTCPPORT/" /etc/ssh/sshd_config
               if [ -d /etc/apf ]; then
                  ${GREP} IG_TCP_CPORTS /etc/apf/conf.apf > ${INSTALLDIR}/apfsshport.tmp
                  GREPPED1="`${GREP} \"# IG_TCP_CPORTS\" ${INSTALLDIR}/apfsshport.tmp`"
                  GREPPED2="`${GREP} \"# IG_TCP_CPORTS\" ${INSTALLDIR}/apfsshport2.tmp`"
                  GREPPED3="`${GREP} IG_TCP_CPORTS ${INSTALLDIR}/apfsshport2.tmp`"
                  GREPPED4="`${GREP} IG_TCP_CPORTS ${INSTALLDIR}/apfsshport.tmp`"
                  GREPPED5="`${GREP} \"# EG_TCP_CPORTS\" ${INSTALLDIR}/apfsshport.tmp`"
                  GREPPED6="`${GREP} \"# EG_TCP_CPORTS\" ${INSTALLDIR}/apfsshport2.tmp`"
                  GREPPED7="`${GREP} EG_TCP_CPORTS ${INSTALLDIR}/apfsshport2.tmp`"
                  GREPPED8="`${GREP} EG_TCP_CPORTS ${INSTALLDIR}/apfsshport.tmp`"
                  perl -pi -e "s/${GREPPED1}//" ${INSTALLDIR}/apfsshport.tmp
                  ${GREP} IG_TCP_CPORTS /etc/apf/conf.apf > ${INSTALLDIR}/apfsshport2.tmp
                  perl -pi -e "s/${GREPPED2}//" ${INSTALLDIR}/apfsshport2.tmp
                  perl -pi -e "s/,22,/,${SSHTCPPORT},/" ${INSTALLDIR}/apfsshport.tmp
                  perl -pi -e "s/${GREPPED3}/${GREPPED4}/" /etc/apf/conf.apf
                  ${RM} -rf ${INSTALLDIR}/apfsshport*
                  ${GREP} EG_TCP_CPORTS /etc/apf/conf.apf > ${INSTALLDIR}/apfsshport.tmp
                  perl -pi -e "s/${GREPPED5}//" ${INSTALLDIR}/apfsshport.tmp
                  ${GREP} EG_TCP_CPORTS /etc/apf/conf.apf > ${INSTALLDIR}/apfsshport2.tmp
                  perl -pi -e "s/${GREPPED6}//" ${INSTALLDIR}/apfsshport2.tmp
                  perl -pi -e "s/22/${SSHTCPPORT}/" ${INSTALLDIR}/apfsshport.tmp
                  perl -pi -e "s/${GREPPED7}/${GREPPED8}/" /etc/apf/conf.apf
                  ${RM} -rf ${INSTALLDIR}/apfsshport*
                  /etc/init.d/apf restart
                  echo "Done."
               fi
               /etc/init.d/sshd restart
            else
               sshport
            fi
         else
            echo "Leaving SSH port as 22."
         fi
      else
         echo "SSH Port already changed."
      fi
   fi
}

## Add a wheel user and force no root login in the SSH deamon's configuration
dowheeluser() {
   echo
   if [ "`${GREP} -m1 -i 'permitrootlogin' /etc/ssh/sshd_config | ${AWK} '{print $2}'`" != "no" ] && [ "`${GREP} -m1 -i 'permitrootlogin' /etc/ssh/sshd_config | ${AWK} '{print $2}'`" != "No" ]; then
      echo "Disabling root login to SSH adds an extra layer of security"
      echo "to prevent hackers from gaining root access.  It requires"
      echo "you to login as a special user and then use the command"
      echo "'su -' to get prompted for root password and become root."
      echo "You should be careful and write the information necessary"
      echo "down incase you need it."
      proceedfunc
      if [ "${PROCEEDASK}" = "y" ]; then
         echo "What username would you like for the wheel user?"
         read WHEELUSERNAME
         echo "You enetered '${WHEELUSERNAME}'.  Ensure this is correct before continuing."
         proceedfunc
         if [ "${PROCEEDASK}" = "y" ]; then
            if [ -d /home/${WHEELUSERNAME} ]; then
               echo "User already exists.  Please select a different username."
               wheeluser
            fi
            adduser -G wheel -m -s /bin/bash -d /home/${WHEELUSERNAME} ${WHEELUSERNAME}
            echo "Please enter a password."
            passwd ${WHEELUSERNAME}
            if [ "`groups ${WHEELUSERNAME} | ${GREP} wheel`" != "" ]; then
               echo "User addition success!  Editing SSHd config and restarting service..."
               GREPPED="`${GREP} -m1 -i 'permitrootlogin' /etc/ssh/sshd_config`"
               perl -pi -e "s/${GREPPED}/PermitRootLogin no/" /etc/ssh/sshd_config
               /etc/init.d/sshd restart
               echo "Done."
            else
               echo "Operation failed."
               echo "SSH still allowing root login."
            fi
         else
            wheeluserask
         fi
      else
         echo "Allowing root login over SSH"
      fi
   else
      echo "SSH deamon already not allowing root login."
   fi
}

dofantasticoinstall() {
   echo
   if [ "${CONTROLPANEL}" = "1" ]; then
      echo "This will install the Fantastico files for cPanel/WHM."
      proceedfunc
      if [ "${PROCEEDASK}" = "y" ]; then
         echo -n "Retrieving Fantastico..."
         cd /usr/local/cpanel/whostmgr/docroot/cgi
         wget -q http://files.betaservant.com/files/free/fantastico_whm_admin.tgz
         echo "Done."
         echo -n "Uncompressing and installing..."
         tar -zxpf fantastico_whm_admin.tgz
         ${RM} -f fantastico_whm_admin.tgz
         echo "Done."
         echo "You can now setup Fantastico in WHM (if your server is already licensed)."
      else
         echo "Not installing Fantastico files."
      fi
   else
      echo "cPanel/WHM not detected."
      echo "Unable to install Fantastico."
   fi
}

## Print the footer
footer() {
   echo
   echo "Easy Linux Security (ELS) Copyright (C) 2005-2007 by Martynas Bendorius and Rich Gannon."
   echo "Please email bug reports to rich@servermonkeys.com or martynas@e-vaizdas.net."
   echo
}

postmessage() {
   if [ "${APFCONFIGNOTICE}" = "1" ]; then
      echo "** IMPORTANT **"
      echo "APF has been installed or updated.  Please ensure the configuration"
      echo "is correct (/etc/apf/conf.apf) and once it is correct and confirmed"
      echo "to work correctly, be sure to change DEVEL_MODE=\"1\" to \"0\" or else"
      echo "your firewall rules will be flushed after 5 minutes of starting APF."
      echo
   fi
   if [ "${NEWBINSYM}" = "1" ]; then
      echo "** NOTE **"
      echo "You can now call ELS with simply \`els --option\` instead of"
      echo "\`/usr/local/els/els.sh --option\`.  If for some reason this does fail,"
      echo "ensure '/usr/local/bin' is in your \$PATH."
      echo
   fi
}

doshowhelp(){
   echo "ELS specific commands:"
   echo "  --checkall          : Check if everything is okay"
   echo "  --help              : Print this help screen"
   echo "  --update            : Update the ELS (this) program to the latest"
   echo "                      : version"
   echo "  --version           : Print the current ELS version"
   echo ""
   echo ""
   echo "ELS usage:"
   echo "  --all               : Install/update all supported software, improve"
   echo "                      : security and optimize some programs and"
   echo "                      : configurations"
   echo "  --apc               : Install/Update APC (Alternative PHP Cache)"
   echo "  --apf               : Install/Update APF Firewall"
   echo "  --bfd               : Install/Update BFD (Brute Force Detection)"
   echo "  --chkrootkit        : Install/Update CHKROOTKIT"
   echo "  --chkrootkitcron    : Install a CHKROOTKIT cronjob (to run nightly)"
   echo "  --chmodfiles        : Chmod dangerous files to root only"
   echo "  --cpvcheck          : Check your control panel version"
   echo "  --disablephpfunc    : Disable dangerous PHP functions"
   echo "  --disabletelnet     : Disable telnet"
   echo "  --distrocheck       : Check your OS version"
   echo "  --eaccelerator      : Install/Update eAccelerator"
   echo "  --forcessh2         : Force SSH protocol 2"
   echo "  --hardensysctl      : Hardening sysctl.conf"
   echo "  --imagemagick       : Install/Update ImageMagick"
   echo "  --libsafe           : Install/Update Libsafe"
   echo "  --mysqloptimizedb   : Run a simple MySQL table optimization and repair command"
   echo "  --mysqlrenice       : Renice MySQL to -20 for highest priority"
   echo "  --mytop             : Install/Update MyTOP"
   echo "  --optimizemysqlconf : Optimize MySQL configuration file (/etc/my.cnf)"
   echo "  --rkhunter          : Install/Update RKHunter"
   echo "  --rkhuntercron      : Install a RKHunter cronjob (to run nightly)"
   echo "  --rootloginemail    : Add an alert for root login to"
   echo "                      : /root/.bash_profile (email must be provided"
   echo "                      : for this option)"
   echo "  --securepartitions  : Secure /tmp, /var/tmp, and /dev/shm partitions"
   echo "                      : (whether in /etc/fstab or not)"
   echo "  --setupcrons        : Setup RKHunter and CHKROOTKIT cronjobs as well"
   echo "                      : as Root Login Alert"
   echo "  --sshport           : Change the port the SSH deamon is listening on"
   echo "                      : (also modifies APF config to use new port)"
   echo "  --suhosin           : Install/Update suhosin"
   echo "  --up2dateconfig     : Edit up2date configuration file to exclude some"
   echo "                      : programs"
   echo "  --vps               : Similiar to --all, but skips operations not"
   echo "                      : compatable with Virtual Private Servers"
   echo "  --wheeluser         : Add a wheel user and force no root login in the"
   echo "                      : SSH deamon's configuration"
   echo "  --yumconfig         : Edit yum configuration file to exclude some"
   echo "                      : programs"
   echo "  --xcache            : Install/Update XCache"
   echo "  --zendopt           : Install/Update Zend Optimizer"
   echo ""
   echo ""
   echo "Remove/Undo functions:"
   echo "  --enablephpfunc     : Enable dangerous PHP functions"
   echo "  --enablephprg       : Enable PHP register_globals"
   echo "  --removeapf         : Remove APF firewall"
   echo "  --removebfd         : Remove BFD (Brute Force Detection)"
   echo "  --rmchkrootkitcron  : Remove a CHKROOTKIT cronjob"
   echo "  --rmrkhuntercron    : Remove a RKHunter cronjob"
   echo "  --undomysqlrenice   : Undo MySQL renice"
   echo ""
   echo ""
   echo "DirectAdmin specific commands:"
   echo "  --updateda          : Update DirectAdmin version"
   echo ""
   echo ""
   echo "cPanel specific commands:"
   echo "  --eximdictatk       : Install the Exim Dictionary Attack ACL for"
   echo "                      : cPanel/WHM servers"
   echo "  --fantasticoinstall : Install the Fantastico files for cPanel/WHM"
   echo "                      : servers"
   echo "  --fixrndc           : Fix RNDC if not already configured on"
   echo "                      : cPanel/WHM servers"
   echo "  --tweakcpsettings   : Tweak cPanel's Tweak Settings file"
   echo ""
   if [ "${CURRENTVERSION}" != "${LATESTVERSION}" ]; then
   echo ""
   echo "You're running an old version of ELS. [ Version: ${CURRENTVERSION} ]"
   echo "The latest version is Version: ${LATESTVERSION}."
   echo "Run with '--update' argument to update now."
   echo ""
   fi
}

##################################################################
## Execute the program
##################################################################

## Always perform rootcheck, supported distros and version file download before anything else
rootcheck
supporteddistros
controlpanelcheck
checkversionsdown

case "$1" in
   --all)
      DOALL=1
      adminemail
      if [ -e /etc/sysconfig/rhn/up2date ]; then
         up2dateconfig
      fi
      if [ -e /etc/yum.conf ]; then
         yumconfig
      fi
      doremovelaus
      dodisableselinux
      dohardensysctl
      docpanelupdate
      dofixrndc
      dotweakcpsettings
      dorootloginemail
      dorkhunter
      dorkhuntercron
      dochkrootkit
      dochkrootkitcron
      doapf
      dobfd
      dolibsafe
      domytop
      dodisabletelnet
      doforcessh2
      dochmodfiles
      dodisablephprg
      dodisablephpfunc
      dooptimizemysqlconf
      domysqlrenice
      domysqloptimizedb
      doimagemagick
      doeximdictatk
      dosshport
      dowheeluser
      footer
      postmessage
   ;;
   --setupcrons)
      dorkhuntercron
      dochkrootkitcron
   ;;
   --version)
      doversioncheck
   ;;
   --checkall)
      docheckall
   ;;
   --up2dateconfig)
      up2dateconfig
   ;;
   --yumconfig)
      yumconfig
   ;;
   --distrocheck)
      dodistrocheck
   ;;
   --cpvcheck)
      docontrolpanelvcheck
   ;;
   --updateda)
      doupdateda
   ;;
   --removelaus)
      doremovelaus
   ;;
   --disableselinux)
      dodisableselinux
   ;;
   --hardensysctl)
      dohardensysctl
   ;;
   --fixrndc)
      dofixrndc
   ;;
   --tweakcpsettings)
      dotweakcpsettings
   ;;
   --rootloginemail)
      if [ "${DOALL}" != "1" ]; then
         adminemail
      fi
      dorootloginemail
   ;;
   --rkhunter)
      dorkhunter
   ;;
   --rkhuntercron)
      if [ "${DOALL}" != "1" ]; then
         adminemail
      fi
      dorkhuntercron
   ;;
   --chkrootkit)
      dochkrootkit
   ;;
   --chkrootkitcron)
      if [ "${DOALL}" != "1" ]; then
         adminemail
      fi
      dochkrootkitcron
   ;;
   --apf)
      adminip
      doapf
   ;;
   --bfd)
      if [ "${ADMINIP}" = "" ]; then
         adminip
      fi
      dobfd
   ;;
   --libsafe)
      dolibsafe
   ;;
   --mytop)
      domytop
   ;;
   --disabletelnet)
      dodisabletelnet
   ;;
   --forcessh2)
      doforcessh2
   ;;
   --chmodfiles)
      dochmodfiles
   ;;
   --enablephprg)
      doenablephprg
   ;;
   --disablephprg)
      dodisablephprg
   ;;
   --disablephpfunc)
      dodisablephpfunc
   ;;
   --enablephpfunc)
      doenablephpfunc
   ;;
   --securepartitions)
      dosecurepartitions
   ;;
   --optimizemysqlconf)
      dooptimizemysqlconf
   ;;
   --mysqlrenice)
      domysqlrenice
   ;;
   --undomysqlrenice)
      doundomysqlrenice
   ;;
   --rmchkrootkitcron)
      dormchkrootkitcron
   ;;
   --rmrkhuntercron)
      dormrkhuntercron
   ;;
   --removeapf)
      doremoveapf
   ;;
   --removebfd)
      doremovebfd
   ;;
   --mysqloptimizedb)
      domysqloptimizedb
   ;;
   --eaccelerator)
      doeaccelerator
   ;;
   --apc)
      doapc
   ;;
   --xcache)
      doxcache
   ;;
   --suhosin)
      dosuhosin
   ;;
   --zendopt)
      dozendopt
   ;;
   --imagemagick)
      doimagemagick
   ;;
   --eximdictatk)
      doeximdictatk
   ;;
   --sshport)
      dosshport
   ;;
   --wheeluser)
      dowheeluser
   ;;
   --fantasticoinstall)
      dofantasticoinstall
   ;;
   --update)
      sh ${INSTALLDIR}/updater.sh
   ;;
   --vps)
   DOALL=1
   SKIPMKE2FS=1
   adminemail
   if [ -e /etc/sysconfig/rhn/up2date ]; then
      up2dateconfig
   fi
   if [ -e /etc/yum.conf ]; then
      yumconfig
   fi
   doremovelaus
   dodisableselinux
   docpanelupdate
   dofixrndc
   dotweakcpsettings
   dorootloginemail
   dorkhunter
   dorkhuntercron
   dochkrootkit
   dochkrootkitcron
   dolibsafe
   domytop
   dodisabletelnet
   doforcessh2
   dochmodfiles
   dodisablephprg
   dodisablephpfunc
   optimizemysqlconf
   domysqlrenice
   domysqloptimizedb
   doimagemagick
   doeximdictatk
   dowheeluser
   footer
   postmessage
   ${RM} -f ${INSTALLDIR}/versions
   ;;
   --help)
      doshowhelp
      exit 0;
   ;;
   *)
      doshowhelp
      exit 0;
   ;;
esac
exit 0;
