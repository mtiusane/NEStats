-- grant usage on stats.* to 'stats'@'localhost'; -- this will create user 'stats' if it doesn't exist
-- drop user 'stats'@'localhost';
-- drop database if exists stats;

-- create database stats;
use stats;

-- Create default user with full privileges
-- create user 'stats'@'localhost' identified by 'stats';
-- grant all privileges on stats.* to 'stats'@'localhost';
-- flush privileges;

drop table if exists player_kills;
drop table if exists player_rankings;
drop table if exists timestamps;
drop table if exists glicko2_scores;
drop table if exists player_glicko2;
drop table if exists player_maps;
drop table if exists game_status_events;
drop table if exists team_events;
drop table if exists player_events;
drop table if exists building_events;
drop table if exists buildings;
drop table if exists player_weapons;
drop table if exists session_weapons;
drop table if exists game_weapons;
drop table if exists sessions;
drop table if exists game_clan_members;
drop table if exists game_clans;
drop table if exists games;
drop table if exists maps;
drop table if exists weapons;
drop table if exists clan_members;
drop table if exists clan_events;
drop table if exists clans;
drop table if exists players;
drop table if exists servers;

create table servers (
       id int not null primary key auto_increment,
       name varchar(64) not null unique,
       ip varchar(40) not null,
       url varchar(64)
);

create table players (
       id int not null primary key auto_increment,
       server_id int not null references servers(id),
       guid varchar(32) not null,
       name varchar(128) not null,
       displayname varchar(128) not null,

       total_time int not null default 0,
       total_time_h int not null default 0,
       total_time_a int not null default 0,

       total_kills int not null default 0,
       total_deaths int not null default 0,
       total_assists int not null default 0,
       total_bkills int not null default 0,
       total_bdeaths int not null default 0,
       total_built int not null default 0,

       total_sessions int not null default 0,
       total_rqs int not null default 0,
       total_games int not null default 0,

       foreign key(server_id) references servers(id),
       unique(server_id,guid)
);

create table clans (
       id int not null primary key auto_increment,
       server_id int not null references servers(id),

       tag varchar(32) not null unique,
       name varchar(32) not null,

       total_time int not null default 0,
       total_time_h int not null default 0,
       total_time_a int not null default 0,

       total_kills int not null default 0,
       total_deaths int not null default 0,
       total_bkills int not null default 0,
       total_bdeaths int not null default 0,
       total_built int not null default 0,

       total_sessions int not null default 0,
       total_rqs int not null default 0,

       foreign key(server_id) references servers(id)
);

create table clan_events (
       id int not null primary key auto_increment,
       clan_id int not null references clans(id),
       time datetime not null,
       type enum('create','add','remove','resign','destroy') not null,

       player_id int not null references players(id),
       target_player_id int references players(id),

       foreign key (clan_id) references clans(id),
       foreign key (player_id) references players(id),
       foreign key (target_player_id) references players(id)
);

create table clan_members (
       clan_id int not null references clans(id),
       player_id int not null references clans(id),

       role enum('leader','member') not null default 'member',

       last_event_id int not null references clan_events(id),

       foreign key (clan_id) references clans(id),
       foreign key (player_id) references players(id),
       foreign key (last_event_id) references clan_events(id),

       primary key (clan_id,player_id)
);

create table weapons (
       id int not null primary key auto_increment,
       server_id int not null references servers(id),
       name varchar(32) not null,
       displayname varchar(64) not null,
       total_kills int not null default 0,
       total_bkills int not null default 0,

       foreign key (server_id) references servers(id),
       unique (server_id,name)
);

create table maps (
       id int not null primary key auto_increment,
       server_id int not null references servers(id),
       name varchar(32) not null unique,

       total_kills int not null default 0,
       total_deaths int not null default 0,
       total_bkills int not null default 0,
       total_bdeaths int not null default 0,
       total_loaded int not null default 0,
       total_games int not null default 0,
       total_time int not null default 0,

       -- total human/alien kills
       total_hkills int not null default 0,
       total_akills int not null default 0,

       -- total human/alien buildings killed
       total_hbkills int not null default 0,
       total_abkills int not null default 0,

       -- total human/alien deaths to buildings
       total_hbdeaths int not null default 0,
       total_abdeaths int not null default 0,

       human_wins int not null default 0,
       alien_wins int not null default 0,
       draws int not null default 0,

       foreign key (server_id) references servers(id)
);

