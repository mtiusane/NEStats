package NEStatsJSON;
use Dancer2;

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
	    (map { $_ => $player->{$_} } (qw/id displayname total_time total_time_h total_time_a total_kills total_deaths total_assists total_bkills total_bdeaths total_built total_sessions total_rqs/)),
	    glicko2 => { map { $_ => $glicko2->{$_} } (qw/rating rd volatility/) }
	}
    } else {
	return { error => 'Unknown player: '.params->{id} }
    }
};

get '/server/:id' => sub {
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
	sort_by      => 'by_kills',
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
    content_type 'application/json';
    return {
	games => \@games,
	offset => params->{offset},
	total  => $count
    };
};

get '/server/:id/maps/:offset/:limit' => sub {
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

};

true;
