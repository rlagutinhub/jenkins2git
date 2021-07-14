#!/bin/bash

# NAME:   JENKINS2GIT.SH
# DESC:   BACKUP JENKINS MASTER CONFIG TO GIT
# DATE:   22-03-2021
# LANG:   BASH
# AUTHOR: LAGUTIN R.A.
# EMAIL:  RLAGUTIN@MTA4.RU

# https://jenkins.io/doc/book/managing/plugins/
# https://wiki.jenkins.io/display/JENKINS/Administering+Jenkins

# JENKINS_HOME
#  +- config.xml     (jenkins root configuration)
#  +- *.xml          (other site-wide configuration files)
#  +- userContent    (files in this directory will be served under your http://server/userContent/)
#  +- fingerprints   (stores fingerprint records)
#  +- plugins        (stores plugins)
#  +- workspace (working directory for the version control system)
#      +- [JOBNAME] (sub directory for each job)
#  +- jobs
#      +- [JOBNAME]      (sub directory for each job)
#          +- config.xml     (job configuration file)
#          +- latest         (symbolic link to the last successful build)
#          +- builds
#              +- [BUILD_ID]     (for each build)
#                  +- build.xml      (build result summary)
#                  +- log            (log file)
#                  +- changelog.xml  (change log)

# https://github.com/sue445/jenkins-backup-script
# https://github.com/ilyaevseev/jenkins2git
# https://gist.github.com/cenkalti/5089392

# JENKINS_HOME=/var/lib/jenkins
REPO_URL=https://updates.jenkins.io

SCR_NAME=_jenkins.plugins.get.sh
SCR_FOLD=${JENKINS_HOME}/plugins
SCR_PATH=${SCR_FOLD}/${SCR_NAME}

