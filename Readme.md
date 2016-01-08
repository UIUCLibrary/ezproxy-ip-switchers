# Ezproxy Ip Switcher Monitor

This project was a quick solution to monitor some abuse that was doing frequent ip hops. There was some interest in the EzProxy mailing list, so UIU decided to share it.  




## Requirements

Perl needs to be installed in your system.  Also, the following perl modules need to be installed onto your system or in your path.

* Text::Template 
* File::Copy
* List::MoreUtils
* DBI 
* POSIX
* Getopt::Long

In addition, it uses in-memory sqlite3 database, so you'll need sqlite3 on the system.

## Installing and Setting Up

This isn't an actual perl module and there's no install script (yet).  

The easiest way to set the script up is 

1. `cd your_ezproxy_path`
2. `git clone the_project_url`
3. `chmod u+x ip-switchers/ip_switches.pl`
   
If you want to use the functionality that will automatically kill and block people who exceed a threshold, you'll need to create a template file. We use Shibboleth, so we have a shibuser.txt that maps users to various groups and does some other checks. 

If you don't want just a report but to actually replace your shibuser.txt w/ the accounts to block:

1. `cd ip-switchers`
2. `cp shibuser.txt.tmpl.skel shibuser.txt.tmpl`
3. `cat ../shibuser.txt >> shibuser.txt.tmpl`

You'll want to then edit the shibuser.txt.tmpl file to replace the auth:eduPersonTargetedID with whatever identifier you want to use and also make sure that it looks right.

## Running the script

### Summary report
```
./ip_switches.pl ../ezproxy.log
```

We've used this during a period where attackers were cycling a lot of accounts by keeping a terminal open w/ this as a watch 
`watch -n 600 './ip_switches.pl ../ezproxy.log'`

### Detailed Report
```
./ip_switches.pl --detailed ../ezproxy.log
```

The detailed dump will also include the ip addresses associated with each account, mainly to help in log analysis of other systems.

### Kill and Block

Make sure to run the following commands in /your_ezproxy_path/ip-switchers. This can and will block people and kill sessions in a way that is difficult to reverse. Be careful and check some of the other summaries first. 

Careful setting this up as a cron job. There are occasionally people who seem to mimic some of the trouble we've seen if they have cruddy vpns and are in a session for a while.

```
./ip_switches.pl --kill ../ezproxy.log
```
  

#### What is kill and block mode doing?

There is a list of blocked identifiers in blocked.txt. Running the above will add any new identifiers to blocked.txt. 

The script then  generates the shibuser.txt file from shibuser.txt.tmpl and the contents of the blocked.txt file. It does this when an account exceeds or equals the hardcoded $ip_change_kill_threshold (15).

Finally, it uses the command line "ezproxy kill \{ezproxy session id\}" to kill any sessions that have been associated with the eduPersonTargetedID.


### How does the script work?

The script reads in an ezproxy.log file given when calling the command-line. It stores cerrtain key ezproxy fields into an in-memory sqlite3 databsae. 

After processing that it then generates reports by running some queries against the in-memory database.

There's a hard-coded $ip_change_reporting_threshold which is currently 3. It'll ignore ip changes by a user below that threshold. 

## Possible improvements

* Set up a configuration file for options such as threshold instead of having it hard-coded.
* Don't rely on cron or similar to email alerts, instead use a perl library or log4perl
* More tools for managing block list
* Permanent database stored
* Have this run as a service, not via cron
* Merge with other scripts for a more robust system that can kill/block based off of more metrics
* Allow slurping of multiple files
