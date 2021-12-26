export DTE=`/bin/date +%C%y.%m.%d.%H.%M`
ORACLE_SID=aries1
export $ORACLE_SID
ORAENV_ASK=NO
. oraenv
cd /ggs

echo 'INFO E* DETAIL' | ./ggsci | awk '/EXTRACT/ {print $1, $2 } / Trail Name/{getline;getline;print "Writes to: " $1 $2;} /Log Read Checkpoint/{print " Reads from: " $4 " " $5 " " $6}' > /tmp/rba.log

_input="/tmp/rba.log"

echo 
echo -----------  Extracts  -----------

while IFS=' ' read -r extract seq rba
do
  if [ $extract == 'EXTRACT' ]
  then
     echo
  fi
  echo $extract $seq $rba
done < "$_input"

rm -f /ggs/rba.log

echo 'INFO P* DETAIL' | ./ggsci | awk '/EXTRACT/ {print $1, $2 } / Trail Name/{getline;getline;print "Writes to: " $1 $2;} /Log Read Checkpoint/{print " Reads from: " $4 " " $5 " " $6}' > /tmp/rba.log

_input="/tmp/rba.log"

echo 
echo -----------  Pumps  -----------

while IFS=' ' read -r extract seq rba
do

  if [ $extract == 'EXTRACT' ]
  then
     echo
  fi
  echo $extract $seq $rba

done < "$_input"

rm -f /ggs/rba.log
