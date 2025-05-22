package NEStats;
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

# -- Template handlers --

set content_type => 'text/html';

sub global_menu
{
    my ($server_id, %params) = @_;
    my @servers = @{Stats::DB::Server::Manager->get_servers(
        sort_by => 'name asc',
        limit  => 25,
        offset => 0,
        # with_objects => [ 'map' ]
    )};
    my $server = $server_id && Stats::DB::Server->new(id => $server_id);
    return {
        menu => [
            { link => '/servers', title => 'Servers' },
            (defined($server_id) ? (
                { link => "/server/$server_id/games", title => 'Games' },
                { link => "/server/$server_id/players", title => 'Players' },
                { link => "/server/$server_id/maps", title => 'Maps' },
                { link => "/server/$server_id/weapons", title => 'Weapons' }
            ) : ())
        ],
        servers => [
            map { +{ id => $_->id, displayname => $_->name } } @servers
        ],
        (defined($server_id) ? (server_id => $server->id, server => { id => $server->id, displayname => $server->name }) : ()),
        %params
    };
}

get '/' => sub {
    redirect '/servers'; # template 'index';
};

get '/servers' => sub {
    template 'servers', global_menu(params->{server_id});
};

get '/games' => sub {
    template 'games', global_menu(params->{server_id});
};

get '/maps' => sub {
    template 'maps', global_menu(params->{server_id});
};

get '/map/:id' => sub {
    template 'map', global_menu(params->{server_id}, map_id => params->{id});
};

get '/game/:id' => sub {
    template 'game', global_menu(params->{server_id}, game_id => params->{id});
};

get '/player/:id' => sub {
    template 'player', global_menu(params->{server_id}, player_id => params->{id});
};

get '/server/:id/games' => sub {
    template 'games', global_menu(params->{id});
};

get '/server/:id/players' => sub {
    template 'players', global_menu(params->{id});
};

get '/server/:id/players/name=:name' => sub {
    template 'players', global_menu(params->{id}, name => params->{name});
};

get '/server/:id/maps' => sub {
    template 'maps', global_menu(params->{id});
};

get '/server/:id/weapons' => sub {
    template 'weapons', global_menu(params->{id});
};

true;
