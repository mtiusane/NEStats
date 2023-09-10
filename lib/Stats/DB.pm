package Stats::DB;

use strict;
use base qw/Rose::DB/;
use Sys::Hostname;

__PACKAGE__->use_private_registry;
__PACKAGE__->register_db(
    domain   => 'development',
    driver   => 'mysql',
    database => 'stats',
    host     => 'localhost',
    username => 'stats',
    password => 'stats',
    mysql_enable_utf8 => 1,
);
__PACKAGE__->register_db(
    domain   => 'production',
    driver   => $ENV{STATS_DB_DRIVER} // 'mysql',
    database => $ENV{STATS_DB_DATABASE} // 'stats',
    host     => $ENV{STATS_DB_HOST} // 'localhost',
    port     => $ENV{STATS_DB_PORT} // 3306,
    username => $ENV{STATS_DB_USER} // 'stats',
    password => $ENV{STATS_DB_PASSWORD} // 'stats',
    mysql_enable_utf8 => 1,
);

__PACKAGE__->default_domain($ENV{STATS_DB_DOMAIN} // 'development');
__PACKAGE__->default_connect_options({ mysql_auto_reconnect => 1 });

1;
