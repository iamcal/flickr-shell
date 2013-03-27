package Flickr::Caa;

use Data::Dumper;
use Switch;
use Curses;
use Term::ReadKey;

use constant {

	# dark colors
	CACA_COLOR_BLACK              => 0,
	CACA_COLOR_RED                => 1,
	CACA_COLOR_GREEN              => 2,
	CACA_COLOR_YELLOW             => 3,
	CACA_COLOR_BLUE               => 4,
	CACA_COLOR_MAGENTA            => 5,
	CACA_COLOR_CYAN               => 6,
	CACA_COLOR_LIGHTGRAY          => 7,

	# light colors
	CACA_COLOR_DARKGRAY           => 8,
	CACA_COLOR_LIGHTRED           => 9,
	CACA_COLOR_LIGHTGREEN         => 10,
	CACA_COLOR_BROWN              => 11,
	CACA_COLOR_LIGHTBLUE          => 12,
	CACA_COLOR_LIGHTMAGENTA       => 13,
	CACA_COLOR_LIGHTCYAN          => 14,
	CACA_COLOR_WHITE              => 15,


	CACA_BACKGROUND_BLACK		=> 0x11,
	CACA_BACKGROUND_SOLID		=> 0x12,

	CACA_ANTIALIASING_NONE		=> 0x21,
	CACA_ANTIALIASING_PREFILTER	=> 0x22,

	CACA_DITHERING_NONE		=> 0x31,
	CACA_DITHERING_ORDERED2		=> 0x32,
	CACA_DITHERING_ORDERED4		=> 0x33,
	CACA_DITHERING_ORDERED8		=> 0x34,
	CACA_DITHERING_RANDOM		=> 0x35,

	LOOKUP_VAL			=> 32,
	LOOKUP_SAT			=> 32,
	LOOKUP_HUE			=> 16,

	HSV_XRATIO	=> 6,
	HSV_YRATIO	=> 3,
	HSV_HRATIO	=> 3,
};


sub new {
	my ($class) = @_;

	my $self = bless {}, $class;

	$self->{dither_mode}	= CACA_DITHERING_NONE;

	$self->{aliasing_mode}	= CACA_ANTIALIASING_NONE;
	$self->{aliasing_mode}	= CACA_ANTIALIASING_PREFILTER;

	$self->{bg_mode}	= CACA_BACKGROUND_BLACK;
	$self->{bg_mode}	= CACA_BACKGROUND_SOLID;

	$self->{window}		= undef;
	$self->{screen_height}	= 100;
	$self->{screen_width}	= 100;

	$self->{color_pairs} = {};
	$self->{color_pair_next} = 1;

	$self->{last_x} = 0;
	$self->{current_color_key} = '';
	$self->{output_driver} = 'ansi';

	$self->{hsv_distances}	= [];
	$self->{lookup_colors}	= [];

	$self->{hsv_palette} = [
		# weight, hue, saturation, value
		4,    0x0,    0x0,    0x0,   # black
		5,    0x0,    0x0,    0x5ff, # 30%
		5,    0x0,    0x0,    0x9ff, # 70%
		4,    0x0,    0x0,    0xfff, # white
		3,    0x1000, 0xfff,  0x5ff, # dark yellow
		2,    0x1000, 0xfff,  0xfff, # light yellow
		3,    0x0,    0xfff,  0x5ff, # dark red
		2,    0x0,    0xfff,  0xfff  # light red
	];


	$self->{color_map} = {
		int(CACA_COLOR_BLACK)		=> [30,1],
		int(CACA_COLOR_RED)		=> [31,1],
		int(CACA_COLOR_GREEN)		=> [32,1],
		int(CACA_COLOR_YELLOW)		=> [33,1],
		int(CACA_COLOR_BLUE)		=> [34,1],
		int(CACA_COLOR_MAGENTA)		=> [35,1],
		int(CACA_COLOR_CYAN)		=> [36,1],
		int(CACA_COLOR_LIGHTGRAY)	=> [37,1],

		int(CACA_COLOR_DARKGRAY)	=> [30,0],
		int(CACA_COLOR_LIGHTRED)	=> [31,0],
		int(CACA_COLOR_LIGHTGREEN)	=> [32,0],
		int(CACA_COLOR_BROWN)		=> [33,0],
		int(CACA_COLOR_LIGHTBLUE)	=> [34,0],
		int(CACA_COLOR_LIGHTMAGENTA)	=> [35,0],
		int(CACA_COLOR_LIGHTCYAN)	=> [36,0],
		int(CACA_COLOR_WHITE)		=> [37,0],	
	};

	return $self;
}


