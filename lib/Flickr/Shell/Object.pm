package Flickr::Shell::Object;

sub new {
	my ($class, $world) = @_;

	my $self = bless {}, $class;

	$self->{world} = $world;
	$self->{world}->add_object($self);

	return $self;
}

sub id { die "Subclass ".(ref $_[0])." doesn't implement id() function\n"; }

sub name { die "Subclass ".(ref $_[0])." doesn't implement name() function\n"; }


1;
