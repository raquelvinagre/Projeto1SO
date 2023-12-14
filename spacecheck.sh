#!/bin/bash

# Default Variables
modification_date=""
file_size=""
current_date="$(date +'%Y%m%d')"
reverse=false
regex_pattern=""
sort_by_name=false
limit_of_lines=""
dir="."


# Function to display help
show_help() {
	echo "Uso: $0 [OPÇÕES] [DIRETÓRIO]"
    echo "Opções:"
    echo "  -n, --name <regex_pattern>    Filtrar por expressão regular no nome"
    echo "  -d, --date <data>             Filtrar por data máxima de modificação (AAAA-MM-DD)"
    echo "  -s, --size <tamanho>          Filtrar por tamanho mínimo de arquivo"
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

# Function to process arguments
process_arguments() {
	while getopts "n:d:s:ral:" opt; do
		case $opt in
			n) regex_pattern="$OPTARG";;
			d) 
			# Check if the date is valid
			if ! date -d "$OPTARG" &>/dev/null; then
			echo "Data Inválida: $OPTARG"
			exit 1
			fi
			modification_date="$OPTARG"
			;;
			s) 
			is_positive_number "$OPTARG"
			file_size="$OPTARG" ;;
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
	shift $((OPTIND - 1)) # Shift the positional parameters
	
	# Check if the directory exists
	if [ -d "$1" ]; then
		dir="$1"
	else
		dir="." # Default directory
	fi
}

#Function to generate the 'find' command based on options
generate_find_command() {
	local find_options="find $dir"

	[ -n "$regex_pattern" ] && find_options+=" -type f -regex '$regex_pattern'"
	[ -n "$modification_date" ] && find_options+=" -newermt '$modification_date 00:00:00'"
	[ -n "$file_size" ] && find_options+=" -size +${file_size}c"

	echo "$find_options"
}



calculate_size() {
    local directory="$1"
    local regex_pattern="$2"
    local modification_date="$3"
    local file_size="$4"
	local sum=0

    # Calculate the directory size using du
    if [ -d "$directory" ]; then
        for item in "$directory"/*; do

			if [ -e "$item" ] && [ -f "$item" ] && { 
    			[[ -z "$regex_pattern" || "$item" =~ $regex_pattern ]] && 
    			[[ -z "$modification_date" || "$(stat -c %Y "$item")" -le "$(date -d "$modification_date" +%s)" ]] && 
   				[[ -z "$file_size" || "$(stat -c %s "$item")" -ge "$file_size" ]]
			}
			then
    		space=$(du -bs "$item" 2>/dev/null | cut -f1)
    		sum=$((sum + space))
			elif [ -d "$item" ]; then
    			space=$(calculate_size "$item" "$regex_pattern" "$modification_date" "$file_size")
    			sum=$((sum + space))
			fi
        done
    fi

    echo "$sum"
}

# Function to process subdirectories
subdirectories() {
    local directory="$1"

    find "$directory" -type d -print 2>&1 | while read -r subdir; do
        if [ -d "$subdir" ]; then
			dir_temp="$subdir"
            space=$(calculate_size "$subdir" "$regex_pattern" "$modification_date" "$file_size")
            if [ "$space" -ne 0 ] && [ "$space" != "NA" ]; then
				echo -e "$space\t$subdir" # echo -e allows the use of \t and \n
            fi
        else
			echo -e "NA\t$dir_temp"
        fi
    done
}

#Function to print the data
print_sorted(){
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
        sorted_data=$(subdirectories "$dir" | sort -t$'\t' $sort_options | head -n "$limit_of_lines")
    else
        sorted_data=$(subdirectories "$dir" | sort -t$'\t' $sort_options)
    fi

    echo "$sorted_data"
}


# Main function
main() {
	process_arguments "$@"
	find_options=$(generate_find_command)
	
	printf "SIZE\tNAME\t%s\n" "$current_date $*" 

	# print_sort_data
	print_sorted
}

main "$@"