create table games (
       id int not null primary key auto_increment,
       map_id int not null references maps(id),
       server_id int not null references servers(id),

       mod_version varchar(32) not null default 'pre-7.6d',

       start datetime not null,
       end datetime,
       wsd datetime,
       sd datetime,
       hs2 datetime,
       as2 datetime,
       hs3 datetime,
       as3 datetime,
       hs4 datetime,
       as4 datetime,
       hs5 datetime,
       as5 datetime,
       outcome varchar(64),
       total_kills int not null default 0,
       total_deaths int not null default 0,
       total_bkills int not null default 0,
       total_bdeaths int not null default 0,
       total_built int not null default 0,

       max_players int not null default 0,
       connects int not null default 0,
       disconnects int not null default 0,
       -- TODO: max_players_a and max_players_h

       import_complete boolean not null default 0,

       foreign key(map_id) references maps(id),
       foreign key(server_id) references servers(id),

       unique (server_id,start)
);

-- Snapshot of each clan participating in the game recorded when the first player in that clan joins
create table game_clans (
       clan_id int not null references clans(id),
       game_id int not null references games(id),

       tag varchar(32) not null,
       name varchar(32) not null,

       foreign key (clan_id) references clans(id),
       foreign key (game_id) references games(id),

       primary key (clan_id,game_id)
);

-- Snapshot of each participating clan's members at time of joining of the first player in game
create table game_clan_members (
       game_clan_id int not null references game_clans(id),
       player_id int not null references players(id),

       -- foreign key (game_clan_id) references game_clans(id),
       -- foreign key (player_id) references players(id),

       primary key (game_clan_id,player_id)
);

create table sessions (
       id int not null primary key auto_increment,
       player_id int references players(id),
       game_id int not null references games(id),
       team enum('human','alien','spectator') not null,
       start datetime not null,
       ip varchar(40) not null,
       end datetime,
       score int,
       ping int,
       name varchar(128),
       total_kills int not null default 0,
       total_deaths int not null default 0,
       total_assists int not null default 0,
       total_bkills int not null default 0,
       total_bdeaths int not null default 0,
       total_built int not null default 0,

       foreign key(player_id) references players(id),
       foreign key(game_id) references games(id)
);

create table game_weapons (
       game_id int not null references games(id),
       weapon_id int not null references weapons(id),

       damage_per_shot int not null default 0,

       -- Accumulated values from all players
       num_fired int not null default 0,
       damage_enemy int not null default 0,
       damage_friendly int not null default 0,
       damage_enemy_buildable int not null default 0,
       damage_friendly_buildable int not null default 0,
       damage_self int not null default 0,

       foreign key (game_id) references games(id),
       foreign key (weapon_id) references weapons(id),

       primary key (game_id,weapon_id)
);

create table session_weapons (
       session_id int not null references sessions(id),
       weapon_id int not null references weapons(id),

       -- NOTE: Duplicate field from game_weapons, this is done to avoid table joins when querying the data
       damage_per_shot int not null default 0,

       num_fired int not null default 0,
       damage_enemy int not null default 0,
       damage_friendly int not null default 0,
       damage_enemy_buildable int not null default 0,
       damage_friendly_buildable int not null default 0,
       damage_self int not null default 0,

       foreign key (session_id) references sessions(id),
       foreign key (weapon_id) references weapons(id),

       primary key (session_id,weapon_id)
);

create table player_weapons (
       player_id int not null,
       weapon_id int not null,

       total_kills int not null default 0,
       total_bkills int not null default 0,
       total_deaths int not null default 0,
       total_bdeaths int not null default 0,

       num_fired int not null default 0,
       damage_enemy int not null default 0,
       damage_friendly int not null default 0,
       damage_enemy_buildable int not null default 0,
       damage_friendly_buildable int not null default 0,
       damage_self int not null default 0,

       foreign key (player_id) references players(id),
       foreign key (weapon_id) references weapons(id),

       primary key (player_id,weapon_id)
);

create table buildings (
       id int not null primary key auto_increment,
       server_id int not null references servers(id),
       name varchar(32) not null unique,

       foreign key (server_id) references servers(id)
);

create table building_events (
       id int not null primary key auto_increment,
       type enum('build','destroy') not null,
       time datetime not null,
       weapon_id int not null references weapons(id),
       building_id int not null references buildings(id),
       session_id int references sessions(id),

       foreign key (weapon_id) references weapons(id),
       foreign key (building_id) references buildings(id),
       foreign key (session_id) references sessions(id)
);

create table player_events (
       id int not null primary key auto_increment,
       time datetime not null,
       weapon_id int not null references weapons(id),
       killed_id int not null references sessions(id),
       killer_id int references sessions(id),
       assist_id int references sessions(id),
       foreign key (weapon_id) references weapons(id),
       foreign key (killed_id) references sessions(id),
       foreign key (killer_id) references sessions(id)
);

