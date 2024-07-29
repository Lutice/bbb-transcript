#!/bin/bash


FILE_LIST="FILE_LIST"
LINK_LIST="LINK_LIST"
INSTALL_CONFIG="INSTALL.config"

function abort(){
    echo "Operation Aborted."
    exit 0
}

function escape() {
    echo "$1" | sed 's/[]\/$*.^[]/\\&/g'
}

function get_param(){
    key="$1"
    grep "^$key=" "$INSTALL_CONFIG" | cut -d'=' -f2-
}

function check_user(){
    if id "$1" >/dev/null 2>&1; then
	return
    else
	false
    fi

}

function replace_param(){
    dry_run="$3" 
    config_file_location="$2"
    param="$1"
    value=$(get_param "$param")
    if [[ -z "$value" ]]; then
	echo "Note: parameter '$param' unset."
	false
    else
	if [[ "$dry_run" == "false" ]]; then
# echo "Before escape: $param"
# echo "Before escape: $value"
	    escaped_param=$(escape "[$param]")
	    escaped_value=$(escape "$value")
# echo "After escape: $escaped_param"
# echo "After escape: $escaped_value"
	    command_string="s/$escaped_param/$escaped_value/g"
	    sed -i "$command_string" "$config_file_location"
	    command_success=$?
	    if [[ "$command_success" -eq 0 ]]; then
		echo "Applied parameter '$param' to '$value'"
		return
	    else
		echo "Failed to apply parameter '$param' to '$value'"
		false
	    fi
	else
	    echo "Would apply parameter '$param' to '$value' to file '$config_file_location'"
	    return
	fi
    fi
}

function usage(){
    cat <<EOF

******************** BBB-TRANSCRIPT INSTALL MANAGER ********************

Usage:
  ./installer.sh <options>

Available actions:
  --install		    To install/update the system files.
  --uninstall		    Delete all related files.
  --export_to <directory>   Export all ACTUAL system files related to a new root directory.

Flags:
  --diff		    Variant of the DRY RUN: show in detail what will be added (using the diff command for each file).
  --confirm		    Disable the DRY RUN.
  --force		    Doesn't prompt confirmation upon uninstalling.

Note:
  Don't forget to fill up the INSTALL.config file for a faster installation.
  You could always fill the necessary parameters in the config file that will be copied to (/etc/bigbluebutton.custom.bbb-transcript/aristote_config.yml).

EOF
}
directory_src_folder="."
installing=""
uninstalling=""
export_to=""
force=false
dryrun=true
diff=false

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
    
    if [[ "$1" == "--diff" ]]; then
	shift
	diff=true
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

if [[ "$uninstalling" == "true" && "$dryrun" == "false" && "$force" != "true" ]]; then
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
	echo -e "\n\n------------- Exporting files to $export_to -------------"
    else
	echo -e "\n\n------------- Exporting files to $export_to (DRY RUN) -------------"
    fi
    while IFS= read -r line; do
	
	if [ -z "$line" ]; then
	    continue
	fi

	file_path=$(echo "$line" | awk '{print $1}')
# ownership=$(echo "$line" | awk '{print $2}')
# permissions=$(echo "$line" | awk '{print $3}')


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
		if [[ "$diff" == true ]]; then
		    diff "$file_path" "$export_to$file_path"
		fi
	    fi

	else
	    echo "File '$file_path' doesn't exist"
	fi
    done < "$FILE_LIST"

    echo
    if [[ "$dryrun" == "false" ]]; then
	echo "Done exporting to directory $export_to."
    else
	echo "Dry run finished."
    fi
    echo ""

