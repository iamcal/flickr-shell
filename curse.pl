#!/usr/bin/perl -w

use strict;
use lib 'lib';
use Curses;
use Term::ReadKey;
use Curses::Widgets;
use Flickr::Caa;

my ($cols,$lines) = GetTerminalSize;

print "screen is ($cols,$lines)\n";

initscr;

my $s = newwin($lines, $cols, 0, 0);

$s->bkgdset(COLOR_PAIR(select_colour(('green', 'magenta'))));
#$s->attron(A_BOLD) if $$conf{FOREGROUND} eq 'yellow';
$s->erase;

$s->clear;
$s->addstr(1, 10, 'X');


my $caa = new Flickr::Caa;

$caa->{window} = $s;
$caa->draw_bitmap(2, 2, 40, 20, undef);


$s->move(4,0);
$s->noutrefresh();


doupdate;
sleep(3);

endwin;