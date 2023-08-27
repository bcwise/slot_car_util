#!/bin/bash

################################################################################
# CONSTANTS
################################################################################
KERNEL_NAME=$(uname -s)
IS_PSEUDO_FLAG=0
IS_VERBOSE_FLAG=0
IS_ACTION__COMPILE_AND_LOAD=0
IS_ACTION__COPY=0

OPERATIVE__HOGWARTS=0
OPERATIVE__PLANETARIUM=0
OPERATIVE__TRACER=0
OPERATIVE__WATERFALL=0
OPERATIVE__UTILITY=0

HOGWARTS_DIR="slot_car--hogwarts_light_control"
PLANETARIUM_DIR="slot_car--planetarium_light_control"
TRACER_DIR="slot_car--tracer_lights"
WATERFALL_DIR="slot_car--waterfall_light_control"

# Devices:
#   /dev/ttyACM0: Planetarium
#   /dev/ttyACM1: Hogwarts
#   /dev/ttyACM2: Waterfall
#   /dev/ttyACM3: Tracer Lights
PLANETARIUM_DEVICE="/dev/ttyACM0"
HOGWARTS_DEVICE="/dev/ttyACM1"
WATERFALL_DEVICE="/dev/ttyACM2"
TRACER_DEVICE="/dev/ttyACM3"

HOGWARTS_FQBN="arduino:avr:mega"
PLANETARIUM_FQBN="arduino:avr:mega"
WATERFALL_FQBN="arduino:avr:mega"
TRACER_FQBN="arduino:avr:uno"

REMOTE_DIR="pi@192.168.68.200:/xfer"



echo "program: $0"
PROGRAM_NAME=$(basename -- "$0")

#----------------------------------------------
# MESSAGE VARIABLES
#----------------------------------------------
MSG_ERROR=0
MSG_WARNING=1
MSG_INFO=2

#----------------------------------------------
# PROGRAM VARIABLES
#----------------------------------------------
RVAL=0
TARGET_DIR="/xfer"
HOST_DIR="~/dev"


################################################################################
# SPECIFIC FUNCTIONS
################################################################################

#-------------------------------------------------------------------
# check_for_root()
#
# Comments:
#    Verify that the user is running as root
#-------------------------------------------------------------------
check_for_root()
{
    if [ "$EUID" -ne 0 ]
      then echo "Please run as root"
      exit
    fi
}


#-------------------------------------------------------------------
# compile_and_load()
#
# Parameters:
#   $1: Program directory
#   $2: Device
#   $2: FQBN
# Comments:
#    Compile and load the given program
#-------------------------------------------------------------------
compile_and_load()
{
    PROGRAM_DIR=$1
    DEVICE=$2
    FQBN=$3

    #===============================
    # Change directories
    #===============================
    cmd="cd $HOME"
    do_cmd "$cmd"
    if [ $RVAL -ne 0 ]; then
            echo "Change directory failed"
        exit 3
    fi


    #===============================
    # Compile
    #===============================
    echo "Compiling..."
    cmd="arduino-cli compile --clean -b ${FQBN} dev/${PROGRAM_DIR}/${PROGRAM_DIR}.ino"
    do_cmd "$cmd"
    if [ $RVAL -ne 0 ]; then
            echo "Compile failed"
        exit 3
    fi

    #===============================
    # Upload
    #===============================
    echo "Uploading..."
    cmd="arduino-cli upload -p ${DEVICE} -b ${FQBN} dev/${PROGRAM_DIR}/${PROGRAM_DIR}.ino"
    do_cmd "$cmd"
    if [ $RVAL -ne 0 ]; then
            echo "Loading failed"
        exit 3
    fi
}


#-------------------------------------------------------------------
# direct_copy()
#
# Parameters:
#   $1: Program directory
#
# Comments:
#    scp the program to the remote directory
#-------------------------------------------------------------------
direct_copy()
{
    PROGRAM=$1

    cmd="scp ${PROGRAM}.ino ${REMOTE_DIR}/${PROGRAM}/."
    do_cmd "$cmd"
    if [ $RVAL -ne 0 ]; then
            echo "Direct copy failed"
        exit 4
    fi
}


#-------------------------------------------------------------------
# remote_copy()
#
# Parameters:
#   $1: Program directory
#
# Comments:
#    scp the program to the remote directory
#-------------------------------------------------------------------
remote_copy()
{
    PROGRAM_DIR=$1

    cmd="scp ${PROGRAM_DIR}/${PROGRAM_DIR}.ino ${REMOTE_DIR}/."
    do_cmd "$cmd"
    if [ $RVAL -ne 0 ]; then
            echo "Copying failed"
        exit 4
    fi
}


################################################################################
# STANDARD FUNCTIONS
################################################################################

#-------------------------------------------------------------------
# internal_error()
# $2: Message
#-------------------------------------------------------------------
internal_error() {
    "[INTERNAL ERROR] $1"
    exit
}


