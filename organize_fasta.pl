#!/usr/bin/perl
use strict;
use warnings;

# Check if a file is provided
if (@ARGV != 1) {
    die "Usage: $0 <input_fasta_file>\n";
}

my $input_file = $ARGV[0];
open(my $in, '<', $input_file) or die "Could not open file '$input_file' $!";

my $header = '';
my $sequence = '';

while (my $line = <$in>) {
    chomp $line;
    if ($line =~ /^>/) {
        if ($header) {
            print "$header\n$sequence\n";
        }
        $header = $line;
        $sequence = '';
    } else {
        $sequence .= $line;
    }
}

# Print the last sequence
if ($header) {
    print "$header\n$sequence\n";
}

close($in);

#Use:
#./organize_fasta.pl input.fasta > output.fasta