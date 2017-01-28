package NEStatsJSON;
use Dancer2;

our $VERSION = '0.1';

use List::Util qw/min max/;
use List::MoreUtils qw/zip/;
use DateTime::Format::Duration;

use lib '../lib';

use Stats::DB;
use Stats::DB::Game;
use Stats::DB::Map;
use Stats::DB::Player;
use Stats::DB::Session;
use Stats::DB::Weapon;
use Stats::DB::Building;
use Stats::DB::PlayerEvent;
use Stats::DB::BuildingEvent;
use Stats::DB::TeamEvent;
use Stats::DB::GameStatusEvent;
use Stats::DB::Server;
use Stats::DB::PlayerRanking;
use Stats::DB::PlayerWeapon;
use Stats::DB::SessionWeapon;
use Stats::DB::GameWeapon;
use Stats::DB::PlayerMap;
use Stats::DB::Clan;

use Stats::Util qw/replace_all db_to_hashref/;

use Glicko2::Player;

use Rose::DB::Object::Helpers qw/as_tree/;

# -- JSON handlers --

set serializer => 'JSON';

get '/servers/:offset/:limit' => sub {
    # TODO: Order query by player count and/or name
    my $count = Stats::DB::Server::Manager->get_servers_count();
    # my $games_count = Stats::DB::Game::Manager->get_games_count(where => [ server_id => params->{server} ]);
    # my $last_game = Stats::DB::Game::Manager->get_games
    my @servers = map +{
	id          => $_->id,
	name        => replace_all($_->name),
	ip          => $_->ip,
	url         => $_->url,
	map         => undef, # { id   => $_->map->id, name => $_->map->name },
	# outcome     => $_->outcome // 'draw',
	# date        => $_->start->dmy,
	# time        => $_->start->hms,
	# max_players => $_->max_players,
    },@{Stats::DB::Server::Manager->get_servers(
	sort_by => 'name asc',
	limit => max(25,params->{limit}),
	offset => params->{offset},
	# with_objects => [ 'map' ]
    )};
    return {
	servers => \@servers,
	offset  => params->{offset},
	total   => $count
    };
};

get '/games/:offset/:limit' => sub {
    # TODO: Implement or remove
};

get '/maps/:offset/:limit' => sub {
    # TODO: Implement or remove
};

get '/player/:id' => sub {
    my $player  = Stats::DB::Player->new(id => params->{id});
    my $glicko2 = Stats::DB::Glicko2->new(player_id => params->{id});
    if ($player->load(speculative => 1)) {
	$glicko2 = Glicko2::Player->new unless($glicko2->load(speculative => 1));
	return {
	    (map { $_ => $player->{$_} } (qw/id total_time total_time_h total_time_a total_kills total_deaths total_assists total_bkills total_bdeaths total_built total_sessions total_rqs/)),
	    (map { 'glicko2_'.$_ => $glicko2->{$_} } (qw/rating rd volatility/)),
	    displayname => replace_all($player->{displayname})
	}
    } else {
	return { error => 'Unknown player: '.params->{id} }
    }
};

get '/player/:id/deaths_by_weapon/:offset/:limit' => sub {
    my $player = Stats::DB::Player->new(id => params->{id});
    my $count = Stats::DB::PlayerWeapon::Manager->get_player_weapons_count(where => [ player_id => $player->id, total_kills => { gt => 0 } ],require_objects => [ 'weapon' ]);
    my @deaths = @{Stats::DB::PlayerWeapon::Manager->get_player_weapons(where => [ player_id => $player->id, total_deaths => { gt => 0 } ],sort_by => [ 'total_deaths desc', 'total_bdeaths desc' ],with_objects => [ 'weapon' ],offset => params->{offset},limit => max(25,params->{limit}))};
    return {
	deaths => [
	    map {
		my $death = $_;
		+{
		    weapon_displayname => replace_all($death->weapon->displayname),
		    (map { 'weapon_'.$_ => $death->weapon->$_ } grep { !/^id|displayname$/ } $death->weapon->meta->column_names),
		    (map { $_ => $death->{$_} } grep { !/^displayname|weapon$/ } $death->meta->column_names)
		}
	    } @deaths
	],
	offset => params->{offset},
	total  => $count
    };
};

