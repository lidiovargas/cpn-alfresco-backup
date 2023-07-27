#!/bin/bash
# Run this script to backup dabatase and files from CPN/Locaweb server.
timestamp=`date "+%Y%m%d-%H%M%S"`

echo "Type the database backup file: "
read dbBkpFile

echo "Type the files backup:"
read bkpFile

scp $bkpFile vaqf7zgk22cz@160.153.90.163:public_html/
scp $dbBkpFile vaqf7zgk22cz@160.153.90.163:public_html/

# mysql -u cpn11 cpn11 -p < ./20190315-181626-cpn11.sql 

echo "Done!"