create table team_events (
       id int not null primary key auto_increment,
       time datetime not null,
       team enum('human','alien','spectator') not null,
       session_id int not null references sessions(id),

       foreign key (session_id) references sessions(id)
);
/***
create table game_events (
       id int not null primary key auto_increment,
       game_id int not null references games(id),
       time datetime not null,
       
       type enum('kill','death','assist','build','destroy','team') not null,
       team enum('human','alien','spectator') not null,

       player_id int references sessions(id) not null,
       target_id int references sessions(id),

       weapon_id int references weapons(id),
       building_id int not null references buildings(id),

       foreign key (player_id) references players(id),
       foreign key (target_id) references players(id),

       foreign key (weapon_id) references weapons(id),
       foreign key (building_id) references buildings(id)
);
***/
create table game_status_events (
       id int not null primary key auto_increment,
       game_id int not null references games(id),
       time datetime not null,
       num_a int not null,
       num_h int not null,
       momentum_a int not null,
       momentum_h int not null,
       mine_rate float not null, -- lmr
       mine_efficiency_a int not null,
       mine_efficiency_h int not null,
       bp_a int not null,
       bp_h int not null,
       building_value_a int not null,
       building_value_h int not null,
       credits_a int not null,
       credits_h int not null,
       team_value_a int not null,
       team_value_h int not null,
       
       foreign key (game_id) references games(id)
);

create table player_maps (
       player_id int not null,
       map_id int not null,
       
       total_games int not null default 0,
       total_sessions int not null default 0,
       total_rqs int not null default 0,
       total_time int not null default 0,
       total_time_a int not null default 0,
       total_time_h int not null default 0,

       total_kills int not null default 0,
       total_bkills int not null default 0,
       total_assists int not null default 0,
       total_deaths int not null default 0,
       total_bdeaths int not null default 0,
       total_built int not null default 0,

       foreign key (player_id) references players(id),
       foreign key (map_id) references maps(id),

       primary key (player_id,map_id)      
);

create table player_kills (
       player_id int not null references players(id),
       target_id int not null references players(id),
       -- weapon_id int not null references weapons(id),

       total_games int not null default 0,
       total_sessions int not null default 0,

       total_kills int not null default 0,
       total_kills_a int not null default 0,
       total_kills_h int not null default 0,

       total_assists int not null default 0,
       total_assists_a int not null default 0,
       total_assists_h int not null default 0,

       foreign key (player_id) references players(id),
       foreign key (target_id) references players(id),
       -- foreign key (weapon_id) references weapons(id),

       primary key (player_id,target_id) -- ,weapon_id
);

-- Glicko2 ratings

create table player_glicko2 (
       id int not null primary key auto_increment,
       player_id int not null references players(id),

       rating float not null default 1500,
       rd float not null default 350,
       volatility float not null default 0.06,

       unique index (player_id),
       foreign key (player_id) references players(id)
);

-- Glicko2 games recorded

create table glicko2_scores (
       id int not null primary key auto_increment,
       glicko2_id int not null references player_glicko2(id),
       session_id int not null references sessions(id),

       score float not null default 0.0,
       opponent_rating float not null default 1500,
       opponent_rd float not null default 350,
       opponent_volatility float not null default 0.06, -- TODO: Not used?

       is_new boolean not null default true, -- set to false once this is included in player's rating

       foreign key (glicko2_id) references player_glicko2(id),
       foreign key (session_id) references sessions(id)
);

create table timestamps (
       id int not null primary key auto_increment,

       server_id int not null,

       name varchar(32) not null,
       value timestamp not null default now(),

       unique key (server_id,name)
);

-- Temporary tables used as aid in queries

create table player_rankings (
       player_id int not null,
       server_id int not null,
       
       glicko2_id int not null references player_glicko2(id),

       by_name int not null default 0,

       by_glicko2 int not null default 0,

       by_kills int not null default 0,
       by_deaths int not null default 0,
       by_assists int not null default 0,
       by_buildings_built int not null default 0,
       by_buildings_killed int not null default 0,
       by_kills_per_deaths int not null default 0,
       by_bkills_per_deaths int not null default 0,
       
       by_team_aliens int not null default 0,
       by_team_humans int not null default 0,

       by_rq int not null default 0,

       primary key (player_id,server_id),
       unique index (player_id,server_id),
       foreign key (player_id) references players(id),
       foreign key (server_id) references servers(id),
       foreign key (glicko2_id) references player_glicko2(id)
);
