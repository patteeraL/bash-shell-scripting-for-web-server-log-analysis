#!/bin/bash

RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'
BOLD=$(tput bold)
NOTBOLD=$(tput sgr0)

usage() {
    # Display usage instructions
    echo
    echo -e "${BLUE}==>${NC}${BOLD} The usage of the log_sum.sh script is as follows:${NOTBOLD}"
    echo
    echo "      log_sum.sh [-L N] (-c|-2|-r|-F|-t) <filename>"
    echo
    echo -e "${BLUE}==>${NC}${BOLD} Optional options${NOTBOLD}"
    echo -e "  ${YELLOW}-L${NC} : Limit the number of results to N (Argument N required)"
    echo
    echo -e "${BLUE}==>${NC}${BOLD} Required options${NOTBOLD}"
    echo -e "  ${YELLOW}-c${NC} : Which IP address makes the most number of connection attempts?"
    echo -e "  ${YELLOW}-2${NC} : Which address makes the most number of successful attempts?"
    echo -e "  ${YELLOW}-r${NC} : What are the most common results codes and where do they come from?"
    echo -e "  ${YELLOW}-F${NC} : What are the most common result codes that indicate failure (no auth, not found etc) and where do they come from?"
    echo -e "  ${YELLOW}-t${NC} : Which IP number get the most bytes sent to them?"
    echo -e "  ${YELLOW}<filename>${NC} : Which refers to the logfile."
    exit 1
}

Limit=""
Filename=""
Command=""

command_check_number() {
    if [ "$1" != "$Command" ] && [ "$Command" != "" ]; then
        echo
        echo -e "${RED}${BOLD}ERROR: Too many commands. Only one command should be given at a time.${NOTBOLD} ${NC}"
        usage
        exit 1
    fi
}

command_check_blank() {
    if [ "$Command" = "" ]; then
        echo
        echo -e "${RED}${BOLD}ERROR: No command given. Please specify a command.${NOTBOLD} ${NC}"
        usage
        exit 1
    fi
}

check_limit() {
    if ! [[ "$Limit" =~ ^[0-9]+$ ]]; then
        echo
        echo -e "${RED}${BOLD}ERROR: Limit quantifier missing or invalid. Please specify a valid Limit. ${NOTBOLD} ${NC}"
        echo
        usage
        exit 1
    fi
}

check_filename() {
    if [ -z "$Filename" ]; then
        echo
        echo -e "${RED}${BOLD}ERROR: <filename> missing. Please specify a valid log file. ${NOTBOLD} ${NC}"
        echo
        usage
        exit 1
    elif [[ "$Filename" == "c"  || "$Filename" == "2" || "$Filename" == "r" || "$Filename" == "F" || "$Filename" == "t" || "$Filename" == -* ]]; then
        echo
        echo -e "${RED}${BOLD}ERROR: Too many commands. Only one command should be given at a time.${NOTBOLD} ${NC}"
        echo
        usage
        exit 1
        echo "PASS"
    elif ! [[ "$Filename" == *.log ]]; then
        echo
        echo -e "${RED}${BOLD}ERROR: <filename> file format error. Please specify a valid log file.${NOTBOLD} ${NC}"
        echo
        usage
        exit 1
    fi
}

limit_output() {
    if [ -n "$Limit" ]; then
        head -n "$Limit"
    else
        cat
    fi
}

count_connection_attempts() {
    awk '{print $1}' "$Filename" | sort | uniq -c | sort -nr | limit_output | awk '{print $2, $1}'
}

count_successful_attempts() {
    awk '$9 == "200" {print $1}' "$Filename" | sort | uniq -c | sort -nr | limit_output | awk '{print $2, $1}'
}


most_common() {

    if [ "$Limit" == "" ]; then
        Limit=$(wc -l < "$Filename")
    fi

    awk '{print $9, $1}' "$Filename" | sort | uniq -c | awk -v Limit="$Limit" '
    {
        ip_count[$2][$3] += $1
        total_count[$2] += $1
    }
    END {
        n_codes = asorti(total_count, sorted_codes, "@val_num_desc")

        for (i = 1; i <= n_codes; i++) {
            code = sorted_codes[i]

            n_ips = asorti(ip_count[code], sorted_ips, "@val_num_desc")
            for (j = 1; j <= n_ips && j <= Limit; j++) {
                ip = sorted_ips[j]
                print code, ip
            }
            print ""
        }
    }'
}

most_common_failure() {
    if [ "$Limit" == "" ]; then
        Limit=$(wc -l < "$Filename")
    fi

    awk '$9 ~ /^[4-5][0-9]{2}$/ {print $9, $1}' "$Filename" | sort | uniq -c | awk -v Limit="$Limit" '
    {
        ip_count[$2][$3] += $1
        total_count[$2] += $1
    }
    END {
        n_codes = asorti(total_count, sorted_codes, "@val_num_desc")

        for (i = 1; i <= n_codes; i++) {
            code = sorted_codes[i]

            n_ips = asorti(ip_count[code], sorted_ips, "@val_num_desc")
            for (j = 1; j <= n_ips && j <= Limit; j++) {
                ip = sorted_ips[j]
                print code, ip
            }
            print ""
        }
    }'
}

IP_most_bytes() {

            awk '{sum[$1]+=$10} END {for (ip in sum) print ip, sum[ip]}' "$Filename" |
            sort -k2 -rn | limit_output
}

while getopts ":L:c:2:r:F:t:" option; do
    case $option in

        L)
            Limit=$OPTARG
            check_limit;;
        c)
            Filename=$OPTARG
            command_check_number "c"
            echo "IP addresses with the most connection attempts."
            count_connection_attempts
            Command='c'
            check_filename
            ;;
        2)
            Filename=$OPTARG
            command_check_number "2"
            echo "IP addresses with the most successful connection attempts."
            count_successful_attempts
            Command='2'
            check_filename
            ;;
        r)
            Filename=$OPTARG
            command_check_number "r"
            echo "Most common result codes with their corresponding IP addresses."
            most_common
            Command='r'
            check_filename
            ;;
        F)
            Filename=$OPTARG
            command_check_number "F"
            echo "Most common result codes that indicate failure with their corresponding IP addresses."
            most_common_failure
            Command='F'
            check_filename
            ;;
        t)
            Filename=$OPTARG
            command_check_number "t"
            echo "IP numbers with the most bytes sent to them."
            IP_most_bytes
            Command='t'
            check_filename ;;
        :)
            echo
            echo -e "${RED}${BOLD}ERROR: Option requires an argument. Please specify an argument.${NOTBOLD} ${NC}"
            echo
            usage
            exit 1;;
        \?)
            echo
            echo -e "${RED}${BOLD}ERROR: Invalid Command. Please specify a valid command.${NOTBOLD} ${NC}"
            echo
            usage
            exit 1;;
    esac
done

command_check_blank
