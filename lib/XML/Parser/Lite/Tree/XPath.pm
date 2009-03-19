package XML::Parser::Lite::Tree::XPath;

use strict;
use warnings;
use XML::Parser::Lite::Tree;
use Data::Dumper;

our $VERSION = '0.02';

sub new {
	my $class = shift;
	my $self = bless {}, $class;
	$self->{tree} = shift;

	#print XML::Parser::Lite::Tree::XPath::Scalar::ise(10) ** XML::Parser::Lite::Tree::XPath::Scalar::ise(3);

	return $self;
}

sub set_tree {
	my ($self, $tree) = @_;
	$self->{tree} = $tree;
}

sub select_nodes {
	my ($self, $xpath) = @_;

	if ($xpath =~ m!\|!){
		my @parts = split /\s*\|\s*/, $xpath;
		my @out;
		my %seen;

		for my $part(@parts){
			print "Running subrule $part...\n";
			map {
				if (!$seen{$_->{order}}){
					$seen{$_->{order}}++;
					push @out, $_;
				}
			} $self->select_nodes($part);
		}

		@out = sort { $a->{order} <=> $b->{order} } @out;

		return @out;
	}


	die "Only absolute XPaths are supported." if $xpath !~ m!^/!;

	$self->{max_order} = $self->_mark_orders($self->{tree}, 1, undef);

	my @tokens = split m!/!, $xpath;
	my @tags = ( $self->{tree} );

	shift @tokens;
	my $no_expand = 0;

	if ( $xpath =~ m!^//(.*)$! ){

		@tokens = split m!/!, $1;
		@tags = $self->_axis_descendant_single( $self->{tree}, 1 );
	}

	for my $token(@tokens){

		# apply the rule
		@tags = $self->apply_rule($token, \@tags);

		# uniquify the results
		my %seen = ();
		@tags = grep { ! $seen{$_->{order}} ++ } @tags;

		# sort the results
		@tags = sort { $a->{order} <=> $b->{order} } @tags;
	}

	@tags = grep{ $_->{type} ne 'root' }@tags;

	return @tags;
}

sub _mark_orders {
	my ($self, $tag, $i, $parent) = @_;

	$tag->{order} = $i++;
	$tag->{parent} = $parent;

	for my $child(@{$tag->{children}}){
		$i = $self->_mark_orders($child, $i, $tag);
	}

	return $i;
}

sub apply_rule {
	my ($self, $rule, $tags) = @_;

	my @out;

	# break off subrules

	my @subrules;
	while($rule =~ m!\[(.*)\]!){
		push @subrules, $1;
		$rule =~ s!\[(.*)\]!!;
	}

	# get axis

	my $axis = 'child';

	if ($rule =~ m/^([a-z-]+)\:\:(.*)/i){
		$rule = $2;
		$axis = $1;
	}

	# get the tag list for filtering

	if ($axis eq 'child'){			$tags = $self->_axis_child($tags);
	}elsif ($axis eq 'descendant'){		$tags = $self->_axis_descendant($tags, 0);
	}elsif ($axis eq 'descendant-or-self'){	$tags = $self->_axis_descendant($tags, 1);
	}elsif ($axis eq 'parent'){		$tags = $self->_axis_parent($tags);
	}elsif ($axis eq 'ancestor'){		$tags = $self->_axis_ancestor($tags, 0);
	}elsif ($axis eq 'ancestor-or-self'){	$tags = $self->_axis_ancestor($tags, 1);
	}elsif ($axis eq 'following-sibling'){	$tags = $self->_axis_following_sibling($tags);
	}elsif ($axis eq 'preceding-sibling'){	$tags = $self->_axis_preceding_sibling($tags);
	}elsif ($axis eq 'following'){		$tags = $self->_axis_following($tags);
	}elsif ($axis eq 'preceding'){		$tags = $self->_axis_preceding($tags);
	}elsif ($axis eq 'self'){		# no-op
	}else{ 					warn "unknown axis $axis."; }

	# process main part of rule

	if ($rule eq '*'){
		@out = @{$tags};

	}elsif ($rule eq 'text()'){
		for my $tag(@{$tags}){
			if (($tag->{'type'} eq 'data')){
				push @out, $tag;
			}
		}

	}elsif ($rule eq 'node()'){
		@out = @{$tags};

	}else{
		for my $tag(@{$tags}){
			if (($tag->{'type'} eq 'tag') && ($tag->{'name'} eq $rule)){
				push @out, $tag;
			}
		}
	}

	# process subrules in order

	my $seq = 1;

	@out = map {
		$_->{seq_num} = $seq++;
		$_->{seq_count} = scalar @out;
		$_;
	} @out;

	for my $rule(@subrules){

		my $tokens = $self->_tokenise_subrule($rule);

		my $code = $self->_build_subrule($tokens);

		#print "subrule: $rule\n";
		#print "code: $code\n\n";

		@out = grep{ eval $code; }@out;
	}

	return @out;
}

