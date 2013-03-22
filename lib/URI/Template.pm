package URI::Template;

use strict;
use warnings;

our $VERSION = '0.17';

use URI;
use URI::Escape        ();
use Unicode::Normalize ();
use overload '""' => \&template;

my $RESERVED = q(:/?#\[\]\@!\$\&'\(\)\*\+,;=);
my %TOSTRING = (
    ''  => \&_tostring,
    '+' => \&_tostring,
    '#' => \&_tostring,
    ';' => \&_tostring_semi,
    '?' => \&_tostring_query,
    '&' => \&_tostring_query,
    '/' => \&_tostring_path,
    '.' => \&_tostring_path,
);

sub new {
    my $class = shift;
    my $templ = shift || die 'No template provided';
    my $self  = bless { template => $templ, _vars => {} } => $class;

    $self->_study;

    return $self;
}

sub _quote {
    my ( $val, $safe ) = @_;
    $safe ||= '';

    # try to mirror python's urllib quote
    my $unsafe = '^A-Za-z0-9\-\._' . $safe;
    return URI::Escape::uri_escape_utf8( Unicode::Normalize::NFKC( $val ),
        $unsafe );
}

sub _tostring {
    my ( $var, $value, $exp ) = @_;
    my $safe = $exp->{ safe };

    if ( ref $value eq 'ARRAY' ) {
        return join( ',', map { _quote( $_, $safe ) } @$value );
    }
    elsif ( ref $value eq 'HASH' ) {
        return join(
            ',',
            map {
                _quote( $_, $safe )
                    . ( $var->{ explode } ? '=' : ',' )
                    . _quote( $value->{ $_ }, $safe )
                } sort keys %$value
        );
    }
    elsif ( defined $value ) {
        return _quote(
            substr( $value, 0, $var->{ prefix } || length( $value ) ),
            $safe );
    }

    return;
}

sub _tostring_semi {
    my ( $var, $value, $exp ) = @_;
    my $safe = $exp->{ safe };
    my $join = $exp->{ op };
    $join = '&' if $exp->{ op } eq '?';

    if ( ref $value eq 'ARRAY' ) {
        if ( $var->{ explode } ) {
            return join( $join,
                map { $var->{ name } . '=' . _quote( $_, $safe ) } @$value );
        }
        else {
            return $var->{ name } . '='
                . join( ',', map { _quote( $_, $safe ) } @$value );
        }
    }
    elsif ( ref $value eq 'HASH' ) {
        if ( $var->{ explode } ) {
            return join(
                $join,
                map {
                    _quote( $_, $safe ) . '='
                        . _quote( $value->{ $_ }, $safe )
                    } sort keys %$value
            );
        }
        else {
            return $var->{ name } . '=' . join(
                ',',
                map {
                    _quote( $_, $safe ) . ','
                        . _quote( $value->{ $_ }, $safe )
                    } sort keys %$value
            );
        }
    }
    elsif ( defined $value ) {
        return $var->{ name } unless length( $value );
        return
            $var->{ name } . '='
            . _quote(
            substr( $value, 0, $var->{ prefix } || length( $value ) ),
            $safe );
    }

    return;
}

sub _tostring_query {
    my ( $var, $value, $exp ) = @_;
    my $safe = $exp->{ safe };
    my $join = $exp->{ op };
    $join = '&' if $exp->{ op } =~ /[?&]/;

    if ( ref $value eq 'ARRAY' ) {
        if( !@$value ) {
            return if $var->{ explode };
            return $var->{ name } . '=';
        }
        if ( $var->{ explode } ) {
            return join( $join,
                map { $var->{ name } . '=' . _quote( $_, $safe ) } @$value );
        }
        else {
            return $var->{ name } . '='
                . join( ',', map { _quote( $_, $safe ) } @$value );
        }
    }
    elsif ( ref $value eq 'HASH' ) {
        if( !keys %$value ) {
            return if $var->{ explode };
            return $var->{ name } . '=';
        }
        if ( $var->{ explode } ) {
            return join(
                $join,
                map {
                    _quote( $_, $safe ) . '='
                        . _quote( $value->{ $_ }, $safe )
                    } sort keys %$value
            );
        }
        else {
            return $var->{ name } . '=' . join(
                ',',
                map {
                    _quote( $_, $safe ) . ','
                        . _quote( $value->{ $_ }, $safe )
                    } sort keys %$value
            );
        }
    }
    elsif ( defined $value ) {
        return $var->{ name } . '=' unless length( $value );
        return
            $var->{ name } . '='
            . _quote(
            substr( $value, 0, $var->{ prefix } || length( $value ) ),
            $safe );
    }
}

sub _tostring_path {
    my ( $var, $value, $exp ) = @_;
    my $safe = $exp->{ safe };
    my $join = $exp->{ op };

    if ( ref $value eq 'ARRAY' ) {
        return unless @$value;
        return join(
            ( $var->{ explode } ? $join : ',' ),
            map { _quote( $_, $safe ) } @$value
        );
    }
    elsif ( ref $value eq 'HASH' ) {
        return join(
            ( $var->{ explode } ? $join : ',' ),
            map {
                _quote( $_, $safe )
                    . ( $var->{ explode } ? '=' : ',' )
                    . _quote( $value->{ $_ }, $safe )
                } sort keys %$value
        );
    }
    elsif ( defined $value ) {
        return _quote(
            substr( $value, 0, $var->{ prefix } || length( $value ) ),
            $safe );
    }

    return;
}

sub _study {
    my ( $self ) = @_;
    my @hunks = grep { defined && length } split /(\{.+?\})/, $self->template;
    for ( @hunks ) {
        next unless /^\{(.+?)\}$/;
        $_ = $self->_compile_expansion( $1 );
    }
    $self->{ studied } = \@hunks;
}

sub _compile_expansion {
    my ( $self, $str ) = @_;

    my %exp = ( op => '', vars => [], str => $str );
    if ( $str =~ /^([+#.\/;?&|!\@])(.+)/ ) {
        $exp{ op }  = $1;
        $exp{ str } = $2;
    }

    $exp{ safe } = $RESERVED if $exp{ op } =~ m{[+#]};

    for my $varspec ( split( ',', delete $exp{ str } ) ) {
        my %var = ( name => $varspec );
        if ( $varspec =~ /=/ ) {
            @var{ 'name', 'default' } = split( /=/, $varspec, 2 );
        }
        if ( $var{ name } =~ s{\*$}{} ) {
            $var{ explode } = 1;
        }
        elsif ( $var{ name } =~ /:/ ) {
            @var{ 'name', 'prefix' } = split( /:/, $var{ name }, 2 );
            if ( $var{ prefix } =~ m{[^0-9]} ) {
                die 'Non-numeric prefix specified';
            }
        }

        # remove "optional" flag (for opensearch compatibility)
        $var{ name } =~ s{\?$}{};
        $self->{ _vars }->{ $var{ name } }++;

        push @{ $exp{ vars } }, \%var;
    }

    my $join  = $exp{ op };
    my $start = $exp{ op };

    if ( $exp{ op } eq '+' ) {
        $start = '';
        $join  = ',';
    }
    elsif ( $exp{ op } eq '#' ) {
        $join = ',';
    }
    elsif ( $exp{ op } eq '?' ) {
        $join = '&';
    }
    elsif ( $exp{ op } eq '&' ) {
        $join = '&';
    }
    elsif ( $exp{ op } eq '' ) {
        $join = ',';
    }

    if ( !exists $TOSTRING{ $exp{ op } } ) {
        die 'Invalid operation "' . $exp{ op } . '"';
    }

    return sub {
        my $variables = shift;

        my @return;
        for my $var ( @{ $exp{ vars } } ) {
            my $value;
            if ( exists $variables->{ $var->{ name } } ) {
                $value = $variables->{ $var->{ name } };
            }
            $value = $var->{ default } if !defined $value;

            next unless defined $value;

            my $expand = $TOSTRING{ $exp{ op } }->( $var, $value, \%exp );

            push @return, $expand if defined $expand;
        }

        return $start . join( $join, @return ) if @return;
        return '';
    };
}

sub template {
    return $_[ 0 ]->{ template };
}

sub variables {
    return keys %{ $_[ 0 ]->{ _vars } };
}

sub expansions {
    my $self = shift;
    return grep { ref } @{ $self->{ studied } };
}

sub process {
    my $self = shift;
    return URI->new( $self->process_to_string( @_ ) );
}

sub process_to_string {
    my $self = shift;
    my $arg  = @_ == 1 ? $_[ 0 ] : { @_ };
    my $str  = '';

    for my $hunk ( @{ $self->{ studied } } ) {
        if ( !ref $hunk ) { $str .= $hunk; next; }

        $str .= $hunk->( $arg );
    }

    return $str;
}

1;

__END__

=head1 NAME

URI::Template - Object for handling URI templates (RFC 6570)

=head1 SYNOPSIS

    use URI::Template;
    my $template = URI::Template->new( 'http://example.com/{x}' );
    my $uri      = $template->process( x => 'y' );
    # uri is a URI object with value 'http://example.com/y'

=head1 DESCRIPTION

This module provides a wrapper around URI templates as described in RFC 6570: 
L<< http://tools.ietf.org/html/rfc6570 >>.

=head1 INSTALLATION

    perl Makefile.PL
    make
    make test
    make install

=head1 METHODS

=head2 new( $template )

Creates a new L<URI::Template> instance with the template passed in
as the first parameter.

=head2 template

This method returns the original template string.

=head2 variables

Returns an array of unique variable names found in the template. NB: they are returned in random order.

=head2 expansions

This method returns an list of expansions found in the template.  Currently,
these are just coderefs.  In the future, they will be more interesting.

=head2 process( \%vars )

Given a list of key-value pairs or an array ref of values (for
positional substitution), it will URI escape the values and
substitute them in to the template. Returns a URI object.

=head2 process_to_string( \%vars )

Processes input like the C<process> method, but doesn't inflate the result to a
URI object.

=head1 AUTHORS

=over 4

=item * Brian Cassidy E<lt>bricas@cpan.orgE<gt>

=item * Ricardo SIGNES E<lt>rjbs@cpan.orgE<gt>

=back

=head1 COPYRIGHT AND LICENSE

Copyright 2007-2013 by Brian Cassidy

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