sub init {
	my ($self) = @_;

	# These ones are constant
	$self->{lookup_colors}->[0] = CACA_COLOR_BLACK;
	$self->{lookup_colors}->[1] = CACA_COLOR_DARKGRAY;
	$self->{lookup_colors}->[2] = CACA_COLOR_LIGHTGRAY;
	$self->{lookup_colors}->[3] = CACA_COLOR_WHITE;

	# These ones will be overwritten
	$self->{lookup_colors}->[4] = CACA_COLOR_MAGENTA;
	$self->{lookup_colors}->[5] = CACA_COLOR_LIGHTMAGENTA;
	$self->{lookup_colors}->[6] = CACA_COLOR_RED;
	$self->{lookup_colors}->[7] = CACA_COLOR_LIGHTRED;

	for (my $v = 0; $v < LOOKUP_VAL; $v++){
	for (my $s = 0; $s < LOOKUP_SAT; $s++){
	for (my $h = 0; $h < LOOKUP_HUE; $h++){

		my $val = 0xfff * $v / (LOOKUP_VAL - 1);
		my $sat = 0xfff * $s / (LOOKUP_SAT - 1);
		my $hue = 0xfff * $h / (LOOKUP_HUE - 1);

		# Initialise distances to the distance between pure black HSV
		# coordinates and our white colour (3)

		my $outbg = 3;
		my $outfg = 3;
		my $distbg = $self->HSV_DISTANCE(0, 0, 0, 3);
		my $distfg = $self->HSV_DISTANCE(0, 0, 0, 3);


		# Calculate distances to eight major colour values and store the
		# two nearest points in our lookup table.

		for (my $i = 0; $i < 8; $i++){

			$dist = $self->HSV_DISTANCE($hue, $sat, $val, $i);

			if ($dist <= $distbg){

				$outfg = $outbg;
				$distfg = $distbg;
				$outbg = $i;
				$distbg = $dist;

			}elsif ($dist <= $distfg){

				$outfg = $i;
				$distfg = $dist;
			}
		}

		$self->{hsv_distances}->[$v]->[$s]->[$h] = ($outfg << 4) | $outbg;
	}
	}
	}

	$self->{last_x} = 0;
	$self->{current_color_key} = '';
}


#
# Draw a bitmap on the screen.
#
# Draw a bitmap at the given coordinates. The bitmap can be of any size and
# will be stretched to the text area.
#
# x1 X coordinate of the upper-left corner of the drawing area.
# y1 Y coordinate of the upper-left corner of the drawing area.
# x2 X coordinate of the lower-right corner of the drawing area.
# y2 Y coordinate of the lower-right corner of the drawing area.
# bitmap Bitmap object to be drawn.
# pixels Bitmap's pixels.
#

