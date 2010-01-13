#$Id$

package Lab::Instrument::IPS12010new;

use strict;
use Lab::VISA;
use Lab::Instrument;
use Lab::Instrument::MagnetSupply;

our $VERSION = sprintf("0.%04d", q$Revision$ =~ / (\d+) /);

our @ISA=('Lab::Instrument::MagnetSupply');

my $default_config={
    use_persistentmode          => 0,
    can_reverse                 => 1,
    can_use_negative_current    => 1,
};

sub new {
    my $proto = shift;
    my @args=@_;
    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new($default_config,@args);
    bless ($self, $class);

    $self->{vi}=new Lab::Instrument(@args);
    
    my $xstatus=Lab::VISA::viSetAttribute($self->{vi}->{instr}, $Lab::VISA::VI_ATTR_TERMCHAR, 0xD);
    if ($xstatus != $Lab::VISA::VI_SUCCESS) { die "Error while setting read termination character: $xstatus";}

    $xstatus=Lab::VISA::viSetAttribute($self->{vi}->{instr}, $Lab::VISA::VI_ATTR_TERMCHAR_EN, $Lab::VISA::VI_TRUE);
    if ($xstatus != $Lab::VISA::VI_SUCCESS) { die "Error while enabling read termination character: $xstatus";}

#    $self->{vi}->Clear();
   
    $self->ips_set_communications_protocol(4);
 
    $self->ips_set_control(3);

    return $self
}


sub ips_set_control {
# 0 Local & Locked
# 1 Remote & Locked
# 2 Local & Unlocked
# 3 Remote & Unlocked
    my $self=shift;
    my $mode=shift;
    $self->{vi}->Query("C$mode\r");
}

sub ips_set_communications_protocol {
# 0 "Normal" (default)
# 2 Sends <LF> after each <CR>
# 4 Extended Resolution
# 6 Extended Resolution. Sends <LF> after each <CR>.
    my $self=shift;
    my $mode=shift;
    $self->{vi}->Write("Q$mode\r");
}

sub ips_read_parameter {
# 0 Demand current (output current)     amp
# 1 Measured power supply voltage       volt
# 2 Measured magnet current             amp
# 3 -
# 4 -
# 5 Set point (target current)          amp
# 6 Current sweep rate                  amp/min
# 7 Demand field (output field)         tesla
# 8 Set point (target field)            tesla
# 9 Field sweep rate                    tesla/minute
#10 - 14 -
#15 Software voltage limit              volt
#16 Persistent magnet current           amp
#17 Trip current                        amp
#18 Persistent magnet field             tesla
#19 Trip field                          tesla
#20 Switch heater current               milliamp
#21 Safe current limit, most negative   amp
#22 Safe current limit, most positive   amp
#23 Lead resistance                     milliohm
#24 Magnet inductance                   henry
    my $self=shift;
    my $parameter=shift;
    #$self->{vi}->Clear();
    my $result=$self->{vi}->Query("R$parameter\r");
    chomp $result;
    $result =~ s/^R//;
    $result =~ s/\r//g;
    return $result;
}

# Hier spezialisierte read-Methoden einf�hren (read_set_point())

#sub ips_get_status {  #freezes magnet
#	my $self=shift;
#	my $result=$self->{vi}->Query("X\r");
#	return $result
#}

sub ips_set_activity {
# 0 Hold
# 1 To Set Point
# 2 To Zero
# 4 Clamp (clamp the power supply output)
    my $self=shift;
    my $mode=shift;
    $self->{vi}->Query("A$mode\r");
}   

sub ips_set_switch_heater {
# 0 Heater Off                  (close switch)
# 1 Heater On if PSU=Magnet     (open switch)
#  (only perform operation
#   if recorded magnet current==present power supply output current)
# 2 Heater On, no Checks        (open switch)
    my $self=shift;
    my $mode=shift;
    $self->{vi}->Query("H$mode\r");
}

sub ips_set_target_current {
    my $self=shift;
    my $current=shift;
    $self->{vi}->Query("I$current\r");
}

sub ips_set_target_field {
    my $self=shift;
    my $field=shift;
    $self->{vi}->Query("J$field\r");
}

sub ips_set_mode {
#       Display     Magnet Sweep
# 0     Amps        Fast
# 1     Tesla       Fast
# 4     Amps        Slow
# 5     Tesla       Slow
# 8     Amps        Unaffected
# 9     Tesla       Unaffected
    my $self=shift;
    my $mode=shift;
    $self->{vi}->Query("M$mode\r");
}

sub ips_set_polarity {
# 0 No action
# 1 Set positive current
# 2 Set negative current
# 3 Swap polarity
    my $self=shift;
    my $mode=shift;
    $self->{vi}->Query("P$mode\r");
}

sub ips_set_current_sweep_rate {
# amps/min
    my $self=shift;
    my $rate=shift;
    $self->{vi}->Query("S$rate\r");
}

sub ips_set_field_sweep_rate {
# amps/min
    my $self=shift;
    my $rate=shift;
    $self->{vi}->Query("T$rate\r");
}


# now comes the interface



sub _get_current {
    my $self=shift;
    my $res=$self->ips_read_parameter(0);
    return($res);
}

sub _set_sweep_target_current {
	my $self=shift;
	my $current=shift;
	$self->ips_set_target_current($current);
}

sub _set_hold {
	my $self=shift;
	my $hold=shift;
	
	if ($hold) {
		$self->ips_set_activity(0);
	} else {
		$self->ips_set_activity(1);
	};
}

sub _get_hold {
    die '_get_hold not implemented for this instrument';
}

sub _set_sweeprate {
	my $self=shift;
	my $rate=shift;
	$rate=$rate*60;
	#print "settin sweep rate to $rate\n";
	#$self->ips_set_current_sweep_rate($rate);
	return($self->_get_sweeprate());
}

sub _get_sweeprate {
	my $self=shift;
	return(($self->ips_read_parameter(6))/60);
}

#sub _active_sweep { doesnt work
#	my $self=shift;
#	my $status=$self->ips_get_status();
#	my $mode=substr($status,11,1);
#	if ($mode!=0){
#	    return(1); #sweeping 1 ,2 ,3
#	}else{ 
#	    return(0) # 0 At Rest 
#	}
#}


sub _init_magnet {
	my $self=shift;#
	print "Set Communication Protocol to Extended Resolution...";
	#$self->ips_set_activity (0);
	$self->ips_set_communications_protocol(4);
	print "done!\n";
	print "Set Magnet to Remote and Unlocked...";
	$self->ips_set_control (3);
	print "done!\n";
	
	print "Unclamp Magnet and Set to Hold...";
	$self->ips_set_activity(0);
	print "done!\n";
	
	# Don't use Heater in Init since the previous user could have used persitent mode and could turn off Power Supply!
	#print "Switch On Heater\n";
        #$self->ips_set_switch_heater(1);
	#print "done!\n";
	
	return(($self->ips_read_parameter(6))/60);
}


1;

