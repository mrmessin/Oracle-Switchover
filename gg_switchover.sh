####################################################################################
# Script: gg_switchover.sh
#
# Author: 
# Last Updated: 11/09/2021
#
# Description: Prepare Golden Gate to dtop running from Current Site.
#              Prepare all current Golden Gate Confogiration at Remote Site to be started.
#
# Requirements: passwordless ssh configured between primary server where Golden Gate is Running
#              and target server where Golden Gate is being swiched to run at.
#              The GG_HOME must be the same at source and target servers
#
# Parmaters: <current site Instance>
#            target server
#
# Example: ./gg_switchover.sh aries1 agoprdd4dbadm01
####################################################################################
#
# Set the environment for the oracle account
. /home/oracle/.bash_profile

# Check that the correct
if (( $# != 2 ));then
  echo "ERROR -> Wrong number of arguments - must pass local db instance, and target server where Golden Gate is moving to"
  exit 8
fi

# Set the Oracle Sid to the database instance and Target server to passed values
export ORACLE_SID=$1
export TARGET_SERVER=$2

# Set variables for process executions
export DTE=`/bin/date +%C%y.%m.%d.%H.%M`
ORAENV_ASK=NO
. oraenv

# Get locations
export SCRIPTLOC=`dirname $0`
export SCRIPTDIR=`basename $0`

# Set the logfile directory
export LOGPATH=${SCRIPTLOC}/logs
export LOGFILE=gg_switchover_${ORACLE_SID}_${TARGET_SERVER}_${DTE}.log
export LOG=$LOGPATH/$LOGFILE

export GG_HOME=/ggs

echo "----------------------------------------------------------------------------------"
echo "----------------------------------------------------------------------------------" >> ${LOG}
echo "Using Database Instance: ${ORACLE_SID}"
echo "Using Database Instance: ${ORACLE_SID}" >> ${LOG}
echo "Target Sever for GG: ${TARGET_SERVER}"
echo "Target Sever for GG: ${TARGET_SERVER}" >> ${LOG}

# Goto the local Golden Gate Home
cd ${GG_HOME}

echo "----------------------------------------------------------------------------------"
echo "----------------------------------------------------------------------------------" >> ${LOG}
echo "Getting the detail for each Extract into log for reference"
echo "Getting the detail for each Extract into log for reference" >> ${LOG}
echo "#"
echo "#" >> ${LOG}
echo 'INFO E* DETAIL' | ./ggsci | awk '/EXTRACT/{print $2}/dirdat/{print $2, $3}' | awk 'ORS=NR%2?FS:RS' >> ${LOG}
echo 'INFO E* DETAIL' | ./ggsci | awk '/EXTRACT/{print $2}/dirdat/{print $2, $3}' | awk 'ORS=NR%2?FS:RS' >  /tmp/erba.log
_einput="/tmp/erba.log"

echo "----------------------------------------------------------------------------------"
echo "----------------------------------------------------------------------------------" >> ${LOG}
echo "Execute a LOEGEND on each Extract Process to force a new trail file at next start"
echo "Execute a LOEGEND on each Extract Process to force a new trail file at next start" >> ${LOG}

while IFS=' ' read -r extract seq rba
do
   echo 'alter extract $extract LOGEND' | ./ggsci  >> ${LOG}
   echo 'stop extract $extract' | ./ggsci  >> ${LOG}
done < "${_einput}"

echo 'INFO E* DETAIL' | ./ggsci | awk '/EXTRACT/{print $2}/dirdat/{print $2, $3}' | awk 'ORS=NR%2?FS:RS' >> ${LOG}

# sleep for 30 seconds for pumps to process any remaining extract records
echo "Sleep to allow pumps to process any remaining extract records"
echo "Sleep to allow pumps to process any remaining extract records" >> ${LOG}
sleep 30

echo "----------------------------------------------------------------------------------"
echo "----------------------------------------------------------------------------------" >> ${LOG}
echo "Getting the detail for each Pump into log for reference"
echo "Getting the detail for each Pump into log for reference" >> ${LOG}
echo "#"
echo "#" >> ${LOG}
echo 'INFO P* DETAIL' | ./ggsci | awk '/EXTRACT/{print $2}/dirdat/{print $2, $3}' | awk 'ORS=NR%2?FS:RS' >> ${LOG}
echo 'INFO P* DETAIL' | ./ggsci | awk '/EXTRACT/{print $2}/dirdat/{print $2, $3}' | awk 'ORS=NR%2?FS:RS' >  /tmp/prba.log
_pinput="/tmp/prba.log"

echo "----------------------------------------------------------------------------------"
echo "----------------------------------------------------------------------------------" >> ${LOG}
echo "Execute a LOEGEND on each Pump Process to force a new trail file at next start"
echo "Execute a LOEGEND on each Pump Process to force a new trail file at next start" >> ${LOG}

while IFS=' ' read -r extract seq rba
do
   echo 'alter extract $extract LOGEND' | ./ggsci  >> ${LOG}
   echo 'stop extract $extract' | ./ggsci  >> ${LOG}
done < "${_pinput}"

# sleep for 30 seconds for pumps to process any remaining extract records
echo "Sleep to allow pumps to process any remaining extract records"
echo "Sleep to allow pumps to process any remaining extract records" >> ${LOG}
sleep 30

echo "----------------------------------------------------------------------------------"
echo "----------------------------------------------------------------------------------" >> ${LOG}
echo "Execute a Stop on all Replicat Processes"
echo "Execute a Stop on all Replicat Processes" >> ${LOG}
echo 'stop replicat R*' | ./ggsci  >> ${LOG}
echo 'stop manager !' | ./ggsci  >> ${LOG}
echo 'info all' | ./ggsci  >> ${LOG}

# Remove all temp files used in process
rm -f ${_einput}
rm -f ${_pinput}

# Copy all status files after everything is shutdown
scp -r ${GG_HOME}/dirdmp ${TARGET_SERVER}/${GG_HOME}
scp -r ${GG_HOME}/dirtmp ${TARGET_SERVER}/${GG_HOME}
scp -r ${GG_HOME}/dirchk ${TARGET_SERVER}/${GG_HOME}
scp -r ${GG_HOME}/dirrpt ${TARGET_SERVER}/${GG_HOME}
scp -r ${GG_HOME}/dirpcs ${TARGET_SERVER}/${GG_HOME}
scp -r ${GG_HOME}/dirsql ${TARGET_SERVER}/${GG_HOME}
scp -r ${GG_HOME}/dircrd ${TARGET_SERVER}/${GG_HOME}
scp -r ${GG_HOME}/dirwlt ${TARGET_SERVER}/${GG_HOME}

exit 0
