#!/usr/bin/perl

use strict;
use warnings;
use Switch 'Perl5';

###############################################################################
# FILE:         freetape.pl
#
# CREATED:      07/10/2013
# UPDATED:      07/16/2013
#
# DESC:         This script is used for a nightly cronjob to check the amount
#					of available tape.
# Usage:        freetape.pl
###############################################################################

#Expectes input file format and explanation:
#hostname:location:tapetype:total#:used#:tapetype:...
# hostname is the name of the server this information is from [eg. samqfs5, samqfs12]
# location is where the server is located [eg. ITC, Poole]
# tapetype is the type of tape [eg. B, C]
# total# is the total number of tapes allocated to the server
# used# is the total number of tapes with more than 1% full (10.24GB on B, 51.20GB on C)
# tapetype, total#, and used# can be repeated for as many tapetypes are in use on the server
# Example: "samqfs12:ITC:B:200:100:C:20:5"

#Input file location
my $input_dir = "/qfs5_misc/qfscfg/freetape/";
#OID directory info
my $storage_dir = "/var/run/collect/4/3/2/0";
#Add extra hosts here
my $free_tape_itc   = "/0/1";
my $free_tape_poole = "/0/2";
my $samqfs          = "/1";
my $sancon          = "/2";
#Offset value to make dir for tape type
my $a_value = (ord('a') - 1);
#Error constants
use constant {
	NAME         => 1,
	DATE_FORM    => 2,
	DATE_OUT     => 3,
	INFO_ERR     => 4,
	HOSTNAME_DIF => 5,
};
#Create date stamp
my ($seconds,$minutes,$hours,$mday,$month,$year,$wday,$yday,$isdst) = localtime();
$year += 1900; # needed to adjust year appropriately
my $date = $year.$month.$mday;
#Important data to determine free tape per library
my $itc_tape_total;
my @itc_tape_alloc;
my @itc_tape_used;
my $poole_tape_total;
my @poole_tape_alloc;
my @poole_tape_used;
#Loop through input_dir for files
my @files = <$input_dir/*>;
foreach my $file (@files) {
	#Check file names
	my @file_split = split('_', $file);
	if (@file_split != 2) {
		error_condition(NAME, $file);
		next;
	}
	my $hostname  = $file_split[0];
	my $file_date = $file_split[1];
	#Check date form
	if ($file_date ne \d{8}) {
		error_condition(DATE_FORM, $file_date);
		next;
	}
	#Check for today's date
	elsif ($file_date ne $date) {
		error_condition(DATE_OUT, $file_date);
		next;
	}
	open (infile_handle, "< $file") || die "Couldn't open $file for read: $!\n";
	while (my $line = <infile_handle>) {
		chomp($line);
		my @info = split(':', $line);
		if (((@info - 2) % 3) != 0) {
			error_condition(INFO_ERR, $line);
			next;
		}
		if ($hostname ne $info[0]) {
			error_condition(HOSTNAME_DIF, $hostname, $info[0]);
			next;
		}
		#tape_types is the number of tapes whose info is given on the line
		my $tape_types = ((@info - 2) / 3);
		my $location   = $info[1];
		my @tape_name;
		my @tape_alloc;
		my @tape_used;
		for (my $i = 1; $i <= $tape_types; $i++) {
			push (@tape_name, ($info[($tape_types * $i) + 2]));
			push (@tape_alloc, ($info[($tape_types * $i) + 3]));
			push (@tape_used, ($info[($tape_types * $i) + 4]));
			if ($hostname ne "sancon[23]") {
				if ($location eq "itc") {
					push (@itc_tape_alloc, ($info[($tape_types * $i) + 3]));
					push (@itc_tape_used, ($info[($tape_types * $i) + 4]));
				}
				if ($location eq "poole") {
					push (@poole_tape_alloc, ($info[($tape_types * $i) + 3]));
					push (@poole_tape_used, ($info[($tape_types * $i) + 4]));
				}
			}
			else {
				if ($location eq "itc") {
					$itc_tape_total = ($info[($tape_types * $i) + 3]);
				}
				if ($location eq "poole") {
					$poole_tape_total = ($info[($tape_types * $i) + 3]);
				}
			}
		}

		#Creating the OID
		# 4.3.2.0.<1>.<2>.<3>.<4>
		# <1> split hostname and number
		#	  if hostname is samqfs = 1
		#	  if hostname is sancon = 2
		#	  else error_condition and next
		# <2> host number
		# <3> determine tape (use 'ord')
		#	  A = 1, B = 2, etc.
		# <4> alloc = 1, used = 2
		# Ex.: Samqfs12, B tapes, Number Allocated = 4.3.2.0.1.12.2.1

		#Break apart hostname for OID use, rebuild it for later
		push (my @host_id, substr ($hostname, index ($hostname, '\d')));
		push (@host_id, $hostname);
		$hostname = $host_id[0].$host_id[1];
		my $OID_dir;
		#Expand this switch as necessary in the future
		if (lc($host_id[0]) eq "samqfs") {
			$OID_dir = $storage_dir . "/". $samqfs;
		}
		elsif (lc($host_id[0]) eq "sancon") {
			$OID_dir = $storage_dir . "/" . $sancon;
		}
		$OID_dir = $OID_dir . $host_id[1];
		for (my $i = 0; $i <= $tape_types; $i++) {
			$OID_dir = $OID_dir . "/" . (lc(ord($tape_name[$i])) - $a_value);
			mkdir ($OID_dir, 0755);
			for (my $j = 1; $j <= 2; $j++) {
				#Allocated = 1, Used = 2
				$OID_dir = $OID_dir . "/" . $j;
				my $string  = "";
				open (outfile_handle, "> $OID_dir") || die "Couldn't open $OID_dir for write: $! \n";
				if ($j == 1) {
					$string = join ('.', "0:", $hostname, $tape_name[$i], "Allocated:INTEGER:", $tape_alloc[$i]);
				}
				else {
					$string = join ('.', "0:", $hostname, $tape_name[$i], "Used:INTEGER:", $tape_used[$i]);
				}
				print outfile_handle $string;
				close outfile_handle;
			} # end for j
		} # end for i
	} # end while line
} # end foreach file
close infile_handle;

#Compute free tape
my $itc_free_total = $itc_tape_total;
for (my $i = 0; $i < @itc_tape_used; $i++) {
  $itc_free_total -= $itc_tape_used[$i];
}
my $poole_free_total = $poole_tape_total;
for (my $i = 0; $i < @poole_tape_used; $i++) {
  $poole_free_total -= $poole_tape_used[$i];
}
#Store free tape information
my $string = "";
#itc_tape
my $OID_dir = "";
$OID_dir = $storage_dir . $free_tape_itc;
open (outfile_handle, "> $OID_dir") || die "Couldn't open $OID_dir for write: $! \n";
$string = join ('.', "0:", "ITC_Free_Tape:INTEGER:", $itc_free_total);
print outfile_handle $string;
close outfile_handle;
#poole_tape
$OID_dir = $storage_dir . $free_tape_poole;
open (outfile_handle, "> $OID_dir") || die "Couldn't open $OID_dir for write: $! \n";
$string = join ('.', "0:", "POOLE_Free_Tape:INTEGER:", $poole_free_total);
print outfile_handle $string;
close outfile_handle;

###########
# End Main
###########

##################
# Begin Functions
##################
sub error_condition {
	switch ($_[0]) {
		case (NAME) {
			print "Improper file name: $_[1]\n";
			print "Use format: <hostname>_<YYYYMMDD>\n";
		}
		case (DATE_FORM) {
			print "Improper date format: $_[1]\n";
			print "Use format: <YYYYMMDD>\n";
		}
		case (DATE_OUT) {
			print "Please update file: $_[1]\n";
			print "Today's date: $date\n";
		}
		case (INFO_ERR) {
			print "Error in inputfile information: $_[1]\n";
			print "Format is: <host>:<local>:<tapetype>:<tapes>:<usedtapes>\n";
		}
		case (HOSTNAME_DIF) {
			print "Filename and hostname different: $_[1], $_[2]\n";
			print "Should be the same\n";
		}
	}
}
