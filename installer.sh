#!/bin/bash


FILE_LIST="FILE_LIST"
LINK_LIST="LINK_LIST"

function abort(){
    echo "Operation Aborted."
    exit 0
}

function usage(){

    echo -e ""
    echo -e "******************** BBB-TRANSCRIPT INSTALL MANAGER ********************"
    echo -e ""
    echo -e "Usage:"
    echo -e "  ./installer.sh <options>"
    echo -e "  "
    echo -e "Available actions:"
    echo -e "  --install\t\t\tTo install/update the system files"
    echo -e "  --uninstall\t\t\tDelete all related files"
    echo -e "  --export_to <directory>\tExport all ACTUAL system files related to a new root directory"
    echo -e "  "
    echo -e "Flags:"
    echo -e "  --confirm\t\t\tDisable the DRY RUN."
    echo -e "  --force\t\t\tDoesn't prompt confirmation upon uninstalling"
    echo -e "  "
    echo -e "  "
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

if [[ "$installing" == "true" && "$uninstalling" == "true" || "$installing" == "true" && -n "$export_to" || "$uninstalling" == "true" && -n "$export_to" ]]; then
    echo "Error: Cannot perform multiple actions at once. Please choose between installing, uninstalling, or exporting to a folder."
    usage
    exit 0
fi

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
		# echo "Would create '$dir_name'"
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

    echo "--- Copying files ---"

    while IFS= read -r file_path; do
	
	if [ -z "$file_path" ]; then
	    continue
	fi

	if [[ -f "$directory_src_folder$file_path" ]]; then
	    
	    dir_name=$(dirname "${file_path}")

	    if [[ "$dryrun" == "false" ]]; then
	    
		# Copy all referenced files at their location
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
		# echo "Would create '$dir_name'"
		echo "Would copy '$directory_src_folder$file_path' to '$file_path'"
	    fi

	else
	    echo "File '$directory_src_folder$file_path' is missing!"
	fi
    done < "$FILE_LIST"

    echo "--- Linking files ---"

    while IFS= read -r line; do
	
	if [ -z "$line" ]; then
	    continue
	fi

	log_label=$(echo "$line" | awk '{print $1}')
	target_link=$(echo "$line" | awk '{print $2}')
	link_name=$(echo "$line" | awk '{print $3}')

	echo "Linking $log_label file..."

	if [[ -f "$target_link" ]]; then
	    
	    dir_name=$(dirname "${file_path}")

	    if [[ "$dryrun" == "false" ]]; then
	    
		# Copy all referenced files at their location
		mkdir -p "$dir_name"
		if [[ $? -ne 0 ]]; then
		    echo "Failed to create '$dir_name'"
		else
		    echo "Created directory '$dir_name'"
		fi

		ln -s "$target_link" "$link_name"
		if [[ $? -ne 0 ]]; then
		    echo "Couldn't create link '$link_name' pointing to '$target_link'"
		else
		    echo "Linked '$link_name' to '$target_link'"
		fi
	    else
		# echo "Would create '$dir_name'"
		echo "Would link '$link_name' to '$target_link'"
	    fi

	else
	    echo "File '$target_link' is missing! Unable to create link '$link_name'"
	fi
    done < "$LINK_LIST"


    echo "--- Checking permissions ---"
    
    # TODO: Check all permissions after installation
    # TODO: Check if logs and token cache files needs to be created

    echo
    echo "Done installing."
elif [[ "$uninstalling" == "true" ]]; then
    
    if [ "$dryrun" == "false" ]; then
	echo "------------- Uninstalling files -------------"
    else
	echo "------------- Uninstalling files (DRY RUN) -------------"
    fi

    echo "--- Unlinking files ---"

    while IFS= read -r line; do
	
	if [ -z "$line" ]; then
	    continue
	fi

	log_label=$(echo "$line" | awk '{print $1}')
	target_link=$(echo "$line" | awk '{print $2}')
	link_name=$(echo "$line" | awk '{print $3}')

	echo "Unlinking $log_label file..."

	if [[ -f "$target_link" ]]; then
	    
	    dir_name=$(dirname "${link_name}")

	    if [[ "$dryrun" == "false" ]]; then
	    
		unlink "$link_name"
		if [[ $? -ne 0 ]]; then
		    echo "Couldn't unlink '$link_name' pointing to '$target_link'"
		else
		    echo "Unlinked '$link_name' to '$target_link'"
		fi
	    else
		echo -e "Would \e[0;31munlink\e[0m '$link_name' to '$target_link'"
	    fi

	else
	    echo "File '$target_link' doesn't even exist for '$link_name'"
	fi
    done < "$LINK_LIST"

    echo "--- Deleting files ---"

    while IFS= read -r file_path; do
	
	if [ -z "$file_path" ]; then
	    continue
	fi

	if [[ -f "$directory_src_folder$file_path" ]]; then
	    
	    dir_name=$(dirname "${file_path}")

	    if [[ "$dryrun" == "false" ]]; then
	    
		rm "$file_path"
		if [[ $? -ne 0 ]]; then
		    echo "Couldn't delete '$file_path'"
		else
		    echo "Deleted $file_path'"
		fi

		find "$dir_name" -type d -empty -delete
	    else
		# echo "Would partially delete '$dir_name'"
		echo -e "Would \e[0;31mdelete\e[0m '$file_path'"
	    fi

	else
	    echo "File '$file_path' doesn't not even exist"
	fi
    done < "$FILE_LIST"


    echo "Uninstall done."

fi    

exit 0
