#!/bin/bash --

# ip_blocker
#
# Copyright (C) 2017  umair siddiqui (umair siddiqui 2011 @ gmail)
#
# ip_blocker script for firewalld to block entire countries, uses Maxmind ip database.    
#  
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




TMP_DIR=/tmp
DATA_DIR=$TMP_DIR/geoip
Countries=""

function chk_args() {
    if [[ "$1" == "" ]];
    then
        echo usage: sudo $0 list-of-countries-code
        echo 
        echo e.g  : sudo $0 pw,cc,mx
        echo  
        echo 
        echo
        exit 1
    else
        Countries="$1"
    fi 
}


function pre_req(){
    if [ "x$(id -u)" != 'x0' ];
    then
        echo $0 requires root/sudo
        exit 1
    fi

    if [[ ! -e /usr/bin/unzip ]]; 
    then
        yum install unzip -y
    fi
    if [[ ! -e /usr/bin/wget ]];
    then
        yum install wget -y
    fi
}

function chk_db(){

    (cd $TMP_DIR; echo $(cat GeoLite2-City-CSV.zip.md5) GeoLite2-City-CSV.zip | md5sum -c &> /dev/null)

    if [[ "x$?" == "x1" ]]; then
        echo db checksum fail, exiting
        exit 1
    else
        echo 0 > /dev/null 
    fi
}


function dl_db( ) {
    echo downloading ip database 
    rm -rf $TMP_DIR/GeoLite2-City-CSV.zip
    rm -rf $TMP_DIR/GeoLite2-City-CSV.zip.md5
    wget -c -O $TMP_DIR/GeoLite2-City-CSV.zip  http://geolite.maxmind.com/download/geoip/database/GeoLite2-City-CSV.zip  
    wget -c -O $TMP_DIR/GeoLite2-City-CSV.zip.md5 http://geolite.maxmind.com/download/geoip/database/GeoLite2-City-CSV.zip.md5
}

function ext_db(){

    rm -rf $DATA_DIR
    mkdir -p $DATA_DIR

    unzip $TMP_DIR/GeoLite2-City-CSV.zip -d $DATA_DIR &> /dev/null
    mv $DATA_DIR/*/*.csv $DATA_DIR

}

function mk_banip_file(){
    regfile=$1
    ipfile=$2
    outfile=$3
    
    for r in $(cat $regfile);
    do
        grep $r $ipfile | awk -F, -e '{print $1}' >> $outfile
    done
    
    bname=$(basename $outfile .txt)
    split -d -l65530 $outfile ${DATA_DIR}/${bname}_part_

}

function mk_ip_set() {
    ipv6=$1
    ip_set_name=$2
    bname=$(basename $ip_set_name)
    replace_old=0

    echo creating ipset $bname from $ip_set_name

    if [[ "x$ipv6" == "x0" ]]; then
        family="inet"
    else
        family="inet6"
    fi

    ipset list $bname &> /dev/null

    if [[ "x$?" == "x1" ]]
    then
        firewall-cmd --permanent --new-ipset=$bname --type=hash:net --option=family=$family    
        firewall-cmd --permanent --ipset=$bname --add-entries-from-file=$ip_set_name 
        firewall-cmd --permanent --add-rich-rule="rule source ipset=$bname drop"
        firewall-cmd --reload
    else
        ipset_dump=$(mktemp -p $TMP_DIR dump.XXXXXX)
        mark4add=$(mktemp  -p $TMP_DIR mark4add.XXXXXX)
        mark4rm=$(mktemp -p $TMP_DIR mark4rm.XXXXXX)
        sorted_ip_set_name=$(mktemp -p $TMP_DIR ip_set_name.XXXXXX)

        cat $ip_set_name | sort > $sorted_ip_set_name

        firewall-cmd --ipset=$bname --get-entries | sort > $ipset_dump

        # add new entries in updated db
        diff --old-line-format= --unchanged-line-format= --new-line-format='%L' $ipset_dump  $sorted_ip_set_name >  $mark4add
        if [ -s $mark4add ];
        then
            firewall-cmd --permanent --ipset=$bname --add-entries-from-file=$mark4add
        fi

        # remove entries which are not present in updated db
        diff --old-line-format= --unchanged-line-format= --new-line-format='%L' $sorted_ip_set_name $ipset_dump > $mark4rm
        if [ -s $mark4rm ]
        then 
            firewall-cmd --permanent --ipset=$bname --remove-entries-from-file=$mark4rm
        fi

        firewall-cmd --permanent --add-rich-rule="rule source ipset=$bname drop"
        firewall-cmd --reload

        rm -rf $ipset_dump
        rm -rf $mark4rm
        rm -rf $mark4add
        rm -rf $sorted_ip_set_name

    fi

}

chk_args "$1"
pre_req
dl_db

chk_db
ext_db

TAB1_F=$DATA_DIR/table1.csv
TAB2_F=$DATA_DIR/table2.csv
REGION_F=$DATA_DIR/regions.txt
IP4_F=$DATA_DIR/ipv4.txt
IP6_F=$DATA_DIR/ipv6.txt

BANIP4_F=$DATA_DIR/ban_ipv4
BANIP6_F=$DATA_DIR/ban_ipv6

echo processing ip database
grep -v -e 'geoname_id' $DATA_DIR/GeoLite2-City-Locations-en.csv | awk -F, -e '{printf("%s,%s\n",$1,$5)}' > $TAB1_F 
grep -v -e 'geoname_id' $DATA_DIR/GeoLite2-City-Blocks-IPv4.csv | awk -F, -e '{printf("%s,%s\n",$1,$2)}' > $IP4_F 
grep -v -e 'geoname_id' $DATA_DIR/GeoLite2-City-Blocks-IPv6.csv | awk -F, -e '{printf("%s,%s\n",$1,$2)}' > $IP6_F 

shopt -s nullglob
display_banner=0
for k in ${Countries//,/ }
do
    echo processing $k
    rm -rf $REGION_F
    grep -i $k $TAB1_F | awk -F, -e '{print $1}' > $REGION_F

    if [[ ! -s  $REGION_F ]]
    then
        continue
    fi
    display_banner=1
    cur_ban_ipv4_file=${BANIP4_F}_${k}.txt
    cur_ban_ipv6_file=${BANIP6_F}_${k}.txt

    rm -rf  $cur_ban_ipv4_file
    rm -rf  $cur_ban_ipv6_file

    touch $cur_ban_ipv4_file
    touch $cur_ban_ipv6_file

    mk_banip_file $REGION_F $IP4_F $cur_ban_ipv4_file &
    mk_banip_file $REGION_F $IP6_F $cur_ban_ipv6_file &

    for pid in $(jobs -p)
    do
        wait $pid
    done 
    
    bname4=$(basename $cur_ban_ipv4_file .txt)
    bname6=$(basename $cur_ban_ipv6_file .txt)

    for ip4_set in $(ls $DATA_DIR/${bname4}_part_*);
    do
        mk_ip_set 0 $ip4_set 
    done 

    for ip6_set in $DATA_DIR/${bname6}_part_*;
    do
        mk_ip_set 1 $ip6_set 
    done 

done

firewall-cmd reload 
shopt -u nullglob
if [[ "x$display_banner" == "x1" ]]
then
    echo ==================================================
    echo -e "created following ipsets (each size 65536)"
    echo firewall-cmd --get-ipsets | grep -e 'ban_ipv._.*_part_.*'
    echo
    echo ==================================================
    echo created following rich rules for firewalld 
    echo firewall-cmd --list-rich-rules | grep -e 'ban_ipv._.*_part_.*'
    echo
    echo ==================================================
fi




