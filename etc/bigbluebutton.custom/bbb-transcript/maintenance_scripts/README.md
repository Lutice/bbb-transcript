# Debug scripts

## `get-all-enrichments.rb`

This script will retrieve all the enrichments owned by Lutice hosted on the Aristote server.
The output is returned on the standard output by default.
To store the results, you can use the command `ruby get-all-enrichments.rb >enrichments.txt` for example.

## `delete-enrichments.rb`

This script will delete the list of enrichment stored into a file.

Usage:
	ruby delete-enrichments.rb file_containing_enrichments_ids.txt
