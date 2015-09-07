#!/usr/bin/perl
use strict;
use warnings;
use File::Basename;
use Data::Dumper;

die "Please provide beamtime folders as arguments" if @ARGV == 0;

&main;

sub main {

  foreach my $dir (@ARGV) {
    unless(-d $dir) {
      print "Skipping $dir, not a directory\n";
    }
    WorkOnDir($dir);
  }
}

sub WorkOnDir {
  my $dir = shift;
  my $md5sum_file = "$dir/MD5SUM";
  my %MD5SUM;
  if (-f $md5sum_file) {
    open(my $fh, "<$md5sum_file") or die "Can't open $md5sum_file: $!";
    %MD5SUM = map {$_=~ s/^(.+?)  (.+?)\n$/$2/; $_ => 1 } <$fh>;
    close $fh;
  }

  my %rundata;          # should have an xz/gz, and xml. and maybe dat
  my @otherfiles;
  while (glob("$dir/*")) {
    my $file = (fileparse($_, '\..*'))[0];  # naked filename
    my $ext  = (fileparse($_, '\.[^.]*'))[2]; # very last extension
    $ext =~ s/\.gz/\.xz/;
    if ($ext =~ /^\.(dat|xz|xml)$/) {
      $rundata{$file}->{$ext}++;
      if ($ext eq '.xz' && exists $MD5SUM{basename($_)}) {
        $rundata{$file}->{'md5sum'}++;
      }
    } elsif ($_ ne $md5sum_file) {
      push(@otherfiles, "'$_'");
    }
  }
  my %n = ();
  foreach my $r (keys %rundata) {
    if (exists $rundata{$r}->{'.xml'} &&
        exists $rundata{$r}->{'.xz'} &&
        exists $rundata{$r}->{'md5sum'}) {
      $n{complete}++;
      if (exists $rundata{$r}->{'.dat'}) {
        $n{original}++;
      }
    } elsif (!exists $rundata{$r}->{'.xml'} &&
             !exists $rundata{$r}->{'.xz'} &&
             !exists $rundata{$r}->{'md5sum'} &&
             exists $rundata{$r}->{'.dat'}) {
      $n{uncompressed}++;
    } elsif (!exists $rundata{$r}->{'.xml'} &&
             exists $rundata{$r}->{'.xz'} &&
             exists $rundata{$r}->{'md5sum'}) {
      $n{nometadata}++;
    }
    else {
      push(@otherfiles, "'$dir/".$r.".*'");
    }
  }
  print "$dir\t ", join(', ', map {"$n{$_} $_"} sort keys %n),"\n";
  if (@otherfiles>0) {
    print 'Other files: ', join(' ',@otherfiles), "\n";
  }

  #print Dumper(\%rundata);
  #print Dumper(\@otherfiles);
}
