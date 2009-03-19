package Flickr::Shell::World;

use Data::Dumper;
use Flickr::Caa;

sub new {
	my ($class, $username) = @_;

	my $self = bless {}, $class;

	$self->{exit_now} = 0;
	$self->{current_location} = undef;
	$self->{rooms} = [];
	$self->{room_index} = {};
	$self->{inv} = [];
	$self->{caa} = new Flickr::Caa;
	$self->{events} = undef;
	$self->{username} = $username;

	return $self;
}

sub add_room {
	my ($self, $room) = @_;

	push @{$self->{rooms}}, $room;
	$self->{room_index}->{$room->id} = $room;
}

sub set_events {
	$_[0]->{events} = $_[1];
}

sub set_location {
	my ($self, $location) = @_;

	$self->{current_location} = $location;
}

sub look {
	my ($self) = @_;

	my $desc = $self->{current_location}->look();

	#print "world-look got desc ".(length $desc)." chars long\n";

	print "$desc\n";
}

sub process {
	my ($self, $command) = @_;

	my $tokens = $self->tokenise($command);


	#
	# is it speech?
	#

	if ($tokens->[0] =~ m/^\{PHRASE\}(.*)$/){

		$self->speech($1);
		return;
	}


	#
	# is it a world verb?
	#

	my $world_verbs = {
		'look'		=> 'look',
		'l'		=> 'look',
		'inventory'	=> 'inventory',
		'i'		=> 'inventory',
		'go'		=> 'go',
		'n'		=> 'go',
		'north'		=> 'go',
		's'		=> 'go',
		'south'		=> 'go',
		'e'		=> 'go',
		'east'		=> 'go',
		'w'		=> 'go',
		'west'		=> 'go',
		'ne'		=> 'go',
		'nw'		=> 'go',
		'se'		=> 'go',
		'sw'		=> 'go',
		'u'		=> 'go',
		'd'		=> 'go',
		'up'		=> 'go',
		'down'		=> 'go',
		'exit'		=> 'exit',
		'quit'		=> 'exit',
		'x'		=> 'exit',
		'logo'		=> 'logo',
		'url'		=> 'uri',
		'uri'		=> 'uri',
	};

	my $verb = lc $tokens->[0];

	if (defined $world_verbs->{$verb}){
		eval "\$self->$world_verbs->{$verb}(\$tokens);";
		warn $@ if $@;
		return;
	}

	#
	# try room verbs
	#

	return if $self->{current_location}->verbs($tokens);


	#
	# fallback
	#

	print "Sorry, I don't understand...\n";
}

sub tokenise {
	my ($self, $command) = @_;

	$command =~ s!(["'])(.*?)\1!${1}{PHRASE}${2}${1}!g;
	$command =~ s!(["'])(.*?)\1!my$q=$1;$_=$2;s@(\s)@"{WSP:".(ord$1)."}"@ge;qq@ $_ @!eg;

	my @tokens = split /\s+/, $command;
	my $tokens = [];

	for my $token (@tokens){

		$token =~ s!{WSP:(\d+)}!chr($1)!eg;

		$token =~ s!^\s*(.*?)\s*$!$1!;

		push @{$tokens}, $token if length $token;
	}

	return $tokens;
}

sub go {
	my ($self, $tokens) = @_;

	shift @{$tokens} if lc $tokens->[0] eq 'go';

	unless (scalar @{$tokens}){
		print "Go where?\n";
		return;
	}


	#
	# try for the n/s/e/w exits
	#

	if (scalar(@{$tokens}) <= 2){

		my $toke1 = lc $tokens->[0];
		my $toke2 = defined $tokens->[1] ? lc $tokens->[1] : '';

		my $exit_map = [
			['north', '', 'n'],
			['north', 'east', 'ne'],
			['north', 'west', 'nw'],
			['south', '', 's'],
			['south', 'east', 'se'],
			['south', 'west', 'sw'],
			['east', '', 'e'],
			['west', '', 'w'],
			['up', '', 'u'],
			['down', '', 'd'],
			['n', '', 'n'],
			['ne', '', 'ne'],
			['nw', '', 'nw'],
			['s', '', 's'],
			['se', '', 'se'],
			['sw', '', 'sw'],
			['e', '', 'e'],
			['w', '', 'w'],
			['u', '', 'u'],
			['d', '', 'd'],
		];

		my $dir = 0;

		for my $key (@{$exit_map}){

			if (($toke1 eq $key->[0]) && ($toke2 eq $key->[1])){

				$dir = $key->[2];
			}
		}

		if ($dir){

			$self->{current_location}->exit($dir);

			return;
		}
	}


	print "Go!\n";
	print Dumper $exits;
}

sub inventory {
	my ($self, $tokens) = @_;

	if (scalar @{$self->{inv}}){

		print "You are carrying:\n";

		for my $object (@{$self->{inv}}){

			print "    $object->name\n";
		}
	}else{
		print "You are carrying:\n";
		print "    nothing\n";
	}
}

sub exit {
	my ($self, $tokens) = @_;

	$self->{exit_now} = 1;
}

sub go_uri {
	my ($self, $uri) = @_;

	#print "setting uri to $uri...\n";

	return if $self->{current_location}->id eq $uri;

	my $room = $self->{room_index}->{$uri};

	unless (defined $room){

		print "Sorry, can't find room $uri!\n";
		return;
	}

	my $old_loc = $self->{current_location}->id;

	#print "setting loc...\n";
	$self->set_location($room);

	#print "looking...\n";
	$self->look();

	if (defined $self->{events}){

		$self->{events}->{location} = $old_loc;
		$self->{events}->write_event("$self->{username} leaves the room");
		$self->{events}->{location} = $room->id;
		$self->{events}->write_event("$self->{username} eneters the room");
	}
}

sub logo {
	Flickr::Photo->new($_[0])->show_photo({'filename' => 'images/logo.png'});
}

sub startup {
	my ($self) = @_;

	if (defined $self->{events}){

		$self->{events}->{location} = $self->{current_location}->id;
		$self->{events}->write_event("$self->{username} materialises");
	}
}

sub speech {
	my ($self, $words) = @_;

	print "\tYou say: \"$words\"\n";

	if (defined $self->{events}){

		$self->{events}->write_event("$self->{username} says: \"$words\"");
	}

}

sub uri {
	my ($self) = @_;

	my $uri = $self->{current_location}->id;
	print "You are currently inside $uri\n";
}

1;