sub draw_bitmap{

	my ($self, $x1, $y1, $x2, $y2, $image) = @_;

	my $w = $x2-$x1;
	my $h = $y2-$y1;

	my $iw = 0;
	my $ih = 0;
	my $h_pad = 0;
	my $v_pad = 0;

	if (defined $image){

		# resize to fit in the box

		$image->Scale('100%,67%');
		my $x = $image->Resize(geometry => ($w-2).'x'.($h-2));
		warn "$x" if "$x";

		#print "done\n";
		#return;

		($iw, $ih) = $image->Get('columns', 'rows');

		$h_pad = 1 + int(($w - $iw) / 2);
		$v_pad = 1 + int(($h - $ih) / 2);

		#($w, $h) = $image->Get('columns', 'rows');
	}

	if ($self->{output_driver} eq 'ansi'){

		#my ($sw, $sh) = GetTerminalSize;

		#$self->{screen_height}	= $sh;
		#$self->{screen_width}	= $sw;
	}


	$self->init();
	#return;

	# Current dithering method
	my $_init_dither = undef;
	my $_get_dirther = undef;
	my $_increment_dither = undef;


	# Only used when background is black

	my $white_colors = [
		CACA_COLOR_BLACK,
		CACA_COLOR_DARKGRAY,
		CACA_COLOR_LIGHTGRAY,
		CACA_COLOR_WHITE,
	];

	my $light_colors = [
		CACA_COLOR_LIGHTMAGENTA,
		CACA_COLOR_LIGHTRED,
		CACA_COLOR_YELLOW,
		CACA_COLOR_LIGHTGREEN,
		CACA_COLOR_LIGHTCYAN,
		CACA_COLOR_LIGHTBLUE,
		CACA_COLOR_LIGHTMAGENTA,
	];

	my $dark_colors = [
		CACA_COLOR_MAGENTA,
		CACA_COLOR_RED,
		CACA_COLOR_BROWN,
		CACA_COLOR_GREEN,
		CACA_COLOR_CYAN,
		CACA_COLOR_BLUE,
		CACA_COLOR_MAGENTA,
	];


	# FIXME: choose better characters!

	my $density_chars = 
		"    ".
		".   ".
		"..  ".
		"....".
		"::::".
		";=;=".
		"tftf".
		'%$%$'.
		"&KSZ".
		"WXGM".
		'@@@@'.
		"8888".
		"####".
		"????";

	my @density_chars = split //, $density_chars;
	$density_chars = \@density_chars;

	my $density_chars_size = scalar(@{$density_chars}) - 1;

	my $x = 0;
	my $y = 0;
	my $deltax = 0;
	my $deltay = 0;


	my $tmp;
	if ($x1 > $x2){ $tmp = $x2; $x2 = $x1; $x1 = $tmp; }
	if ($y1 > $y2){ $tmp = $y2; $y2 = $y1; $y1 = $tmp; }

	$deltax = $x2 - $x1 + 1;
	$deltay = $y2 - $y1 + 1;


	if ($self->{dither_mode} == CACA_DITHERING_NONE){
		$_init_dither		= \&init_no_dither;
		$_get_dither		= \&get_no_dither;
		$_increment_dither	= \&increment_no_dither;
	}

	if ($self->{dither_mode} == CACA_DITHERING_ORDERED2){
		$_init_dither		= \&init_ordered2_dither;
		$_get_dither		= \&get_ordered2_dither;
		$_increment_dither	= \&increment_ordered2_dither;
	}

	if ($self->{dither_mode} == CACA_DITHERING_ORDERED4){
		$_init_dither		= \&init_ordered4_dither;
		$_get_dither		= \&get_ordered4_dither;
		$_increment_dither	= \&increment_ordered4_dither;
	}

	if ($self->{dither_mode} == CACA_DITHERING_ORDERED8){
		$_init_dither		= \&init_ordered8_dither;
		$_get_dither		= \&get_ordered8_dither;
		$_increment_dither	= \&increment_ordered8_dither;
	}

	if ($self->{dither_mode} == CACA_DITHERING_RANDOM){
		$_init_dither		= \$self->init_random_dither;
		$_get_dither		= \$self->get_random_dither;
		$_increment_dither	= \$self->increment_random_dither;
	}

	unless (defined $_init_dither){
		# Something wicked happened!
		die("bad dither mode!");
		return;
	}

	for ($y = $y1 > 0 ? $y1 : 0; $y <= $y2 && $y <= $self->{screen_height}; $y++){
	$self->$_init_dither($y);
	for ($x = $x1 > 0 ? $x1 : 0; $x <= $x2 && $x <= $self->{screen_width}; $x++){

		my $ch = 0;
		my $r = 0;
		my $g = 0;
		my $b = 0;
		my $a = 0;
		my $hue = 0;
		my $sat = 0;
		my $val = 0;
		my $fromx = 0;
		my $fromy = 0;
		my $tox = 0;
		my $toy = 0;
		my $myx = 0;
		my $myy = 0;
		my $dots = 0;
		my $outfg = 0;
		my $outbg = 0;
		my $outch = chr 0;

		#  First get RGB

		if (0){
		if ($self->{aliasing_mode} == CACA_ANTIALIASING_PREFILTER){

			$fromx = ($x - $x1) * $w / $deltax;
			$fromy = ($y - $y1) * $h / $deltay;
			$tox = ($x - $x1 + 1) * $w / $deltax;
			$toy = ($y - $y1 + 1) * $h / $deltay;

			# We want at least one pixel

			if ($tox == $fromx){ $tox++; }
			if ($toy == $fromy){ $toy++; }

			$dots = 0;

			for ($myx = $fromx; $myx < $tox; $myx++){
			for ($myy = $fromy; $myy < $toy; $myy++){

				$dots++;
				my ($ri, $gi, $bi, $ai) = $self->get_rgba_default($image, $myx, $myy);
				$r += $ri;
				$g += $gi;
				$b += $bi;
				$a += $ai;
			}
			}

			# Normalize
			$r /= $dots;
			$g /= $dots;
			$b /= $dots;
			$a /= $dots;

		}else{

			$fromx = ($x - $x1) * $w / $deltax;
			$fromy = ($y - $y1) * $h / $deltay;
			$tox = ($x - $x1 + 1) * $w / $deltax;
			$toy = ($y - $y1 + 1) * $h / $deltay;

			# tox and toy can overflow the screen, but they cannot overflow
			# when averaged with fromx and fromy because these are guaranteed
			# to be within the pixel boundaries.

			$myx = int(($fromx + $tox) / 2);
			$myy = int(($fromy + $toy) / 2);

			($r, $g, $b, $a) = $self->get_rgba_default($image, $myx, $myy);

print "pixel[$myx,$myy] = $r $g $b\n";
next;
		}

			($hue, $sat, $val) = $self->rgb2hsv_default($r, $g, $b);
		}

		if (1){
		if (defined $image){

			my $px = ($x - $x1) - $h_pad;
			my $py = ($y - $y1) - $v_pad;

			my $to_l = $px < 0;
			my $to_t = $py < 0;
			my $to_r = $px >= $iw;
			my $to_b = $py >= $ih;

			if ($to_l || $to_t || $to_r || $to_b){

				$r = 0xfff;
				$g = 0xfff;
				$b = 0xfff;

			}else{

				($r, $g, $b, $a) = split /,/, $image->Get("pixel[$px,$py]");

				$r >>= 4;
				$g >>= 4;
				$b >>= 4;
			}

#print "pixel[$px,$py] = $r $g $b\n";
#next;

#die "$r, $g, $b";

			#if (bitmap->has_alpha && a < 0x800) continue;

			# Now get HSV from RGB
			($hue, $sat, $val) = $self->rgb2hsv_default($r, $g, $b);

#die "($hue, $sat, $val)";

			#$sat = 0x777;
			#$val = 0x777;

		}else{


			$hue = int(0x5fff * (($x-$x1) / ($x2-$x1)));
			$sat = int(0xfff * (($y-$y1) / ($y2-$y1)));
			$val = int(0xfff * (($y-$y1) / ($y2-$y1)));
			$val = 0x777;
		}
		}


		# The hard work: calculate foreground and background colours,
		# as well as the most appropriate character to output.

		if ($self->{bg_mode} == CACA_BACKGROUND_SOLID){

			my $point = chr 0;
			my $distfg = 0;
			my $distbg = 0;

			$self->{lookup_colors}->[4] = $dark_colors->[1 + $hue / 0x1000];
			$self->{lookup_colors}->[5] = $light_colors->[1 + $hue / 0x1000];
			$self->{lookup_colors}->[6] = $dark_colors->[$hue / 0x1000];
			$self->{lookup_colors}->[7] = $light_colors->[$hue / 0x1000];

			my $idx_v = ($val + $self->$_get_dither() * (0x1000 / LOOKUP_VAL) / 0x100) * (LOOKUP_VAL - 1) / 0x1000;
			my $idx_s = ($sat + $self->$_get_dither() * (0x1000 / LOOKUP_SAT) / 0x100) * (LOOKUP_SAT - 1) / 0x1000;
			my $idx_h = (($hue & 0xfff) + $self->$_get_dither() * (0x1000 / LOOKUP_HUE) / 0x100) * (LOOKUP_HUE - 1) / 0x1000;

	#die "$idx_v $idx_s $idx_h";

			$point = $self->{hsv_distances}->[$idx_v]->[$idx_s]->[$idx_h];

			$distfg = $self->HSV_DISTANCE($hue % 0xfff, $sat, $val, ($point >> 4));
			$distbg = $self->HSV_DISTANCE($hue % 0xfff, $sat, $val, ($point & 0xf));

			# Sanity check due to the lack of precision in hsv_distances,
			# and distbg can be > distfg because of dithering fuzziness.

			if ($distbg > $distfg){ $distbg = $distfg; }

			$outfg = $self->{lookup_colors}->[($point >> 4)];
			$outbg = $self->{lookup_colors}->[($point & 0xf)];

			$ch = $distbg * 2 * ($density_chars_size - 1) / ($distbg + $distfg);
			$ch = 4 * $ch + $self->$_get_dither() / 0x40;

	#print "[$ch]";

			if ($ch >= scalar(@{$density_chars})){

				$ch = scalar(@{$density_chars}) - 1;
			}

			$outch = $density_chars->[$ch];


	#print "chr(".(ord $outch).") ";


		}else{

			$outbg = CACA_COLOR_BLACK;

			if ($sat < 0x200 + $self->$_get_dither() * 0x8){

				$outfg = $white_colors->[1 + ($val * 2 + $self->$_get_dither() * 0x10) / 0x1000];

			}elsif ($val > 0x800 + $self->$_get_dither() * 0x4){

				$outfg = $light_colors->[($hue + $self->$_get_dither() * 0x10) / 0x1000];

			}else{
				$outfg = $dark_colors->[($hue + $self->$_get_dither() * 0x10) / 0x1000];
			}

			$ch = ($val + 0x2 * $self->$_get_dither()) * 10 / 0x1000;
			$ch = 4 * $ch + $self->$_get_dither() / 0x40;
#	print "[$ch]";
			$outch = $density_chars->[$ch];
#	print "chr(".(ord $outch).") ";
		}

		# Now output the character
		$self->set_color($outfg, $outbg);
		$self->putchar($x, $y, $outch);

		$self->$_increment_dither();
#die "one pixel";
	}
	}
}