get '/player/:id/kills_by_weapon/:offset/:limit' => sub {
    my $player = Stats::DB::Player->new(id => params->{id});
    my $count = Stats::DB::PlayerWeapon::Manager->get_player_weapons_count(where => [ player_id => $player->id, total_kills => { gt => 0 } ],require_objects => [ 'weapon' ]);
    my @kills = @{Stats::DB::PlayerWeapon::Manager->get_player_weapons(where => [ player_id => $player->id, total_kills => { gt => 0 } ],sort_by => [ 'total_kills desc', 'total_bkills desc' ],with_objects => [ 'weapon' ],offset => params->{offset},limit => max(25,params->{limit}))};
    return {
	kills => [
	    map {
		my $kill = $_;
		+{
		    weapon_displayname => replace_all($kill->weapon->displayname),
		    (map { 'weapon_'.$_ => $kill->weapon->$_ } grep { !/^id|displayname$/ } $kill->weapon->meta->column_names),
		    (map { $_ => $kill->{$_} } grep { !/^displayname|weapon$/ } $kill->meta->column_names)
		}
	    } @kills
	],
	offset => params->{offset},
	total  => $count
    };
};

get '/player/:id/favorite_maps/:offset/:limit' => sub {
    my $player = Stats::DB::Player->new(id => params->{id});
    my $count = Stats::DB::PlayerMap::Manager->get_player_maps_count(where => [ player_id => $player->id,total_kills => { gt => 0 } ],require_objects => => [ 'map' ]);
    my @maps = map {
	displayname => replace_all($_->map->name),
	total_kills => $_->total_kills
    },@{Stats::DB::PlayerMap::Manager->get_player_maps(where => [ player_id => $player->id, total_kills => { gt => 0 } ],sort_by => 'total_kills desc',with_objects => [ 'map' ],offset => params->{offset},limit => max(25,params->{limit}))};
    return {
	maps   => \@maps,
	offset => params->{offset},
	total  => $count
    };
};

get '/server/:id' => sub {
    my $server = Stats::DB::Server->new(id => params->{id});
    $server->load(speculative => 1);
    return {
	id   => $server->id,
	name => replace_all($server->name),
	url  => $server->url
    };
};

get '/server/:id/players/:offset/:limit' => sub {
    my $where = [ 'player.server_id' => params->{id} ];
    my $count = Stats::DB::PlayerRanking::Manager->get_player_rankings_count(where => $where,require_objects => [ 'player' ]);
    my @players = map {
	+{
	    player  => db_to_hashref($_->player),
	    glicko2 => db_to_hashref($_->glicko2)
	}
    } @{Stats::DB::PlayerRanking::Manager->get_player_rankings(
	where        => $where,
	sort_by      => 'by_glicko2 asc',
	limit        => params->{limit},
	offset       => params->{offset},
	with_objects => [ 'player', 'glicko2' ],
    )};
    return +{
	players => \@players,
	offset  => params->{offset},
	total   => $count
    };
};

get '/server/:id/games/:offset/:limit' => sub {
    my $count = Stats::DB::Game::Manager->get_games_count(where => [ max_players => { gt => 1 }, server_id => params->{id} ]);
    my @games = map +{
	id          => $_->id,
	map         => {
	    id   => $_->map->id,
	    name => replace_all($_->map->name)
	},
	outcome     => $_->outcome // 'draw',
	date        => $_->start->dmy,
	time        => $_->start->hms,
	max_players => $_->max_players,
	start       => $_->start,
	end         => $_->end
    },@{Stats::DB::Game::Manager->get_games(
	where => [
	    server_id   => params->{id},
	    max_players => { gt => 1 },
	    total_kills => { gt => 0 },
	],
	sort_by => 'start desc',
	limit => max(25,params->{limit}),
	offset => params->{offset},
	with_objects => [ 'map' ]
    )};
    return {
	games => \@games,
	offset => params->{offset},
	total  => $count
    };
};

