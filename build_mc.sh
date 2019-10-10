#!/bin/bash
# © Copyright IBM Corporation 2019.
# LICENSE: Apache License, Version 2.0 (http://www.apache.org/licenses/LICENSE-2.0)
#
# Instructions:
# Download build script: wget https://raw.githubusercontent.com/linux-on-ibm-z/scripts/master/Minio-client/RELEASE.2019-08-14T20-49-49Z/build_mc.sh
# Execute build script: bash build_mc.sh    (provide -h for help)
#

set -e  -o pipefail

PACKAGE_NAME="minio-client"
PACKAGE_VERSION="RELEASE.2019-08-14T20-49-49Z"
SOURCE_ROOT="$(pwd)"
USER="$(whoami)"
GOPATH=$SOURCE_ROOT


FORCE="false"
TESTS="false"
LOG_FILE="${SOURCE_ROOT}/logs/${PACKAGE_NAME}-${PACKAGE_VERSION}-$(date +"%F-%T").log"
GO_INSTALL_URL="https://raw.githubusercontent.com/linux-on-ibm-z/scripts/master/Go/1.13/build_go.sh"
PATCH_URL="https://raw.githubusercontent.com/linux-on-ibm-z/scripts/master/Minio-client/${PACKAGE_VERSION}/patch"

trap cleanup 0 1 2 ERR

#Check if directory exists
if [ ! -d "$SOURCE_ROOT/logs/" ]; then
   mkdir -p "$SOURCE_ROOT/logs/"
fi

# Need handling for RHEL 6.10 as it doesn't have os-release file
if [ -f "/etc/os-release" ]; then
	source "/etc/os-release"
else
	cat /etc/redhat-release >>"${LOG_FILE}"
	export ID="rhel"
	export VERSION_ID="6.x"
	export PRETTY_NAME="Red Hat Enterprise Linux 6.x"
fi

function prepare() {
	if command -v "sudo" >/dev/null; then
		printf -- 'Sudo : Yes\n' >>"$LOG_FILE"
	else
		printf -- 'Sudo : No \n' >>"$LOG_FILE"
		printf -- 'You can install the same from installing sudo from repository using apt, yum or zypper based on your distro. \n'
		exit 1
	fi

	if [[ "$FORCE" == "true" ]]; then
		printf -- 'Force attribute provided hence continuing with install without confirmation message\n' |& tee -a "$LOG_FILE"
	else
		# Ask user for prerequisite installation
		printf -- "\nAs part of the installation, dependencies would be installed/upgraded. \n"
		while true; do
			read -r -p "Do you want to continue (y/n) ? :  " yn
			case $yn in
			[Yy]*)
				printf -- 'User responded with Yes. \n' >> "$LOG_FILE"
				break
				;;
			[Nn]*) exit ;;
			*) echo "Please provide confirmation to proceed." ;;
			esac
		done
	fi
}

function cleanup() {
    # Remove artifacts
	rm -rf $SOURCE_ROOT/build_go.sh
    printf -- "Cleaned up the artifacts\n" 

}
function configureAndInstall() {
	printf -- 'Configuration and Installation started \n'

	# Install go
	printf -- "\nInstalling Go . . . \n"  
	printf -- "\nDownloading Build Script for Go . . . \n"  
	rm -rf build_go.sh
	wget -O build_go.sh $GO_INSTALL_URL 
	bash build_go.sh -y -v 1.13 
	printf -- "\nGo version is: "
	go version
	
	#Set environment variables
	printf -- "\nSet environment variables . . . \n"
	export PATH=$PATH:$GOPATH/bin
	
	#Install Jq (For RHEL and SLES)
	if [[ "$ID" != "ubuntu" ]]; then
		printf -- "\nInstalling Jq . . . \n" 
		cd $SOURCE_ROOT
		wget -O jq-1.5.tar.gz  https://github.com/stedolan/jq/releases/download/jq-1.5/jq-1.5.tar.gz
		tar -xzf jq-1.5.tar.gz
		cd jq-1.5/
		./configure
		make
		sudo make install
	fi
	
	#Download Minio-client code
	printf -- "\nDownloading Minio-client . . . \n"
	mkdir -p $GOPATH/src/github.com/minio
	cd $GOPATH/src/github.com/minio
	git clone https://github.com/minio/mc.git
	cd mc/
	git checkout RELEASE.2019-08-14T20-49-49Z
	
	#Build and Install Minio
	printf -- "\nBuilding and Installing Minio-client . . . \n"
	cd $GOPATH/src/github.com/minio/mc
	
	# Modify Makefile, patching Makefile
	printf -- "\nDownloading patch for minio-client Makefile . . . \n" 
	#curl  -o "mc_makefile.diff" $PATCH_URL/mc_makefile.diff 
	#printf -- "\nApplying patch to Makefile . . . \n"  
	curl -o mc_makefile.diff https://eef0b9a5ed30c98cf86f318385aa0d4933eb0a53@raw.github.ibm.com/loz/Minio/master/Makefile_minio_client_patch
	patch Makefile mc_makefile.diff
	rm -rf mc_makefile.diff
	
	make
	make install
	
	# Run Tests
	runTest

	#Cleanup
	cleanup

	printf -- "\n Installation of Minio-client was sucessfull \n\n" 
}

