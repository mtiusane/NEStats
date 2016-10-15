package Stats::LogParser::Tremulous;

use strict;
use warnings;
use base qw/Stats::LogParser/;

use Stats::DB::Weapon;

sub new {
    my ($class,%params) = @_;
    my $self = $class->SUPER::new(sub { initializeServer($_[0]); },%params);
    bless($self,$class);
}

sub initializeServer {
    my ($server) = @_;
    my %weapons = (
	'MOD_ABOMB' => 'Basilisk Bomb [basilisk]',
	'MOD_ABUILDER_CLAW' => 'Granger Claw [granger]',
	'MOD_ASPAWN' => 'Exploding Alien Building [egg]',
	'MOD_ATUBE' => 'Acid Tube [acidtube]',
	'MOD_BLASTER' => 'Blaster [blaster]',
	'MOD_CHAINGUN' => 'Chaingun [chaingun]',
	'MOD_CONSTRUCT' => 'Construct [ckit]',
	'MOD_CRUSH' => 'Crush',
	'MOD_DECONSTRUCT' => 'Deconstruct [ckit] [granger]',
	'MOD_FALLING' => 'Falling',
	'MOD_FLAMER' => 'Flamer [flamer]',
	'MOD_FLAMER_SPLASH' => 'Flamer Splash [flamer]',
	'MOD_FLAMES' => 'Tyrant Flames [tyrant]',
	'MOD_GRENADE' => 'Grenade [grenade]',
	'MOD_HDOG' => 'Hot Dog',
	'MOD_HSPAWN' => 'Exploding Human Building [telenode]',
	'MOD_INFECTION' => 'Infection [dretch]',
	'MOD_LASGUN' => 'Lasgun [lasgun]',
	'MOD_LAVA' => 'Lava',
	'MOD_LCANNON' => 'Lucifer Cannon [lcannon]',
	'MOD_LCANNON_SPLASH' => 'Lucifer Cannon Splash [lcannon]',
	'MOD_LEVEL0_BITE' => 'Dretch Bite [dretch]',
	'MOD_LEVEL1_CLAW	' => 'Basilisk Claw [basilisk]',
	'MOD_LEVEL1_PCLOUD' => 'Adv. Basilisk Gas [basilisk]',
	'MOD_LEVEL2_BOUNCEBALL' => 'Adv. Marauder Barb [advmarauder]',
	'MOD_LEVEL2_CLAW' => 'Marauder Claw [marauder]',
	'MOD_LEVEL2_ZAP' => 'Adv. Marauder Zap [advmarauder]',
	'MOD_LEVEL3_BOUNCEBALL' => 'Adv. Goon Barb [advdragoon]',
	'MOD_LEVEL3_CLAW' => 'Dragoon Claw [dragoon]',
	'MOD_LEVEL3_POUNCE' => 'Dragoon Pounce [dragoon]',
	'MOD_LEVEL4_CLAW' => 'Tyrant Claw [tyrant]',
	'MOD_LEVEL4_CRUSH' => 'Tyrant Crush [tyrant]',
	'MOD_LEVEL4_TRAMPLE' => 'Tyrant Trample [tyrant]',
	'MOD_LEVEL5_BOUNCEBALL' => 'Hummel Prickles',
	'MOD_LEVEL5_CLAW	' => 'Hummel Claw',
	'MOD_LEVEL5_POUNCE' => 'Hummel Pounce',
	'MOD_LEVEL5_PRICKLES' => 'Hummel Prickles',
	'MOD_LEVEL5_ZAP' => 'Hummel Zap',
	'MOD_MACHINEGUN' => 'Rifle [rifle]',
	'MOD_MD2' => 'Mass Driver Projectile [mdriver]',
	'MOD_MDRIVER' => 'Mass Driver [mdriver]',
	'MOD_MGTURRET' => 'Turret [turret]',
	'MOD_MGTURRET2' => 'Flame Turret [turret]',
	'MOD_MINE' => 'Mine [grenade]',
	'MOD_NOBP' => 'No Build Points',
	'MOD_NOCREEP' => 'No Creep',
	'MOD_OVERMIND' => 'Overmind [overmind]',
	'MOD_PAINSAW' => 'Painsaw [painsaw]',
	'MOD_POISON' => 'Poison [booster]',
	'MOD_PRIFLE' => 'Pulse Rifle [prifle]',
	'MOD_PSAWBLADE' => 'Painsaw Blade [painsaw]',
	'MOD_REACTOR' => 'Reactor [reactor]',
	'MOD_ROCKETL' => 'Rocket Launcher',
	'MOD_ROCKETL_SPLASH' => 'Rocket Launcher Splash',
	'MOD_SHOTGUN' => 'Shotgun [shotgun]',
	'MOD_SLAP' => 'Slap',
	'MOD_SLIME' => 'Infestation Slime',
	'MOD_SLOWBLOB' => 'Granger Spit [advgranger]',
	'MOD_SMOKE' => 'Smoke Grenade',
	'MOD_SPITEFUL_ABCESS' => 'Spiteful Abcess',
	'MOD_SUICIDE' => 'Suicide',
	'MOD_SWARM' => 'Hive Swarm [hive]',
	'MOD_TELEFRAG' => 'Telefrag',
	'MOD_TESLAGEN' => 'Tesla Generator',
	'MOD_TRIGGER_HURT' => 'World',
	'MOD_UNKNOWN' => 'Unknown',
	'MOD_WATER' => 'Water (Drowning)',
    );
    foreach my $mod (sort { $a cmp $b } keys(%weapons)) {
	my $weapon = Stats::DB::Weapon->new(server_id => $server->id,name => $mod);
	$weapon->load(speculative => 1);
	$weapon->displayname($weapons{$mod});
	$weapon->save;
    }
}

1;
