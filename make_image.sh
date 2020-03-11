#!/bin/bash

help_usage()
{
    echo "Make base docker image..."
    echo "-----------------------------------------------------------------------------"
    echo "$0 [<options>]"
    echo -e "OPTIONS:"
    echo -e "\t-b | --build-script=<path_to_script> \t -- path to the build script (ex. ./fs/build_all.sh)"
    echo -e "\t-t | --toolchain=<version> \t\t -- version of the toolchain (ex. 7.4.1-2019.02)"
    echo -e "\t-u | --user=<username> \t\t\t -- username for session"
    echo -e "\t-e | --environment=<path_to_environment> -- path to the environment script (default: ./_env.sh)"
    echo -e "\t-v | --verbose \t\t\t\t -- make the operation more talkative"
    echo -e "\t-h | --help \t\t\t\t -- this help"
    echo ""
}

create_command()
{
    [ ${VERBOSE} ] && echo "${FUNCNAME[*]}()..."

    set_toolchain_url
    get_toolchain

    print_environment
    # check_toolchain_avail
    # [ ! $? -eq 0 ] && exit 1

    create_docker_image

    return 0
}

main()
{
    [ ! -e ./libdocker.sh ] && echo "ERROR: ./libdocker.sh not found!.." && exit 1
    . ./libdocker.sh

    ENV_FILE=./_env.sh
    [ ! -e ${ENV_FILE} ] && echo "ERROR: environment (${ENV_FILE}) not found!.." && exit 1
    . ${ENV_FILE}
    
    while [ -n $1 ]; do
        PARAM=`echo $1 | awk -F= '{print $1}'`
        VALUE=`echo $1 | awk -F= '{print $2}'`

        case ${PARAM} in
            -h | --help)
                help_usage
                exit
                ;;
            -e | --environment)
                ENV_FILE=${VALUE}
                [ ! -e ${ENV_FILE} ] && echo "ERROR: environment (${ENV_FILE}) not found!.." && exit 1
                . ${ENV_FILE}
                break
                ;;
            -t | --toolchain)
                export APP_TOOLCHAIN_VERSION=${VALUE}
                ;;
            -u | --user)
                export DOCKER_USER=${VALUE}
                ;;
            -b | --build-script)
                export BUILD_SCRIPT=${VALUE}
                ;;
            -v | --verbose)
                export VERBOSE=1
                ;;
            *)
                # help_usage
                break
                ;;
        esac
        shift
    done

    [ ${VERBOSE} ] && echo "Enabled debug output..."

    check_docker
    [ ! $? -eq 0 ] && exit 1

    start_docker
    
    if [ ${VERBOSE} ]; then
        time create_command
    else
        create_command
    fi
}

main $@
