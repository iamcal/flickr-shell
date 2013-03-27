package Flickr::Feed;

use XML::Parser::Lite::Tree;
use XML::Parser::Lite::Tree::XPath;
use LWP::Simple;

sub new {
	my ($class) = @_;

	my $self = bless {}, $class;

	return $self;
}

sub load_photos_from_feed {
	my ($self, $file) = @_;

	my $data = '';

	open F, $file or die "Can't open $file: $!";

	$data .= $_ while <F>;

	close F;

	my $tree = XML::Parser::Lite::Tree::instance()->parse($data);
	my $xpath = new XML::Parser::Lite::Tree::XPath($tree);

	my @photos = $xpath->select_nodes('/rsp/photos/photo');
	my $out = [];

	for my $photo (@photos){

		push @{$out}, $photo->{attributes};

		$self->cache_photo($photo->{attributes});
	}

	return $out;
}

sub cache_photo {
	my ($self, $attr) = @_;

	$attr->{url} = "http://static.flickr.com/$attr->{server}/$attr->{id}_$attr->{secret}.jpg";
	$attr->{filename} = "cache/$attr->{id}_$attr->{secret}.jpg";

	unless (-e $attr->{filename}){

		getstore($attr->{url}, $attr->{filename});

		print "cached url $attr->{url}\n";
	}
}

1;
