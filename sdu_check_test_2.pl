#!/usr/bin/perl

use strict;
use warnings;

###############################################################################
# FILE:         sdu_check.pl
#
# CREATED:      06/03/2013
# UPDATED:      06/10/2013
#
# DESC:         This script is used for a nightly cronjob to the previous days sar
# Usage:        sdu_check.pl <filesystem_name> <optional-copy_old_datafile>
###############################################################################

###############################################################################
# Step 1 - Perform initializations.
###############################################################################


my $metadata_server = `/usr/ucb/hostname`;
my $prog_name = `basename $0`;          #Program name, e.g. putsar.sh

my ($seconds,$minutes,$hours,$mday,$month,$year,$wday,$yday,$isdst) = localtime();
$year += 1900;
my @days = qw/Sun Mon Tue Wed Thu Fri Sat/;
my $stime = $days[$wday] . " " . join("/", $month, $mday, $year) . ", " . join(":", $hours , $minutes);
my $tstamp = "$year$month$mday" . "_" . "$hours$minutes$seconds";
my $logfile = "/var/tmp/sdu_check.pl_" . $tstamp;
my $fsdir = '/usr/local/data';
my $fsname = $ARGV[0];
my $inputfile = "/usr/local/data" . $fsname . "-sdu.infile";
open (inputfile_handle, "<$inputfile") || die "Couldn't open $inputfile for read: $!\n";

#system("touch $logfile");
#system("exec >> $logfile 2>&1"); # Append stdout & stderr to logfile # TODO - FIX THE FOLLOWING LINE
#open ($logfile_handle, '>>', $logfile) or die ("Can't open $logfile for append: $!\n");
open (logfile_handle, ">$logfile") || die "Couldn't open $logfile for append: $!\n";

print logfile_handle "Starting program $prog_name $stime\n";
print logfile_handle "fsdir     is $fsdir\n";
print logfile_handle "fsname    is $fsname\n";
print logfile_handle "inputfile is $inputfile\n";

#################################################################################
# Step 2 - Validate Input Parameters and create string containing dates the
#          script needs to create reports for.
#################################################################################

# TODO - fix to print filesystem_name, and to print it everytime it scans a new file system.

if (@ARGV != 1) {
    print "you must enter a name to distinguish which filesystem\n";
}
my $todaysdate = join("-", $year, $month, $mday);

my $count = 0;

#TODO - fix cat. maybe use file io instead
foreach my $dir(`cat $inputfile`) {
my $inputstr = $todaysdate . ",";

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
		my @oid_pathname = split(':', $dir);
		my $oid = $oid_pathname[0];
		my @path = split('/', $oid_pathname[1]);

		#@path[0] should always be empty due to the syntax of the input file.
		if (($path[0] ne "") || ((scalar @path) < 2)) {
			print logfile_handle "Invalid path name: $path[0]\n";
		} else {
			if ((scalar @path) == 2) {
				#if line is a file system name, print it out
				print "fsname    is $fsname\n";
				print "oid       is $oid\n";
			}
			# debug
			print logfile_handle "Running sdu -s $oid_pathname[1]\n";
			# end debug

			my $cmdoutput = `/opt/SUNWsamfs/bin/sdu -s $oid_pathname[1]`;

			# debug
			print logfile_handle "Running awk '{print \$1}' on cmdoutput\n";
			# end debug

			my $bashcommand = $cmdoutput . " \| awk '{print \$1}'";
			my $dirsize = `$bashcommand`;
			$inputstr = $inputstr . $dirsize . ",";
			print logfile_handle "dir is $dir,size is $dirsize\n";
			print logfile_handle "inputstr is $inputstr\n";
			$count += 1;

			my $dirname = $path[-1];
			print logfile_handle "count is $count, dirname is $dirname\n";
			print logfile_handle "Directory is: $dirname found size is $dirsize\n";
			print logfile_handle "Collecting data for directory $dirname oid is $oid\n";

			# ds_collect_update.pl ######################################
			#system("/usr/local/src/ds_collect_update.pl", $dirsize, $dirname, INTEGER, $oid);
			# Convert Data
			my $gigs = int ($dirsize / 1024 / 1024);

			# debug
			print logfile_handle "argv1=$dirsize \n";
			print logfile_handle "gigs=$gigs \n";
			# end debug

			if ($gigs < 1) {
			  $gigs = 1;
			}

			# Break down OID
			my @oidtemp = split (/\./, $oid);
			pop(@oidtemp);
			my $oidDir = join('/',@oidtemp);
			my @oidValues = split(/\./, $oid);
			my $fileOID = $oidValues[-1];

			# debug
			print logfile_handle "dirOID:$oidDir \n";
			print logfile_handle "fileOID:$fileOID \n";
			# end debug

			# create directory structure if needed
			my $dirother = "/var/run/collect/$oidDir";

			# debug
			print "dir:$dirother \n";
			# end debug

			if (!(-d $dirother)) {
			   # debug
			   #print "dir does not exist\n";
			   # end debug
			   system("mkdir -p $dirother");
			}
			# Open file and write data to it
			open FH, ">/var/run/collect/$oidDir/$fileOID" or die "Can't open file /var/run/collect/$oidDir/$fileOID\n";
			my $data = join("$fileOID:" . $2 . ":" . $3 . ":" . $gigs);

			# debug
			print logfile_handle "$data \n";
			# end debug

			print FH $data;
			close FH;
			# end ds_collect_update.pl ############################################

			print "Finished collecting data for directory $dirname";
			if (@path == 2) {
				print logfile_handle "fsname is $fsname:  oid is $oid\n";
			}
		}
	}
}

close logfile_handle;

#end of script