#######################################################################
##
## Axis selecting functions
##

sub _axis_child {
	my ($self, $tags) = @_;

	my @out;

	for my $tag(@{$tags}){
		for my $child(@{$tag->{children}}){
			push @out, $child;
		}
	}

	return \@out;
}

sub _axis_descendant {
	my ($self, $tags, $me) = @_;

	my @out;

	for my $tag(@{$tags}){

		push @out, $tag if $me;

		map{
			push @out, $_;
		}$self->_axis_descendant_single($tag, 0);
	}

	return \@out;
}

sub _axis_descendant_single {
	my ($self, $tag, $me) = @_;

	my @out;

	push @out, $tag if $me;

	for my $child(@{$tag->{children}}){

		if ($child->{type} eq 'tag'){

			map{
				push @out, $_;
			}$self->_axis_descendant_single($child, 1);
		}
	}

	return @out;
}

sub _axis_parent {
	my ($self, $tags) = @_;

	my @out;

	for my $tag(@{$tags}){
		push @out, $tag->{parent} if defined $tag->{parent};
	}

	return \@out;
}

sub _axis_ancestor {
	my ($self, $tags, $me) = @_;

	my @out;

	for my $tag(@{$tags}){

		push @out, $tag if $me;

		map{
			push @out, $_;
		}$self->_axis_ancestor_single($tag, 0);
	}

	return \@out;
}

sub _axis_ancestor_single {
	my ($self, $tag, $me) = @_;

	my @out;

	push @out, $tag if $me;

	if (defined $tag->{parent}){

		map{
			push @out, $_;
		}$self->_axis_ancestor_single($tag->{parent}, 1);
	}

	return @out;	
}

sub _axis_following_sibling {
	my ($self, $tags) = @_;

	my @out;

	for my $tag(@{$tags}){
		if (defined $tag->{parent}){
			my $parent = $tag->{parent};
			my $found = 0;
			for my $child(@{$parent->{children}}){
				push @out, $child if $found;
				$found = 1 if $child->{order} == $tag->{order};
			}
		}
	}

	return \@out;
}

sub _axis_preceding_sibling {
	my ($self, $tags) = @_;

	my @out;

	for my $tag(@{$tags}){
		if (defined $tag->{parent}){
			my $parent = $tag->{parent};
			my $found = 0;
			for my $child(@{$parent->{children}}){
				$found = 1 if $child->{order} == $tag->{order};
				push @out, $child unless $found;
			}
		}
	}

	return \@out;
}

sub _axis_following {
	my ($self, $tags) = @_;

	my $min_order  = 1 + $self->{max_order};
	for my $tag(@{$tags}){
		$min_order = $tag->{order} if $tag->{order} < $min_order;
	}

	# recurse the whole tree, adding after we find $min_order (but don't descend into it!)

	my @tags = $self->_axis_following_recurse( $self->{tree}, $min_order );

	return \@tags;
}

sub _axis_following_recurse {
	my ($self, $tag, $min) = @_;

	my @out;

	push @out, $tag if $tag->{order} > $min;

	for my $child(@{$tag->{children}}){

		if (($child->{order}) != $min && ($child->{type} eq 'tag')){

			map{
				push @out, $_;
			}$self->_axis_following_recurse($child, $min);
		}
	}

	return @out;
}

