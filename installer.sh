#!/bin/bash


FILE_LIST="FILE_LIST"
DIR_LIST="DIRECTORY_LIST"

function abort(){
    echo "Operation Aborted."
    exit 0
}

function usage(){

    echo -e "Usage:"
    echo -e "  ./installer.sh <options>"
    echo
    echo -e "Options:"
    echo -e "  --install\t\t\tTo install/update the system files"
    echo -e "  --uninstall\t\t\tDelete all related files"
    echo -e "  --force\t\t\tDoesn't prompt confirmation upon uninstalling"
    echo -e "  --export_to <directory>\tExport all ACTUAL system files related to a new root directory"
    echo -e "  "
    echo -e "  "
#    echo "Note:"
#    echo "  Exporting might be"
}
directory_src_folder="."
installing=""
uninstalling=""
export_to=""
force=false
dryrun=true

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Please use sudo." 1>&2
    exit 1
fi

if [[ $# -eq 0 ]]; then
    usage
    exit 0
fi

while [[ $# -ge 1 ]]; do

    
    if [[ "$1" == "--help" ]]; then
	usage
	exit 0
    fi
    
    if [[ "$1" == "--install" ]]; then
	shift
	installing=true
	continue
    fi

    if [[ "$1" == "--uninstall" ]]; then
	shift
	uninstalling=true
	continue
    fi

    if [[ "$1" == "--confirm" ]]; then
	shift
	dryrun=false
	continue
    fi

    if [[ "$1" == "--force" ]]; then
	shift
	force=true
	continue
    fi

    if [[ "$1" == "--export_to" ]]; then
	shift
	export_to="$1"
	shift
	continue
    fi

    echo "Argument '$1' not regonized. Use --help for details."
    exit 0
    
done

if [[ -z "$export_to" && "$dryrun" == "false" && "$force" != "true" ]]; then
    read -p "Are you sure you want to uninstall bbb-transcript ? (yes/no) " choice

    if [[ "$choice" != "yes" ]]; then
	abort
    fi
    
    read -p "Are you REALLY sure you want to uninstall bbb-transcript ? (yes/no) " choice

    if [[ "$choice" != "yes" ]]; then
	abort
    fi
fi

if [[ -n "$export_to" ]]; then

    if [ "$dryrun" == "false" ]; then
	echo "------------- Exporting files to $export_to -------------"
    else
	echo "------------- Exporting files to $export_to (DRY RUN) -------------"
    fi
    while IFS= read -r file_path; do
	
	if [ -z "$file_path" ]; then
	    continue
	fi

	if [[ -f "$file_path" ]]; then
	    
	    dir_name=$(dirname "${export_to}${file_path}")

	    if [[ "$dryrun" == "false" ]]; then
		mkdir -p "$dir_name"
		if [[ $? -ne 0 ]]; then
		    echo "Failed to create '$dir_name'"
		else
		    echo "Created directory '$dir_name'"
		fi

		cp -r "$file_path" "$export_to$file_path"
		
		if [[ $? -ne 0 ]]; then
		    echo "Couldn't copy '$export_to$file_path'"
		else
		    echo "Copied '$export_to$file_path'"
		fi
	    else
		echo "Would create '$dir_name'"
		echo "Would copy '$file_path' to '$export_to$file_path'"
	    fi

	else
	    echo "File '$file_path' doesn't exist"
	fi
    done < "$FILE_LIST"

    echo
    echo "Done exporting to directory $export_to."

elif [ "$installing" == "true" ]; then

    if [ "$dryrun" == "false" ]; then
	echo "------------- Installing files -------------"
    else
	echo "------------- Installing files (DRY RUN) -------------"
    fi
    while IFS= read -r file_path; do
	
	if [ -z "$file_path" ]; then
	    continue
	fi

	if [[ -f "$directory_src_folder$file_path" ]]; then
	    
	    dir_name=$(dirname "${file_path}")

	    if [[ "$dryrun" == "false" ]]; then
		mkdir -p "$dir_name"
		if [[ $? -ne 0 ]]; then
		    echo "Failed to create '$dir_name'"
		else
		    echo "Created directory '$dir_name'"
		fi

		cp -r "$directory_src_folder$file_path" "$file_path"
		
		if [[ $? -ne 0 ]]; then
		    echo "Couldn't copy '$directory_src_folder$file_path'"
		else
		    echo "Copied '$directory_src_folder$file_path'"
		fi
	    else
		echo "Would create '$dir_name'"
		echo "Would copy '$directory_src_folder$file_path' to '$file_path'"
	    fi

	else
	    echo "File '$directory_src_folder$file_path' is missing!"
	fi
    done < "$FILE_LIST"

    echo
    echo "Done installing."
fi    

exit 0