function plugins_col(){

    if [ ! -r "${SCR_PATH}" ]; then exit 1; fi

    for MANIFEST in $(find ${JENKINS_HOME}/plugins/*/META-INF/ -name "MANIFEST.MF" 2>/dev/null); do

        MANIFEST=$(echo ${MANIFEST/$'\r'/} | sed 's/ *$//g')

        SHORT_NAME=$(echo $(cat $MANIFEST | grep -i "^Short-Name" | cut -d ":" -f 2-))
        SHORT_NAME=$(echo ${SHORT_NAME/$'\r'/} | sed 's/ *$//g')

        PLUGIN_VERSION=$(echo $(cat $MANIFEST | grep -i "^Plugin-Version" | cut -d ":" -f 2-))
        PLUGIN_VERSION=$(echo ${PLUGIN_VERSION/$'\r'/} | sed 's/ *$//g')

        for PLUGIN_FILE in $(find ${JENKINS_HOME}/plugins/ -name "$SHORT_NAME.[hj]pi" 2>/dev/null); do
            if [ $PLUGIN_FILE ]; then break; fi
        done

        for PLUGIN_DISABLED in $(find ${JENKINS_HOME}/plugins/ -name "$SHORT_NAME.[hj]pi.disabled" 2>/dev/null); do
            if [ $PLUGIN_DISABLED ]; then break; fi
        done

        for PLUGIN_PINNED in $(find ${JENKINS_HOME}/plugins/ -name "$SHORT_NAME.[hj]pi.pinned" 2>/dev/null); do
            if [ $PLUGIN_PINNED ]; then break; fi
        done

        if [ $PLUGIN_FILE ]; then PLUGIN_SHA1SUM=$(echo $(sha1sum $PLUGIN_FILE | cut -d " " -f 1) | sed 's/ *$//g'); fi

        echo "# ${SHORT_NAME}|${PLUGIN_VERSION}|${PLUGIN_FILE}|${PLUGIN_SHA1SUM}|${PLUGIN_DISABLED}|${PLUGIN_PINNED}" >> ${SCR_PATH}
        SHORT_NAME=; PLUGIN_VERSION=; PLUGIN_FILE=; PLUGIN_SHA1SUM=; PLUGIN_DISABLED=; PLUGIN_PINNED=;
        echo -n . # progress

    done

}

# $1 - $SHORT_NAME
# $2 - $PLUGIN_VERSION
# $3 - PLUGIN_SHA1SUM
function plugins_check(){

    if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then exit 1; fi

    local SHORT_NAME=$1
    local PLUGIN_VERSION=$2
    local PLUGIN_SHA1SUM=$3

    PLUGIN_INFO_STR=$(curl -k -s -L ${REPO_URL}/download/plugins/${SHORT_NAME}/ | sed 's/<\/*[^>]*>//g' | grep -A 3 -i "^${PLUGIN_VERSION}")
    if [ "$(echo ${PLUGIN_INFO_STR} | grep "${PLUGIN_SHA1SUM}")" ] ; then return 0; else return 1; fi

}

function plugins_gen(){

    plugins_count=0

    if [ ! -r "${SCR_PATH}" ]; then exit 1; fi

    echo "mkdir -p ${JENKINS_HOME}/plugins" >> ${SCR_PATH}

    while read SECTION; do
        if [[ "$SECTION" =~ ^#!.*$ ]]; then

            while read COL; do
                if [[ ! $COL =~ ^#\ .*$ ]]; then break; fi

                COL=$(echo $COL | sed 's/^#//g' | sed 's/ *$//g')

                COL_ARR=($(echo $COL | tr "|" "\n"))
                SHORT_NAME=${COL_ARR[0]}
                PLUGIN_VERSION=${COL_ARR[1]}
                PLUGIN_FILE=${COL_ARR[2]}
                PLUGIN_SHA1SUM=${COL_ARR[3]}
                PLUGIN_DISABLED=${COL_ARR[4]}
                PLUGIN_PINNED=${COL_ARR[5]}

                # echo "${SHORT_NAME}|${PLUGIN_VERSION}|${PLUGIN_FILE}|${PLUGIN_SHA1SUM}|${PLUGIN_DISABLED}|${PLUGIN_PINNED}"
                if [ ! -z $SHORT_NAME ] && [ ! -z $PLUGIN_VERSION ] && [ ! -z $PLUGIN_FILE ] && [ ! -z $PLUGIN_SHA1SUM ]; then

                    plugins_check $SHORT_NAME $PLUGIN_VERSION $PLUGIN_SHA1SUM

                    if [ $? -eq 0 ]; then
                        echo "echo \"${SHORT_NAME} ${PLUGIN_VERSION} [SHA-1: ${PLUGIN_SHA1SUM} OK]\"" >> ${SCR_PATH}
                    else
                        echo "echo \"${SHORT_NAME} ${PLUGIN_VERSION} [SHA-1: ${PLUGIN_SHA1SUM} ERR]\"" >> ${SCR_PATH}
                    fi

                    echo "curl -k -L -# \"${REPO_URL}/download/plugins/${SHORT_NAME}/${PLUGIN_VERSION}/${SHORT_NAME}.hpi\" -o \"${PLUGIN_FILE}\"" >> ${SCR_PATH}
                    if [ ! -z $PLUGIN_DISABLED ]; then echo "touch \"$PLUGIN_DISABLED\"" >> ${SCR_PATH}; fi
                    if [ ! -z $PLUGIN_PINNED ]; then echo "touch \"$PLUGIN_PINNED\"" >> ${SCR_PATH}; fi

                fi

                SHORT_NAME=; PLUGIN_VERSION=; PLUGIN_FILE=; PLUGIN_SHA1SUM=; PLUGIN_DISABLED=; PLUGIN_PINNED=;
                echo -n . # progress

                plugins_count=$((plugins_count+1))

           done

        fi

    done < ${SCR_PATH}

    if [ $plugins_count -eq 0 ]; then exit 1; fi

}

function main(){

    cd "$JENKINS_HOME"

    if [ ! -d $SCR_FOLD ]; then mkdir -p $SCR_FOLD; fi

    cat <<EOF > ${SCR_PATH}
#!/bin/sh -e
EOF

    plugins_col; plugins_gen

    # Add general configurations, secrets, job configurations, nodes, user content, users and plugins info
    ls -1d *.xml jobs/*/*.xml nodes/* secrets/* users/* userContent/* plugins/${SCR_NAME} 2>/dev/null | grep -v '^queue.xml$' | xargs -r -d '\n' git add --

    # Track deleted files
    # LANG=C git status | awk '$1 == "deleted:" { print $2; }' | xargs -r git rm --ignore-unmatch
    LANG=C git status --porcelain | awk '$1 == "D" { $1=""; print }' | xargs -r git rm --ignore-unmatch

    LANG=C git status | egrep -q '^nothing .*to commit' || {
        git commit -m "Automated Jenkins commit at $(date '+%Y-%m-%d %H:%M:%S')"
        git push -q -u origin master
    }

}

main
