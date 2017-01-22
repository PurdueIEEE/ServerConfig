#!/usr/bin/env bash

# Run server image (New mailman server) and copy what we get inside the 
# /var/lib/mailman/{data,lists,archives} directories.
# We will use this dir skeleton as the basic image of data_image.

# Abort on failure.
set -e

# Check if mailman_server_cont is running. If it does,
# we will abort. We don't want to initialize the data while the server
# container is running.
nlines_server=`docker ps | grep mailman_server_cont | wc -l`
if [ "$nlines_server" -gt "0" ]
	then echo "mailman_server_cont is still running! Aborting data initialization." && \
		exit
fi

# Count the amount of lines with "mailman_data_cont" inside the 
# output of "docker ps -a". This tells us if the mailman_data_cont container is there.
# If it is there, we backup it first. If it is not there, there is nothing
# to backup.
nlines_data=`docker ps -a | grep mailman_data_cont | wc -l`
if [ "$nlines_data" -gt "0" ]
	then echo "There might be important data inside mailman_data_cont.
Creating a backup first..." && \
	       	./backup_data.sh ; fi


# Generate directories:
mkdir -p ./var_files/data
mkdir -p ./var_files/lists
mkdir -p ./var_files/archives


# Get the directories contents by running a new mailman_server:
docker run --name  gen_skeleton_cont \
        -v $(readlink -f ./var_files/data):/mm_vfiles/data \
        -v $(readlink -f ./var_files/lists):/mm_vfiles/lists \
        -v $(readlink -f ./var_files/archives):/mm_vfiles/archives \
	-v $(readlink -f ./server_image/assets):/raw_assets \
	-v $(readlink -f ./server.conf):/raw_assets/server.conf \
        mailman_server sh -c "chmod +x /raw_assets/*.sh && \
		/raw_assets/conf_server.sh && \
		/assets/server_first_usage.sh && \
		/assets/run_server.sh && \
		cp -R /var/lib/mailman/data /mm_vfiles && \
		cp -R /var/lib/mailman/lists /mm_vfiles && \
		cp -R /var/lib/mailman/archives /mm_vfiles"

# Cleanup the gen_skeleton_cont:
docker rm -f gen_skeleton_cont

# Remove the mailman_data_cont (If it is in the list of "docker ps -a"
if [ "$nlines_data" -gt "0" ]
        then docker rm -f mailman_data_cont
fi

# Build a new mailman_data_cont:
docker run --name mailman_data_cont \
       -v $(readlink -f ./var_files):/mm_vfiles \
       mailman_data \
       sh -c "\
       cp -R /mm_vfiles/data /var/lib/mailman && \
       cp -R /mm_vfiles/lists /var/lib/mailman && \
       cp -R /mm_vfiles/archives /var/lib/mailman && \
       rm -R /mm_vfiles/data && \
       rm -R /mm_vfiles/lists && \
       rm -R /mm_vfiles/archives"

rm -rf ./var_files

# Unset abort on failure.
set +e
