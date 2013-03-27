package Flickr::Shell::Lobby;

use base Flickr::Shell::Room;

sub id {
	return 'flickr://lobby';
}

sub look {
	return "You are standing in the lobby of the prestigous Flickr building.\nDoors lead north, east and west.";
}

sub exits {
	return {
		'n'	=> 'flickr://recent',
		'w'	=> 'flickr://tags',
		'e'	=> 'flickr://maps',
	};
}

1;
