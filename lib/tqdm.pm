package tqdm;

# DATE
# VERSION

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(tqdm tqdm_scalar);

$|++;

sub tqdm {
    tie my @ary, "Tie::tqdm::Array";
    push @ary, @_;
    return @ary;
}

sub tqdm_scalar {
    tie my @ary, "Tie::tqdm::Scalar";
    return @ary;
}

package
    Tie::tqdm::Base;

use Time::HiRes qw(time);

sub _ncols {
    my $class = shift;

    my $ncols;
    if ($ENV{COLUMNS}) {
        $ncols = $ENV{COLUMNS};
    } elsif (eval { require Term::Size; 1 }) {
        ($ncols, undef) = Term::Size::chars();
    } else {
        $ncols = 80;
    }
    $^O =~ /Win/ ? $ncols-1 : $ncols;
}

sub _update {
    my $self = shift;
    my $idx  = shift;

    my $time = time();
    return if defined $self->{last_update_time} &&
        ($time - $self->{last_update_time} < 0.1);

    print "Updating $time vs $self->{last_update_time}\n";

    # clean previous bar
    print STDERR (" " x length $self->{bar}), ("\b" x length $self->{bar})
        if $self->{bar};

    # draw new bar
    $self->{bar} = $self->_bar($idx, $time);
    print STDERR $self->{bar}, ("\b" x length $self->{bar});

    $self->{last_update_time} = $time;
}

sub _sec2dur {
    my $self = shift;
    my $sec  = shift;

    my $hours = int($sec/3600); $sec -= $hours*3600;
    my $mins  = int($sec/60);   $sec -= $mins *60;
    if ($hours >= 0) {
        sprintf "%d:%02d:%02d", $hours, $mins, $sec;
    } else {
        sprintf "%02d:%02d", $mins, $sec;
    }
}

package
    Tie::tqdm::Scalar;

our @ISA = qw(Tie::tqdm::Base);

sub TIESCALAR {
    my $class = shift;
    bless {
        start_time => time(),
        ncols => $class->_ncols,
        num_sets => 0,
        last_update_time => undef,
        interactive => (-t STDOUT),
    }, $class;
}

package
    Tie::tqdm::Array;

our @ISA = qw(Tie::tqdm::Base);

sub TIEARRAY {
    my $class = shift;
    bless {
        array => [],
        start_time => time(),
        ncols => $class->_ncols,
        last_fetched_index => -1,
        last_update_time => undef,
        interactive => (-t STDOUT),
    }, $class;
}

sub FETCH {
    my $self = shift;
    my $idx  = shift;

    #print "D:FETCH($idx)\n";
    if ($self->{interactive}) {
        if ($idx != $self->{last_fetched_index}) {
            $self->_update($idx);
            $self->{last_fetched_index} = $idx;
        }
    }
    $self->{array}[$idx];
}

sub FETCHSIZE {
    my $self = shift;
    scalar @{$self->{array}};
}

sub PUSH {
    my $self = shift;
    push @{$self->{array}}, @_;
}

sub DESTROY {
    my $self = shift;

    if ($self->{interactive}) {
        print STDERR $self->_bar($#{$self->{array}}, time()), "\n";
    } else {
        print STDERR "\n" if $self->{last_update_time};
    }
}

sub _bar {
    my ($self, $idx, $time) = @_;

    my $size = @{ $self->{array} } || 1;
    my $elapsed = $time - $self->{start_time};
    my $remain  = ($size-$idx-1)/($idx+1) * $elapsed;
    my $part1 = sprintf "%3d%%|", ($idx+1)/$size*100;
    my $part3 = sprintf "|%d/%d [%s<%s, %.2git/s]",
        $idx+1, $size,
        $self->_sec2dur($elapsed), $self->_sec2dur($remain),
        $elapsed ? ($idx+1)/$elapsed : 0;
}

1;
# ABSTRACT: Fast, extensible progress meter

=for Pod::Coverage ^([A-Z].+)$

=head1 SYNOPSIS


=head1 DESCRIPTION

B<VERY EARLY RELEASE. SOME THINGS ARE STILL MISSING.>

This module is a somewhat loose port from a Python package of the same name [1].

Keywords: progress meter, progress bar, progress indicator, CLI.


=head1 FUNCTIONS

=head2 tqdm

Usage:

 tqdm(LIST)

Will return a tied array.

=head2 tqdm_scalar

Usage:

 tqdm_scalar()

Will return a tied scalar.


=head1 SEE ALSO

[1] L<https://pypi.org/project/tqdm/>
