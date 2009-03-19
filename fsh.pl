#!/usr/bin/perl -w

use strict;
use lib 'lib';
use Flickr::Shell;
use Flickr::Shell::World;
use Flickr::Shell::Lobby;
use Flickr::Shell::TagGallery;
use Flickr::Shell::Events;
use Flickr::Shell::RecentRoom;
use Flickr::Shell::MapRoom;


my $shell = new Flickr::Shell;
$shell->set_prompt('? ');
$shell->reset();
print "\n";

#
# get a username
#

print "Please enter your name: ";
my $name = $shell->get_command('');
print "\n";


#
# put them into the lobby
#

my $world = new Flickr::Shell::World($name);
my $lobby = new Flickr::Shell::Lobby($world);
my $tags = new Flickr::Shell::TagGallery($world);
my $recent = new Flickr::Shell::RecentRoom($world);
my $maps = new Flickr::Shell::MapRoom($world);

my $events = new Flickr::Shell::Events('DBI:RAM:', 'root', 'bob');
$shell->set_poll($events);
$world->set_events($events);

$world->set_location($lobby);
$world->startup();
$world->look();
print "\n";

while (1){
	my $command = $shell->get_command('? ');

	print "\n";

	$world->process($command);

	last if $world->{exit_now};

	print "\n";
}

print "Goodbye!\n";