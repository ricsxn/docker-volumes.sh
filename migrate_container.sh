#!/bin/bash
#
# migrate_container.sh
#

trap cleanup EXIT

TMP_FILES=$(mktemp)
TS=$(date +%Y%m%d%H%M%S)
LOGFILE=$(basename $0 | sed 's/\w*$//' | sed 's/\.w*$/.log/')
DOCKER_VOLUMES=https://raw.githubusercontent.com/ricardobranco777/docker-volumes.sh/master/docker-volumes.sh

cleanup() {
  if [ -f $TMP_FILES ]; then
    while read f; do
      rm -f $f
    done < $TMP_FILES
    rm -f $TMP_FILES
  fi
}

# Create a temporary file and add it to the temporary fields list
tempfile() {
  TMP=$(mktemp)
  [ -f $TMP_FILES -a\
    -f "$TMP" ] &&\
    echo $TMP >> $TMP_FILES &&\
    echo $TMP ||\
    return 1
}

# Prepare execution steps for container migration
prepare_steps() {
  # Script body commands
  STEP_CMDS=$(tempfile)
  STEP_DESC=$(tempfile)
  DOCKER_RUNCMD=$(tempfile)

  # Steps commands
  cat >$STEP_CMDS <<EOF
ssh ${USER}@${HOST} docker -v >/dev/null 2>&1 </dev/null
${LOAD_DOCKER_VOLUMES_CMD}
docker stop ${CONTAINER}
docker commit ${CONTAINER} ${CONTAINER}:${TS}
docker save ${CONTAINER} | ssh ${USER}@${HOST} docker load
rm -f ${CONTAINER}-volumes.tar && ./docker-volumes.sh ${CONTAINER} save ${CONTAINER}-volumes.tar
scp ${CONTAINER}-volumes.tar ${USER}@${HOST}:
IMGNAME=$(docker inspect --format='{{.Config.Image}}' ${CONTAINER}) && docker run --rm -v /var/run/docker.sock:/var/run/docker.sock assaflavie/runlike ${CONTAINER} | sed s/"--network=\\\w*"// | sed s/"--detach=\\\w*"// | sed "s#\$IMGNAME#${CONTAINER}:${TS}#" | sed s/"docker run"// > ${DOCKER_RUNCMD}
scp ${DOCKER_RUNCMD} ${USER}@${HOST}:${CONTAINER}.runopts && ssh ${USER}@${HOST} "printf 'docker create ' >mkcontainer && cat ${CONTAINER}.runopts >>mkcontainer && chmod +x mkcontainer && ./mkcontainer" </dev/null
scp docker-volumes.sh ${USER}@${HOST}: && ssh ${USER}@${HOST} ./docker-volumes.sh ${CONTAINER} load ${CONTAINER}-volumes.tar </dev/null
docker start ${CONTAINER}
ssh ${USER}@${HOST} docker start ${CONTAINER} </dev/null
ssh ${USER}@${HOST} "rm -f docker-volumes.sh mkcontainer ${CONTAINER}.runopts ${CONTAINER}-volumes.tar"
EOF
  # Steps descriptions
  cat >$STEP_DESC <<EOF
Checking ssh connection at ${USER}@${HOST}
${LOAD_DOCKER_VOLUMES_DESC}
Stoping container ${CONTAINER}
Commiting container image
Saving container image and load it at ${USER}@${HOST}
Saving container volumes ${CONTAINER}-volumes
Copying volume archive ${CONTAINER}-volumes
Extracting docker run command line for ${CONTAINER}
Creating destination container at ${USER}@${HOST}
Loading container volumes ${CONTAINER}-volumes at ${USER}@${HOST}
Start container locally
Start container at ${USER}@${HOST}
Cleaning up working files at ${USER}@${HOST}
EOF
}

# Execute migration steps
execute_steps() {
  [ $DRYRUN -eq 0 ] &&\
    printf "#\n# Migrating ${CONTAINER} to ${USER}@${HOST}\n#\n" > $LOGFILE ||\
    printf "#!/bin/bash\n#\n# Migration script for container ${CONTAINER} to ${USER}@${HOST}\n#\n" > $LOGFILE
  CMDSEQN=1
  while read cmd; do
    remark_flag=$(echo $cmd | grep ^# | wc -l)
    if [ $remark_flag -eq 0 ]; then
      cmd_desc="$(sed -n ${CMDSEQN}p $STEP_DESC)"
      if [ $DRYRUN -eq 0 ]; then
        echo "Executing: $cmd ($cmd_desc)" >> $LOGFILE
        printf "${cmd_desc} ... "
        eval "$cmd"  >>$LOGFILE 2>&1
        RES=$?
        [ $RES -ne 0 ] &&\
          echo -e "\033[31mfailed\033[0m" &&\
          return 1 ||\
          echo -e "\033[32mdone\033[0m"
      else
        echo "$cmd # $cmd_desc"
        echo "$cmd # $cmd_desc" >> $LOGFILE
      fi
    fi
    CMDSEQN=$((CMDSEQN + 1))
  done < $STEP_CMDS
}

docker_volumes() {
  LOAD_DOCKER_VOLUMES_CMD="# docker-volumes.sh exists"
  LOAD_DOCKER_VOLUMES_DESC="# docker-volumes.sh exists"
  DOCKER_VOLUMES_NAME=$(basename $DOCKER_VOLUMES)
  [ ! -f $DOCKER_VOLUMES_NAME ] &&\
    LOAD_DOCKER_VOLUMES_CMD="curl -s $DOCKER_VOLUMES > $DOCKER_VOLUMES_NAME" &&\
    LOAD_DOCKER_VOLUMES_DESC="Loading docker-volumes.sh from GitHub"
  return 0
}

success_steps() {
  [ $DRYRUN -eq 0 ] &&\
    echo "Operation performed successfully"
}

#
# Code body
#

USER=ubuntu
HOST=212.189.145.33
CONTAINER=test-liferay
DRYRUN=0

docker_volumes &&\
prepare_steps &&\
execute_steps &&\
success_steps ||\
echo "Unable to migrate container: ${CONTAINER} at ${USER}@${HOST}"