sub _axis_preceding {
	my ($self, $tags) = @_;

	my $max_order  = -1;
	my $parents;
	for my $tag(@{$tags}){
		if ($tag->{order} > $max_order){
			$max_order = $tag->{order};
			$parents = $self->_get_parent_orders($tag);
		}
	}

	# recurse the whole tree, adding until we find $max_order (but don't descend into it!)

	my @tags = $self->_axis_preceding_recurse( $self->{tree}, $parents, $max_order );

	return \@tags;
}

sub _axis_preceding_recurse {
	my ($self, $tag, $parents, $max) = @_;

	my @out;

	push @out, $tag if $tag->{order} < $max && !$parents->{$tag->{order}};

	for my $child(@{$tag->{children}}){

		if (($child->{order}) != $max && ($child->{type} eq 'tag')){

			map{
				push @out, $_;
			}$self->_axis_preceding_recurse($child, $parents, $max);
		}
	}

	return @out;
}

sub _get_parent_orders {
	my ($self, $tag) = @_;
	my $parents;

	while(defined $tag->{parent}){
		$tag = $tag->{parent};
		$parents->{$tag->{order}} = 1;
	}

	return $parents;
}

#######################################################################
##
## Subrule parser and runtime
##

sub _tokenise_subrule {
	my ($self, $rule) = @_;

	my $tokens = [];

	# numeric subrules are a special case

	if ($rule =~ m!^([0-9]+)$!){
		push @{$tokens}, {
			'token' => 'num_seq',
			'number' => $1,
		};
		return $tokens;
	}

	while(length($rule)){

		if ($rule =~ m!^@\*(.*)$!){

			push @{$tokens}, {
				'token' => 'at_star',
			};
			$rule = $1;

		}elsif ($rule =~ m!^@([a-z]+)(.*?)$!i){

			push @{$tokens}, {
				'token' => 'at_name',
				'name' => $1,
			};
			$rule = $2;

		}elsif ($rule =~ m!^([a-z][a-z-]*)\((.*?)$!i){

			push @{$tokens}, {
				'token' => 'func',
				'name' => $1,
			};
			$rule = $2;

		}elsif ($rule =~ m!^\)(.*?)$!){

			push @{$tokens}, {
				'token' => 'close_bracket',
			};
			$rule = $1;

		}elsif ($rule =~ m!^\*(\).*?)$!){

			push @{$tokens}, {
				'token' => 'children_star',
			};
			$rule = $1;

		}elsif ($rule =~ m#^(=|!=|<|<=|>|>=|,|mod|div|and|or|\+|\-|\*|\/)(.*?)$#i){

			my $map = {
				'=' => 'eq',
				'!=' => 'ne',
				'<' => 'lt',
				'<=' => 'le',
				'>' => 'gt',
				'>=' => 'ge',
				',' => ',',
				'mod' => '%',
				'div' => '**',
				'and' => '&&',
				'or' => '||',
				'+' => '+',
				'-' => '-',
				'*' => '*',
				'/' => '/',
			};

			push @{$tokens}, {
				'token' => 'op',
				'op' => $map->{$1},
			};
			$rule = $2;

		}elsif ($rule =~ m!^'([^']*)'(.*?)$!){

			push @{$tokens}, {
				'token' => 'literal',
				'string' => $1,
			};
			$rule = $2;

		}elsif ($rule =~ m!^"([^"]*)"(.*?)$!){

			push @{$tokens}, {
				'token' => 'literal',
				'string' => $1,
			};
			$rule = $2;

		}elsif ($rule =~ m!^([0-9]*\.[0-9]+|[0-9]+)(.*?)$!){

			push @{$tokens}, {
				'token' => 'literal',
				'string' => $1,
			};
			$rule = $2;

		}elsif ($rule =~ m!^([a-z]+)(.*?)$!i){

			push @{$tokens}, {
				'token' => 'children',
				'name' => $1,
			};
			$rule = $2;

		}elsif ($rule =~ m!^\s+(.*?)$!){

			$rule = $1;

		}else{

			warn "tokenising of subrule failed at <<$rule>>";
			return $tokens;
		}
	}

	return $tokens;
}

