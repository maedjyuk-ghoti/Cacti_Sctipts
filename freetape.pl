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
my $input_dir = "/qfs5_misc/qfscfg/freetape";
#Directory for old Input files
my $old_dir = "/qfs5_misc/qfscfg/freetape/old";
#OID directory info
my $storage_dir = "/var/run/collect/4/3/2/0";
#Add extra hosts here
my $free_tape_itc   = "/0";
my $free_tape_poole = "/0";
my $samqfs          = "/1";
my $sancon          = "/2";
#Offset value to make dir for tape type
my $a_val_adj = (ord('A') - 1);
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
$month = $month + 1;
my $date = $year."0".$month.$mday;
print "today is: $date\n";
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
	my @dir = split('/', $file);
if ($dir[-1] eq "old") {
next;
}
	my @file_split = split('_', $dir[-1]);
	if (@file_split != 2) {
		error_condition(1, $file);
		next;
	}
if ($file_split[0] eq "devedwdi1") {
next;
}
	my $hostname  = $file_split[0];
	my $file_date = $file_split[1];

	#Check for today's date
	if ($file_date ne $date) {
		print "moving $file to old directory\n";
	#	system ("mv $file $old_dir");
		next;
	}
	open (infile_handle, "< $file") || die "Couldn't open $file for read: $!\n";
	while (my $line = <infile_handle>) {
		chomp($line);
		my @info = split(':', $line);
		if (((@info - 2) % 3) != 0) {
			error_condition(4, $line);
			next;
		}
		if ($hostname ne $info[0]) {
			error_condition(5, $hostname, $info[0]);
			next;
		}
		#tape_types is the number of tapes whose info is given on the line
		my $tape_types = ((@info - 2) / 3);
		my $location   = $info[1];
		print "$location, $hostname\n";
		my @tape_name;
		my @tape_alloc;
		my @tape_used;
		for (my $i = 0; $i < $tape_types; $i++) {
			push (@tape_name, ($info[(3 * $i) + 2]));
			push (@tape_alloc, ($info[(3 * $i) + 3]));
			push (@tape_used, ($info[(3 * $i) + 4]));
			if ($hostname eq "sancon2" || $hostname eq "sancon3") {
				print "WHOOP! THERE IT IS!\n";
				if ($location eq "itc") {
					$itc_tape_total = ($info[(3 * $i) + 3]);
								print "itc_tape_total = $itc_tape_total\n";
				}
				if ($location eq "poole") {
					$poole_tape_total = ($info[(3 * $i) + 3]);
								print "poole_tape_total = $poole_tape_total\n";
				}
			}
			else {
				if ($location eq "itc") {
					push (@itc_tape_alloc, ($info[(3 * $i) + 3]));
					push (@itc_tape_used, ($info[(3 * $i) + 4]));
				}
				if ($location eq "poole") {
					push (@poole_tape_alloc, ($info[(3 * $i) + 3]));
					push (@poole_tape_used, ($info[(3 * $i) + 4]));
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
		my @host_id;
		my $id_name  = substr($hostname, 0, 6);
		my $id_num = substr($hostname, 6, (length($hostname) - 6));
		push (@host_id, $id_name);
		push (@host_id, $id_num);
		my $OID_dir;
		#Expand this switch as necessary in the future
		if (lc($host_id[0]) eq "samqfs") {
			$OID_dir = $storage_dir . "/1";
		}
		elsif (lc($host_id[0]) eq "sancon") {
			$OID_dir = $storage_dir . "/2";
		}
		$OID_dir = $OID_dir . "/" . $host_id[1];
		for (my $i = 0; $i < $tape_types; $i++) {
			my $tape_val = (ord($tape_name[$i]) - $a_val_adj);
			$OID_dir = $OID_dir . "/" . $tape_val;
			if (!(-d $OID_dir)) {
				system("mkdir -p $OID_dir");
			}
			for (my $j = 1; $j <= 2; $j++) {
				#Allocated = 1, Used = 2
				my $string;
				my $dir_str = $OID_dir . "/" . $j;
				open outfile_handle, "> $dir_str" or die "Couldn't open $dir_str for write: $! \n";
				if ($j == 1) {
					$string = "0:" . @host_id . "Allocated:INTEGER:" . $tape_alloc[$i];
				}
				else {
					$string = "0:" . @host_id . "Used:INTEGER:" . $tape_used[$i];
				}
				print outfile_handle $string;
				close outfile_handle;
			} # end for j
		} # end for i
	} # end while line
} # end foreach file
close infile_handle;

#Compute free tape
			print "itc_tape_total = $itc_tape_total\n";
			print "poole_tape_total = $poole_tape_total\n";
my $itc_free_total = $itc_tape_total;
for (my $k = 0; $k < @itc_tape_used; $k++) {
  $itc_free_total -= $itc_tape_used[$k];
}
my $poole_free_total = $poole_tape_total;
for (my $l = 0; $l < @poole_tape_used; $l++) {
  $poole_free_total -= $poole_tape_used[$l];
}
#Store free tape information
my $o_string = "";
#itc_tape
my $OID_dir;
$OID_dir = $storage_dir . $free_tape_itc;
if (!(-d $OID_dir)) {
	system("mkdir -p $OID_dir");
}
open outfile_handle, ">$OID_dir/1" or die "Couldn't open $OID_dir for write: $! \n";
print "$itc_free_total\n";
$o_string = join ('.', "0:", "ITC_Free_Tape:INTEGER:", $itc_free_total);
print outfile_handle $o_string;
close outfile_handle;
#poole_tape
$OID_dir = $storage_dir . $free_tape_poole;
if (!(-d $OID_dir)) {
	system("mkdir -p $OID_dir");
}
open outfile_handle, ">$OID_dir/2" or die "Couldn't open $OID_dir for write: $! \n";
print "$poole_free_total\n";
$o_string = join ('.', "0:", "POOLE_Free_Tape:INTEGER:", $poole_free_total);
print outfile_handle $o_string;
close outfile_handle;

###########
# End Main
###########

##################
# Begin Functions
##################
sub error_condition {
	if ($_[0] == 1) {
			print "Improper file name: $_[1]\nUse format: <hostname>_<YYYYMMDD>\n"
	}
	elsif ($_[0] == 2) {
			print "Improper date format: $_[1]\nUse format: <YYYYMMDD>\n"
	}
	elsif ($_[0] == 3) {
			print "Please update file: $_[1]\nToday's date: $date\n"
	}
	elsif ($_[0] == 4) {
			print "Error in inputfile information: $_[1]\nFormat is: <host>:<local>:<tapetype>:<tapes>:<usedtapes>\n"
	}
	elsif ($_[0] == 5) {
			print "Filename and hostname different: $_[1], $_[2]\nShould be the same\n"
	}
}
