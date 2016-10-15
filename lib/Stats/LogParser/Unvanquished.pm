package Stats::LogParser::Unvanquished;

use strict;
use warnings;
use base qw/Stats::LogParser/;

use Log::Log4perl qw/:easy/;
my $log = Log::Log4perl->get_logger("Stats::LogParser");

use Stats::DB::Weapon;
use Stats::DB::GameStatusEvent;

sub new {
    my ($class,%params) = @_;
    my $self = $class->SUPER::new(sub { initializeServer($_[0]); },%params);
    bless($self,$class);
}

sub handleRealTime {
    my ($self,%fields) = @_;
    $self->SUPER::handleRealTime(%fields);
    # TODO: Could start a parallel import here
}

sub handleShutdownGame {
    my ($self,%fields) = @_;
    # TODO: Hardcoded file path for now....
    my $filename = $self->sourcePath;
    $filename =~ s|^(.+)/(.+?)$|$1/stats/gameplay/|;
    $filename .= $self->{game}->{realtime}->strftime('%Y%m%d_%H%M%S_').$self->{game}->{map}.'.log';
    if (open FI,'<',$filename) {
	eval {
	    while(my $line = <FI>) {
		chomp($line);
		$self->unvParseLine($line);
	    }
	    close FI;
	};
	if ($@) {
            $self->log->warn("Error parsing game log: $filename");
	}
    } else { $self->log->warn("Failed to open game log: $filename"); }
    $self->SUPER::handleShutdownGame(%fields);
}

sub unvHandleVersion {
    my ($self,%fields) = @_;
}

sub unvHandleVariable {
    my ($self,%fields)= @_;
}

sub unvParseT {
    my ($self,$value) = @_;
    if ($value =~ /^(?<s>\d+)$/) {
        return DateTime::Duration->new(seconds => $+{s});
    } else {
        return undef;
    }
}

sub unvParseTRelative {
    my ($self,$value) = @_;
    return $self->db_game->start->clone->add_duration($self->unvParseT($value));
}

sub unvHandleGameStatusEvent {
    my ($self,%fields) = @_;
    # print "STATUS: ".join(" ",map { $_ = $fields{$_} } keys(%fields))."\n";
    my $status = Stats::DB::GameStatusEvent->new(
	game_id => $self->db_game->id,
	time    => $self->unvParseTRelative($fields{time}),
	num_a   => $fields{anum},
	num_h   => $fields{hnum},
	momentum_a => $fields{amom},
	momentum_h => $fields{hmom},
	mine_rate  => $fields{lmr},
	mine_efficiency_a => $fields{ame},
	mine_efficiency_h => $fields{hme},
	bp_a => $fields{abp},
	bp_h => $fields{hbp},
	building_value_a => $fields{abrv},
	building_value_h => $fields{hbrv},
	credits_a => $fields{acre},
	credits_h => $fields{hcre},
	team_value_a => $fields{aval},
	team_value_h => $fields{hval}
    );
    $status->save;
}

sub unvParseLine {
    my ($self,$line) = @_;
    if ($line =~ /^\s*#\s+Version:\s*(?<version>.+?)\s*$/) {
	# # Version: 0.45
	$self->unvHandleVersion(%+);
    } elsif ($line =~ /^\s*#\s+(?<variable>g_\S+)\s*:\s*(.+?)\s*$/) {
	# # g_momentumHalfLife:           5
	$self->unvHandleVariable(%+);
    } elsif ($line =~ /^\s*\#.*$/) {
	#... -- any comment
    } elsif ($line =~ /^\s*(?<time>\d+)\s+(?<anum>\d+)\s+(?<hnum>\d+)\s+(?<amom>-?\d+)\s+(?<hmom>-?\d+)\s+(?<lmr>-?\d+(?:\.\d+)?)\s+(?<ame>-?\d+)\s+(?<hme>-?\d+)\s+(?<abp>-?\d+)\s+(?<hbp>-?\d+)\s+(?<abrv>-?\d+)\s+(?<hbrv>-?\d+)\s+(?<acre>-?\d+)\s+(?<hcre>-?\d+)\s+(?<aval>-?\d+)\s+(?<hval>-?\d+)\s*$/) {
	# 390  4  4   89   85  6.4    2    0   11    3  160  110  322  388  300  400
	$self->unvHandleGameStatusEvent(%+);
    } else {
	print "Unrecognized line: $line\n";
    }
}

