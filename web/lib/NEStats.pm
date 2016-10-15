package NEStats;
use Dancer ':syntax';

our $VERSION = '0.1';

use List::Util qw/min max/;
use List::MoreUtils qw/zip/;
use DateTime::Format::Duration;

use lib '../lib';

use Stats::Emoticons qw/$emoticons/;

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

use Glicko2::Player;

use Rose::DB::Object::Helpers qw/as_tree/;

# -- Template handlers --

get '/' => sub {
    redirect '/servers'; # template 'index';
};

get '/servers' => sub {
    template 'servers';
};

get '/games' => sub {
    template 'games';
};

get '/maps' => sub {
    template 'maps';
};

get '/map/:id' => sub {
    template 'map',{ map_id => params->{id} };
};

get '/game/:id' => sub {
    template 'game',{ game_id => params->{id} };
};

get '/player/:id' => sub {
    template 'player',{ player_id => params->{id} };
};

get '/server/:id/games' => sub {
    template 'games',{ server_id => params->{id} };
};

get '/server/:id/players' => sub {
    template 'players',{ server_id => params->{id} };
};

get '/server/:id/maps' => sub {
    template 'maps',{ server_id => params->{id} };
};

# -- JSON handlers --

get '/json/servers/:offset/:limit' => sub {
    # TODO: Order query by player count and/or name
    my $count = Stats::DB::Server::Manager->get_servers_count();
    # my $games_count = Stats::DB::Game::Manager->get_games_count(where => [ server_id => params->{server} ]);
    # my $last_game = Stats::DB::Game::Manager->get_games
    my @servers = map +{
	id          => $_->id,
	name        => $_->name,
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

get '/json/games/:offset/:limit' => sub {

};

get '/json/maps/:offset/:limit' => sub {
};

get '/json/player/:id' => sub {
    my $player  = Stats::DB::Player->new(id => params->{id});
    my $glicko2 = Stats::DB::Glicko2->new(player_id => params->{id});
    if ($player->load(speculative => 1)) {
	$glicko2 = Glicko2::Player->new unless($glicko2->load(speculative => 1));
	return {
	    (map { $_ => $player->{$_} } (qw/id displayname total_time total_time_h total_time_a total_kills total_deaths total_assists total_bkills total_bdeaths total_built total_sessions total_rqs/)),
	    glicko2 => { map { $_ => $glicko2->{$_} } (qw/rating rd volatility/) }
	}
    } else {
	return { error => 'Unknown player: '.params->{id} }
    }
};

get '/json/server/:id' => sub {
};

get '/json/server/:id/players/:offset/limit' => sub {
};

get '/json/server/:id/games/:offset/:limit' => sub {
    my $count = Stats::DB::Game::Manager->get_games_count(where => [ max_players => { gt => 1 }, server_id => params->{server} ]);
    my @games = map +{
	id          => $_->id,
	map         => {
	    id   => $_->map->id,
	    name => $_->map->name
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

get '/json/server/:id/maps/:offset/:limit' => sub {
};

get '/json/game/:id' => sub {
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

get '/json/game/:id/sessions/:team/:offset/:limit' => sub {
    my $count = Stats::DB::Session::Manager->get_sessions_count(where => [ game_id => params->{id}, team => params->{team} ]);
    my @sessions = @{Stats::DB::Session::Manager->get_sessions(where => [ game_id => params->{id}, team => params->{team} ],with_objects => [ 'player' ],offset => params->{offset},limit => params->{limit})};
    return {
	sessions => [ map {
	    {
		player => $_->player ? {
		    id   => $_->player->id,
		    name => $_->player->displayname
		} : {
		    id   => undef,
		    name => $_->name
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

get '/json/map/:id' => sub {

};

true;
