# docker-volumes.sh
This repository is a Fork of the original [docker-volumes.sh](https://github.com/ricardobranco777/docker-volumes.sh)
The [docker export](https://docs.docker.com/engine/reference/commandline/export/) and [docker commit](https://docs.docker.com/engine/reference/commandline/commit/) commands do not save the container volumes. Use this script to save and load the container volumes.


# Usage

`docker-volumes.sh [-v|--verbose] CONTAINER [save|load] TARBALL`

# Podman

To use [Podman](https://podman.io) instead of Docker, prepend `DOCKER=podman` to the command line to set the `DOCKER` environment variable.

# Example

Let's migrate a container to another host with all its volumes.

```
# Stop the container 
docker stop $CONTAINER
# Create a new image
docker commit $CONTAINER $CONTAINER
# Save and load image to another host
docker save $CONTAINER | ssh $USER@$HOST docker load 

# Save the volumes (use ".tar.gz" if you want compression)
docker-volumes.sh $CONTAINER save $CONTAINER-volumes.tar

# Copy volumes to another host
scp $CONTAINER-volumes.tar $USER@$HOST:

### On the other host:

# Create container with the same options used in the previous container
docker create --name $CONTAINER [<PREVIOUS CONTAINER OPTIONS>] $CONTAINER

# Load the volumes
docker-volumes.sh $CONTAINER load $CONTAINER-volumes.tar

# Start container
docker start $CONTAINER
```

# Migration utility
In this repository it is possible to exploit the `migrate_container.sh` utility that starting from the example above provides an atomic execution from the source server to migrate an existing container into a destination host.
In order to execute this script, it is necessary to exchange SSH key in order to allow connection from source machine to the destination.
Then inside the script configure the variables:

```bash
USER=<destination username>
HOST=<destination IP/hostname>
CONTAINER=<source container name>
DRYRUN=<0 to provide the migration, otherwise only commands will be printed>
```

In addition to the steps provided in the original example, this utility takes care about the option used in the source host to create the container. However several of these options have been disabled; these options are:

```
--network # Leaving active this option, the script should also take care of its network creation
--detach  # Option not supported in the destination host during my tests
```

To manage options, it is recommended to modify the `migrate_container.sh` code inside the creation of `STEP_CMDS` file at the line starting with the assignment of the `IMGNAME` variable. At the end of that line a `sed`piped chain is in charge to filter out unwanted options. Please modify this line accordingly to your needs.
Enabling the `DRYRUN` option (placing a non zero value), migration commands will be not executed but only printed in the standard output.
This option could be very useful to generate and test migration scripts.
This script also generates the `migrate_container.log` log file, `DRYRUN`option is acrive, the  file will contain a shell script with all necessary commands to perform the migration, otherwhise it will contain the list of executed commans plus its standard output and standard error.

# Notes
* This script could have been written in Python or Go, but the tarfile module and the tar package lack support for writing sparse files.
* We use the Ubuntu 18.04 Docker image with GNU tar v1.29 that uses **SEEK\_DATA**/**SEEK\_HOLE** to [manage sparse files](https://www.gnu.org/software/tar/manual/html_chapter/tar_8.html#SEC137).
* To see the volumes that would be processed run `docker container inspect -f '{{json .Mounts}}' $CONTAINER` and pipe it to either [`jq`](https://stedolan.github.io/jq/) or `python -m json.tool`.
