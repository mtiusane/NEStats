package Stats::LogParser;

use strict;
use v5.10;

use Stats::DB;
use Stats::DB::Server;
use Stats::DB::Game;
use Stats::DB::Map;
use Stats::DB::Player;
use Stats::DB::Session;
use Stats::DB::Weapon;
use Stats::DB::Building;
use Stats::DB::PlayerEvent;
use Stats::DB::BuildingEvent;
use Stats::DB::TeamEvent;
use Stats::DB::PlayerWeapon;
use Stats::DB::SessionWeapon;
use Stats::DB::GameWeapon;
use Stats::DB::PlayerMap;
use Stats::DB::Clan;
use Stats::DB::ClanEvent;
use Stats::DB::ClanMember;
use Stats::DB::GameClan;
use Stats::DB::GameClanMember;
use Stats::DB::Glicko2;
use Stats::DB::Glicko2Score;
use Stats::DB::TimeStamp;

use Glicko2::Player;

use DateTime;
use DateTime::Duration;

use List::Util qw/max pairs/;

use Log::Log4perl qw/:easy/;

use constant MIN_GLICKO2_TIME  => 3600;
use constant MIN_GLICKO2_GAMES => 10;
use constant MAX_SLOTS => 1024;

sub new {
    my ($class,$initializer,%params) = @_;
    die "Server ip (server_ip) and name (server_name) must be provided." unless (defined($params{server_name}) && defined($params{server_ip}));
    my $self = {
	log     => Log::Log4perl->get_logger("Stats::LogParser"),
        game    => undef,
        db_game => undef,
	last_glicko2 => undef,
        slots => [ map { undef } (1..MAX_SLOTS) ],
        guids => {
            0 => +{
                name          => '<world>',
                simple_name   => '<world>',
                total_kills   => 0,
                total_deaths  => 0,
                authenticated => 1,
            }
        },
        cache => { },
        line  => undef,
	source_path => undef,
        # games => [ ],
	in_game => 0,
    };
    $self->{slots}->[MAX_SLOTS-1] = {
        connect       => DateTime->now,
        guid          => 0,
        name          => '<world>',
        simple_name   => '<world>',
        authenticated => 1,
    };
    $self->{db_server} = Stats::DB::Server->new(ip => $params{server_ip},name => $params{server_name},url => $params{server_url});
    unless ($self->{db_server}->load(speculative => 1)) {
	# TODO: Load default values here
	$self->{db_server}->save;
    }
    # TODO: Not the prettiest way of implementing this but will have to do for now...
    $initializer->($self->{db_server});
    # my $db_world = $slots[1023]->{db_player} = Stats::DB::Player->new(server_id => $self->{db_server}->id,guid => '0',name => '<world>');
    # $db_world->load(speculative => 1) || $db_world->save;
    bless($self,$class);
}

sub log { $_[0]->{log} }
sub game { $_[0]->{game} }
sub slots { $_[0]->{slots} }
sub guids { $_[0]->{guids} }
# sub games { @{$_[0]->{games}} }
sub db_game { $_[0]->{db_game} }

sub loadCached {
    my ($self,$cacheName,$class,$initializer,$keys) = @_;
    my $cache = $self->{cache}->{$cacheName} //= { };
    my $cacheKey = join(' ',map { $_.'_'.$keys->{$_} } keys(%$keys));
    return $cache->{$cacheKey} if (defined $cache->{$cacheKey});
    my $result = $class->new(%$keys);
    unless ($result->load(speculative => 1)) {
        $initializer->($result) if (defined $initializer);
        $result->save;
    }
    return $cache->{$cacheKey} = $result;
}

sub dropCache {
    my ($self,$name) = @_;
    delete $self->{cache}->{$name};
}

sub loadBuilding {
    my ($self,$name) = @_;
    return $self->loadCached('buildings',qw/Stats::DB::Building/,undef,{
	server_id => $self->{db_server}->id,
	name      => $name
    });
}

sub loadWeapon {
    my ($self,$name) = @_;
    return $self->loadCached('weapons',qw/Stats::DB::Weapon/,sub { $_[0]->displayname($_[0]->name); },{
	server_id => $self->{db_server}->id,
	name      => $name,
    });
}

sub loadGameWeapon {
    my ($self,$name) = @_;
    return undef unless (defined $self->{game});
    return $self->loadCached('game_weapons',qw/Stats::DB::GameWeapon/,undef,{ weapon_id => $self->loadWeapon($name)->id, game_id => $self->{db_game}->id });
}

sub loadPlayerWeapon {
    my ($self,$player_id,$name) = @_;
    return $self->loadCached('player_weapons',qw/Stats::DB::PlayerWeapon/,undef,{ weapon_id => $self->loadWeapon($name)->id, player_id => $player_id });
}

sub loadSessionWeapon {
    my ($self,$session_id,$name) = @_;
    return $self->loadCached('session_weapons',qw/Stats::DB::SessionWeapon/,undef,{ weapon_id => $self->loadWeapon($name)->id, session_id => $session_id });
}

sub loadPlayer {
    my ($self,$id) = @_;
    return undef unless (defined $id);
    return $self->loadCached('players',qw/Stats::DB::Player/,undef,{ id => $id });
}

sub beginSession {
    my ($self,%params) = @_;
    my $result = Stats::DB::Session->new(
	game_id   => $params{game_id},
	player_id => $params{player_id},
	name      => $params{name},
	ip        => $params{ip},
	team      => $params{team},
	start     => $params{start}
    );
    $result->save;
    if (my $db_player = $self->loadPlayer($params{player_id})) {
	if ($params{team} =~ /^alien|humans$$/) {
	    $db_player->total_sessions($db_player->total_sessions+1);
	    $self->{game}->{db_players}->{$db_player->id} = $db_player;
	} elsif ($params{is_new}) { # 'spectator'
	    $db_player->total_rqs($db_player->total_rqs+1);
	}
	$db_player->save;
    }
    return $result;
}

sub endSession {
    my ($self,$session,$end) = @_;
    $session->end($end);
    $session->save;
    if ($session->team =~ /^human|alien$/) {
	if (my $player = $self->loadPlayer($session->player_id)) {
	    my $duration = $self->getDuration($end-$session->start);
	    $player->total_time($player->total_time+$duration);
	    if ($session->team eq 'human') {
		$player->total_rqs($player->total_rqs+1) if (!defined($self->{db_game}->end));
		$player->total_time_h($player->total_time_h+$duration);
	    } elsif ($session->team eq 'alien') {
		$player->total_rqs($player->total_rqs+1) if (!defined($self->{db_game}->end));
		$player->total_time_a($player->total_time_a+$duration);
	    }
	    $player->save;
	    my $playerMap = Stats::DB::PlayerMap->new(player_id => $player->id,map_id => $self->{db_game}->map_id);
	    $playerMap->load(speculative => 1);
	    $playerMap->total_time($playerMap->total_time+$duration);
	    # TODO: Might be useful to track total time for a and h in each map.
	    $playerMap->save();
	}
    }
}

sub handleInitGame {
    my ($self,%fields) = @_;
    $self->{game} = {
        start        => $self->parseTime($fields{time}),
        map          => $fields{mapname},
        parameters   => { map { $_ => $fields{$_} } grep { /^time|mapname$/ } keys(%fields) },
        players      => { },
        total_kills  => [ ],
        total_deaths => [ ],
        result       => 'Draw (voted / crashed)',
        score        => [ ],
	db_players   => { },
    };
}

