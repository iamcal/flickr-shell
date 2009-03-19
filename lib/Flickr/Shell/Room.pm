package Flickr::Shell::Room;

sub new {
	my ($class, $world, $args) = @_;

	my $self = bless {}, $class;

	$self->{world} = $world;

	$self->init($args);

	$self->{world}->add_room($self);

	return $self;
}

sub init { 1; }

sub exits { return {}; }

sub id { die "Subclass ".(ref $_[0])." doesn't implement id() function\n"; }

sub look { die "Subclass ".(ref $_[0])." doesn't implement look() function\n"; }

sub exit {
	my ($self, $dir) = @_;

	my $exits = $self->exits();

	my $exit = $exits->{$dir};

	if (defined $exit){

		$self->{world}->go_uri($exit);
	}else{
		print "You can't go that way!\n";
	}
}

sub verbs { return 0; }


1;
