#!/usr/bin/perl

use strict;
use warnings;
use Sys::Hostname; #used for 'my $metadata_server = hostname();'

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

my $metadata_server = hostname();
my $prog_name = $0; 	         #Program name, e.g. putsar.sh
my ($seconds,$minutes,$hours,$mday,$month,$year,$wday,$yday,$isdst) = localtime();
$year += 1900; # needed to adjust year appropriately
my @days = qw/Sun Mon Tue Wed Thu Fri Sat/;
my $stime = $days[$wday] . " " . join("/", $month, $mday, $year) . ", " . join(":", $hours , $minutes);
my $tstamp = "$year$month$mday" . "_" . "$hours$minutes$seconds";
my $logfile = "/var/tmp/sdu_check.pl_" . $tstamp;
my $fsdir = '/usr/local/data';
my $fsname = $ARGV[0];
my $inputfile = "/usr/local/data" . $fsname . "-sdu.infile";

open (inputfile_handle, "< $inputfile") || die "Couldn't open $inputfile for read: $!\n";
open (logfile_handle, "> $logfile") || die "Couldn't open $logfile for append: $!\n";

my_print("Starting program $prog_name $stime\n");
my_print("fsdir      is $fsdir\n");
my_print("fsname     is $fsname\n");
my_print("inputfile  is $inputfile\n");

#################################################################################
# Step 2 - Validate Input Parameters and create string containing dates the
#          script needs to create reports for.
#################################################################################

# TODO -

if (@ARGV != 1) {
    my_print("you must enter a name to distinguish which filesystem\n");
	exit 1;
}
my $todaysdate = join("-", $year, $month, $mday);
my $count = 0;
while (<inputfile_handle>) {
	chomp($_);
	my $inputstr = $todaysdate . ",";

	#Skip to next line in $inputfile if current one is commented out.
 	next if /^#/;

	#Parse the line gathered from $inputfile
	my @oid_pathname = split(':', $_);
	my $oid = $oid_pathname[0];
	my @path = split('/', $oid_pathname[1]);

	#@path[0] should always be empty due to the syntax of the input file.
	if (($path[0] ne "") || ((scalar @path) < 2)) {
		my_print("Invalid path name: $path[0]\n");
	} else {
		if ((scalar @path) == 2) {
			#if line is a file system name, print it out
			my_print("fsname     is $fsname\n");
			my_print("oid        is $oid\n");
		}

		# debug
		#print "Running sdu -s $oid_pathname[1]\n";
		# end debug

		my $cmdoutput = `/opt/SUNWsamfs/bin/sdu -s $oid_pathname[1]`;

		# debug
		#print "Running awk '{print \$1}' on cmdoutput\n";
		#print "$cmdoutput\n";
		# end debug

		my @temp = split(' ', $cmdoutput);
		my $dirsize = $temp[0];
		$inputstr = $inputstr . $dirsize . ",";
		my_print("dir        is $oid_pathname[1]\n");
		my_print("size       is $dirsize\n");
		my_print("inputstr   is \"$inputstr\"\n");
		$count += 1;
		my $dirname = $path[-1];
		my_print("count      is $count\n");
		my_print("dirname    is $dirname\n");
		my_print("Directory  is $dirname\n");
		my_print("Found size is $dirsize\n");
		#my_print("oid        is $oid\n");
		# Convert Data
		my $gigs = ($dirsize / 1024.0 / 1024.0);
		my $gigs_str = sprintf("%.2f", $gigs);

		# debug
		#print "argv1=$dirsize\n";
		#print "gigs=$gigs_str\n";
		# end debug

		if ($gigs < 1) {
		#  $gigs = 1;
		}
		# Break down OID
		my @oidtemp = split ('\.', $oid);
		pop(@oidtemp);
		my $oidDir = join('/',@oidtemp);
		my @oidValues = split('\.', $oid);
		my $fileOID = $oidValues[-1];

		# debug
		#print "dirOID:$oidDir\n";
		#print "fileOID:$fileOID\n";
		# end debug

		# create directory structure if needed
		my $dirother = "/var/run/collect/$oidDir";

		# debug
		#print "dir:$dirother \n";
		# end debug

		if (!(-d $dirother)) {
			# debug
			#print "dir does not exist\n";
			# end debug

			system("mkdir -p $dirother");
		}
		# Open file and write data to it
		open FH, ">/var/run/collect/$oidDir/$fileOID" or die "Can't open file /var/run/collect/$oidDir/$fileOID\n";
		my $data = join(":", $fileOID, $dirname, "INTEGER", $gigs_str);

		# debug
		#print "$data \n";
		# end debug

		print FH $data;
		close FH;
		# end of ds_collect_update.pl

		my_print ("Finished collecting data for directory $dirname\n");
		#if (@path == 2) {
		#	my_print ("fsname is $fsname:  oid is $oid\n");
		#}
	}
}

close logfile_handle;
#end of main script

#Subroutines/Functions
# my_print
#  Desc:	Prints to stdout and another stream
sub my_print {
	print $_[0];
	print logfile_handle $_[0];
}

