# BBB-TRANSCRIPT

# The goal of BBB-transcript
This system provides an automated way to retrieve a transcript of any BigBlueButton meeting thanks to the Aristote AI, developped by Central Supélec.

# How to use it ?
## Quick install
- `git clone https://github.com/Lutice/bbb-transcript.git` to clone the project in a lambda temporary directory ;
- `cd bbb-transcript/` to go in the cloned directory ;
- `sudo nano INSTALL.config` or `sudo vim INSTALL.config` to customize your installation *(you can always modify the `aristote_config.yml` configuration file later, after the installation)* ;
- `sudo ./installer.sh` and follow the instructions to install it on your system ;

# How does it work ?
In short, it uses the bigbluebutton *post_publish* phase to execute a ruby script at the end of a meeting, that will send the audio data to Aristote's API to begin the enrichment process. It then waits for Aristote's SUCCESS notification to retreieve and save the transcript automatically.

## Files and workflow

### All files list
To function correctly, here is the list of the files needed (*provided in this github*) and their location:

- `/usr/local/bigbluebutton/core/scripts/post_publish/post_publish_transcript.rb`

- `/usr/local/bigbluebutton/core/lib/bbb-transcript/fields_checker.rb`
- `/usr/local/bigbluebutton/core/lib/bbb-transcript/ruby_logger.rb`
- `/usr/local/bigbluebutton/core/lib/bbb-transcript/token_get.rb`

- `/etc/bigbluebutton.custom/bbb-transcript/aristote_config.yml`
- `/etc/bigbluebutton.custom/bbb-transcript/config.nginx`

- `/etc/bigbluebutton.custom/bbb-transcript/test_scripts/get_all_enrichments.rb`
- `/etc/bigbluebutton.custom/bbb-transcript/test_scripts/delete_enrichments.rb`

- `/etc/bigbluebutton.custom/bbb-transcript/maintenance_scripts/delete_enrichments.rb`
- `/etc/bigbluebutton.custom/bbb-transcript/maintenance_scripts/get_all_enrichments.rb`


The following files are still needed, but are easily *customizable* (it is OK to change those of location as long as the YAML and nginx config file checks out):
- `/var/www/bbb-transcript/aristote_webhook.php`
- `/var/www/bbb-transcript/get_transcript.php`
- `/var/www/bbb-transcript/index.php`

Those four following files must be in the **lib/** directory (this **lib/** directory must also be in the same directory than the three above files):
- `/var/www/bbb-transcript/lib/config_parser.php`
- `/var/www/bbb-transcript/lib/get_token.php`
- `/var/www/bbb-transcript/lib/php_logger.php`
- `/var/www/bbb-transcript/lib/utlis.php`


### Phases
Before the transcript gets safely saved in the 'transcript.base-directory' directory (see config file), two main steps are performed:

- Post Publish (Enrichment Begin) Phase
- Enrichment Fetch and Save Phase

#### Post Publish (Enrichment Begin) Phase
The post publish phase takes place a small moment after the end of a meeting.  
During this phase, BBB executes all the ruby scripts contained inside of the `/usr/local/bigbluebutton/core/scripts/post_publish/` directory, in which resides the first script of this system: `post_publish_transcript.rb`.  

This file takes care of the startup of the enrichment process. It will in this order:  
- Retrieve the made recordings during the {meeting_id} session. If there are multiple opus files (in case the recording has been paused and resumed at least once), those files will be concatenated.  
- Build an new enrichment request with the opus file (and the settings used in the *config file*) and send it to Aristote.
- If the enrichment's start is successful, the script will finally create a temporary file named *{enrichment_id}* bearing the associated *{meeting_id}* (at location defined at **[transcripts.base-directory]** + **[transcripts.meeting-map-directory]** the two concatenated).

From this point, the system will just wait for the Aristote's response, aka the enrichment success notification.

#### Enrichment Fetch and Save Phase
This phase activates itself upon notification received from Aristote at the webhook url **[webhook-url]**.  
- The webhook is handled by the file `aristote_webhook.php` that accepts POST requests.  
- In case of a SUCCESS status returned by Aristote along its ID, the enrichment is then searched in the temp directory (**[transcripts.base-directory] + [transcripts.meeting-map-directory]**) to match it with the correct meeting_id it belongs to.  
- The transcript is then fetched from Aristote with another request made in the same PHP file, to save it at the location **[transcripts.base-directory]** with the name **[transcripts.filename]**. The temp file is then deleted upon success of the operation.  
- Additionally, if the option **[aristote-server.keep-clean]** is set to "true", the enrichment hosted on Aristote server will be prompted to be deleted via a last request dealt by this same PHP file.  


### Get the transcript of a meeting
After the transcript being successfully saved, you have multiple ways to retrieve it for your personnal application.  
One of the intented way, is by sending a GET request to the end point **[get-transcript-url]** which is by default `https://yourpersonnalsite.com/bbb-transcript/get_transcript.php`, handled by the `/var/www/bbb-transcript/get_transcript.php` file.

To get the transcript, simply send a GET request to the **[get-transcript-url]** url bearing two parameters: (*meeting_id*, *checksum*). MeetingId is the id reference of the meeting you want to retrive the transcript of. The checksum serves as an authentication field and is the hash (sha256) of *meeting_id* and the BBB security salt concatenated together.  
The GET request will only be processed by the PHP file if it can verify that the checksum is correct.  
- If the server cannot access the security salt and therefore is unable to verify the security salt, a 500 error is returned.
- If the checksum is incorrect, a 401 error is returned.
- If a transcript for the provided meeting_id exists, it is returned.
- If a transcript for the provided meeting_id does not exist, a 404 error is returned.

Of course, a 500 error is returned if another unknown error occurs.



