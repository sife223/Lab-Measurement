package Lab::Moose::Instrument::SpectrumAnalyzer;

#ABSTRACT: Role of Generic Spectrum Analyzer for Lab::Moose::Instrument

use 5.010;

use PDL::Core qw/pdl cat nelem/;

use Carp;
use Moose::Role;
use MooseX::Params::Validate;
use Lab::Moose::Instrument qw/
    timeout_param
    precision_param
    validated_getter
    validated_setter
    validated_channel_getter
    validated_channel_setter
    /;
#use Lab::Moose::Instrument::Cache;

requires qw(
    sense_frequency_start_query 
    sense_frequency_start
    sense_frequency_stop_query
    sense_frequency_stop
    sense_sweep_points_query
    sense_sweep_points
    sense_sweep_count_query
    sense_sweep_count
    sense_bandwidth_resolution_query
    sense_bandwidth_resolution
    sense_bandwidth_video_query
    sense_bandwidth_video
    sense_sweep_time_query
    sense_sweep_time
    display_window_trace_y_scale_rlevel_query
    display_window_trace_y_scale_rlevel
    unit_power_query
    unit_power
    get_traceY
);

=pod

=encoding UTF-8

=head1 NAME

Lab::Moose::Instrument::SpectrumAnalyzer - Role of Generic Spectrum Analyzer

=head1 DESCRIPTION

Basic commands to make functional basic spectrum analyzer

=head1 METHODS

Driver assuming this role must implements the following high-level method:

=head2 C<get_traceXY>

 $data = $sa->traceXY(timeout => 10, trace => 2);

Perform a single sweep and return the resulting spectrum as a 2D PDL:

 [
  [freq1,  freq2,  freq3,  ...,  freqN],
  [power1, power2, power3, ..., powerN],
 ]

I.e. the first dimension runs over the sweep points.

This method accepts a hash with the following options:

=over

=item B<timeout>

timeout for the sweep operation. If this is not given, use the connection's
default timeout.

=item B<trace>

number of the trace (1..3). Defaults to 1.

=back

=head2 C<get_traceY>

 $data = $sa->traceY(timeout => 10, trace => 2);

Return Y points of a given trace in a 1D PDL:

=head2 C<get_traceX>

 $data = $sa->traceX(timeout => 10);

Return X points of a trace in a 1D PDL:

=head1 Hardware capabilities and presets attributes

Not all devices implemented full set of SCPI commands.
With following we can mark what is available

=head2 C<capable_to_query_number_of_X_points_in_hardware>

Can hardware report the number of points in a sweep. I.e. can it respont
to analog of C<[:SENSe]:SWEep:POINts?> command.

Default is 1, i.e true.

=head2 C<capable_to_set_number_of_X_points_in_hardware>

Can hardware set the number of points in a sweep. I.e. can it respont
to analog of C<[:SENSe]:SWEep:POINts> command.

Default is 1, i.e true.

=head2 C<hardwired_number_of_X_points>

Some hardware has fixed/unchangeable number of points in the sweep.
So we can set it here to simplify the logic of some commands.

This is not set by default.
Use C<has_hardwired_number_of_X_points> to check for its availability.

=cut

has 'capable_to_query_number_of_X_points_in_hardware' => (
	is => 'rw',
	isa => 'Bool',
	required => 1,
	default => 1,
);

has 'capable_to_set_number_of_X_points_in_hardware' => (
	is => 'rw',
	isa => 'Bool',
	required => 1,
	default => 1,
);

has 'hardwired_number_of_X_points' => (
	is => 'rw',
	isa => 'Int',
	predicate => 'has_hardwired_number_of_X_points',
);

sub sense_sweep_points_from_traceY_query {
    # quite a lot of hardware does not report it, so we deduce it from Y-trace data
    my ( $self, $channel, %args ) = validated_channel_getter( \@_ );
    return nelem($self->get_traceY(%args));
}

sub get_Xpoints_number {
    my ( $self, $channel, %args ) = validated_channel_getter( \@_ );
    if ( $self->has_hardwired_number_of_X_points) {
       carp("using hardwired number of points: ".$self->hardwired_number_of_X_points."\n");
       return $self->cached_sense_sweep_points( $self->hardwired_number_of_X_points );
    }
    if ( $self->capable_to_query_number_of_X_points_in_hardware ) {
        carp("using hardware capabilities to detect number of points in a sweep\n");
	return $self->sense_sweep_points_query(%args);
    }
    carp("trying heuristic to detect number of points in a sweep\n");
    return $self->cached_sense_sweep_points( $self->sense_sweep_points_from_traceY_query(%args) );
};

sub linspaced_array {
    my ( $start, $stop, $num_points ) = @_;

    my $num_intervals = $num_points - 1;

    if ( $num_intervals == 0 ) {
        # Return a single point.
        return [$start];
    }

    my @result;

    for my $i ( 0 .. $num_intervals ) {
        my $f = $start + ( $stop - $start ) * ( $i / $num_intervals );
        push @result, $f;
    }

    return \@result;
}

sub get_traceX {
    my ( $self, %args ) = @_;
    my $trace = delete $args{trace};

    my $start      = $self->cached_sense_frequency_start();
    my $stop       = $self->cached_sense_frequency_stop();
    my $num_points = $self->get_Xpoints_number();
    my $traceX = pdl linspaced_array( $start, $stop, $num_points );
    return $traceX;
}

sub get_traceXY {
    my ( $self, %args ) = @_;

    my $traceY = $self->get_traceY( %args );
    # number of sweep points is known from the length of traceY
    # so we set it to avoid extra call to get_traceY 
    if ( !$self->capable_to_query_number_of_X_points_in_hardware ) {
	    #carp("setting cache with sweep number of points via heuristic");
	    $self->cached_sense_sweep_points( nelem($traceY) );
    }
    my $traceX = $self->get_traceX( %args );

    return cat( $traceX, $traceY );
}


1;

