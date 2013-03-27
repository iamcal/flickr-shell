package Flickr::Shell::MapRoom;

use base Flickr::Shell::Room;
use Flickr::Photo;
use Data::Dumper;


sub init {
	my ($self, $args) = @_;
}

sub id { "flickr://maps"; }

sub look {
	my ($self) = @_;

	my $desc = "You are standing in a map room - there is a large map on the wall.\n";
	$desc .= "You can see the lobby through a door to the west.";

	return $desc;
}


sub show_photo {
	Flickr::Photo->new($_[0]->{world})->show_photo({'filename' => 'images/map.png'});
}

sub verbs {
	my ($self, $tokens) = @_;

	my $flat = lc join '::', @{$tokens};

	if ($flat eq 'examine'){ $self->show_photo; return 1; }
	if ($flat eq 'examine::map'){ $self->show_photo; return 1; }
	if ($flat eq 'ex'){ $self->show_photo; return 1; }

	return 0;
}

sub exits {
	return {
		'w'	=> 'flickr://lobby',
	};
}
1;
