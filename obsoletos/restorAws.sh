#!/bin/bash
# Run this script to backup dabatase and files from CPN/Locaweb server.
timestamp=`date "+%Y%m%d-%H%M%S"`

#echo "Type the database backup file: "
#read dbBkpFile

#echo "Type the files backup:"
#read bkpFile

#scp $bkpFile vaqf7zgk22cz@160.153.90.163:public_html/
#scp $dbBkpFile vaqf7zgk22cz@160.153.90.163:public_html/

mysql -u cpn11 cpn11 -pCpnPl@an0201 'drop database cpn11;' 
mysql -u cpn11 cpn11 -pCpnPl@an0201 'create database cpn11;' 
mysql -u cpn11 cpn11 -pCpnPl@an0201 < ./cpn.com.br-20210715-200819-database.sql 

echo "Done!"
