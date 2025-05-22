package Stats::DB;

use strict;
use base qw/Rose::DB/;
use Sys::Hostname;

my $db_driver_args = {
    mysql => {
	db      => { mysql_enable_utf8    => 1 },
	connect => { mysql_auto_reconnect => 1 },
    },
    MariaDB => {
	db      => { mariadb_enable_utf8    => 1 },
	connect => { mariadb_auto_reconnect => 1 },
    },
};
my $db_driver = $ENV{STATS_DB_DRIVER} // 'mysql';

__PACKAGE__->use_private_registry;
__PACKAGE__->register_db(
    domain   => 'development',
    driver   => $db_driver,
    database => 'stats',
    host     => 'localhost',
    username => 'stats',
    password => 'stats',
    %{$db_driver_args->{$db_driver}->{db}},
);
__PACKAGE__->register_db(
    domain   => 'production',
    driver   => $db_driver,
    database => $ENV{STATS_DB_DATABASE} // 'stats',
    host     => $ENV{STATS_DB_HOST} // 'localhost',
    port     => $ENV{STATS_DB_PORT} // 3306,
    username => $ENV{STATS_DB_USER} // 'stats',
    password => $ENV{STATS_DB_PASSWORD} // 'stats',
    %{$db_driver_args->{$db_driver}->{db}},
);

__PACKAGE__->default_domain($ENV{STATS_DB_DOMAIN} // 'development');
__PACKAGE__->default_connect_options({ %{$db_driver_args->{$db_driver}->{connect}} });

1;
