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

# set serializer => 'Mutable';
set content_type => 'text/html';

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

true;