sub rgb2hsv_default {
	my ($self, $r, $g, $b) = @_;

	my ($hue, $sat, $val) = (0, 0, 0);

	my $min = $r;
	my $max = $r;

	$min = $g if $min > $g;
	$max = $g if $max < $g;
	$min = $b if $min > $b;
	$max = $b if $max < $b;

	my $delta = $max - $min; # 0 - 0xfff
	$val = $max; # 0 - 0xfff

	if ($delta){

		$sat = 0xfff * $delta / $max; # 0 - 0xfff

		# Generate *hue between 0 and 0x5fff

		if ($r == $max){
			$hue = 0x1000 + 0x1000 * ($g - $b) / $delta;
		}elsif ($g == $max){
			$hue = 0x3000 + 0x1000 * ($b - $r) / $delta;
		}else{
			$hue = 0x5000 + 0x1000 * ($r - $g) / $delta;
		}
	}else{
		$sat = 0;
		$hue = 0;
	}

	return ($hue, $sat, $val);
}


sub init_no_dither{ return 'woo'; }
sub get_no_dither{ return 0x80; }
sub increment_no_dither{}

sub HSV_DISTANCE{
	my ($self, $h, $s, $v, $index) = @_;

	#print "Called with ($h, $s, $v, $index)\n";

	my $v1 = $v - $self->{hsv_palette}->[$index * 4 + 3];
	my $s1 = $s - $self->{hsv_palette}->[$index * 4 + 2];
	my $h1 = $h - $self->{hsv_palette}->[$index * 4 + 1];

	my $s2 = $self->{hsv_palette}->[$index * 4 + 3] ? HSV_YRATIO * $s1 * $s1 : 0;
	my $h2 = $self->{hsv_palette}->[$index * 4 + 2] ? HSV_HRATIO * $h1 * $h1 : 0;

	return $self->{hsv_palette}->[$index * 4] * ((HSV_XRATIO * $v1 * $v1) + $s2 + $h2);
}

