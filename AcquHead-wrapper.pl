#!/usr/bin/perl

# This is just a wrapper in order to generate the
# an genxml.pl options list from AcquHead output

use strict;
use warnings;

die "Provide input filename" unless @ARGV==1;

my @out = `AcquHead $ARGV[0]`;
if($? >> 8) {
  die "$ARGV[0]: AcquHead exited with non-zero exit code";
}

my %f;
for(@out) {
  chomp;
  next if $_ =~ /^#/;
  my ($name, $val) = split(':',$_,2);
  $val =~ s/^\s+//;
  $val =~ s/\s+$//;
  $val =~ s/'/'"'"'/g; # quote escaping for shells...
  $f{$name} = $val;
}

my $format = $f{'Mk2?'} ? 'Mk2' : 'Mk1';
my $label = "Run $f{RunNumber} on $f{Time} to $f{OutFile} as $format";

print "--label '$label' --description '$f{Description}' --comment '$f{RunNote}'";

