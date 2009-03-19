#!/usr/bin/perl -w

use strict;
use lib 'lib';
use Flickr::Caa;
use Image::Magick;
use Term::ReadKey;
use Data::Dumper;


#
# load the image
#

my $image = Image::Magick->new;

#my $x = $image->Read('sunset.jpg');
#my $x = $image->Read('leen.jpg');
#my $x = $image->Read('flickr_logo_beta_big.gif');
my $x = $image->Read('map.png');

warn "$x" if "$x";

my ($sw, $sh) = GetTerminalSize;


#print "\e[2J";


#
# create the caa
#

my $caa = new Flickr::Caa;
$caa->draw_bitmap(0, 0, $sw-2, $sh-5, $image);
#$caa->draw_bitmap(0, 0, 20, 10, $image);



$x = $image->Write('leen.png');
warn "$x" if "$x";