sub _build_subrule {
	my ($self, $tokens) = @_;

	my $code = '';

	for my $token(@{$tokens}){

		if ($token->{token} eq 'at_star'){
			$code .= ' (scalar(keys %{$_->{attributes}})>0) ';

		}elsif ($token->{token} eq 'at_name'){
			$code .= " XML::Parser::Lite::Tree::XPath::_func_DefineString( \$_->{attributes}->{$token->{name}} ) ";

		}elsif ($token->{token} eq 'func'){
			if ($token->{name} eq 'not'){
				$code .= " !( ";

			}elsif ($token->{name} eq 'last'){
				$code .= " ((\$_->{seq_num} == \$_->{seq_count}) ";

			}elsif ($token->{name} eq 'last-id'){
				$code .= " (XML::Parser::Lite::Tree::XPath::Scalar::ise(\$_->{seq_count}) ";

			}elsif ($token->{name} eq 'normalize-space'){
				$code .= " XML::Parser::Lite::Tree::XPath::_func_NormalizeSpace( ";

			}elsif ($token->{name} eq 'count'){
				$code .= " XML::Parser::Lite::Tree::XPath::_func_Count( ";

			}elsif ($token->{name} eq 'name'){
				$code .= " ((\$_->{name}) ";

			}elsif ($token->{name} eq 'starts-with'){
				$code .= " XML::Parser::Lite::Tree::XPath::_func_StartsWith( ";

			}elsif ($token->{name} eq 'contains'){
				$code .= " XML::Parser::Lite::Tree::XPath::_func_Contains( ";

			}elsif ($token->{name} eq 'string-length'){
				$code .= " length( ";

			}elsif ($token->{name} eq 'position'){
				$code .= " (\$_->{seq_num} ";

			}elsif ($token->{name} eq 'floor'){
				$code .= " XML::Parser::Lite::Tree::XPath::_func_Floor( ";

			}elsif ($token->{name} eq 'ceiling'){
				$code .= " XML::Parser::Lite::Tree::XPath::_func_Ceiling( ";


			}else{
				warn "function $token->{name} not implemented";
			}

		}elsif ($token->{token} eq 'close_bracket'){
			$code .= " ) ";

		}elsif ($token->{token} eq 'num_seq'){
			$code .= " (\$_->{seq_num} == $token->{number}) ";

		}elsif ($token->{token} eq 'op'){
			$code .= " $token->{op} ";

		}elsif ($token->{token} eq 'literal'){

			my $literal = $token->{string};

			$literal =~ s!([\\'])!\\$1!g;

			$code .= " XML::Parser::Lite::Tree::XPath::Scalar::ise('$literal') ";

		}elsif ($token->{token} eq 'children'){
			$code .= " XML::Parser::Lite::Tree::XPath::_func_GetChildren(\$_, '$token->{name}') ";

		}elsif ($token->{token} eq 'children_star'){
			$code .= " XML::Parser::Lite::Tree::XPath::_func_GetChildren(\$_, '*') ";

		}else{
			warn "code generation for token $token->{token} is not implemented"
		}
	}

	return $code;
}

#######################################################################
##
## Runtime functions
##

sub _func_DefineString {
	my $data = $_[0];
	$data = '' if !defined $data;
	return $data;
}

sub _func_NormalizeSpace {
	my $data = "$_[0]";
	$data =~ s!^\s*(.*?)\s*$!$1!;
	return $data;
}

sub _func_Count {
	my $data = $_[0];
	if (ref $data eq 'ARRAY'){
		return XML::Parser::Lite::Tree::XPath::Scalar::ise(scalar @{$data});
	}else{
		return XML::Parser::Lite::Tree::XPath::Scalar::ise(1);
	}
}

sub _func_GetChildren {
	my ($node, $name) = @_;
	my @nodes = grep{
		if ($_->{type} eq 'tag'){
			if ($name eq '*'){
				1;
			}else{
				if (defined $_->{name}){
					if ($_->{name} eq $name){
						1;
					}else{
						0;
					}
				}else{
					0;
				}
			}
		}else{
			0;
		}
	}@{$node->{children}};
	return \@nodes;
}

sub _func_StartsWith {
	my ($str, $substr) = @_;
	$substr = quotemeta $substr;
	return ($str =~ m/^$substr/) ? 1 : 0;
}

sub _func_Contains {
	my ($str, $substr) = @_;
	$substr = quotemeta $substr;
	return ($str =~ m/$substr/) ? 1 : 0;
}

sub _func_Floor {
	return XML::Parser::Lite::Tree::XPath::Scalar::ise(int $_[0]);
}

sub _func_Ceiling {
	return XML::Parser::Lite::Tree::XPath::Scalar::ise((int $_[0] < $_[0]) ? int $_[0]+1 : int $_[0]);
}


#######################################################################
##
## Scary overloading crap
##

package XML::Parser::Lite::Tree::XPath::Scalar;

use overload
        '**' => sub {
		#($_[1], $_[0]) = ($_[0], $_[1]) if $_[2];
		$_[0] += 0;
		$_[1] += 0;
		#print "dividing $_[0] by $_[1]...\n";
		int(($_[0] + 0) / ($_[1] + 0));
        },
        '0+' => sub { $_[0]->{data}+0; },
        '""' => sub { "$_[0]->{data}"; },
        'bool' => sub { $_[0]->{data}?1:0; },
        'fallback' => 1;

sub ise {
        my $ref = {'data' => $_[0] };
        return bless $ref, 'XML::Parser::Lite::Tree::XPath::Scalar';
}


1;
__END__

=head1 NAME

XML::Parser::Lite::Tree::XPath - XPath access to XML::Parser::Lite::Tree trees

=head1 SYNOPSIS

  use XML::Parser::Lite::Tree;
  use XML::Parser::Lite::Tree::XPath;

  my $xpath = new XML::Parser::Lite::Tree::XPath($tree);

  my @nodes = $xpath->select_nodes('/photoset/photos');


=head1 DESCRIPTION

This module offers limited XPath functionality for C<XML::Parser::Lite::Tree> objects. 
For more information about XPath see L<http://www.zvon.org/xxl/XPathTutorial/General/examples.html>

=head2 METHODS

=over 4

=item C<new($tree)>

Returns an C<XML::Parser::Lite::Tree::XPath> object for the given tree.

=item C<set_tree($tree)>

Sets the tree for the object.

=item C<select_nodes($xpath)>

Returns an array of nodes for the given XPath.

=back


=head1 AXES

The child axis is used by default. The following rules are equivilent:

  /foo/bar
  /foo/child::bar

The following axes are supported:

  ancestor
  ancestor-or-self
  child
  descendant
  descendant-or-self
  following
  following-sibling
  preceding
  preceding-sibling
  parent
  self

But these axes are B<not> supported:

  attribute
  namespace


=head1 FUNCTIONS

Only a handful of the XPath functions are implemented. If you need further
functions, send the author a test case and he'll try and implement them.

The following functions are supported:

  last()
  not()
  normalize-space()
  count()
  name()
  starts-with()
  contains()
  position()
  string-length()
  floor()
  ceiling()

But these functions are B<not> currently supported:

  id()
  string()
  concat()
  substring_before()
  substring_after()
  substring()
  translate()
  boolean()
  true()
  false()
  lang()
  number()
  sum()
  round()
  x_lower()
  x_upper()
  generate_id()


=head1 UNSUPPORTED FEATURES

In addition to the unsupported functions and axes, several XPath features are also unsupported.

  * attribute fetching
  * relative paths

=head1 CAVEATS

Sub-rules are evaluated in a boolean context, B<except> in the case where a subrule is a simple 
integer (e.g. C<//foo[3]>). This has some odd side effects - the C<last()> function returns
a boolean specifying whether the element is the last in the set or not. To get the sequence
number of the last element in a set (e.g. C<//foo[position() = last()]>), use the C<last-id()>
function instead. If you need to do some sort of caclulation which would return a position
(e.g. C<//foo[1+1]>), then compare the value using the C<position()> function to get the
correct result (e.g. C<//foo[1+1 = position()]>).


=head1 AUTHOR

Copyright (C) 2004, Cal Henderson, E<lt>cal@iamcal.comE<gt>


=head1 SEE ALSO

L<XML::Parser::Lite>
L<XML::Parser::Lite::Tree>
L<http://www.w3.org/TR/xpath>


=cu