sub handleRealTime {
    my ($self,%fields) = @_;
    return unless (defined $self->{game});
    $self->{game}->{realtime} = DateTime->new(time_zone => '+0000',%fields);
    $self->log->info(sprintf('Importing game: %s %s',$self->{game}->{map},$self->{game}->{realtime}));
    my $map = Stats::DB::Map->new(server_id => $self->{db_server}->id,name => $self->{game}->{map});
    $map->load(speculative => 1) || $map->save;
    # TODO: if ($self->{cache}->{total_players} > 0) -- perhaps at some point
    $map->total_loaded($map->total_loaded+1);
    $self->{cache}->{map} = $map;
    $self->{cache}->{total_players} = 0;
    $self->{db_game} = Stats::DB::Game->new(
        map_id      => $map->id,
        server_id   => $self->{db_server}->id,
        start       => $self->{game}->{realtime},
    );
    if ($self->{db_game}->load(speculative => 1)) {
        # Re-importing an existing game entry - remove all event data first
        deleteGameEntries($self->{db_game}->id);
    } else {
        $self->{db_game}->max_players(0);
        $self->{db_game}->save;
    }
}

sub handleShutdownGame {
    my ($self,%fields) = @_;
    return unless (defined $self->{game});
    foreach my $slot (0..63) {
        next unless defined $self->{slots}->[$slot];
	next if $self->{slots}->[$slot]->{disconnected};
        $self->handleClientDisconnect(time => $fields{time},guid => $self->{slots}->[$slot]->{guid},slot => $slot);
    }
    my $hadPlayers = $self->{db_game}->max_players > 0;
  
    foreach my $player (values %{$self->{cache}->{players}}) { $player->save; }
    foreach my $cache (qw/map players player_weapons session_weapons game_weapons/) { $self->dropCache($cache); }

    my $updateNeeded = $hadPlayers;
    $updateNeeded = 1 if ($self->updateGlicko2());

    undef $self->{game};
    undef $self->{db_game};

    $self->updateRankings() if ($updateNeeded);
}

sub handleSuddenDeath {
    my ($self,%fields) = @_;
    return unless (defined $self->{game});
    $self->{game}->{sd} = $self->parseTime($fields{time});
    $self->{db_game}->sd($self->{db_game}->start->clone->add_duration($self->{game}->{sd}));
    $self->{db_game}->save;
}

sub handleWeakSuddenDeath {
    my ($self,%fields) = @_;
    return unless (defined $self->{game});
    $self->{game}->{wsd} = $self->parseTime($fields{time});
    $self->{db_game}->wsd($self->{db_game}->start->clone->add_duration($self->{game}->{wsd}));
    $self->{db_game}->save;
}

sub handleClientConnect
{
    # TODO: Optional $fields{flags} handling added for unv, assumes bots never have guid and wont have a matching player record
    # TODO: Verify that bot players are handled correctly and no extra player records are created
    my ($self,%fields) = @_;
    return unless (defined $self->{game});
    unless ($fields{simplename}) {
	# TODO: (1.1): Not tested yet, 1.1 doesn't provide separate simplename field
	$fields{simplename} = $fields{name};
	$fields{simplename} =~ s/\^.//g;
    }
    my $db_player = ($fields{guid} !~ /^X+$/) ? Stats::DB::Player->new(server_id => $self->{db_server}->id,guid => $fields{guid}) : undef;
    if ($db_player) {
	unless ($db_player->load(speculative => 1)) {
	    $db_player->name($fields{simplename});
	    $db_player->displayname($fields{name});
	    $db_player->save;
	} elsif ($db_player->displayname ne $fields{name}) {
	    $db_player->displayname($fields{name});
	    $db_player->save;
	}
    }
    my ($name,$simplename) = ($fields{name},$fields{simplename});
    if ($fields{flags} !~ /^\s*$/) {
	$name       .= " $fields{flags}";
	$simplename .= " $fields{flags}";
    }
    my $db_session = $self->beginSession(
	game_id   => $self->{db_game}->id,
	player_id => (defined($db_player) ? $db_player->id : undef),
	name      => $name,
	ip        => $fields{ip},
	team      => 'spectator',
	start     => $self->parseTimeRelative($fields{time}),
	is_new    => 1
    );
    return unless (defined $self->{game});
    # my $event = Stats::DB::TeamEvent->new(
    #   time       => $self->parseTimeRelative($fields{time}),
    #   team       => 'spectator',
    #   session_id => $db_session->id
    # );
    # $event->save;
    $self->{slots}->[$fields{slot}] = {
        connect       => $self->parseTime($fields{time}),
        guid          => $fields{guid},
        name          => $name,
        simple_name   => $simplename,
        ip            => $fields{ip},
        authenticated => 0,
        db_session    => $db_session,
    };
    $self->{guids}->{$fields{guid}} //= {
        guid          => $fields{guid},
        name          => $name,
        simple_name   => $simplename,
        ip            => $fields{ip},
        authenticated => 0,
        total_kills   => 0,
        total_deaths  => 0,
        level         => 0,
    };
    $self->{game}->{players}->{$fields{guid}} //= +{
        guid         => $fields{guid},
        sessions     => [ ],
        kills        => { },
        deaths       => { },
        total_kills  => [ ],
        total_deaths => [ ],
    };
    push @{$self->{game}->{players}->{$fields{guid}}->{sessions}},$self->parseTime($fields{time}) if (defined $db_player);
    $self->{db_game}->max_players(max($self->{db_game}->max_players,++$self->{cache}->{total_players}));
    $self->{db_game}->save;
}

sub handleClientDisconnect {
    my ($self,%fields) = @_;
    return unless (defined $self->{game});
    my $time = $self->parseTime($fields{time});
    push @{$self->{game}->{players}->{$fields{guid}}->{sessions}},$time;
    my $db_session = $self->{slots}->[$fields{slot}]->{db_session};
    if (defined $db_session) {
        my $duration = $self->getDuration($time);
	$self->endSession($db_session,$self->parseTimeRelative($fields{time}));
    } else {
        $self->log->warn("ClientDisconnect(): No active db_session for slot $fields{slot} guid $fields{guid}");
    }
    # NOTE: Slot is *not* set to undef, instead marking as disconnected. This is done
    #       in order to correctly parse assist messages involving disconnected player
    $self->{slots}->[$fields{slot}]->{disconnected} = 1;
    --$self->{cache}->{total_players};
}

sub handleAdminAuth {
    my ($self,%fields) = @_;
    return unless (defined $self->{game});
    my $guid = $fields{guid};
    
    $self->{guids}->{$guid}->{simple_name} = $fields{authname};
    $self->{guids}->{$guid}->{level} = $fields{level};
    $self->{game}->{players}->{$guid}->{authenticated} = $self->{guids}->{$guid}->{authenticated} = 1;
    $self->{game}->{players}->{$guid}->{simple_name} = $fields{simplename};
    my $db_player = Stats::DB::Player->new(server_id => $self->{db_server}->id,guid => $guid);
    unless ($db_player->load(speculative => 1)) {
        $db_player->displayname($fields{authname});
        $db_player->name($fields{authname});
        $db_player->save;
    }
}

