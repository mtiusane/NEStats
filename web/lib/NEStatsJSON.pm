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

use Stats::Util qw/replace_all/;

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

};

get '/maps/:offset/:limit' => sub {
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
		    (map { 'weapon_'.$_ => $death->weapon->$_ } grep { !/^id|displayname$/ } keys(%{$death->weapon})),
		    (map { $_ => $death->{$_} } grep { !/^displayname|weapon$/ } keys(%$death))
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
		    (map { 'weapon_'.$_ => $kill->weapon->$_ } grep { !/^id|displayname$/ } keys(%{$kill->weapon})),
		    (map { $_ => $kill->{$_} } grep { !/^displayname|weapon$/ } keys(%$kill))
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
	    player  => $_->player,
	    glicko2 => $_->glicko2
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
    },@{Stats::DB::Game::Manager->get_games(
	where => [
	    server_id   => params->{id},
	    max_players => { gt => 1 },
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
	maps   => \@maps,
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
	    total_built => $game->total_built
	}
    };
};

get '/game/:id/sessions/:team/:offset/:limit' => sub {
    my $count = Stats::DB::Session::Manager->get_sessions_count(where => [ game_id => params->{id}, team => params->{team} ]);
    my @sessions = @{Stats::DB::Session::Manager->get_sessions(where => [ game_id => params->{id}, team => params->{team} ],with_objects => [ 'player' ],offset => params->{offset},limit => params->{limit})};
    return {
	sessions => [ map {
	    {
		player => $_->player ? {
		    id   => $_->player->id,
		    name => replace_all($_->player->displayname)
		} : {
		    id   => undef,
		    name => replace_all($_->name)
		},
		ping  => $_->ping,
		score => $_->score,
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
	(map { $_ => $map->{$_} } grep { !/^_/ } keys(%$map))
    }
};

get '/map/:id/top_killers/:offset/:limit' => sub {
    my $map = Stats::DB::Map->new(id => params->{id});
    my $count = Stats::DB::Game::Manager->get_games_count(where => [ map_id => $map->id ]); # , max_players => { gt => 0 }
    my @top_killers = @{Stats::DB::PlayerMap::Manager->get_player_maps(where => [ map_id => $map->id, total_kills => { gt => 0 } ],with_objects => [ 'player' ],sort_by => 'total_kills desc',offset => params->{offset},limit => params->{limit})};
    return {
	top_killers => [
	    map {
		my $killer = $_;
		{
		    player_displayname => replace_all($killer->player->displayname),
		    (map { $_ => $killer->{$_} } grep { !/^_/ } grep { !/^player$/ } keys(%$killer))
		}
	    } @top_killers
	],
	offset => params->{offset},
	total  => $count
    };
	    
};

get '/map/:id/recent_games/:offset/:limit' => sub {
    my $map = Stats::DB::Map->new(id => params->{id});
    unless ($map->load(speculative => 1)) {
	return {
	    error => "Invalid map id: ".params->{id}
	}
    }
    my $count = Stats::DB::Game::Manager->get_games_count(where => [ max_players => { gt => 1 }, map_id => $map->id ]);
    my @games = @{Stats::DB::Game::Manager->get_games(where => [ max_players => { gt => 1 }, map_id => $map->id ],sort_by => 'start desc',limit => params->{limit},offset => params->{offset})};
    return {
	recent_games => [
	    map {
		my $game = $_;
		+{
		    # map_displayname => replace_all($map->name),
		    map { $_ => $game->{$_} } grep { !/^_/ } keys(%$game)
		}
	    } @games
	],
	offset => params->{offset},
	total  => $count
    };
};

true;