#-------------------------------------------------------------------
# err_msg()
# $1: Message Type
# $2: Message
# $3: Exit
#-------------------------------------------------------------------
err_msg() {
    if [[ $# -ne 3 ]]; then
        internal_error "msg() error.  Invalid parameter count ($#)"
    fi

    MSG_TYPE=$1
    MSG=$2
    MSG_EXIT=$3
    is_verbose "[err_msg] MSG_TYPE: $MSG_TYPE"

    case $1 in
    $MSG_ERROR)
        MSG_TYPE_STRING="ERROR"
        ;;
    $MSG_WARNING)
        MSG_TYPE_STRING="WARNING"
        ;;
    $MSG_INFO)
        MSG_TYPE_STRING="INFO"
        ;;
    *)
        MSG_TYPE_STRING="UNKNOWN"
        ;;
    esac

    echo "[$MSG_TYPE_STRING] $MSG"

    if [ '$MSG_EXIT' != '0' ]; then
        exit
    fi
}


#-------------------------------------------------------------------
# msg()
# $1: Message
#-------------------------------------------------------------------
msg() {
    echo "$1"
}


#-------------------------------------------------------------------
# is_verbose()
#-------------------------------------------------------------------
is_verbose() {
    if [[ $IS_VERBOSE_FLAG -eq 1 ]]; then
        echo "[VERBOSE] $1"
    fi
}

#-------------------------------------------------------------------
# do_cmd
#-------------------------------------------------------------------
do_cmd() {
    local cmd=$1
    RVAL=0

    if [[ $IS_PSEUDO_FLAG -eq 1 ]]; then
        echo "[PSEUDO] $cmd"
    else
        if [[ $IS_VERBOSE_FLAG -eq 1 ]]; then
            is_verbose "[cmd] $cmd"
        fi
        eval "$cmd"
        RVAL=$?
    fi
}


#-------------------------------------------------------------------
# help
#-------------------------------------------------------------------
help() {
    echo "PROGRAM"
    echo "   $PROGRAM_NAME"
    echo
    echo "SYNOPSIS"
    echo "   $PROGRAM_NAME [-h, --hogwarts], [-p, --planetarium], [-w, --waterfall], [-t, --tracer]"
    echo "                 [--help], [-p, --pseudo], [-v, --verbose]"
    echo
    echo "DESCRIPTION"
    echo "     $PROGRAM_NAME is used copy slot car programs."
    echo
    echo "ACTIONS"
    echo "   NOTE: only one of the following actions may be done."
    echo
    echo "   -c, --copy"
    echo "      Copy the given files to the remote target directory"
    echo "   -l, --load"
    echo "      Compile and load the given files to the remote machine"
    echo
    echo "OPERATIVES"
    echo "   -h, --hogwarts"
    echo "      Copy the hogwart program to the remote slot_car target directory"
    echo
    echo "   -p, --planetarium"
    echo "      Copy the planetarium program to the remote slot_car target directory"
    echo
    echo "   -t, --tracer"
    echo "      Copy the tracer program to the remote slot_car target directory"
    echo
    echo "   -w, --waterfall"
    echo "      Copy the waterfall program to the remote slot_car target directory"
    echo
    echo "OPTIONS"
    echo "   --help"
    echo "      Bring up the help text."
    echo
    echo "   --pseudo"
    echo "      Test mode, don't actually do anything"
    echo
    echo "   -v, --verbose"
    echo "      Verbose (used for debugging)"
    echo
    exit
}

################################################################################
# PARSE
################################################################################
parse()
{

SHORT=c,h,l,p,t,w,u,p,v
LONG=copy,load,hogwarts,planetarium,tracer,waterfall,utility,help,pseudo,verbose
OPTS=$(getopt --options $SHORT --longoptions $LONG -- "${@}")

eval set -- "$OPTS"

while :; do
    case "$1" in
    -c | --copy)
        if [[ $IS_ACTION__COMPILE_AND_LOAD -eq 1 ]]; then
            echo "Error: unable to do more than one action"
            help
            exit 2
        fi
        IS_ACTION__COPY=1
        shift
        ;;
    -l | --load)
        if [[ $IS_ACTION__COPY -eq 1 ]]; then
            echo "Error: unable to do more than one action"
            help
            exit 2
        fi
        IS_ACTION__COMPILE_AND_LOAD=1
        shift
        ;;
    -h | --hogwarts)
        OPERATIVE__HOGWARTS=1
        shift
        ;;
    -p | --planetarium)
        OPERATIVE__PLANETARIUM=1
        shift
        ;;
    -t | --tracer)
        OPERATIVE__TRACER=1
        shift
        ;;
    -u | --utility)
        OPERATIVE__UTILITY=1
        shift
        ;;
    -w | --waterfall)
        OPERATIVE__WATERFALL=1
        shift
        ;;
    --help)
        help
        exit 2
        ;;
    --pseudo)
        IS_PSEUDO_FLAG=1
        shift
        ;;
    -v | --verbose)
        echo "is verbose now 1"
        IS_VERBOSE_FLAG=1
        shift 1
        ;;
    --)
        shift
        break
        ;;
    *)
        echo "Unexpected option: $1"
        shift
        break
        ;;
    esac
