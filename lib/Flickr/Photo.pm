package Flickr::Photo;

use Image::Magick;
use Term::ReadKey;

sub new {
	my ($class, $world) = @_;

	my $self = bless {}, $class;

	$self->{world} = $world;

	return $self;
}

sub show_photo {
	my ($self, $photo) = @_;

	my ($sw, $sh) = GetTerminalSize;

	my $image = Image::Magick->new;
	my $x = $image->Read($photo->{filename});
	warn "$x" if "$x";

	$self->{world}->{caa}->draw_bitmap(0, 0, $sw-2, $sh-5, $image);

	print "\n";
}

1;