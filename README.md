# bash-shell-scripting-for-web-server-log-analysis
Create a Bash script to analyze thttpd.log file from a thttpd web server, extracting key data to identify anomalies and detect potential intrusions.

## The usage of the log_sum.sh script is as follows:

    log_sum.sh [-L N] (-c|-2|-r|-F|-t) <filename>

### Optional options:
-L N: Limit the number of results to N (Argument N required)

### Required options:
-c: Which IP address makes the most number of connection attempts?
-2: Which address makes the most number of successful attempts?
-r: What are the most common result codes and where do they come from?
-F: What are the most common result codes that indicate failure (no auth, not found, etc.) and where do they come from?
-t: Which IP number gets the most bytes sent to them?

<filename>: Refers to the logfile.

## Implementation explanation:

### 1.  -L (Limit):
    Can be called along with N (integer value to signify the limit), which will be stored in the $Limit variable.
    $Limit is initialized as an empty string.
    Since the -L is optional, in each command, the function `limit_output()` will be called. It checks if a limit exists and if so, the results will be limited to the value set by the $Limit variable.

### 2. -c (Connection Attempts):
    Function: `count_connection_attempts()`.
    The command pipeline used:
        ```
        awk '{print $1}' "$Filename" | sort | uniq -c | sort -nr | limit_output | awk '{print $2, $1}'
        ``` 
        - `awk '{print $1}' "$Filename"`: Extracts the first field (IP addresses) from the logfile.
        - `sort`: Sorts the extracted IPs.
        - `uniq -c`: Counts the number of unique occurrences of each IP.
        - `sort -nr`: Sorts the counts in reverse numerical order.
        - `limit_output`: Limits the result based on the $Limit value.
        - `awk '{print $2, $1}'`: Rearranges the output to display the IP address first, followed by the count of connection attempts.

### 3. -2 (Successful Attempts) :
    Function: `count_successful_attempts()`.
    The command pipeline used:
        ```
        awk '$9 == "200" {print $1}' "$Filename" | sort | uniq -c | sort -nr | limit_output | awk '{print $2, $1}'
        ```    
        - `awk '$9 == "200"'`: Filters the lines where the 9th field (status code) equals 200 (successful attempts).
        - `sort`: Sorts the IPs extracted from the 1st field.
        - `uniq -c`: Counts the unique successful connection attempts by each IP.
        - `sort -nr`: Sorts the counts in reverse numerical order.
        - `limit_output`: Limits the result to the specified $Limit value.
        - `awk '{print $2, $1}'`: Outputs the IP addresses followed by the count of successful attempts.

### 4. -r (Common Result Codes):
    Function: `most_common()`.
    The command pipeline used:
        ```
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
        ```    
        - `awk '{print $9, $1}'`: Extracts the result code (9th field) and the IP address (1st field).
        - `sort`: Sorts the output.
        - `uniq -c`: Counts the occurrences of each result code and IP combination.
        - `awk -v Limit="$Limit"`: Limits the result based on the $Limit value.
        - Then it sorts and prints the results in the required pattern specified in the instruction.

### 5. -F (Failure Codes):
    Function: `most_common_failure()`.
    The command pipeline used:
        ```
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
        ``` 
        - `awk '$9 ~ /^[4-5][0-9]{2}$/'`: Filters the log lines where the result code is a 4xx or 5xx (client or server error).
        - `sort`: Sorts the output.
        - `uniq -c`: Counts the occurrences of each error result code and IP combination.
        - `awk -v Limit="$Limit"`: Limits the result based on the $Limit value.
        - Then it sorts and prints the results in the required pattern specified in the instruction.

### 6. -t (Bytes Sent):
    Function: `IP_most_bytes()`.
    The command pipeline used:
        ```
        awk '{sum[$1]+=$10} END {for (ip in sum) print ip, sum[ip]}' "$Filename" | sort -k2 -rn | limit_output
        ``` 
        - `awk '{sum[$1]+=$10}'`: Sums up the bytes (10th field) for each unique IP (1st field).
        - `END {for (ip in sum) print ip, sum[ip]}`: After processing all lines, prints each IP and the corresponding total number of bytes.
        - `sort -k2 -rn`: Sorts the output based on the total number of bytes, in descending order.
        - `limit_output`: Limits the result based on the $Limit value.

### Error handling:
    `command_check_number()`: Verifies only one command (-c, -2, -r, -F, or -t) is issued.
    `command_check_blank()`: Ensures a command is provided, prompting an error if missing.
    `check_limit()`: Validates that the limit value is a valid integer.
    `check_filename()`: Ensures a valid logfile is provided and checks if it ends with .log.
    `usage()`: Echoes the usage instructions every time an error occurs, providing guidance on the correct input format.
