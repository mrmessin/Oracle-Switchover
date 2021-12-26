#!/bin/bash
#
#####################################################################
#   Name: ora_deploy_dr_switchover.sh
#
#
# Description:  Script to run through list of databases to switchover
#               to DR site.
#
# Parameters:   file list of servers databases instances to utilize and services at complete
#               <hostname> <db name> <db instance> <primarynode> <primarydb> <service,service,service>
#
#####################################################################
#
# Set the environment for the oracle account
. /home/oracle/.bash_profile

# Check that the correct
if (( $# != 1 ));then
  echo "ERROR -> Wrong number of arguments - must pass file name with host, db, db instance and services to put into DR test mode"
  exit 8
fi

#
# assign ORACLE_SID for local host, this will include the instance designation for Standby database
export inputfile=$1

#####################################################
# Check if input file passed and exists
#####################################################
if [ ! -f "${inputfile}" ]
then
   echo "ERROR -> ${inputfile} does not exist can not process switchover."
   exit 8
fi

#####################################################
# Script environment
#####################################################
# assign a date we can use as part of the logfile
export DTE=`/bin/date +%m%d%C%y%H%M`

# Get locations
export SCRIPTLOC=`dirname $0`
export SCRIPTDIR=`basename $0`

# Set the logfile directory
export LOGPATH=${SCRIPTLOC}/logs
export LOGFILE=ora_deploy_dr_switchover_${inputfile}_${DTE}.log
export LOG=$LOGPATH/$LOGFILE

#####################################################
# Script Environment variables
#####################################################
# export the page list (Change as require for process notifications)
export PAGE_LIST=dbas@availity.com,dbas@realmed.com
export EMAIL_LIST=DBAs@availity.com

echo "#################################################################################################"
echo "Using the Following Parameter Files:"
echo "Using the Following Parameter Files:" >> ${LOG}
echo "Node/db/dbinstance List File -> ${inputfile}"
echo "Node/db/dbinstance List File -> ${inputfile}" >> ${LOG}

# To protect environment a protecton file is utilized that must be removed manually for process to run
if [ -f "${SCRIPTLOC}/.dr_start_protection" ]
then
   echo "ERROR -> Script Protection on Please remove file .dr_switchover_protection and re-execute if you really want to run process"
   echo "ERROR -> Script Protection on Please remove file .dr_switchover_protection and re-execute if you really want to run process" >> ${LOG}
   exit 8
fi

echo "#######################################################################################"
echo "# Starting DR Switchover for List of databases "
echo "#######################################################################################"
echo "#######################################################################################" >> ${LOG}
echo "# Starting DR Switchover for List of databases " >> ${LOG}
echo "#######################################################################################" >> ${LOG}

# Loop through the file for putting into DR Mode
while read -r line
do
   ########################################################
   # Assign the nodename and agent home for processing
   export nodename=`echo ${line}| awk '{print $1}'`
   export dbname=`echo ${line}| awk '{print $2}'`
   export instname=`echo ${line}| awk '{print $3}'`
   export primarynode=`echo ${line}| awk '{print $4}'`
   export dbprimary=`echo ${line}| awk '{print $5}'`
   export primaryinst=`echo ${line}| awk '{print $6}'`
   export services=`echo ${line}| awk '{print $7}'`

   echo "------------------------------------------------------------------------------"
   echo "------------------------------------------------------------------------------" >> ${LOG}
   echo "Starting Switchover for ${nodename} - ${dbname} from ${primarynode} - ${dbprimary} with Services ${services}"
   echo "Starting Switchover for ${nodename} - ${dbname} from ${primarynode} - ${dbprimary} with Services ${services}" >> ${LOG}
   echo "--"
   echo "--" >> ${LOG}

   #########################################################################################
   # Set dbhome for instance on node 
   echo "Getting ORACLE_HOME for Database -> ${nodename} - ${dbname} - ${instname} ...." 
   echo "Getting ORACLE_HOME for Database -> ${nodename} - ${dbname} - ${instname} ...." >> ${LOG}
   export cmd="/usr/local/bin/dbhome ${instname}"
   export ORACLE_HOME=`ssh -n ${nodename} ${cmd} `

   # Check ORACLE_HOME is set
   if [ $? -eq 0 ]; then
      echo "Get Oracle HOME for ${nodename} - ${instname} is Determined." 
      echo "Get Oracle HOME for ${nodename} - ${instname} is Determined." >> ${LOG}
   else
      echo "ERROR -> Get Oracle HOME for ${nodename} - ${instname} could not be determined, aborting process"
      echo "ERROR -> Get Oracle HOME for ${nodename} - ${instname} could not be determined, aborting process" >> ${LOG}
      exit 8
   fi

   # Show the ORACLE_HOME value we got.
   echo "ORACLE_HOME for Database -> ${nodename} - ${dbname} - ${instname} -> ${ORACLE_HOME} ...." 
   echo "ORACLE_HOME for Database -> ${nodename} - ${dbname} - ${instname} -> ${ORACLE_HOME} ...." >> ${LOG}

   #########################################################################################
   # Check database is in physical standby before we start to convert 
   echo "Checking that Target database -> ${dbname} is a physical standby......."
   echo "Checking that Target database -> ${dbname} is a physical standby......." >> ${LOG}
   export cmd="export ORACLE_HOME=${ORACLE_HOME}; export ORACLE_SID=${instname}; echo -ne 'set feedback off\n set head off\n set pagesize 0\n select database_role from v\$database;' | $ORACLE_HOME/bin/sqlplus -s '/ AS SYSDBA'"
   export result=`ssh -n ${nodename} ${cmd} `
   #echo "${result}" >> ${LOG}
   #echo "${result}"
                       
   if [ "${result}" != "PHYSICAL STANDBY" ]
    then
       echo "ERROR -> Database Instance $instname} on ${nodename} is not in Physical Standby Mode, Not Converting to Snapshot Standby"
       echo "ERROR -> Database Instance ${instname} on ${nodename} is not in Physical Standby Mode, Not Converting to Snapshot Standby" >> ${LOG}
       exit 8
   fi
 
   #########################################################
   # Verify Primary datbase is a primary
   echo "Verify Database is in Primary Mode for -> ${primarynode} - ${dbprimary} - ${primaryinst}"
   echo "Verify Database is in Primary Mode for -> ${primarynode} - ${dbprimary} - ${primaryinst}" >> ${LOG}
   export cmd="export ORACLE_HOME=${ORACLE_HOME}; export ORACLE_SID=${primaryinst}; echo -ne 'set feedback off\n set head off\n set pagesize 0\n select database_role from v\$database;' | $ORACLE_HOME/bin/sqlplus -s '/ AS SYSDBA'"
   export result=`ssh -n ${primarynode} ${cmd} `
   #echo "${result}" >> ${LOG}

   if [ "${result}" != "PRIMARY" ]
    then
       echo "ERROR -> Database Instance ${primaryinst} on ${primarynode} is not in Primary Mode, can not continue, exiting."
       echo "ERROR -> Database Instance ${primaryinst} on ${primarynode} is not in Primary Mode, can not continue, exiting." >> ${LOG}
       exit 8
   else
       echo "Database Instance ${primaryinst} on ${primarynode} in Primary Mode......"
       echo "Database Instance ${primaryinst} on ${primarynode} in Primary Mode......" >> ${LOG}
   fi
 
   ##############################################################################
   # Check that Standby Database does not have any lag and ready for switchover
   echo "Checking Ready to Switchover Database -> ${nodename} - ${dbname} - ${instname}...." 
   echo "Checking Ready to Switchover Database -> ${nodename} - ${dbname} - ${instname}...." >> ${LOG}

   #########################################################
   # Check Transport Lag +00 00:00:00
   export cmd="export ORACLE_HOME=${ORACLE_HOME}; export ORACLE_SID=${instname}; echo -ne 'set feedback off\n set head off\n set pagesize 0\n SELECT value FROM v$dataguard_stats where name = 'transport lag';' | $ORACLE_HOME/bin/sqlplus -s '/ AS SYSDBA'"
   export transportlag=`ssh -n ${nodename} ${cmd} `
  
   if [ ${transportlag} != "+00 00:00:00" ]
    then
      echo "ERROR -> ${dbname} Transport Lag Exists ${transportlag} aborting......"
      echo "ERROR -> ${dbname} Transport Lag Exists ${transportlag} aborting......" >> ${LOG}
      exit 8
   else
      echo "${dbname} Transport Lag at ${transportlag} continuing......"
      echo "${dbname} Transport Lag at ${transportlag} continuing......" >> ${LOG}
   fi

   #########################################################
   # Check Apply Lag +00 00:00:00
   export cmd="export ORACLE_HOME=${ORACLE_HOME}; export ORACLE_SID=${instname}; echo -ne 'set feedback off\n set head off\n set pagesize 0\n SELECT value FROM v$dataguard_stats where name = 'apply lag';' | $ORACLE_HOME/bin/sqlplus -s '/ AS SYSDBA'"
   export applylag=`ssh -n ${nodename} ${cmd} `
 
   if [ ${applylag} != "+00 00:00:00" ]
    then
      echo "ERROR -> ${dbname} Apply Lag Exists ${transportlag} aborting......"
      echo "ERROR -> ${dbname} Apply Lag Exists ${transportlag} aborting......" >> ${LOG}
      exit 8
   else
      echo "${dbname} Apply Lag at ${transportlag} continuing......"
      echo "${dbname} Apply Lag at ${transportlag} continuing......" >> ${LOG}
   fi

   #########################################################
   # If there is a custom glogin.sql that must be moved out of the way or it will fail
   echo "Handling glogin.sql on ${nodename} as not to casue sysdba connection error locally"
   echo "Handling glogin.sql on ${nodename} as not to casue sysdba connection error locally" >> ${LOG}
   export cmd="mv ${ORACLE_HOME}/sqlplus/admin/glogin.sql ${ORACLE_HOME}/sqlplus/admin/glogin.sql.save"
   ssh -n ${nodename} ${cmd} >> ${LOG}

   #########################################################
   # Do a Validate in the Broker and get status we are Ready
   # Must Get SYS Password to be used
   # dgmgrl sys/${syspwd}@${dbprimary} -echo << END
   # validate database ${dbname} ;
   # EOF

   #########################################################
   # Switchover Standby Database to Primary
   echo "Switching Standby Database to Primary -> ${nodename} - ${dbname} - ${instname}...." 
   echo "Switching Standby Database to Primary -> ${nodename} - ${dbname} - ${instname}...." >> ${LOG}
   # Must Get SYS Password to be used
   # dgmgrl sys/${syspwd}@${dbprimary} -echo << END
   # switchover to ${dbname} ;
   # EOF

   #########################################################
   # Verify Old Standby datbase is now primary
   echo "Verify Database is in Primary Mode for -> ${dbname}"
   echo "Verify Database is in Primary Mode for -> ${dbname}" >> ${LOG}
   export cmd="export ORACLE_HOME=${ORACLE_HOME}; export ORACLE_SID=${instname}; echo -ne 'set feedback off\n set head off\n set pagesize 0\n select database_role from v\$database;' | $ORACLE_HOME/bin/sqlplus -s '/ AS SYSDBA'"
   export result=`ssh -n ${nodename} ${cmd} `
   #echo "${result}" >> ${LOG}

   if [ "${result}" != "PRIMARY" ]
    then
       echo "ERROR -> Database Instance ${instname} on ${nodename} is not in Primary Mode, can not continue, exiting."
       echo "ERROR -> Database Instance ${instname} on ${nodename} is not in Primary Mode, can not continue, exiting." >> ${LOG}
       exit 8
   else
       echo "Database Instance ${instname} on ${nodename} in Primary Mode......"
       echo "Database Instance ${instname} on ${nodename} in Primary Mode......" >> ${LOG}
   fi

   #########################################################
   # Check that old primary is now PHYSICAL STANDBY
   echo "Checking Old Primary is now Standby -> ${primarynode} - ${dbprimary} - ${primaryinst}...." 
   echo "Checking Old Primary is now Standby -> ${primarynode} - ${dbprimary} - ${primaryinst}...." >> ${LOG}
   export cmd="export ORACLE_HOME=${ORACLE_HOME}; export ORACLE_SID=${primaryinst}; echo -ne 'set feedback off\n set head off\n set pagesize 0\n select database_role from v\$database;' | $ORACLE_HOME/bin/sqlplus -s '/ AS SYSDBA'"
   export result=`ssh -n ${primarynode} ${cmd} `

   if [ "${result}" != "PHYSICAL STANDBY" ]
    then
       echo "ERROR -> Database Instance ${primaryinst} on ${primarynode} is not in Physical Standby Mode, can not continue, exiting."
       echo "ERROR -> Database Instance ${primaryinst} on ${primarynode} is not in Physical Standby Mode, can not continue, exiting." >> ${LOG}
       exit 8
   else
       echo "Database Instance ${primaryinst} on ${primarynode} in Physical Standby Mode......"
       echo "Database Instance ${primaryinst} on ${primarynode} in Physical Standby Mode......" >> ${LOG}
   fi

   #########################################################
   # verify that the New Primary is open read write
   echo "Verifying that New Primary is open READ WRITE -> ${dbname}"
   echo "Verifying that New Primary is open READ WRITE -> ${dbname}" >> ${LOG}
   export cmd="export ORACLE_HOME=${ORACLE_HOME}; export ORACLE_SID=${instname}; echo -ne 'set feedback off\n set head off\n set pagesize 0\n select open_mode from v\$database;' | $ORACLE_HOME/bin/sqlplus -s '/ AS SYSDBA'"
   export result=`ssh -n ${nodename} ${cmd} `
   #echo "${result}" >> ${LOG}

   if [ "${result}" != "READ WRITE" ]
    then
       echo "ERROR -> Database is not Open READ WRITE, can not continue, exiting skipping database......"
       echo "ERROR -> Database is not Open READ WRITE, can not continue, exiting skipping database......" >> ${LOG}
       exit 8
   else
       echo "Database Instance ${instname} on ${nodename} is Open READ WRITE......"
       echo "Database Instance ${instname} on ${nodename} is Open READ WRITE......" >> ${LOG}
   fi

   #######################################################################
   # Services for database
   echo "Starting Services for database -> ${dbname}" 
   echo "Starting Services for database -> ${dbname}"  >> ${LOG}
   if [ "${services}" = "" ]
    then
      export cmd="export ORACLE_HOME=${ORACLE_HOME}; export ORACLE_SID=${instname}; export DBNAME=${dbname}; ${ORACLE_HOME}/bin/srvctl start service -d ${dbname}"
      ssh -n ${nodename} ${cmd} >> ${LOG}
      
      # Check execution of start Services was successful
      if [ $? -eq 0 ]; then
         echo "Start Services -> ALL on ${nodename} for db ${dbname} was successful." 
         echo "Start Services -> ALL on ${nodename} for db ${dbname} was successful."  >> ${LOG}
      else
         echo "WARNING -> Start Services -> ALL on ${nodename} for db ${dbname} was not successful Please Check!." 
         echo "WARNING -> Start Services -> ALL on ${nodename} for db ${dbname} was not successful Please Check!."  >> ${LOG}
      fi
   else
      #########################################################
      # Start services now that all instances are open
      export cmd="export ORACLE_HOME=${ORACLE_HOME}; export ORACLE_SID=${instname}; export DBNAME=${dbname}; ${ORACLE_HOME}/bin/srvctl start service -d ${dbname} -s ${services}"
      ssh -n ${nodename} ${cmd} >> ${LOG}

      # Check execution of start Services was successful
      if [ $? -eq 0 ]; then
         echo "Start Services -> ${services} on ${nodename} for db ${dbname} was successful." 
         echo "Start Services -> ${services} on ${nodename} for db ${dbname} was successful."  >> ${LOG}
      else
         echo "WARNING -> Start Services -> ${services} on ${nodename} for db ${dbname} was not successful Please Check!." 
         echo "WARNING -> Start Services -> ${services} on ${nodename} for db ${dbname} was not successful Please Check!."  >> ${LOG}
      fi
   fi 

   #########################################################
   # Put glogin.sql back
   echo "Put glogin.sql back in place on node ${nodename}"
   echo "Put glogin.sql back in place on node ${nodename}" >> ${LOG}
   export cmd="mv ${ORACLE_HOME}/sqlplus/admin/glogin.sql.save ${ORACLE_HOME}/sqlplus/admin/glogin.sql"
   ssh -n ${nodename} ${cmd} >> ${LOG}

   echo "Completed Switchover to Primary for ${nodename} - ${dbname} - ${instname} from ${primarynode} - ${dbprimary} - ${primaryinst}"
   echo "Completed Switchover to Primary for ${nodename} - ${dbname} - ${instname} from ${primarynode} - ${dbprimary} - ${primaryinst}" >> ${LOG}
   echo "----------------------------------------------------------------------------------------------"
   echo "----------------------------------------------------------------------------------------------" >> ${LOG}

   echo "Checking the scan name we want to use for service connection checks!"
   echo "Checking the scan name we want to use for service conncction checks!" >> ${LOG}

   # determine scan name to use
   cmd="export ORACLE_HOME=${ORACLE_HOME}; ${ORACLE_HOME}/bin/srvctl config scan | grep \"SCAN name:\" | awk '{print \$3}' | tr -d ,"
   #echo ${cmd}
   export scan_name=`ssh -n ${nodename} ${cmd} `

   if [ "${scan_name}" = "" ]
    then
       echo "ERROR -> Could not get scan name can not check service connections."
       echo "ERROR -> Could not get scan name can not check service connections." >> ${LOG}
       exit 8
   else
      echo "Will Continue Checking Connections using scan name ${scan_name}."
      echo "Will Continue Checking Connections using scan name ${scan_name}." >> ${LOG}
   fi

   echo "Using Scan Name -> ${scan_name} for connection checks."
   echo "Using Scan Name -> ${scan_name} for connection checks." >> ${LOG}

   #########################################################
   # set username and password for connection check user we can create user for test then drop user     
   export myuser=avdba
   export mypassword="avdba#2ALL"

   #########################################################
   # List of all services loop through and check connection to database through each service
   # Report any service where connection fails to screen and log
   if [ "${services}" = "" ]
    then
      # Get list of services to loop through
      # Execute the command to list services based on parameter passed
      export cmd="export ORACLE_HOME=${ORACLE_HOME}; $ORACLE_HOME/bin/srvctl config service -d ${dbname} | grep \"Service name:\" | awk '{print \$3}'"
      #echo ${cmd}
      export servicelist=`ssh -n ${nodename} ${cmd} `
      echo "${servicelist}" >> ${LOG}

      if [ "${servicelist}" = "" ]
       then
         echo "WARNING -> No Services retrived from Service List Please Verify."
         echo "WARNING -> No Services retrived from Service List Please Verify." >> ${LOG}
      else 
         # Run connection for service 
         for thisservice in ${servicelist}
         do
            export thisservice="${thisservice}.availity.net"
            export cmd="export ORACLE_HOME=${ORACLE_HOME}; echo \"select 1 from dual; \" | $ORACLE_HOME/bin/sqlplus -s ${myuser}/${mypassword}@'(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${scan_name})(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${thisservice})))'"
            #export result=`ssh -n ${nodename} ${cmd} >> ${LOG}`
            export result=`ssh -n ${nodename} ${cmd}`
            export result=`echo ${result} | xargs`

            # Check execution of instance/db state was successful
            if [ "${result}" = "1 ---------- 1" ]; then
               echo "Connection Using Service ${thisservice} OK."
               echo "Connection Using Service ${thisservice} OK." >> ${LOG}
            else
               echo "ERROR -> Connection Using Service ${thisservice} Failed Please check error."
               echo "ERROR -> Connection Using Service ${thisservice} Failed Please check error." >> ${LOG}
               echo ${result}
               echo ${result} >> ${LOG}
            fi
         done 
      fi
   else
      # loop through services separate by ,
      for thisservice in $(echo ${services} | sed "s/,/ /g")
      do
         export thisservice="${thisservice}.availity.net"
         export cmd="export ORACLE_HOME=${ORACLE_HOME}; echo \"select 1 from dual; \" | $ORACLE_HOME/bin/sqlplus -s ${myuser}/${mypassword}@'(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${scan_name})(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=${thisservice})))'"
         #export result=`ssh -n ${nodename} ${cmd} >> ${LOG}`
         export result=`ssh -n ${nodename} ${cmd}`
         export result=`echo ${result} | xargs`

         # Check execution of instance/db state was successful
         if [ "${result}" = "1 ---------- 1" ]; then
            echo "Connection Using Service ${thisservice} OK."
            echo "Connection Using Service ${thisservice} OK." >> ${LOG}
         else
            echo "ERROR -> Connection Using Service ${thisservice} Failed Please check error."
            echo "ERROR -> Connection Using Service ${thisservice} Failed Please check error." >> ${LOG}
            echo ${result}
            echo ${result} >> ${LOG}
         fi
      done
   fi

   echo "Completed Switchover and Services Check for ${nodename} - ${dbname} - ${instname}"
   echo "Completed Switchober and Services Check for ${nodename} - ${dbname} - ${instname}" >> ${LOG}
   echo "----------------------------------------------------------------------------------------------"
   echo "----------------------------------------------------------------------------------------------" >> ${LOG}
done < "${inputfile}"

echo "-"
echo "-" >> ${LOG}
echo "##############################################################################################"
echo "##############################################################################################" >> ${LOG}
echo "Switchover for all nodes/db/instances in list from ${inpufile} successful."
echo "Switchover for all nodes/db/instances in list from ${inpufile} successful." >> ${LOG}

# Put protection file back in place now that the process has run
touch ${SCRIPTLOC}/.dr_switchover_protection

# Mail Cron Run Log
/bin/mailx -s "Switchover for Oracle Databases Completed" dba_team@availity.com <${LOG}

exit 0