elif [ "$installing" == "true" ]; then

    if [ "$dryrun" == "false" ]; then
	echo -e "\n\n------------- Installing files -------------"
    else
	echo -e "\n\n------------- Installing files (DRY RUN) -------------"
    fi

    echo -e "\n\n--- Checking users  ---"

    bad_config=false

    bbb_user=$(get_param "bbb_user")
    php_user=$(get_param "php_user")
    if ! check_user "$bbb_user"; then
	echo -e "The user '$bbb_user' doesn't exist for 'bbb_user'"
	bad_config=true
    else
	echo -e "Will be using the user '$bbb_user' for 'bbb_user'"
    fi
    if ! check_user "$php_user"; then
	echo -e "The user '$php_user' doesn't exist for 'php_user'"
	bad_config=true
    else
	echo -e "Will be using the user '$php_user' for 'php_user'"
    fi

    if [[ "$bad_config" == "true" && "$dryrun" == "false" ]]; then
	exit 1
    fi

    echo -e "\n\n--- Copying files ---"
    while IFS= read -r line; do
    	
	if [ -z "$line" ]; then
	    continue
	fi

	file_path=$(echo "$line" | awk '{print $1}')
	ownership=$(echo "$line" | awk '{print $2}')
	permissions=$(echo "$line" | awk '{print $3}')


	if [[ -f "$directory_src_folder$file_path" || -d "$directory_src_folder$file_path" ]]; then
	    
	    dir_name=$(dirname "${file_path}")

	    if [[ "$dryrun" == "false" ]]; then
	    
		if ! [[ -d "$dir_name" ]]; then	
		    mkdir -p "$dir_name"
		    if [[ $? -ne 0 ]]; then
			echo "Failed to create '$dir_name'"
		    else
			echo "Created directory '$dir_name'"
		    fi
		fi

		overwritten=false
		if [ -f "$file_path" ]; then
		    overwritten=true
		fi

		cp -r "$directory_src_folder$file_path" "$file_path"
		if [[ $? -ne 0 ]]; then
		    echo "Couldn't copy '$directory_src_folder$file_path'"
		else
		    if [[ "$overwritten" == "true" ]]; then
			echo "Overwritten '$file_path'"
		    else
			echo "Copied '$file_path'"
		    fi
		    if [[ -n "$ownership" ]]; then
			chown "$ownership" "$file_path"
		    fi
		    
		    if [[ -n "$permissions" ]]; then
			chmod "$permissions" "$file_path"
		    fi
		fi
	    else
		if ! [[ -d "$dir_name" ]]; then	
		    echo "Would create $dir_name"
		fi
		if [[ -f "$file_path" ]]; then
		    echo "'$file_path' already exists and would be overwritten"
		else
		    echo "Would copy '$directory_src_folder$file_path' to '$file_path'"
		fi
		if [[ "$diff" == true ]]; then
		    diff "$directory_src_folder$file_path" "$file_path" 
		fi
	    fi

	else
	    echo "File '$directory_src_folder$file_path' is missing!"
	fi
    done < "$FILE_LIST"

    
    echo -e "\n\n--- Transcripts directory ---"
    if [[ "$dryrun" == "false" ]]; then 
	mkdir -p "/var/bigbluebutton/transcripts"
        chown bigbluebutton:www-data "/var/bigbluebutton/transcripts"
	echo "Created '/var/bigbluebutton/transcripts'"
    else
	if [[ -d "/var/bigbluebutton/transcripts" ]]; then
	    echo "Directory '/var/bigbluebutton/transcripts' already exists."
	else
	    echo "Would create '/var/bigbluebutton/transcripts'"
	fi
    fi

    echo -e "\n\n--- Linking files ---"

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
		echo "Would create '$dir_name'"
		echo "Would link '$link_name' to '$target_link'"
	    fi

	else
	    echo "File '$target_link' is missing! Unable to create link '$link_name'"
	fi
    done < "$LINK_LIST"


    echo -e "\n\n--- Replacing arguments  ---"
    
    missing_args=""
    conf_file=$(get_param "config_file_loc")
    vars_to_replace=$(get_param "vars_to_install")
    for var in $vars_to_replace; do
	if ! replace_param "$var" "$conf_file" "$dryrun"; then
	    missing_args="$missing_args $var"
	fi
    done
    

    echo -e "\n\n--- Checking permissions ---"
    
    # TODO: Check all permissions after installation

    echo
    if [[ "$dryrun" == "false" ]]; then
	echo -e "\n\n--- Restarting Nginx ---"
	systemctl restart nginx.service
	if [[ "$?" -ne 0 ]]; then
	    echo "Something went wrong when restarting NGINX. Please check the logs of the installation above."
	else
	    echo "Done installing."
	    if [[ -n "$missing_args" ]]; then
		echo -e "\nThe following arguments were or did not set correctly:"
		for missing_arg in $missing_args; do
		    echo "- $missing_arg"
		done
		echo -e "\nTo make the system fully functionnal, please replace the variables in [brackets] contained in the following file:\n'/etc/bigbluebutton.custom/bbb-transcript/aristote_config.yml'"
	    fi
	fi
    else
	echo "Dry run finished."
    fi


elif [[ "$uninstalling" == "true" ]]; then
    
    if [ "$dryrun" == "false" ]; then
	echo -e "\n\n------------- Uninstalling files -------------"
    else
	echo -e "\n\n------------- Uninstalling files (DRY RUN) -------------"
    fi

    echo -e "\n\n--- Unlinking files ---"

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

    echo -e "\n\n--- Deleting files ---"

    while IFS= read -r line; do
	
	if [ -z "$line" ]; then
	    continue
	fi

	file_path=$(echo "$line" | awk '{print $1}')
# ownership=$(echo "$line" | awk '{print $2}')
# permissions=$(echo "$line" | awk '{print $3}')

	if [[ -f "$file_path" ]]; then
	    
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
	    echo "File '$file_path' doesn't even exist"
	fi
    done < "$FILE_LIST"


    echo ""
    if [[ "$dryrun" == "false" ]]; then
	echo "Uninstallation completed."
	read -p "Do you want to clean the transcripts directory? (/var/bigbluebutton/transcripts) " clean_transcript
	if [[ "$clean_transcript" == "yes" ]]; then
	   rm -fr "/var/bigbluebutton/transcripts"
	   echo "Cleared /var/bigbluebutton/transcripts"
	fi
    else
	echo "Dry run finished."
    fi

fi    

exit 0
