#!/usr/bin/perl

use strict;
use warnings;

###############################################################################
# Perl script to update convert diskspace information send in bytes
# to giga bytes and store the information in a Collect file.
# This script will create the directory structure if it doesn't exist.
# See Collect documentation for more information on how Collect works.
#
# Usage: ds_collect_update.pl <diskspace_bytes> <datadiscription> INTEGER <OID>
###############################################################################

# Convert Data
$gigs = int ($1 / 1024 / 1024);

# debug
#print "argv1=$1 \n";
#print "gigs=$gigs \n";
# end debug

if ($gigs < 1) {
  $gigs = 1;
}

# Break down OID
@oidtemp = split (/\./, $4);
pop(@oidtemp);
$oidDir = join('/',@oidtemp);
@oidValues = split(/\./, $4);
$fileOID = $oidValues[-1];

# debug
#print "dirOID:$oidDir \n";
#print "fileOID:$fileOID \n";
# end debug

# create directory structure if needed
$dir = "/var/run/collect/$oidDir";

# debug
#print "dir:$dir \n";
# end debug

if (!(-d $dir)) {
   # debug
   #print "dir does not exist\n";
   # end debug
   system("mkdir -p $dir");
}
# Open file and write data to it
open FH, ">/var/run/collect/$oidDir/$fileOID" or die "Can't open file /var/run/collect/$oidDir/$fileOID\n";
$data = "$fileOID:$2:$3:$gigs";

# debug
#print "$data \n";
# end debug

print FH $data;
close FH;
