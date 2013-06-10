#!/usr/bin/perl

use strict;
use warnings;

###############################################################################
# FILE:  	sdu_check.pl
#
# CREATED:	06/03/2013
# UPDATED:	06/10/2013
#
# DESC:		This script is used for a nightly cronjob to the previous days sar
# Usage:	sdu_check.pl <filesystem_name> <optional-copy_old_datafile>
###############################################################################

###############################################################################
# Step 1 - Perform initializations.
###############################################################################

# TODO -

my $metadata_server = `/usr/ucb/hostname`;
my $prog_name = `basename $0`;          #Program name, e.g. putsar.sh
my $stime = `date +"%a %D, %I:%M%p"`;   # Format: Thu 05/05/99, 4:44PM
my $tstamp = `date +"%Y%m%d_%H%M%S"`;
my $logfile = "/var/tmp/" . $prog_name . "_" . $tstamp;

my $fsdir = "/usr/local/data/";
my $fsname = $1;
my $inputfile = $fsdir . $fsname . '-sdu.infile';
my $td_datafile = $fsdir . $fsname . '_sdu_data.csv';
print "td_datafile is $td_datafile";
my $title_page = $fsdir . $fsname . '-sdu_title';
my $ftp_input_file = "/usr/local/data/" . $fsname . '-sdu_ftp.infile';
print "ftp file is $ftp_input_file";

touch $logfile;
system("exec >> $logfile 2>&1"); # Append stdout & stderr to logfile # TODO - FIX THE FOLLOWING LINE
#open ($logfile_handle, '>>', $logfile) or die ("Can't open $logfile for append: $!");
print "Starting program $prog_name $stime";
print "fsdir is $fsdir";
print "fsname is $fsname";
print "ftp file is $ftp_input_file";
print "td_datafile is $td_datafile";
print "inputfile is $inputfile";
print "title is $title_page";
print "Input file for program is  $inputfile";

#################################################################################
# Step 2 - Validate Input Parameters and create string containing dates the
#          script needs to create reports for.
#################################################################################

# TODO - fix to print filesystem_name, and to print it everytime it scans a new file system.

if ($# != 1) {
	print "you must enter a name to distinguish which filesystem";
}
if ($# == 2) {
	cp $td_datafile $2;
	cat $title_page > $td_datafile;
}
my $todaysdate = `date +"%Y-%m-%d"`;
my $inputstr = $todaysdate . ",";
my $count = 0;
foreach my $dir(`cat $inputfile`) {
	
	#Skip the line if commented out.
	if (index($dir,"#") != -1) {
		#nothing happens here.
	} else {
		
		##########################
		# Input file should be in the following format:
		#  <OID_Number>:<FileSystem>
		#  <OID_Number>:<FileSystem>/<Directory>
		#  (etc.)
		#
		# You can comment out a line, signalling this program to skip that line,
		#  by having two crunch/pound (##) anywhere in the line, although it is
		#  preferred at the beginning of the line.
		#
		# In the example below, lines 3, 6, 7, and 8 are commented out.
		#
		# Example:
		#  4.3.2.1.1:/A_File_System
		#  4.3.2.1.2:/A_File_System/A_Directory1
		#  ##4.3.2.1.3:/A_File_System/A_Directory2
		#  4.3.2.2.1:/B_File_System
		#  4.3.2.2.2:/B_File_System/B_Directory1
		#  ##:/B_File_System/B_Directory2
		#  4.3.2.2.3#:/B_File_System/B_Directory3
		#  4.3.2.2.4:/B_File_System##/B_Directory4
		##########################
		
		#parse the line gathered from $inputfile
		my @oid_pathname = split(/:/, $dir);
		my $oid = $oid_pathname[0];
		my @path = split(/\//, $oid_pathname[1]);
		
		#@path[0] should always be empty due to the syntax of the input file.
		if (($path[0] ne "") || ((scalar @path) < 2)) {
			print "Invalid path name: $path";
		} else if ((scalar @path) == 2) {
			#if line is a file system name, print it out
			print "fsname is $fsname:  oid is $oid";
		} else {
			my $cmdoutput = `/opt/SUNWsamfs/bin/sdu -s $dir`;
			my $dirsize = `echo $cmdoutput | awk '{echo $1}'`;
			$inputstr = $inputstr . $dirsize . ",";
			print "dir is $dir,size is $dirsize";
			print "inputstr is $inputstr";
			$count += 1;
			
			my $dirname = $path[-1];
			print "count is $count, dirname is $dirname";
			print "Directory is: $dirname found size is $dirsize";
			print "Collecting data for directory $dirname oid is $oid";
			system("/usr/local/src/ds_collect_update.pl", $dirsize, $dirname, INTEGER, $oid);
			print "Finished collecting data for directory $dirname";
		}
	}
}
print "fsname is $fsname:  oid is $oid";
print "$inputstr" >> $td_datafile;

#end of script
