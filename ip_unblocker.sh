#!/bin/bash --

# ip_unblocker
#
# Copyright (C) 2017  umair siddiqui (umair siddiqui 2011 at gmail)
#
# ip_unblocker remove ipsets and rules created by ip_blocker    
# 
##########################################################################
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

Countries=""

if [[ "$1" == "" ]];
then
    echo usage: sudo $0 list-of-countries-code
    echo
    echo               -or-
    echo 
    echo        sudo $0 all
    echo
    echo
    echo e.g  : sudo $0 pw,cc,mx
    echo  
    echo        sudo $0 all 
    echo
    exit 1
else
    Countries="$1"
fi


if [ "x$(id -u)" != 'x0' ];
then
    echo $0 requires root/sudo
    exit 1
fi


if [[ "$Countries" == "all" ]]; then
    list_ipset=$(ipset list | grep Name | grep -o -e 'ban_ipv._.*_part_.*' )
else
    for k in ${Countries//,/ }
    do
        l=$(ipset list | grep Name | grep -o -e "ban_ipv._${k}_part_.*" )
        list_ipset="$list_ipset $l"
    done
fi

for i in $list_ipset
do
    echo removing ipset $i and its firewall rules
    firewall-cmd --permanent --delete-ipset=$i &> /dev/null
    ipset destroy $i &> /dev/null
    firewall-cmd --permanent --remove-rich-rule="rule source ipset=$i drop"
    firewall-cmd --reload 
done





