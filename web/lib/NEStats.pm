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

my $global_menu = [
    { link => '/servers', title => 'Servers' },
    { link => '/server/1/games', title => 'Games' },
    { link => '/server/1/players', title => 'Players' },
    { link => '/server/1/maps', title => 'Maps' },
    { link => '/server/1/weapons', title => 'Weapons' }
];

get '/' => sub {
    redirect '/servers'; # template 'index';
};

get '/servers' => sub {
    template 'servers',{ menu => $global_menu };
};

get '/games' => sub {
    template 'games',{ menu => $global_menu };
};

get '/maps' => sub {
    template 'maps',{ menu => $global_menu };
};

get '/map/:id' => sub {
    template 'map',{ menu => $global_menu, map_id => params->{id} };
};

get '/game/:id' => sub {
    template 'game',{ menu => $global_menu, game_id => params->{id} };
};

get '/player/:id' => sub {
    template 'player',{ menu => $global_menu, player_id => params->{id} };
};

get '/server/:id/games' => sub {
    template 'games',{ menu => $global_menu, server_id => params->{id} };
};

get '/server/:id/players' => sub {
    template 'players',{ menu => $global_menu, server_id => params->{id} };
};

get '/server/:id/maps' => sub {
    template 'maps',{ menu => $global_menu, server_id => params->{id} };
};

get '/server/:id/weapons' => sub {
    template 'weapons',{ menu => $global_menu, server_id => params->{id} };
};

true;