sub set_color{
	my ($self, $fg, $bg) = @_;

	my $key = "$fg:$bg";

	if ($self->{output_driver} eq 'ansi'){

		$self->{current_color_key} = $key;

		if (!defined $self->{color_pairs}->{$key}){

			my ($fg_col, $fg_dark) = @{$self->{color_map}->{$fg}};
			my ($bg_col, $bg_dark) = @{$self->{color_map}->{$bg}};

			$bg_col += 10;

			$self->{color_pairs}->{$key} = "\e[${fg_col};".($fg_dark?2:1).";${bg_col};".($bg_dark?6:5)."m";
		}

		return;
	}

	if ($self->{output_driver} eq 'curses'){

		if (!defined $self->{color_pairs}->{$key}){

			my $pr = $self->{color_pair_next};
			$self->{color_pair_next}++;

			init_pair($pr, $fg, $bg);
			$self->{color_pairs}->{$key} = $pr;

			print "new pair: $key\n";
		}

		$self->{window}->bkgdset($self->{color_pairs}->{$key});
	}
}

sub putchar{
	my ($self, $x, $y, $outch) = @_;

	if ($self->{output_driver} eq 'curses'){

		$self->{window}->addch($y, $x, $outch);
		return;
	}

	if ($self->{output_driver} eq 'ansi'){

		if ($x < $self->{last_x}){

			print "\n";
		}

		$self->{last_x} = $x;

		print $self->{color_pairs}->{$self->{current_color_key}};
		print $outch;
		print "\e[0m";
	}
}

sub get_rgba_default {

	my ($self, $image, $myx, $myy) = @_;

	my ($r, $g, $b, $a) = split /,/, $image->Get("pixel[$myx,$myy]");

	$r >>= 4;
	$g >>= 4;
	$b >>= 4;
	$a >>= 4;

	return ($r, $g, $b, $a);
}

1;