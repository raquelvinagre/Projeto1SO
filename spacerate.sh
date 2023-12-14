#!/bin/bash

# Default variables
reverse=false
sort_by_name=false
limit_of_lines=""
file1="${*:(-2):1}" # Second to last argument
file2="${!#}" # Last argument

# Function to display help
show_help() {
    echo "Uso: $0 [OPÇÕES] <arquivo1> <arquivo2>"
    echo "Opções:"
    echo "  -r, --reverse                 Ordenar em ordem reversa"
    echo "  -a, --alphabetical            Ordenar alfabeticamente"
    echo "  -l, --limit <linhas>          Limitar o número de linhas no output"
}

# Simple function to check if a number is positive
is_positive_number(){
	if ! [[ "$1" =~ ^[0-9]+$ ]]; then
		echo "Número Inválido: $1"
		exit 1
	fi
}

# Function to process the arguments
process_arguments() {
	while getopts ":ral:" opt; do
		case $opt in
			r) reverse=true ;;
			a) sort_by_name=true ;;
			l) 
			is_positive_number "$OPTARG"
			limit_of_lines="$OPTARG" ;;
			\?)
				show_help
				exit 1
				;;
		esac
	done
}

# Function to compare two spacecheck files
compare_sizes() {
    # Check if both input files exist
    if [ ! -f "$file1" ] || [ ! -f "$file2" ]; then
        echo "Error: Both input files must exist."
        exit 1
    fi

    declare -A data1
    declare -A data2

    # Read and allocate the sizes and names of the files from the first directory into an associative array
    while IFS=$'\t' read -r size name; do
        data1["$name"]=$size
    done < <(tail -n +2 "$file1") # Skip the first line

    # Read and allocate the sizes and names of the files from the second directory into an associative array
    while IFS=$'\t' read -r size name; do
        data2["$name"]=$size
    done < <(tail -n +2 "$file2") # Skip the first line

    # Process and compare the sizes from file1 and file2
    # Compare the two directories
    for file in "${!data2[@]}"; do
        if [ -n "${data1[$file]}" ]; then
            size1="${data1[$file]}"
            size2="${data2[$file]}"
            if [[ $size1 != "NA" && $size2 != "NA" ]]; then
            diff=$((size2 - size1))
            echo -e "$diff\t$file"     
            else
                echo -e "NA\t$file"
            fi
        else
            diff="${data2[$file]}"
            echo -e "$diff\t$file NEW"
        fi
    done

    for file in "${!data1[@]}"; do
        if [ -z "${data2[$file]}" ]; then
            size1="${data1[$file]}"
            size1_double="${data1[$file]}"
            diff=$(( size1 - 2*size1_double ))            
            echo -e "$diff\t$file REMOVED"
        fi
    done
}

# Function to print the data
print_sorted_data(){
    # sorted_data=$(compare_sizes "$file1" "$file2" | sort -t$'\t' -k1,1 -h -r)
    sort_options="-k1,1 -h -r"
    
    if [ "$sort_by_name" = true ]; then # If the -a option is used
        sort_options="-k2,2 -d"
        if [ "$reverse" = true ]; then # If the -r && -a option is used
            sort_options+=" -r"
        fi
    else 
        if [ "$reverse" = true ]; then # If the -r option is used
            sort_options="-k1,1 -h"
        fi
    fi

    if [ -n "$limit_of_lines" ]; then
        sorted_data=$(compare_sizes "$file1" "$file2" | sort -t$'\t' $sort_options | head -n "$limit_of_lines")
    else
        sorted_data=$(compare_sizes "$file1" "$file2" | sort -t$'\t' $sort_options)
    fi

    echo "$sorted_data"
}

# Main function
main() {
    process_arguments "$@" # Process the arguments
    printf "SIZE  NAME  %s\n" "$*" # Print the header
    print_sorted_data 
}
main "$@"