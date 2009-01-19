package URI::Template;

use strict;
use warnings;

our $VERSION = '0.15';

use URI;
use URI::Escape qw(uri_escape_utf8);
use Unicode::Normalize;
use overload '""' => \&template;

=head1 NAME

URI::Template - Object for handling URI templates

=head1 SYNOPSIS

    use URI::Template;
    my $template = URI::Template->new( 'http://example.com/{x}' );
    my $uri      = $template->process( x => 'y' );
    # uri is a URI object with value 'http://example.com/y'

=head1 DESCRIPTION

This is an initial attempt to provide a wrapper around URI templates
as described at http://www.ietf.org/internet-drafts/draft-gregorio-uritemplate-03.txt

=head1 INSTALLATION

    perl Makefile.PL
    make
    make test
    make install

=head1 METHODS

=head2 new( $template )

Creates a new L<URI::Template> instance with the template passed in
as the first parameter.

=cut

sub new {
    my $class = shift;
    my $templ = shift || die 'No template provided';
    my $self  = bless { template => $templ, _vars => {} } => $class;
    
    $self->_study;

    return $self;
}

sub _study {
    my ($self) = @_;
    my @hunks = grep { defined && length } split /(\{.+?\})/, $self->template;
    for (@hunks) {
      next unless /^\{(.+?)\}$/;
      $_ = $self->_compile_expansion($1);
    }
    $self->{studied} = \@hunks;
}

sub _op_gen_join {
  my ($self, $exp) = @_;

  return sub {
    my ($var) = @_;

    my @pairs;
    for my $keypair (@{ $exp->{vars} }) {
      my $key = $keypair->[ 0 ];
      my $val = $keypair->[ 1 ]->( $var );
      next if !exists $var->{$key} && $val eq '';
      Carp::croak "invalid variable ($key) supplied to join operator"
        if ref $var->{$key};

      push @pairs, $key . '=' . $val;
    }
    return join $exp->{arg}, @pairs;
  };
}

sub _op_gen_opt {
    my ($self, $exp) = @_;

    Carp::croak "-opt accepts exactly one argument" if @{ $exp->{vars} } != 1;

    my $value   = $exp->{arg};
    my $varname = $exp->{vars}->[0]->[0];

    return sub {
      my ($var) = @_;
      return '' unless exists $var->{$varname} and defined $var->{$varname};
      return '' if ref $var->{$varname} and not @{ $var->{$varname} };

      return $value;
    };
}

sub _op_gen_neg {
    my ($self, $exp) = @_;

    Carp::croak "-neg accepts exactly one argument" if @{ $exp->{vars} } != 1;

    my $value   = $exp->{arg};
    my $varname = $exp->{vars}->[0]->[0];

    return sub {
      my ($var) = @_;
      return $value unless exists $var->{$varname} && defined $var->{$varname};
      return $value if ref $var->{$varname} && !  @{ $var->{$varname} };

      return '';
    };
}

sub _op_gen_prefix {
    my ($self, $exp) = @_;

    Carp::croak "-prefix accepts exactly one argument" if @{$exp->{vars}} != 1;

    my $prefix = $exp->{arg};
    my $name   = $exp->{vars}->[0]->[0];

    return sub {
      my ($var) = @_;
      return '' unless exists $var->{$name} && defined $var->{$name};
      my $array = ref $var->{$name} ? $var->{$name} : [ $var->{$name} ];
      return '' unless @$array;

      return join '', map { "$prefix$_" } @$array;
    };
}

sub _op_gen_suffix {
    my ($self, $exp) = @_;

    Carp::croak "-suffix accepts exactly one argument" if @{$exp->{vars}} != 1;

    my $suffix = $exp->{arg};
    my $name   = $exp->{vars}->[0]->[0];

    return sub {
      my ($var) = @_;
      return '' unless exists $var->{$name} && defined $var->{$name};
      my $array = ref $var->{$name} ? $var->{$name} : [ $var->{$name} ];
      return '' unless @$array;

      return join '', map { "$_$suffix" } @$array;
    };
}

sub _op_gen_list {
    my ($self, $exp) = @_;

    Carp::croak "-list accepts exactly one argument" if @{$exp->{vars}} != 1;

    my $joiner = $exp->{arg};
    my $name   = $exp->{vars}->[0]->[0];

    return sub {
      my ($var) = @_;
      return '' unless exists $var->{$name} && defined $var->{$name};
      Carp::croak "variable ($name) used in -list must be an array reference"
        unless ref $var->{$name};

      return '' unless my @array = @{ $var->{$name} };

      return join $joiner, @array;
    };
}

# not op_gen_* as it is not an op from the spec
sub _op_fill_var {
    my( $self, $exp ) = @_;
    my( $var, $default ) = split( /=/, $exp, 2 );
    $default = '' if !defined $default;

    return $var, sub {
        return exists $_[0]->{$var} ? $_[0]->{$var} : $default;
    };
}

sub _compile_expansion {
    my ($self, $str) = @_;

    if ($str =~ /\A-([a-z]+)\|(.*?)\|(.+)\z/) {
      my $exp = { op => $1, arg => $2, vars => [ map { [ $self->_op_fill_var( $_ ) ] } split /,/, $3 ] };
      $self->{ _vars }->{ $_->[ 0 ] }++ for @{ $exp->{ vars } };
      Carp::croak "unknown expansion operator $exp->{op} in $str"
        unless my $code = $self->can("_op_gen_$exp->{op}");

      return $self->$code($exp);
    }

    # remove "optional" flag (for opensearch compatibility)
    $str =~ s{\?$}{};

    my @var = $self->_op_fill_var( $str );
    $self->{ _vars }->{ $var[ 0 ] }++;
    return $var[ 1 ];
}

=head2 template

This method returns the original template string.

=cut

sub template {
    return $_[ 0 ]->{ template };
}

=head2 variables

Returns an array of unique variable names found in the template. NB: they are returned in random order.

=cut

sub variables {
    return keys %{ $_[ 0 ]->{ _vars } };
}

=head2 expansions

This method returns an list of expansions found in the template.  Currently,
these are just coderefs.  In the future, they will be more interesting.

=cut

sub expansions {
    my $self = shift;
    return grep { ref } @{ $self->{studied} };
}

=head2 process( \%vars )

Given a list of key-value pairs or an array ref of values (for
positional substitution), it will URI escape the values and
substitute them in to the template. Returns a URI object.

=cut

sub process {
    my $self = shift;
    return URI->new( $self->process_to_string( @_ ) );
}

=head2 process_to_string( \%vars )

Processes input like the C<process> method, but doesn't inflate the result to a
URI object.

=cut

sub process_to_string {
    my $self = shift;
    my $arg  = @_ == 1 ? $_[0] : { @_ };

    my %data;
    for my $key (keys %$arg) {
      $data{ $key } = ref $arg->{$key}
                    ? [ map { uri_escape_utf8(NFKC($_)) } @{ $arg->{$key} } ]
                    : uri_escape_utf8(NFKC($arg->{$key}));
    }

    my $str = '';

    for my $hunk (@{ $self->{studied} }) {
        if (! ref $hunk) { $str .= $hunk; next; }

        $str .= $hunk->(\%data);
    }

    return $str;
}

=head1 AUTHOR

Brian Cassidy E<lt>bricas@cpan.orgE<gt>

Ricardo SIGNES E<lt>rjbs@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2007-2009 by Brian Cassidy

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

1;