get '/server/:id/maps/:offset/:limit' => sub {
    my $count = Stats::DB::Map::Manager->get_maps_count(where => [ server_id => params->{id} ]);
    my @maps = @{Stats::DB::Map::Manager->get_maps(
        where   => [ server_id => params->{id} ],
	sort_by => 'total_games desc',
	limit   => max(25,params->{limit}),
	offset  => params->{offset},
    )};
    return {
	maps   => [
	    map {
		my $map = $_;
		+{
		    %{db_to_hashref($map)},
		    url => '/map/'.$map->id
		}
	    } @maps
	],
	offset => params->{offset},
	total  => $count
    };
};

get '/server/:id/weapons/:offset/:limit' => sub {
    my $count = Stats::DB::Weapon::Manager->get_weapons_count(where => [ server_id => params->{id} ]);
    my @weapons = map {
	id           => $_->id,
	name         => replace_all($_->displayname),
	total_kills  => $_->total_kills,
	total_bkills => $_->total_bkills
    },@{Stats::DB::Weapon::Manager->get_weapons(
        where   => [ server_id => params->{id} ],
	sort_by => 'total_kills desc',
	limit   => max(25,params->{limit}),
	offset  => params->{offset},
    )};
    return {
	weapons => \@weapons,
	offset  => params->{offset},
	total   => $count
    };
};

get '/game/:id' => sub {
    my $game = Stats::DB::Game->new(id => params->{id});
    $game->load(speculative => 1);
    return {
	game => {
	    id => $game->id,
	    server_id => $game->server_id,

	    as2 => $game->as2,
	    as3 => $game->as3,
	    as4 => $game->as4,
	    as5 => $game->as5,

	    hs2 => $game->hs2,
	    hs3 => $game->hs3,
	    hs4 => $game->hs4,
	    hs5 => $game->hs5,

	    connects => $game->connects,
	    disconnects => $game->disconnects,

	    max_players => $game->max_players,
	    outcome => $game->outcome,

	    sd => $game->sd,
	    wsd => $game->wsd,

	    start => $game->start,
	    end => $game->end,

	    total_kills => $game->total_kills,
	    total_deaths => $game->total_deaths,
	    total_bkills => $game->total_bkills,
	    total_bdeaths => $game->total_bdeaths,
	    total_built => $game->total_built,
	}
    };
};