sub handleDie {
    my ($self,%fields) = @_;
    return unless (defined $self->{game});
    unless ($fields{killerslot} >= 64 || defined($self->{slots}->[$fields{killerslot}]->{db_session})) {
        $self->log->warn("handleDie(): No db session for killerslot $fields{killerslot}");
        return;
    }
    unless ($fields{killedslot} >= 64 || defined($self->{slots}->[$fields{killedslot}]->{db_session})) {
        $self->log->warn("handleDie(): No db session for killedslot $fields{killedslot}");
        return;
    }
    unless ($fields{assistslot} >= 64 || defined($self->{slots}->[$fields{assistslot}]->{db_session})) {
	$self->log->warn("handleDie(): No db session for assistslot $fields{assistslot}");
	return;
    }
    # print "DEBUG: assist: $fields{assistslot} ".(defined($fields{assistslot}) ? "1" : "0")."\n";
    my $killer_session = (($fields{killerslot} // 64) < 64) ? $self->{slots}->[$fields{killerslot}]->{db_session} : undef;
    my $killed_session = (($fields{killedslot} // 64) < 64) ? $self->{slots}->[$fields{killedslot}]->{db_session} : undef;
    my $assist_session = (($fields{assistslot} // 64) < 64) ? $self->{slots}->[$fields{assistslot}]->{db_session} : undef;
    my $weapon = $self->loadWeapon($fields{mod});
    my $event = Stats::DB::PlayerEvent->new(
        time      => $self->parseTimeRelative($fields{time}),
        weapon_id => $weapon->id,
        killer_id => defined($killer_session) ? $killer_session->id : undef,
        killed_id => defined($killed_session) ? $killed_session->id : undef,
	assist_id => defined($assist_session) ? $assist_session->id : undef,
    );
    $event->save;

    $weapon->total_kills($weapon->total_kills+1);
    $weapon->save;

    my $map = $self->{cache}->{map};
    if (defined($assist_session)) {
	$assist_session->total_assists($assist_session->total_assists+1);
	$assist_session->save;

	if (my $assist = $self->loadPlayer($assist_session->player_id)) {
	    $assist->total_assists($assist->total_assists+1);
	    $assist->save;

	    my $assistMap = Stats::DB::PlayerMap->new(player_id => $assist->id,map_id => $map->id);
	    $assistMap->load(speculative => 1);
	    $assistMap->total_assists($assistMap->total_assists+1);
	    $assistMap->save();
	}
    }
    if (defined($killer_session)) {
        $killer_session->total_kills($killer_session->total_kills+1);
        $killer_session->save;

        $killed_session->total_deaths($killed_session->total_deaths+1);
        $killed_session->save;

        # TODO: Map's total kills == map's total deaths as it is
        $self->{db_game}->total_kills($self->{db_game}->total_kills+1);
        $self->{db_game}->total_deaths($self->{db_game}->total_deaths+1);

        $map->total_kills($map->total_kills+1);
        $map->total_deaths($map->total_deaths+1);

        if (my $killer = $self->loadPlayer($killer_session->player_id)) {
	    $killer->total_kills($killer->total_kills+1);
	    $killer->save;

	    my $killerMap = Stats::DB::PlayerMap->new(player_id => $killer->id,map_id => $map->id);
	    $killerMap->load(speculative => 1);
	    $killerMap->total_kills($killerMap->total_kills+1);
	    $killerMap->save();
	    
	    my $killerWeapon = Stats::DB::PlayerWeapon->new(player_id => $killer->id,weapon_id => $weapon->id);
	    $killerWeapon->load(speculative => 1);
	    $killerWeapon->total_kills($killerWeapon->total_kills+1);
	    $killerWeapon->save();
	}
	    
        if (my $killed = $self->loadPlayer($killed_session->player_id)) {
	    $killed->total_deaths($killed->total_deaths+1);
	    $killed->save;

	    my $killedMap = Stats::DB::PlayerMap->new(player_id => $killed->id,map_id => $map->id);
	    $killedMap->load(speculative => 1);
	    $killedMap->total_deaths($killedMap->total_deaths+1);
	    $killedMap->save();
	    
	    my $killedWeapon = Stats::DB::PlayerWeapon->new(player_id => $killed->id,weapon_id => $weapon->id);
	    $killedWeapon->load(speculative => 1);
	    $killedWeapon->total_deaths($killedWeapon->total_deaths+1);
	    $killedWeapon->save();
	}
    } else {
        $self->{db_game}->total_bdeaths($self->{db_game}->total_bdeaths+1);
        $map->total_bdeaths($map->total_bdeaths+1);

        $killed_session->total_bdeaths($killed_session->total_bdeaths+1);
        $killed_session->save;

        if (my $killed = $self->loadPlayer($killed_session->player_id)) {
	    $killed->total_bdeaths($killed->total_bdeaths+1);
	    $killed->save;

	    my $killedMap = Stats::DB::PlayerMap->new(player_id => $killed->id,map_id => $map->id);
	    $killedMap->load(speculative => 1);
	    $killedMap->total_bdeaths($killedMap->total_bdeaths+1);
	    $killedMap->save();

	    my $killedWeapon = Stats::DB::PlayerWeapon->new(player_id => $killed->id,weapon_id => $weapon->id);
	    $killedWeapon->load(speculative => 1);
	    $killedWeapon->total_bdeaths($killedWeapon->total_bdeaths+1);
	    $killedWeapon->save();
	}
    }
}

sub handleConstruct {
    my ($self,%fields) = @_;
    return unless (defined $self->{game});
    $self->{slots}->[$fields{entityid}] = {
        guid => $fields{mod}
    };
    my $weapon = $self->loadWeapon($fields{mod});
    my $building = $self->loadBuilding($fields{buildingname});
    my $session = $self->{slots}->[$fields{slot}]->{db_session};
    $session->total_built($session->total_built+1);
    $session->save;

    my $event = Stats::DB::BuildingEvent->new(
        type => 'build',
        time => $self->parseTimeRelative($fields{time}),
        weapon_id => $weapon->id,
        session_id => $session->id,
        building_id => $building->id
    );
    $event->save;

    my $player = $self->loadPlayer($session->player_id);
    if ($player) {
	$player->total_built($player->total_built+1);
	$player->save;

	my $map = $self->{cache}->{map};
	my $playerMap = Stats::DB::PlayerMap->new(player_id => $player->id,map_id => $map->id);
	$playerMap->load(speculative => 1);
	$playerMap->total_built($playerMap->total_built+1);
	$playerMap->save();
    }
}

sub handleDeconstruct {
    my ($self,%fields) = @_;
    # return unless (defined $self->{game});
    my $guid = $fields{mod};
    $self->{guids}->{$guid} //= {
        guid          => $guid,
        name          => $fields{mod},
        simple_name   => $fields{mod},
        authenticated => 0,
        total_kills   => 0,
        total_deaths  => 0,
        level         => 0,
    };
    $self->{game}->{players}->{$guid} //= +{
        guid         => $guid,
        sessions     => [ ],
        kills        => { },
        deaths       => { },
        total_kills  => [ ],
        total_deaths => [ ],
    };
    # TODO: Theres a case when supporting structures are killed and MOD_NOCREEP kills existing buildings
    #       the killed building's builder can be selected as killer even though his slot might already be disconnected (undef).
    #       Currently getting around it by null deconner field in those cases but this bug is likely to affect other statistics too.
    my $weapon = $self->loadWeapon($fields{mod});
    $weapon->total_bkills($weapon->total_bkills+1);
    $weapon->save;

    my $building = $self->loadBuilding($fields{buildingname});
    my $deconner = (($fields{playerid} < 64) ? $self->{slots}->[$fields{playerid}]->{db_session} : undef);
    my $event = Stats::DB::BuildingEvent->new(
        type => 'destroy',
        time => $self->parseTimeRelative($fields{time}),
        weapon_id => $weapon->id,
        session_id => $deconner ? $deconner->id : undef,
        building_id => $building->id
    );
    $event->save;

    my $map = $self->{cache}->{map};
    $map->total_bkills($map->total_bkills+1);
    $map->save;

    if (defined $deconner) {
        if (my $player = $self->loadPlayer($deconner->player_id)) {
	    $player->total_bkills($player->total_bkills+1);

	    my $playerMap = Stats::DB::PlayerMap->new(player_id => $player->id,map_id => $map->id);
	    $playerMap->load(speculative => 1);
	    $playerMap->total_bkills($playerMap->total_bkills+1);
	    $playerMap->save();

	    my $playerWeapon = Stats::DB::PlayerWeapon->new(player_id => $player->id,weapon_id => $weapon->id);
	    $playerWeapon->load(speculative => 1);
	    $playerWeapon->total_bkills($playerWeapon->total_bkills+1);
	    $playerWeapon->save();
	}
	$deconner->total_bkills($deconner->total_bkills+1);
	$deconner->save;
    }
    ++$self->{guids}->{$fields{mod}}->{total_deaths};
    undef $self->{slots}->[$fields{entityid}];
}

sub handleExit {
    my ($self,%fields) = @_;
    return unless (defined $self->{game});
    $self->{game}->{result} = $fields{reason};
    $self->{game}->{end} = $self->parseTime($fields{time});
    $self->{db_game}->end($self->{db_game}->start->clone->add_duration($self->{game}->{end}));
    if ($fields{reason} =~ /^humans.*$/i) { # 'Humans win.'
	$self->{db_game}->outcome('humans');
    } elsif ($fields{reason} =~ /^aliens.*$/i) { # 'Aliens win.'
	$self->{db_game}->outcome('aliens');
    } elsif ($fields{reason} =~ /^evacuation.*$/i) { # 'Evacuation.'
	$self->{db_game}->outcome('draw');
    } elsif ($fields{reason} =~ /^timelimit.*$/i) { # 'Timelimit hit.'
	$self->{db_game}->outcome('draw');
    } elsif ($fields{reason} =~ /^nextmap.*$/i) { # 'nextmap was run by (console|playername)'
	$self->{db_game}->outcome('draw');
    } else {
	$self->{db_game}->outcome($fields{reason});
    }
    $self->{db_game}->save;
    if ($self->{db_game}->max_players >= 2) {
	my $outcome = $self->{db_game}->outcome;
	my $map = $self->{cache}->{map};
	if ($outcome eq 'humans') {
	    $map->human_wins($map->human_wins+1);
	} elsif ($outcome eq 'aliens') {
	    $map->alien_wins($map->alien_wins+1);
	} else {
	    $map->draws($map->draws+1);
	}
	$map->total_games($map->total_games+1);
	$map->total_time($map->total_time+$self->getDuration($self->{db_game}->end - $self->{db_game}->start));
	$map->save;
	foreach my $player (values %{$self->{game}->{db_players}}) {
	    $player->total_games($player->total_games+1);
	    $player->save;
	}
    }
}

sub handleScore {
    my ($self,%fields) = @_;
    return unless (defined $self->{game});
    # push @{$self->{game}->{score}},{
    #   guid => $self->{slots}->[$fields{slot}]->{guid},
    #   score => $fields{score},
    #   ping  => $fields{ping},
    #   name  => $fields{name},
    # };
    # print "SCORE: ".join(" ",map { "$_ = $fields{$_}" } keys(%fields))."\n";
    my $db_session = $self->{slots}->[$fields{slot}]->{db_session};
    $db_session->score($fields{score});
    $db_session->ping($fields{ping});
    # $db_session->name($fields{name});
    $db_session->save;
}

sub handleChangeTeam {
    my ($self,%fields) = @_;
    return unless (defined $self->{game});
    my $db_session = $self->{slots}->[$fields{slot}]->{db_session};
    if (defined $db_session) {
	$self->endSession($db_session,$self->parseTimeRelative($fields{time}));
    } else {
        $self->log->warn("ChangeTeam(): No active db_session for slot $fields{slot} guid $fields{guid}");
        return;
    }
    my $player_id = $db_session->player_id;
    my $db_session = $self->{slots}->[$fields{slot}]->{db_session} = $self->beginSession(
	slot      => $fields{slot},
	game_id   => $self->{db_game}->id,
	player_id => $player_id,
	name      => $self->{slots}->[$fields{slot}]->{name},
        team      => $fields{team},
        ip        => $self->{slots}->[$fields{slot}]->{ip},
        start     => $self->parseTimeRelative($fields{time}),
	is_new    => 0
    );
}

# TODO: (1.1)
sub handleClientTeamClass {
    my ($self,%fields) = @_;
    # 1.1, provides same fields in regex except for message
    $self->handleChangeTeam(%fields);
}

# TODO: (1.1)
sub handleClientTeam {
    my ($self,%fields) = @_;
    # TODO: 1.1, required to catch leaving team but only provides name
}

sub handleClientRename {
    my ($self,%fields) = @_;
    return unless (defined $self->{game});
    my $player = Stats::DB::Player->new(guid => $fields{guid});
    if ($player->load(speculative => 1)) {
        if ($player->displayname ne $fields{newnameformatted}) {
            $player->displayname($fields{newnameformatted});
            $player->save;
        }
    }
}

sub handleStage {
    my ($self,%fields) = @_;
    return unless (defined $self->{game});
    my $time = $self->parseTimeRelative($fields{time});
    if ($fields{team} eq 'H') {
        if ($fields{stage} == 2) {
            $self->{db_game}->hs2($time);
        } elsif ($fields{stage} == 3) {
            $self->{db_game}->hs3($time);
        } elsif ($fields{stage} == 4) {
            $self->{db_game}->hs4($time);
        } elsif ($fields{stage} == 5) {
            $self->{db_game}->hs5($time);
        }
    } elsif ($fields{team} eq 'A') {
        if ($fields{stage} == 2) {
            $self->{db_game}->as2($time);
        } elsif ($fields{stage} == 3) {
            $self->{db_game}->as3($time);
        } elsif ($fields{stage} == 4) {
            $self->{db_game}->as4($time);
        } elsif ($fields{stage} == 5) {
            $self->{db_game}->as5($time);
        }
    }
    $self->{db_game}->save;
}

sub handleCombatSettings {
    my ($self,%fields) = @_;
    return unless (defined $self->{game});
    foreach my $entry (pairs split /\s+/,$fields{weapons}) {
        my $game_weapon = $self->loadGameWeapon($entry->[0]);
        $game_weapon->{damage_per_shot} = $entry->[1];
        $game_weapon->save;
    };
}

sub handleCombatStats {
    my ($self,%fields) = @_;
    return unless (defined $self->{game});
    my $db_session = $self->{slots}->[$fields{slot}]->{db_session};
    return unless (defined $db_session);
    foreach my $entry (pairs split /\s+/,$fields{data}) {
        my ($num_fired,$e_damage,$f_damage,$eb_damage,$fb_damage,$s_damage) = split(/,/,$entry->[1]);
        my $sweapon = $self->loadSessionWeapon($db_session->id,$entry->[0]);
        $sweapon->num_fired($num_fired);
        $sweapon->damage_enemy($e_damage);
        $sweapon->damage_friendly($f_damage);
        $sweapon->damage_enemy_buildable($eb_damage);
        $sweapon->damage_friendly_buildable($fb_damage);
        $sweapon->damage_self($s_damage);
        $sweapon->save;
        my $pweapon = $self->loadPlayerWeapon($db_session->player_id,$entry->[0]);
        $pweapon->num_fired($pweapon->num_fired+$num_fired);
        $pweapon->damage_enemy($pweapon->damage_enemy+$e_damage);
        $pweapon->damage_friendly($pweapon->damage_friendly+$f_damage);
        $pweapon->damage_enemy_buildable($pweapon->damage_enemy_buildable+$eb_damage);
        $pweapon->damage_friendly_buildable($pweapon->damage_friendly_buildable+$fb_damage);
        $pweapon->damage_self($pweapon->damage_self+$s_damage);
        $pweapon->save;
        my $gweapon = $self->loadGameWeapon($entry->[0]);
        $gweapon->num_fired($gweapon->num_fired+$num_fired);
        $gweapon->damage_enemy($gweapon->damage_enemy+$e_damage);
        $gweapon->damage_friendly($gweapon->damage_friendly+$f_damage);
        $gweapon->damage_enemy_buildable($gweapon->damage_enemy_buildable+$eb_damage);
        $gweapon->damage_friendly_buildable($gweapon->damage_friendly_buildable+$fb_damage);
        $gweapon->damage_self($gweapon->damage_self+$s_damage);
        $gweapon->save;
    };
}

sub handleClanInfo {
    my ($self,%fields) = @_;
    my $clan = Stats::DB::Clan->new(tag => $fields{tag});
    my $isnew = !$clan->load(speculative => 1);
    if ($isnew || $clan->name ne $fields{name}) {
        $clan->name($fields{name});
        $clan->save;
    }
    my $player = Stats::DB::Player->new(guid => $fields{guid});
    $player->load(speculative => 1);

    if ($fields{type} eq 'Add') {
        if ($isnew) {
            Stats::DB::ClanEvent->new(clan_id => $clan->id,time => DateTime->now,type => 'create',player_id => $player->id)->save;
        }
        Stats::DB::ClanEvent->new(clan_id => $clan->id,time => DateTime->now,type => 'add',player_id => $player->id)->save;
    } elsif ($fields{type} =~ /^Remove|Resign$/) {
        Stats::DB::ClanEvent->new(clan_id => $clan->id,time => DateTime->now,type => lc($fields{type}),player_id => $player->id)->save;
        if (ClanMember::Manager->get_clan_members_count(clan_id => $clan->id) == 1) {
            Stats::DB::ClanEvent->new(clan_id => $clan->id,time => DateTime->now,type => 'destroy',player_id => $player->id)->save;
        }
    } elsif ($fields{type} eq 'Auth') {
        
    }
}

sub deleteGameEntries {
    my ($game_id) = @_;
    my @sessions = map { $_->id } @{Stats::DB::Session::Manager->get_sessions(where => [ game_id => $game_id ])};
    if (scalar(@sessions)) {
        Stats::DB::TeamEvent::Manager->delete_team_events(where => [ session_id => \@sessions ]);
        Stats::DB::BuildingEvent::Manager->delete_building_events(where => [ session_id => \@sessions ]);
        Stats::DB::PlayerEvent::Manager->delete_player_events(where => [ or => [ killed_id => \@sessions, killer_id => \@sessions, assist_id => \@sessions ] ]);
    }
}

sub loadGlicko2 {
    my ($self,$player_id,%extra) = @_;
    return {
	player  => $player_id,
	glicko  => Glicko2::Player->new,
	db      => undef,
        %extra,
    } unless (defined $player_id);
    my $result = Stats::DB::Glicko2->new(player_id => $player_id);
    $result->save unless ($result->load(speculative => 1));
    # print "LOAD: $player_id -> ".Glicko2::Player->new(rating => $result->rating,rd => $result->rd,volatility => $result->volatility)."\n";
    return {
	player => $player_id,
	glicko => Glicko2::Player->new(rating => $result->rating,rd => $result->rd,volatility => $result->volatility),
	db     => $result,
	%extra
    };
}

sub saveGlicko2 {
    my ($self,$glicko2) = @_;
    if (defined(my $db = $glicko2->{db})) {
	$db->rating($glicko2->{glicko}->rating);
	$db->rd($glicko2->{glicko}->rd);
	$db->volatility($glicko2->{glicko}->volatility);
	$db->save;
    }
}

sub getDuration {
    my ($self,$d) = @_;
    return 86400*$d->days+3600*$d->hours+60*$d->minutes+$d->seconds;
}

sub updateGlicko2 {
    my ($self) = @_;
    my $game = $self->{db_game};
    #return 0 unless (defined $game->end);
    return 0 unless (defined $game->outcome);
    my $score_values;
    if ($game->outcome =~ /^humans/i) {
	$score_values = { human => 1.0, alien => 0.0 }
    } elsif ($game->outcome =~ /^aliens/i) {
	$score_values = { human => 0.0, alien => 1.0 }
    } else { # /^draw$/i
	$score_values = { human => 0.5, alien => 0.5 }
    }
    unless (defined $score_values) {
	$self->log->warn("Unrecognized outcome: '".$game->outcome."' skipping rankings update.");
	next;
    }
    my %teams = (human => [ ],alien => [ ]);
    foreach my $session (@{Stats::DB::Session::Manager->get_sessions(where => [ game_id => $game->id,team => [ 'human', 'alien' ]])}) {
	push @{$teams{$session->team}},$self->loadGlicko2($session->player_id,session => $session);
    }
    next unless(scalar(@{$teams{human}}) && scalar(@{$teams{alien}}));
    my $game_duration = $self->getDuration($game->end - $game->start);
    foreach my $team ('human','alien') {
	my $comp = $teams{$team.'_composite'} = Glicko2::Player->new(rating => 0,rd => 0,volatility => 0);
	my $team_duration = 0.0;
	foreach my $session (@{$teams{$team}}) {
	    my $session_duration = $self->getDuration($session->{session}->end - $session->{session}->start);
	    my $relative_duration = $session_duration/$game_duration;
	    $team_duration += $relative_duration;
	    $comp->rating($comp->rating+$relative_duration*$session->{glicko}->rating);
	    $comp->rd($comp->rd+$relative_duration*$session->{glicko}->rd);
	    # $comp->volatility($comp->volatility+$session->{glicko}->volatility); # TODO: Not used for update?
	}
	$comp->rating($comp->rating/$team_duration);
	$comp->rd($comp->rd/$team_duration);
	# $comp->volatility($comp->volatility/$team_duration); # TODO: Not used for update?
    }
    my %opponents = (human => $teams{alien_composite},alien => $teams{human_composite});
    foreach my $team ('human','alien') {
	foreach my $entry (@{$teams{$team}}) {
	    # print "Append queue: ".((defined $entry->{db}) ? $entry->{db}->id : 'null')."\n";
	    next unless (defined $entry->{db});
	    Stats::DB::Glicko2Score->new(glicko2_id          => $entry->{db}->id,
					 session_id          => $entry->{session}->id,
					 score               => $score_values->{$team},
					 opponent_rating     => $opponents{$team}->rating,
					 opponent_rd         => $opponents{$team}->rd,
					 opponent_volatility => $opponents{$team}->volatility,
					 is_new              => 1)->save;
	}
    }
    $self->{last_glicko2} = $game->end->clone;
    # print "  Last glicko2: ".$self->{last_glicko2}."\n";
    return 1;
}

sub updateRankings {
    my ($self) = @_;
    my $server_id = $self->{db_server}->id;
    my $lastUpdate = Stats::DB::TimeStamp->new(name => 'last_glicko2',server_id => $server_id);
    if (!$lastUpdate->load(speculative => 1) || !defined($lastUpdate->value) || !defined($self->{last_glicko2}) || $self->getDuration($self->{last_glicko2} - $lastUpdate->value) >= 12*3600) {
	# print "  Updating glicko2\n";
	my %matches = map {
	    $_->id => {
		glicko2  => $self->loadGlicko2($_->id),
		outcomes => [ ]
	    }
	} @{Stats::DB::Player::Manager->get_players(query => [ server_id => $server_id ])};
	my @scores = @{Stats::DB::Glicko2Score::Manager->get_glicko2_scores(query => [ is_new => 1, 'session.player.server_id' => $server_id, 'session.player.total_time' => { ge => MIN_GLICKO2_TIME }, 'session.player.total_games' => { ge => MIN_GLICKO2_GAMES } ],with_objects => [ 'session', 'session.player'] )};
	foreach my $score (@scores) {
	    push @{$matches{$score->session->player_id}->{outcomes}},{
		opponent => Glicko2::Player->new(rating     => $score->opponent_rating,
						 rd         => $score->opponent_rd,
						 volatility => $score->opponent_volatility),
		score    => $score->score
	    };
	    $score->is_new(0);
	    $score->save;
	}
	foreach my $match (values %matches) {
	    # print "Outcomes: ".scalar(@{$match->{outcomes}})."\n";
	    $match->{glicko2}->{glicko}->update(@{$match->{outcomes}});
	    $self->saveGlicko2($match->{glicko2});
	}
	$lastUpdate->value($self->{last_glicko2});
	$lastUpdate->save;
    }
    my @statements = (
        # TODO: Done as part of import, verify that it works (also replace total_rqs with a direct dependability score?)
        # "update players p set total_sessions = (select count(*) from sessions s where s.player_id = p.id and s.end is not null and s.team != 'spectator')",
        # "update players p set total_rqs = (select count(*) from sessions s,games g where s.player_id = p.id and s.game_id = g.id and s.end is not null and s.team != 'spectator' and s.end < g.end and p.total_sessions >= 10)",
        # Update player rankings - needed for player name searches with nearby player rankings display
        "delete from player_rankings where server_id = $server_id",
        "set \@rownum=-1",
	"insert into player_rankings (player_id,server_id,glicko2_id,by_glicko2) select p.id as player_id,$server_id,g.id as glicko2_id,\@rownum:=\@rownum+1 as by_glicko2 from players p,player_glicko2 g where server_id = $server_id and g.player_id = p.id order by g.rating desc",
	# TODO: For some reason the above insert wont get players in correct order so we're rearranging them on the next two lines
        "set \@rownum=-1",
	"update player_rankings r left join (select p.id,\@rownum:=\@rownum+1 as value from players p,player_glicko2 g where server_id = $server_id and g.player_id = p.id order by g.rating desc) as q on r.player_id = q.id set by_glicko2 = value",
	"set \@rownum=-1",
	"update player_rankings r left join (select id,\@rownum:=\@rownum+1 as value from players where server_id = $server_id order by total_kills desc) as p on r.player_id = p.id set by_kills = value",
        "set \@rownum=-1",
        "update player_rankings r left join (select id,\@rownum:=\@rownum+1 as value from players where server_id = $server_id order by name) as p on r.player_id = p.id set by_name = value",
        "set \@rownum=-1",
        "update player_rankings r left join (select id,\@rownum:=\@rownum+1 as value from players where server_id = $server_id order by total_deaths desc) as p on r.player_id = p.id set by_deaths = value",
        "set \@rownum=-1",
        "update player_rankings r left join (select id,\@rownum:=\@rownum+1 as value from players where server_id = $server_id order by total_assists desc) as p on r.player_id = p.id set by_assists = value",
        "set \@rownum=-1",
        "update player_rankings r left join (select id,\@rownum:=\@rownum+1 as value from players where server_id = $server_id order by total_built desc) as p on r.player_id = p.id set by_buildings_built = value",
        "set \@rownum=-1",
        "update player_rankings r left join (select id,\@rownum:=\@rownum+1 as value from players where server_id = $server_id order by total_bkills desc) as p on r.player_id = p.id set by_buildings_killed = value",
        "set \@rownum=-1",
        "update player_rankings r left join (select id,\@rownum:=\@rownum+1 as value from players where server_id = $server_id order by total_kills/total_deaths desc) as p on r.player_id = p.id set by_kills_per_deaths = value",
        "set \@rownum=-1",
        "update player_rankings r left join (select id,\@rownum:=\@rownum+1 as value from players where server_id = $server_id order by total_bkills/total_deaths desc) as p on r.player_id = p.id set by_bkills_per_deaths = value",
        "set \@rownum=-1",
        "update player_rankings r left join (select id,\@rownum:=\@rownum+1 as value from players where server_id = $server_id order by total_time_a/total_time_h desc) as p on r.player_id = p.id set by_team_aliens = value",
        "set \@rownum=-1",
        "update player_rankings r left join (select id,\@rownum:=\@rownum+1 as value from players where server_id = $server_id order by total_time_h/total_time_a desc) as p on r.player_id = p.id set by_team_humans = value",
        "set \@rownum=-1",
        "update player_rankings r left join (select id,\@rownum:=\@rownum+1 as value from players where server_id = $server_id order by total_rqs/total_sessions) as p on r.player_id = p.id set by_rq = value",
        # Player/Map kills/deaths statistics - Handled directly during import
        # 'delete from player_maps',
        # 'insert into player_maps (player_id,map_id,total_kills) select p.id as player_id,m.id as map_id,sum(s.total_kills) as total_kills from player_events e,maps m,players p,sessions s,games g where s.player_id = p.id and s.game_id = g.id and g.map_id = m.id and e.killer_id = s.id group by player_id',
        # 'update player_maps pm left join (select p.id as player_id,m.id as map_id,sum(s.total_deaths) as total_deaths from player_events e,maps m,players p,sessions s,games g where s.player_id = p.id and s.game_id = g.id and g.map_id = m.id and e.killed_id = s.id group by player_id) as q on pm.player_id = q.player_id and pm.map_id = q.map_id set pm.total_deaths = q.total_deaths',
        # 'update player_maps pm left join (select p.id as player_id,m.id as map_id,sum(s.total_bkills) as total_bkills from building_events e,maps m,players p,sessions s,games g where s.player_id = p.id and s.game_id = g.id and g.map_id = m.id and e.session_id = s.id group by player_id) as q on pm.player_id = q.player_id and pm.map_id = q.map_id set pm.total_bkills = q.total_bkills',
        # Player/Weapon kills/deaths statistics - Handled directly during import
        # 'delete from player_weapons',
        # 'insert into player_weapons (player_id,weapon_id,total_kills) select p.id as player_id,w.id as weapon_id,sum(s.total_kills) as total_kills from player_events e,weapons w,players p,sessions s where s.player_id = p.id and e.weapon_id = w.id and e.killer_id = s.id',
        # 'update player_weapons pw left join (select p.id as player_id,w.id as weapon_id,sum(s.total_deaths) as total_deaths from player_events e,weapons w,players p,sessions s where s.player_id = p.id and e.weapon_id = w.id and e.killed_id = s.id) as q on pw.player_id = q.player_id and pw.weapon_id = q.weapon_id set pw.total_deaths = q.total_deaths',
        # 'update player_weapons pw left join (select p.id as player_id,w.id as weapon_id,sum(s.total_bkills) as total_bkills from player_events e,weapons w,players p,sessions s where s.player_id = p.id and e.weapon_id = w.id and e.killer_id = s.id) as q on pw.player_id = q.player_id and pw.weapon_id = q.weapon_id set pw.total_bkills = q.total_bkills'
    );
    my $db = Stats::DB->new_or_cached;
    foreach my $statement (@statements) {
        # print "Q: $statement\n";
        $db->dbh->do($statement);
    }
}

# Splits the given line into multiple lines in order to fix bugs in server log.
sub splitLine {
    my ($self,$line) = @_;
    if ($line =~ /^\s*(?<line1>\d+:\d+\s*Inactivity:\s*\d+)\s+(?<line2>.+)\s*$/) {
	# This was a case in some earlier new edge gpp builds
        return ($+{line1},$+{line2});
    } else {
	# Recent versions of unvanquished seem to output lines joined together with \x00
	return split /\x00\s*/,$line;
        # return ($line);
    }
}

sub parseLine {
    my ($self,$line) = @_;
    $self->{line} = $line; # For debug messages use
    eval {
	if ($line =~ /^\s*(?<time>\d+:\d+)\s*-+\s*$/) {
            # Delimiter - skipped
	} elsif (!$self->{in_game}) {
	    if ($line =~ /^\s*(?<time>\d+:\d+)\s*InitGame:\s+\\(?<rawdata>.+)\s*$/) {
		my %data = split /\\/,$+{rawdata};
		$self->handleInitGame(%+,%data);
		$self->{in_game} = 1;
	    } else {
		$self->log->warn("Unrecognized line: $line");
		return;
	    }
	} elsif ($line =~ /^\s*(?<time>\d+:\d+)\s*ShutdownGame:\s*$/) {
            $self->handleShutdownGame(%+);
	    $self->{in_game} = 0;
	} elsif ($line =~ /^\s*(?:\d+:\d+)\s*RealTime:\s+(?<year>\d{4})[\/-](?<month>\d{2})[\/-](?<day>\d{2})\s+(?<hour>\d{2}):(?<minute>\d{2}):(?<second>\d{2})(?:(\s+(?<time_zone>[A-Z]+)))?\s*$/) { # TODO: optional time_zone added for unv
            $self->handleRealTime(%+);
        } elsif ($line =~ /^\s*(?<time>\d+:\d+)\s*Beginning\s*Sudden\s*Death\s*$/) {
            $self->handleSuddenDeath(%+);
        } elsif ($line =~ /^\s*(?<time>\d+:\d+)\s*Beginning\s*Weak\s*Sudden\s*Death\s*$/) {
            $self->handleWeakSuddenDeath(%+);
        } elsif ($line =~ /^\s*(?<time>\d+:\d+)\s*ClientConnect:\s+(?<slot>\d+)\s+\[(?<ip>\S+?)\]\s+\((?<guid>\S+?)\)(?:\s+\"(?<simplename>.+?)\")?\s+\"(?<name>.+?)\"(?:\s+(?<flags>\S+))?\s*$/) {
	    # TODO: (1.1): Simplename made optional
            $self->handleClientConnect(%+);
        } elsif ($line =~ /^\s*(?<time>\d+:\d+)\s*ClientDisconnect:\s*(?<slot>\d+)\s+\[(?<ip>\S*?)\]\s+\((?<guid>\S+?)\)\s+\"(?<simplename>.+?)\"\s*$/) {
            $self->handleClientDisconnect(%+);
        } elsif ($line =~ /^\s*(?<time>\d+:\d+)\s*AdminAuth:\s+(?<slot>\d+)\s+\"(?<simplename>.+?)\"\s+\"(?<authname>.+?)\"\s+\[(?<level>\-?\d+)\]\s+\((?<guid>\S+?)\):\s+.+$/) {
            $self->handleAdminAuth(%+);
        } elsif ($line =~ /^\s*(?<time>\d+:\d+)\s*Die:\s+(?<killerslot>\d+)\s+(?<killedslot>\d+)\s+(?<mod>\S+)(?:\s+(?<assistslot>\d+)\s+(?<assistteam>\d+))?:\s+(?<killername>.+?)\s+killed\s+(?<killedname>.+)$/) {
            $self->handleDie(%+);
	} elsif ($line =~ /^\s*(?<time>\d+:\d+)\s*Kill:\s+(?<killerslot>\d+)\s+(?<killedslot>\d+)\s+(?<modnumber>\S+):\s+(?<killername>.+?)\s+killed\s+(?<killedname>.+?)\s+by\s+(?<mod>\S+)$/) {
	    # TODO: (1.1) Kill message instead of Die but provides mostly same information.
	    $self->handleDie(%+);
        } elsif ($line =~ /^\s*(?<time>\d+:\d+)\s*Construct:\s+(?<slot>\d+)\s+(?<entityid>\d+)\s+(?<buildingname>\S+):\s+.+$/) {
            # 31:26 Construct: 0 177 mgturret: Pat is building Machinegun Turret
            # 31:04 Construct: 0 149 medistat: CU|Mario is building Medistation
            $self->handleConstruct(%+,mod => 'MOD_CONSTRUCT');
	} elsif ($line =~ /^\s*(?<time>\d+:\d+)\s*Construct:\s+(?<slot>\d+)\s+(?<entityid>\d+)\s+(?<buildingname>\S+)\s+(?<replacedids>\d+(?:\s+\d+)*?):\s+.+$/) {
	    # 4:51 Construct: 0 149 mgturret 119: CU|narbatucker is building Machinegun Turret, replacing Telenode
	    # 2:27 Construct: 0 158 mgturret 83 70: DRM vs. freeloaders is building Machinegun Turret, replacing Machinegun Turret and Drill
	    $self->handleConstruct(%+,mod => 'MOD_CONSTRUCT');
        } elsif ($line =~ /^\s*(?<time>\d+:\d+)\s*Deconstruct:\s+(?<playerid>\d+)\s+(?<entityid>\d+)\s+(?<buildingname>\S+)\s+(?<mod>\S+):\s+.+$/) {
            # 32:48 Deconstruct: 0 168 acid_tube MOD_MACHINEGUN: Acid Tube destroyed by Pat
            $self->handleDeconstruct(%+);
        } elsif ($line =~ /^\s*(?<time>\d+:\d+)\s*Exit:\s+(?<reason>.+)\s*$/) {
            $self->handleExit(%+);
        } elsif ($line =~ /^\s*(?<time>\d+:\d+)\s*score:\s+(?<score>\-?\d+)\s+ping:\s+(?<ping>\d+)\s+client:\s+(?<slot>\d+)\s+(?<name>.+?)\s*$/) {
            # 1101:22score: 48  ping: 412  client: 0 kwergangregory
            # 17:31 score: 8  ping: 322  client: 1 bluedemon1
            $self->handleScore(%+);
        } elsif ($line =~ /^\s*(?<time>\d+:\d+)\s*Warmup:\s+(?<duration>\d+)\s*$/) {
            # Warmup definition - not used
        } elsif ($line =~ /^\s*(?<time>\d+:\d+)\s*ClientBegin:\s+(?<slot>\d+)\s*$/) {
            # ClientBegin - not used
        } elsif ($line =~ /^\s*(?<time>\d+:\d+)\s*AdminExec:.*$/) {
            # AdminExec - not used
        } elsif ($line =~ /^\s*(?<time>\d+:\d+)\s*Say(?:Team|Area)?:\s+(?<slot>\-?\d+)\s+\"(?<name>.+?)\":\s+(?<message>.*?)\s*$/) {
            # Say, SayTeam, SayArea - not used
        } elsif ($line =~ /^\s*(?<time>\d+:\d+)\s*ChangeTeam:\s+(?<slot>\d+)\s+(?<team>\S+):\s+(?<message>.*?)\s*$/) {
            # 41:06 ChangeTeam: 1 human: Lucirant switched teams
            # team values: human, alien, spectator directly mapped as enum in db
            $self->handleChangeTeam(%+);
	} elsif ($line =~ /^\s*(?<time>\d+:\d+)\s*ClientTeamClass:\s+(?<slot>\d+)\s+(?<team>\S+)\s+(?<weapon>\S+)\s*$/) {
	    # TODO: (1.1)
	    # 2:22 ClientTeamClass: 0 human rifle
	    $self->handleClientTeamClass(%+)
	} elsif ($line =~ /^\s*(?<time>\d+:\d+)\s*ClientTeam:\s+(?<displayname>.+?)\s+left the (?<team>humans|aliens)\.\s*$/) {
	    # TODO: (1.1)
	    # 21:39 ClientTeam: ^7[LEGO] ^2l^3ooooo^2s^5er^7 left the aliens.
        } elsif ($line =~ /^\s*(?<time>\d+:\d+)\s*ClientRename:\s+(?<slot>\d+)\s+\[(?<ip>\S+)?\]\s+\((?<guid>(\S+)?)\)\s+\"(?<name>.+?)\"\s+->\s+\"(?<newname>.+?)\"\s+\"(?<newnameformatted>.+?)\"\s*$/) {
            # 1:43 ClientRename: 1 [86.135.175.36] (B2DA87EFC901CB0B35AB87EE33DD669F) ":InfD:Mors" -> "[ye]Kai [flamer]" "^3[ye]^1K^4ai ^2[flamer]
            $self->handleClientRename(%+);
        } elsif ($line =~ /^\s*(?<time>\d+:\d+)\s*Call(?:Team)?Vote:\s+(?<slot>\d+)\s+\"(?<name>.+?)\":\s+(?<vote>.+?)\s*$/) {
            # CallVote, CallTeamVote - not used
        } elsif ($line =~ /^\s*(?<time>\d+:\d+)\s*EndVote:\s+.+$/) {
            # EndVote - not used
        } elsif ($line =~ /^\s*(?<time>\d+:\d+)\s*(?:Priv|Admin)Msg(?:Public)?:\s+.+$/) {
            # PrivMsg, AdminMsg, AdminMsgPublic (NOTE: Also matches PrivMsgPublic) - not used 
        } elsif ($line =~ /^\s*(?<time>\d+:\d+)\s*Anti-camper\s+bonus\s+for\s+killing\s+(?<killedname>.+?)\s+near\s+(?<numdefenses>\d+)\s+defences:\s+(?<percentage>\d+)\%\s*$/) {
            # Anti-camper bonus - not used
        } elsif ($line =~ /^\s*(?<time>\d+:\d+)\s*Stage:\s+(?<team>[A|H])\s+(?<stage>\d+):\s+(?<message>.+?)\s*$/) {
            # 7:30 Stage: A 2: Aliens reached Stage 2
            $self->handleStage(%+);
        } elsif ($line =~ /^\s*(?<time>\d+:\d+)\s*revert:\s+(?<operation>restore|remove)\s+(?<entityid>\d+)\s+(?<name>.+?)\s*$/) {
            # revert - not used
        } elsif ($line =~ /^\s*(?<time>\d+:\d+)\s*Inactivity:\s*(?<slot>\d+)\s*$/) {
            # 44:35 Inactivity: 10
            # $self->handleInactivity(%+);
        } elsif ($line =~ /^\s*(?<time>\d+:\d+)\s*CombatSettings:\s+(?<weapons>.+?)\s*$/) {
            # 0:00 CombatSettings: MOD_BLASTER 10 MOD_MACHINEGUN 5 MOD_PAINSAW 11 MOD_PSAWBLADE 60 MOD_SHOTGUN 55 MOD_LASGUN 9 MOD_MDRIVER 40 MOD_CHAINGUN 6 MOD_PRIFLE 9 MOD_FLAMER 20 MOD_LIGHTNING 6 MOD_LCANNON 265 MOD_ROCKETL 80 MOD_GRENADE 340 MOD_ABUILDER_CLAW 20 MOD_SLOWBLOB 4 MOD_LEVEL1_CLAW 32 MOD_LEVEL2_CLAW 40 MOD_LEVEL2_CLAW_UPG 45 MOD_LEVEL2_ZAP 60 MOD_LEVEL3_CLAW 80 MOD_LEVEL3_BOUNCEBALL 115 MOD_LEVEL4_CLAW 100 MOD_LEVEL4_FLAMES 50 MOD_LEVEL5_CLAW 30 MOD_LEVEL5_BOUNCEBALL 7
            $self->handleCombatSettings(%+);
        } elsif ($line =~ /^\s*(?<time>\d+:\d+)\s*CombatStats:\s+(?<slot>\d+)\s+(?<data>.+?)\s*$/) {
            # 13:49 CombatStats: 0 MOD_BLASTER 240,80,0,0,0,0 MOD_MACHINEGUN 655,120,0,75,5,0 MOD_PAINSAW 2211,220,0,0,22,0 MOD_PSAWBLADE 180,120,0,0,0,0 MOD_LASGUN 2376,261,0,891,0,0 MOD_MDRIVER 800,200,0,440,0,0 MOD_LCANNON 3016,909,0,814,17,87 MOD_GRENADE 340,0,0,329,0,0
            $self->handleCombatStats(%+);
        } elsif ($line =~ /^\s*(?<time>\d+:\d+)\s*Clan(?<type>Add|Remove|Resign|Auth):\s+\[(?<tag>.+?)\]\s+(?<guid>\S+)\s+(?<isleader>[01])\s+(?<name>.+)\s*$/) {
            $self->handleClanInfo(%+);
	#} elsif ($line =~ /^\s(\d+)\s+(?<time>\d+:\d+)\s*-+\s*$/) {
	#    # 4  0:00 ------------------------------------------------------------
        } else {
            $self->log->warn("Unrecognized line: $line");
        }
    };
    if ($@) {
        die "ERROR: $@\nLINE: $line\n";
    }
}

sub parseLines {
    my ($self,@lines) = @_;
    foreach my $line (@lines) {
        foreach my $token ($self->splitLine($line)) {
            $self->parseLine($token)
        }
    }
}

sub parseFile {
    my ($self,$path) = @_;
    open FI,'<',$path or die "Unable to read file: $path";
    $self->sourcePath($path);
    while(chomp(my $line = <FI>)) {
        foreach my $token ($self->splitLine($line)) {
            $self->parseLine($token);
        }
    }
    close FI;
}

sub parseTime {
    my ($self,$value) = @_;
    if ($value =~ /^(?<m>\d+)\:(?<s>\d+)$/) {
        return DateTime::Duration->new(minutes => $+{m},seconds => $+{s});
    } else {
        return undef;
    }
}

sub parseTimeRelative {
    my ($self,$value) = @_;
    return $self->{db_game}->start->clone->add_duration($self->parseTime($value));
}

sub sourcePath {
    my ($self,$value) = @_;
    $self->{source_path} = $value if (defined $value);
    return $self->{source_path};
}

1;
