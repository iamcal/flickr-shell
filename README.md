# flickr-shell - A text adventure with pictures

This was one of my entires to a Yahoo! internal hack day back in maybe 2007.

The interesting code was released as a <a href="https://github.com/iamcal/perl-Image-Caa">perl module</a> at 
the time, but this code has sat in my private SVN for the last 5 years.


## Running it

Once you've got all the requirements set up, start it up like this:

    perl fsh.pl

The first time through, it will cache a bunch of files locally. It was built this way so that
it could be demoed offline. It should be easy to refactor this.

The feeds are also cached local API calls. If should be equally easy to switch these to using
real API calls and have the tags be actual active/popular tags, instead of just some common
ones I picked out.

## Commands

You can move around using compass directions

    n
    e
    south
    west

To look at a photo:

    examine photo
    examine
    ex

Some rooms require `x` rather than `ex`, but in others `x` causes you to exit. It's a game!


## Requirements

This requires both Curses and ImageMagick and does a crappy job of detecting whether they are 
installed and correctly configured. To install the packages with `yum`:

    yum install ncurses ncurses-devel
    yum install ImageMagick-perl
    perl -MCPAN -e'install Curses'

If you find that ImageMagick has missing delegates (you'll get tons of error messages when
trying to show images) then try this:

    yum erase ImageMagick
    yum install ImageMagick
    yum install ImageMagick-perl

If you have a particularly broken ImageMagick package, you may need to completely rebuild it
following the steps here: 
http://serverfault.com/questions/170395/adding-png-jpg-support-to-imagemagick-in-php-on-centos

After doing that, you'll need to rebuild the perl bindings:

    perl -MCPAN -e'install Image::Magick'