get '/game/:id/sessions' => sub {
    my @sessions = @{Stats::DB::Session::Manager->get_sessions(query => [ game_id => params->{id}, team => { 'ne' => 'spectator' } ]) // [ ]};
    return {
	sessions => [
	    map { {
		id        => $_->id,
		player_id => $_->player_id,
		name      => $_->name, # replace_all($_->name),
		team      => $_->team
	    } } @sessions
	]
    };
};

get '/session/:id/events' => sub {
    my $session = Stats::DB::Session->new(id => params->{id});
    $session->load(speculative => 1) || return { error => "No such session: ".params->{id} };
    my @weapons = @{Stats::DB::Weapon::Manager->get_weapons() // [ ]};
    my %weapons_by_id = map { $_->id => replace_all($_->displayname) } @weapons;
    my %buildings_by_id = map { $_->id => replace_all($_->name) } @{Stats::DB::Building::Manager->get_buildings() // [ ]};
    return {
	id     => $session->id,
	name   => $session->name,
	events => [ # sort { DateTime->compare($a,$b) } (
	    { time => $session->start, type => "team", team => $session->team },
	    (map {
		my $event = $_;
		{
		    time      => $event->time,
		    type      => ((defined($event->killer_id) && $event->killer_id == $session->id) && "kill") ||
		                 ((defined($event->killed_id) && $event->killed_id == $session->id) && "death") ||
		                 ((defined($event->assist_id) && $event->assist_id == $session->id) && "assist"),
		    weapon    => $weapons_by_id{$event->weapon_id},
		    killer_id => $event->killer_id,
		    killed_id => $event->killed_id,
		    assist_id => $event->assist_id
		}
	    } @{Stats::DB::PlayerEvent::Manager->get_player_events(where => [ or => [ killer_id => $session->id, killed_id => $session->id, assist_id => $session->id ]]) // [ ]}),
	    (map {
		my $event = $_;
		{
		    time     => $event->time,
		    type     => $event->type,
		    building => $buildings_by_id{$event->building_id},
		    weapon   => $weapons_by_id{$event->weapon_id}
		}
	    } @{Stats::DB::BuildingEvent::Manager->get_building_events(where => [ session_id => $session->id ]) // [ ]}),
	    (map {
		my $event = $_;
		{
		    time    => $event->time,
		    type    => 'team',
		    team    => $event->team
		}
	    } @{Stats::DB::TeamEvent::Manager->get_team_events(where => [ session_id => $session->id ]) // [ ]}),
	    { time => $session->end, type => 'end', team => $session->team }
	] # )
    };
};

get '/game/:id/events' => sub {
    my %scoreValues = (
	kill    => 1.5,
	death   => -1,
	assist  => 0.5,
	build   => 1,
	destroy => 2,
	team    => 1,
    );
    my @weapons = @{Stats::DB::Weapon::Manager->get_weapons() // [ ]};
    # my %weapon_names = map { $_->name => replace_all($_->displayname) } @weapons;
    my %weapons_by_id = map { $_->id => replace_all($_->displayname) } @weapons;
    my %buildings_by_id = map { $_->id => replace_all($_->name) } @{Stats::DB::Building::Manager->get_buildings() // [ ]};
    my @sessions = @{Stats::DB::Session::Manager->get_sessions(query => [ game_id => params->{id} ], with_objects => [ 'player' ]) // [ ]};
    my %players_by_session_id = map {
	$_->id => $_->player
    } @sessions;
    my %names_by_session_id = map {
	$_->id => replace_all($_->name); # defined($players_by_session_id{$_->id}) ? $players_by_session_id{$_->id}->displayname : $_->name),
    } @sessions;
    my @events = map {
	my $session = $_;
     	my $player = $session->player;

	my $team = $session->team;
	my $prefix = replace_all($session->name);

	my @player;
	push @player,{ time => $session->start, type => "team", team => $team };
	push @player,map {
	    my $event = $_;
	    {
		time   => $event->time,
		type   => (($event->killer_id == $session->id) && "kill") ||
		          (($event->killed_id == $session->id) && "death") ||
		          (($event->assist_id == $session->id) && "assist"),
		weapon => $weapons_by_id{$event->weapon_id}
	    }
	} @{Stats::DB::PlayerEvent::Manager->get_player_events(where => [ or => [ killer_id => $session->id, killed_id => $session->id, assist_id => $session->id ] ],sort_by => 'time') // [ ]};
	push @player,map {
	    my $event = $_;
	    {
		time     => $event->time,
		type     => $event->type,
		building => $buildings_by_id{$event->building_id},
		weapon   => $weapons_by_id{$event->weapon_id}
	    }
	} @{Stats::DB::BuildingEvent::Manager->get_building_events(where => [ session_id => $session->id ],sort_by => 'time') // [ ]};
	push @player,map {
	    my $event = $_;
	    {
		time    => $event->time,
		type    => 'team',
		team    => $event->team
	    }
	} @{Stats::DB::TeamEvent::Manager->get_team_events(where => [ session_id => $session->id ],sort_by => 'time') // [ ]};
	push @player,{
	    time    => $session->end,
	    type    => 'end'
	};
	{
	    player_id   => 
	    player_name => $prefix, # $player->displayname,
	    entries     => \@player
	};
    } @sessions;
    my @status_events = @{Stats::DB::GameStatusEvent::Manager->get_game_status_events(query => [ game_id => params->{id} ],sort_by => 'time')};
    return {
	events        => \@events,
	status_events => [ map { db_to_hashref($_) } @status_events ],
    };
};

get '/game/:id/sessions/:team/:offset/:limit' => sub {
    my $count = Stats::DB::Session::Manager->get_sessions_count(where => [ game_id => params->{id}, team => params->{team} ]);
    my @sessions = @{Stats::DB::Session::Manager->get_sessions(where => [ game_id => params->{id}, team => params->{team} ],with_objects => [ 'player' ],offset => params->{offset},limit => params->{limit},sort_by => [ 'score desc' ])};
    return {
	sessions => [ map {
	    {
		($_->player ? (
		    player_id   => $_->player->id,
		    player_name => replace_all($_->player->displayname),
		    player_url  => '/player/'.$_->player->id,
		) : (
		    player_id   => undef,
		    player_name => replace_all($_->name),
		    player_url  => undef,
		)),
		ping  => $_->ping // 'N/A',
		score => $_->score // 'N/A',
		start => $_->start,
		end   => $_->end
	    }
	} @sessions ],
	offset  => params->{offset},
	total   => $count
    };
};

get '/map/:id' => sub {
    my $map = Stats::DB::Map->new(id => params->{id});
    unless ($map->load(speculative => 1)) {
	return {
	    error => "Invalid map id: ".params->{id}
	}
    }
    return {
	displayname => replace_all($map->name),
	(map { $_ => $map->{$_} } grep { !/^_/ } $map->meta->column_names)
    }
};

get '/map/:id/players/:offset/:limit' => sub {
    my $map = Stats::DB::Map->new(id => params->{id});
    my $where = [ map_id => $map->id, total_kills => { gt => 0 } ];
    my $count = Stats::DB::Game::Manager->get_games_count(where => $where);
    my @players = map {
	my $killer = $_;
	my %player = map { $_ => $killer->player->$_ } $killer->player->meta->column_names;
	foreach my $override (grep { defined($player{$_}) } $killer->meta->column_names) {
	    $player{$override} = $killer->$override;
	}
	my $glicko2 = Stats::DB::Glicko2->new(player_id => $killer->player->id);
	$glicko2 = undef unless ($glicko2->load(speculative => 1));
	{
	    player  => \%player,
	    glicko2 => { map { $_ => $glicko2->$_ } $glicko2->meta->column_names }
	}
    } @{Stats::DB::PlayerMap::Manager->get_player_maps(where => $where,with_objects => [ 'player' ],sort_by => 'total_kills desc',offset => params->{offset},limit => params->{limit})};
    return {
	players => \@players,
	offset => params->{offset},
	total  => $count
    };
};

get '/map/:id/games/:offset/:limit' => sub {
    my $map = Stats::DB::Map->new(id => params->{id});
    unless ($map->load(speculative => 1)) {
	return {
	    error => "Invalid map id: ".params->{id}
	}
    }
    my $count = Stats::DB::Game::Manager->get_games_count(where => [ max_players => { gt => 1 }, map_id => $map->id ]);
    my @games = map {
	id          => $_->id,
	map         => {
	    id   => $map->id,
	    name => replace_all($map->name)
	},
	outcome     => $_->outcome // 'draw',
	date        => $_->start->dmy,
	time        => $_->start->hms,
	max_players => $_->max_players,
	start       => $_->start,
	end         => $_->end
    },@{Stats::DB::Game::Manager->get_games(where => [ max_players => { gt => 1 }, map_id => $map->id ],sort_by => 'start desc',limit => params->{limit},offset => params->{offset})};
    return {
	games => \@games,
	offset => params->{offset},
	total  => $count
    };
};

true;
