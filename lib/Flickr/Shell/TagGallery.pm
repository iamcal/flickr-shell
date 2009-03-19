package Flickr::Shell::TagGallery;

use base Flickr::Shell::Room;
use Flickr::Shell::TagRoom;

sub init {
	my ($self) = @_;

	$self->{tags} = ['kitten', 'sunset', 'portrait'];
	$self->{position} = 0;

	# create the tag rooms

	for my $tag (@{$self->{tags}}){

		new Flickr::Shell::TagRoom($self->{world}, {'tag' => $tag});
	}
}

sub id {
	return 'flickr://tags';
}

sub look {
	my ($self) = @_;

	my $desc = "You are standing in a long east-west corridoor.\n";
	$desc .= "A door to the north is labelled '$self->{tags}->[$self->{position}]'.\n";

	my $p = $self->{position};
	my $mx = scalar(@{$self->{tags}})-1;

	if ($p>0 && $p<$mx){
		$desc .= "The coridoor continues east and west.";
	}elsif ($p==$mx){
		$desc .= "The coridoor continues east.";
	}else{
		$desc .= "The coridoor continues west, the lobby lies eest.";
	}

	return $desc;
}


sub exit {
	my ($self, $dir) = @_;


	if ($dir eq 'n'){
		my $tag = $self->{tags}->[$self->{position}];

		$self->{world}->go_uri("flickr://tags/$tag");

		return;
	}


	if ($dir eq 'e'){

		if ($self->{position} == 0){

			$self->{world}->go_uri("flickr://lobby");
			return;

		}else{

			$self->{position}--;
			$self->{world}->look();
			return;
		}

	}


	if ($dir eq 'w'){

		if ($self->{position} == scalar(@{$self->{tags}})-1){

		}else{

			$self->{position}++;
			$self->{world}->look();
			return;
		}

	}

	return $self->SUPER::exit($dir);
}

1;
