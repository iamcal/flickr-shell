package Flickr::Shell::Events;

use DBI;

sub new {
	my ($class) = @_;

	my $self = bless {}, $class;

	$self->{file} = 'events.txt';
	$self->{location} = '?';
	$self->{last_time} = time();

	return $self;
}

sub poll {
	my ($self) = @_;

	my $events = [];
	my $times = [];

	open F, $self->{file} or die "can't open events file: $!";

	while (<F>){
		my ($room, $time, $message) = split /\|/, $_, 3;

		if ($room eq $self->{location}){

			if ($time > $self->{last_time}){

				chomp $message;

				push @{$events}, $message;
				push @{$times}, $time;
			}
		}
	}

	close F;

	if (scalar @{$times}){ $self->{last_time} = pop @{$times}; }

	return $events;
}

sub write_event {
	my ($self, $message) = @_;

	my $time = time();

	open F, ">>$self->{file}" or die "can't open events file: $!";

	print F "$self->{location}|$time|$message\n";

	close F;

	$self->{last_time} = $time;
}


1;
