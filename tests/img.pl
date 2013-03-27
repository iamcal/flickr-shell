#!/usr/bin/perl -w

use strict;
use lib '../lib';
use Flickr::Caa;
use Term::ANSIColor;

my $caa = new Flickr::Caa;

print color 'clear';

$caa->draw_bitmap(2 ,2, 40, 20, undef);
print "\n";