function runTest() {
	set +e
	if [[ "$TESTS" == "true" ]]; then
		printf -- "TEST Flag is set , Continue with running test \n" 
		cd $GOPATH/src/github.com/minio/mc
		export PATH=$PATH:$GOPATH/bin
		make test

		printf -- "Tests completed. \n"

	fi
	set -e
}

function logDetails() {
	printf -- '**************************** SYSTEM DETAILS *************************************************************\n' >"$LOG_FILE"
	if [ -f "/etc/os-release" ]; then
		cat "/etc/os-release" >>"$LOG_FILE"
	fi

	cat /proc/version >>"$LOG_FILE"
	printf -- '*********************************************************************************************************\n' >>"$LOG_FILE"

	printf -- "Detected %s \n" "$PRETTY_NAME"
	printf -- "Request details : PACKAGE NAME= %s , VERSION= %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" |& tee -a "$LOG_FILE"
}

# Print the usage message
function printHelp() {
	echo
	echo "Usage: "
	echo "  bash build_mc.sh  [-d debug] [-y install-without-confirmation] [-t install-with-tests]"
	echo
}

while getopts "h?dyt" opt; do
	case "$opt" in
	h | \?)
		printHelp
		exit 0
		;;
	d)
		set -x
		;;
	y)
		FORCE="true"
		;;
	t)
		TESTS="true"
		;;
	esac
done

function gettingStarted() {
	printf -- '\n***********************************************************************************************\n'
	printf -- "Getting Started: \n"
	printf -- "Verify minio-client is installed using following commands : \n"
	printf -- "  $ export PATH=\$PATH:$GOPATH/go/bin  \n"
	printf -- "  $ mc version  \n\n"
	printf -- '*************************************************************************************************\n'
	printf -- '\n'
}

###############################################################################################################

logDetails
prepare #Check Prequisites

DISTRO="$ID-$VERSION_ID"
case "$DISTRO" in
"ubuntu-16.04" | "ubuntu-18.04" | "ubuntu-19.04")
	printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" |& tee -a "$LOG_FILE"
	printf -- "Installing dependencies... it may take some time.\n"
	sudo apt-get update -y
	sudo apt-get install -y git make wget tar gcc curl jq |& tee -a "${LOG_FILE}"
	configureAndInstall |& tee -a "${LOG_FILE}"
	;;
"rhel-7.5" | "rhel-7.6" | "rhel-7.7" )
	printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" |& tee -a "$LOG_FILE"
	printf -- "Installing dependencies... it may take some time.\n"
	sudo yum install -y git make wget tar gcc curl which |& tee -a "${LOG_FILE}"
	printf -- "Creating link..\n" |& tee -a "${LOG_FILE}"
	sudo ln /usr/bin/gcc /usr/bin/s390x-linux-gnu-gcc
    configureAndInstall |& tee -a "${LOG_FILE}"
	;;
"rhel-8.0")
	printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" |& tee -a "$LOG_FILE"
	printf -- "Installing dependencies... it may take some time.\n"
	sudo yum install -y git make wget tar gcc curl which diffutils |& tee -a "${LOG_FILE}"
	printf -- "Creating link..\n" |& tee -a "${LOG_FILE}"
	sudo ln /usr/bin/gcc /usr/bin/s390x-linux-gnu-gcc
	configureAndInstall |& tee -a "${LOG_FILE}"
	;;
"sles-12.4" | "sles-15" | "sles-15.1")
	printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" |& tee -a "$LOG_FILE"
	printf -- "Installing dependencies... it may take some time.\n"
	sudo zypper install -y git make wget tar gcc which curl |& tee -a "${LOG_FILE}"
	printf -- "Creating link..\n" |& tee -a "${LOG_FILE}"
	sudo ln /usr/bin/gcc /usr/bin/s390x-linux-gnu-gcc 
    configureAndInstall |& tee -a "${LOG_FILE}"
	;;
*)
	printf -- "%s not supported \n" "$DISTRO" |& tee -a "$LOG_FILE"
	exit 1
	;;
esac

gettingStarted |& tee -a "${LOG_FILE}"
