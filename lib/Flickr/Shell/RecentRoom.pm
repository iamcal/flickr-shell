package Flickr::Shell::RecentRoom;

use base Flickr::Shell::Room;
use Flickr::Feed;
use Flickr::Photo;
use Data::Dumper;


sub init {
	my ($self, $args) = @_;

	$self->{position} = 0;
	$self->{feed} = Flickr::Feed->new();
	$self->{photos} = $self->{feed}->load_photos_from_feed("feeds/recent.xml");
}

sub id { "flickr://recent"; }

sub look {
	my ($self) = @_;

	my $desc = "You are standing in a long north-south corridoor.\n";
	$desc .= "There is a recently uploaded photo on the wall.\n";

	my $p = $self->{position};
	my $mx = scalar(@{$self->{photos}})-1;

	if ($p>0 && $p<$mx){
		$desc .= "The coridoor continues north and south.";
	}elsif ($p==$mx){
		$desc .= "The coridoor continues south.";
	}else{
		$desc .= "The coridoor continues north, the lobby lies south.";
	}

	return $desc;
}


sub exit {
	my ($self, $dir) = @_;

	if ($dir eq 's'){

		if ($self->{position} == 0){

			$self->{world}->go_uri("flickr://lobby");
			return;

		}else{

			$self->{position}--;
			$self->{world}->look();
			return;
		}

	}


	if ($dir eq 'n'){

		if ($self->{position} == scalar(@{$self->{photos}})-1){

		}else{

			$self->{position}++;
			$self->{world}->look();
			return;
		}

	}

	return $self->SUPER::exit($dir);
}


sub photo {
	return $_[0]->{photos}->[$_[0]->{position}];
}

sub show_photo {
	Flickr::Photo->new($_[0]->{world})->show_photo($_[0]->photo);
}

sub verbs {
	my ($self, $tokens) = @_;

	my $flat = lc join '::', @{$tokens};

	if ($flat eq 'examine'){ $self->show_photo; return 1; }
	if ($flat eq 'examine::photo'){ $self->show_photo; return 1; }
	if ($flat eq 'ex'){ $self->show_photo; return 1; }

	return 0;
}

1;