done
# Positional Parameters remaining...
# echo "The number of positional parameter : $#"
# if [ "$#" = 0 ]; then
#     echo "You forgot to put the file name at the end of the command line"
#     echo "All position parameters remaining: '$@'"
#     echo "1: $1"
# fi

is_verbose "-------------------------------------------------------------"
is_verbose " ACTIONS"
is_verbose "-------------------------------------------------------------"
is_verbose " IS_ACTION__COMPILE_AND_LOAD:    $IS_ACTION__COMPILE_AND_LOAD"
is_verbose " IS_ACTION__COPY:                $IS_ACTION__COPY"
is_verbose ""
is_verbose "-------------------------------------------------------------"
is_verbose " OPERATIVES"
is_verbose "-------------------------------------------------------------"
is_verbose " OPERATIVE__HOGWARTS:            $OPERATIVE__HOGWARTS"
is_verbose " OPERATIVE__PLANETARIUM:         $OPERATIVE__PLANETARIUM"
is_verbose " OPERATIVE__TRACER:              $OPERATIVE__TRACER"
is_verbose " OPERATIVE__UTILITY:             $OPERATIVE__UTILITY"
is_verbose " OPERATIVE__WATERFALL:           $OPERATIVE__WATERFALL"
is_verbose ""
is_verbose "-------------------------------------------------------------"
is_verbose "IS_VERBOSE_FLAG flag:            $IS_VERBOSE_FLAG"
is_verbose "IS_PSEUDO_FLAG flag:             $IS_PSEUDO_FLAG"
is_verbose "-------------------------------------------------------------"

return 1

} # parse()



################################################################################
# MAIN
################################################################################
main() {
    parse "${@}"
    # check_for_root

    #-------------------------------------------------------------------
    # Hogwarts
    #-------------------------------------------------------------------
    if [[ $IS_ACTION__COPY -eq 1 ]]; then
        is_verbose "ACTION: copy..."
        if [[ $OPERATIVE__HOGWARTS -eq 1 ]]; then
            cmd="scp ${HOGWARTS_DIR}/${HOGWARTS_DIR}.ino ${REMOTE_DIR}/${HOGWARTS_DIR}/."
            do_cmd "$cmd"
        fi
        if [[ $OPERATIVE__PLANETARIUM -eq 1 ]]; then
            cmd="scp ${PLANETARIUM_DIR}/${PLANETARIUM_DIR}.ino ${REMOTE_DIR}/${PLANETARIUM_DIR}/."
            do_cmd "$cmd"
        fi
        if [[ $OPERATIVE__TRACER -eq 1 ]]; then
            cmd="scp ${TRACER_DIR}/${TRACER_DIR}.ino ${REMOTE_DIR}/${TRACER_DIR}/${TRACER_DIR}/."
            do_cmd "$cmd"
        fi
        if [[ $OPERATIVE__UTILITY -eq 1 ]]; then
            direct_copy "${PROGRAM_NAME}"
        fi
        if [[ $OPERATIVE__WATERFALL -eq 1 ]]; then
            cmd="scp ${WATERFALL_DIR}/${WATERFALL_DIR}.ino ${REMOTE_DIR}/${WATERFALL_DIR}/."
            do_cmd "$cmd"
        fi
    fi

    # Compile and load
    if [[ $IS_ACTION__COMPILE_AND_LOAD -eq 1 ]]; then
        is_verbose "ACTION: compile_and_load..."
        if [[ $OPERATIVE__HOGWARTS -eq 1 ]]; then
            compile_and_load ${HOGWARTS_DIR} ${HOGWARTS_DEVICE} ${HOGWARTS_FQBN}
        fi
        if [[ $OPERATIVE__PLANETARIUM -eq 1 ]]; then
            compile_and_load ${PLANETARIUM_DIR} ${PLANETARIUM_DEVICE} ${PLANETARIUM_FQBN}
        fi
        if [[ $OPERATIVE__TRACER -eq 1 ]]; then
            compile_and_load ${TRACER_DIR} ${TRACER_DEVICE} ${TRACER_FQBN}
        fi
        if [[ $OPERATIVE__WATERFALL -eq 1 ]]; then
            compile_and_load ${WATERFALL_DIR} ${WATERFALL_DEVICE} ${WATERFALL_FQBN}
        fi
    fi

    #-------------------------------------------------------------------
    # Done!
    #-------------------------------------------------------------------
    echo "Complete!"
}


# For unit testing, we don't call main() if the file is sourced by the
# unit test framework
if [ "$0" == "$BASH_SOURCE" ] ; then
  main "$@"
fi

#==============================================================================