sub initializeServer {
    my ($server) = @_;
    my %weapons = (
	MOD_ABUILDER_CLAW     => 'Granger Nibble [granger]',
	MOD_ASPAWN            => 'Exploding Alien Building',
	MOD_ATUBE             => 'Acid Tube [acidtube]',
	MOD_BLASTER           => 'Blaster [blaster]',
	MOD_BURN              => 'Burnt by flames',
	MOD_CHAINGUN          => 'Chaingun [chaingun]',
	MOD_CONSTRUCT         => 'Construction',
	MOD_CRUSH             => 'Crushed',
	MOD_DECONSTRUCT       => 'Deconstruction',
	MOD_FALLING           => 'Falling',
	MOD_FIREBOMB          => 'Fire Bomb',
	MOD_FLAMER            => 'Flamer [flamer]',
	MOD_FLAMER_SPLASH     => 'Flamer Splash [flamer]',
	MOD_GRENADE           => 'Grenade [grenade]',
	MOD_HSPAWN            => 'Exploding Human Building',
	MOD_LASGUN            => 'Lasgun [lasgun]',
	MOD_LCANNON           => 'Lucifer Cannon [lcannon]',
	MOD_LCANNON_SPLASH    => 'Irradiation [lcannon]',
	MOD_LEVEL0_BITE       => 'Dretch Bite [dretch]',
	MOD_LEVEL1_CLAW       => 'Mantis Claw [basilisk]',
	MOD_LEVEL2_CLAW       => 'Marauder Claw [marauder]',
	MOD_LEVEL2_ZAP        => 'Adv. Marauder Zap [advmarauder]',
	MOD_LEVEL3_BOUNCEBALL => 'Adv. Dragoon Barb [advdragoon]',
	MOD_LEVEL3_CLAW       => 'Dragoon Chomp [dragoon]',
	MOD_LEVEL3_POUNCE     => 'Dragoon Pounce [dragoon]',
	MOD_LEVEL4_CLAW       => 'Tyrant Claw [tyrant]',
	MOD_LEVEL4_TRAMPLE    => 'Tyrant Trample [tyrant]',
	MOD_MACHINEGUN        => 'Machinegun [rifle]',
	MOD_MDRIVER           => 'Mass Driver [mdriver]',
	MOD_MGTURRET          => 'Machinegun Turret [turret]',
	MOD_NOCREEP           => 'No Creep',
	MOD_OVERMIND          => 'Overmind [overmind]',
	MOD_PAINSAW           => 'Pain Saw [painsaw]',
	MOD_POISON            => 'Poison [booster]',
	MOD_PRIFLE            => 'Pulse Rifle [prifle]',
	MOD_REACTOR           => 'Reactor [reactor]',
	MOD_ROCKETPOD         => 'Rocket Pod',
	MOD_SHOTGUN           => 'Shotgun [shotgun]',
	MOD_SLOWBLOB          => 'Adv. Granger Spit [granger]',
	MOD_SPIKER            => 'Spiker',
	MOD_SUICIDE           => 'Suicide',
	MOD_SWARM             => 'Hive Swarm [hive]',
	MOD_TELEFRAG          => 'Telefragged',
	MOD_TRIGGER_HURT      => 'Trigger Hurt',
	MOD_WEIGHT_A          => 'Crushed by an alien',
	MOD_WEIGHT_H          => 'Crushed by a human',
    );
    foreach my $mod (sort { $a cmp $b } keys(%weapons)) {
	my $weapon = Stats::DB::Weapon->new(server_id => $server->id,name => $mod);
	$weapon->load(speculative => 1);
	$weapon->displayname($weapons{$mod});
	$weapon->save;
    }
}

1;
