####################################################################################
# Script: gg_copy_config.sh
#
# Author:
# Last Updated: 11/09/2021
#
# Description: Prepare Golden Gate paramter Config Files to Target Environment
#              done before the gg_switchover.sh process so config can be done
#              before hand so config can be verified and updated for target
#
# Requirements: passwordless ssh configured between primary server where Golden Gate is Running
#              and target server where Golden Gate is being swiched to run at.
#              The GG_HOME must be the same at source and target servers
#
# Parmaters: <current site Instance>
#            target server
#
# Example: ./gg_copy_config.sh aries1 agoprdd4dbadm01
####################################################################################
#
# Set the environment for the oracle account
. /home/oracle/.bash_profile

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
export LOGFILE=gg_copy_config_${ORACLE_SID}_${TARGET_SERVER}_${DTE}.log
export LOG=$LOGPATH/$LOGFILE

export GG_HOME=/ggs

echo "----------------------------------------------------------------------------------"
echo "----------------------------------------------------------------------------------" >> ${LOG}
echo "Copy Needed Golden Gate Files to Target ${TARGET_SERVER}/ggs"
echo "Copy Needed Golden Gate Files to Target ${TARGET_SERVER}/ggs" >> ${LOG}
scp ${GG_HOME}/GLOBALS ${TARGET_SERVER}/${GG_HOME}
scp -r ${GG_HOME}/dirdmp ${TARGET_SERVER}/${GG_HOME}
scp -r ${GG_HOME}/dirtmp ${TARGET_SERVER}/${GG_HOME}
scp -r ${GG_HOME}/dirchk ${TARGET_SERVER}/${GG_HOME}
scp -r ${GG_HOME}/dirprm ${TARGET_SERVER}/${GG_HOME}
scp -r ${GG_HOME}/dirrpt ${TARGET_SERVER}/${GG_HOME}
scp -r ${GG_HOME}/dirpcs ${TARGET_SERVER}/${GG_HOME}
scp -r ${GG_HOME}/dirsql ${TARGET_SERVER}/${GG_HOME}
scp -r ${GG_HOME}/dirdef ${TARGET_SERVER}/${GG_HOME}
scp -r ${GG_HOME}/dircrd ${TARGET_SERVER}/${GG_HOME}
scp -r ${GG_HOME}/dirwlt ${TARGET_SERVER}/${GG_HOME}
scp ${GG_HOME}/dirdat/*.mac ${TARGET_SERVER}/${GG_HOME}/dirdat

exit 0
