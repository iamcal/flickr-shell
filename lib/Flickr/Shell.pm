package Flickr::Shell;

use Term::ReadKey;
use Data::Dumper;

$|++;

sub new {
	my ($class) = @_;

	my $self = bless {}, $class;

	$self->{prompt} = '>';
	$self->{poll} = undef;
	$self->{poll_timer} = 2;

	return $self;
}

sub set_prompt {
	my ($self, $prompt) = @_;

	$self->{prompt} = $prompt;
}

sub reset {
	my ($self) = @_;

	print "\e[2J";
}

sub get_command {
	my ($self, $prompt) = @_;

	print defined $prompt ? $prompt : $self->{prompt};

	ReadMode 3;

	my $line_buffer = '';

	while (1){

		#
		# wait for key
		#

		while (not defined ($key = ReadKey($self->{poll_timer}))) {

			if (defined $self->{poll}){

				my $messages = $self->{poll}->poll();

				if (scalar @{$messages}){

					print "\n\n";

					for my $message (@{$messages}){

						print "\t$message\n";
					}

					print "\n";
					print defined $prompt ? $prompt : $self->{prompt};

					print $line_buffer;
				}
			}

		}


		#
		# check for return
		#

		if ((ord $key == 13) || (ord $key == 10)){

			print "\n";
			ReadMode 0;

			return $line_buffer;
		}


		#
		# backspace
		#

		if (ord $key == 8){

			if (length $line_buffer){
				$line_buffer = substr $line_buffer, 0, length($line_buffer) - 1;
				print chr(8).' '.chr(8);
			}

			next;
		}


		#
		# clear screen
		#

		if (ord $key == 12){

			$self->reset();

			print defined $prompt ? $prompt : $self->{prompt};

			print $line_buffer;

			next;
		}


		#
		# clear line
		#

		if (ord $key == 11){

			if (length $line_buffer){
				print chr(8) for 1..length $line_buffer;
				print ' ' for 1..length $line_buffer;
				print chr(8) for 1..length $line_buffer;
				$line_buffer = '';
			}

			next;

		}


		#
		# skip other control chars
		#

		if (ord $key < 20){

			next;
		}


		#
		# add to buffer
		#

		$line_buffer .= $key;
		print $key;

		#print "\n".(ord $key)."\n".$line_buffer;
	}
}

sub set_poll {
	my ($self, $poll) = @_;

	$self->{poll} = $poll;
}

1;
