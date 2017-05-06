$(document).ready(function() {
    var player_id = $('#content div#player a.data.player_id').attr('href');
    $.get('/json/player/'+player_id,function(data) {
	Common.load_fields_generic($('#content div#player_overall'), data);
	Common.load_fields_generic($('#content div#player_glicko'), data);
    });
    Common.scroll_table_generic('#content div#player_deaths',function(offset,limit) {
	return '/json/player/'+player_id+'/deaths_by_weapon/'+offset+'/'+limit;
    },function(data) {
	return data.deaths;
    });
    Common.scroll_table_generic('#content div#player_kills',function(offset,limit) {
	return '/json/player/'+player_id+'/kills_by_weapon/'+offset+'/'+limit;
    },function(data) {
	return data.kills;
    });
    Common.scroll_table_generic('#content div#player_maps',function(offset,limit) {
	return '/json/player/'+player_id+'/favorite_maps/'+offset+'/'+limit;
    },function(data) {
	return data.maps;
    });
    Common.scroll_table_generic('#content div#player_top_kills',function(offset,limit) {
	return '/json/player/'+player_id+'/most_kills/'+offset+'/'+limit;
    },function(data) {
	return data.kills;
    });
    Common.scroll_table_generic('#content div#player_top_killers',function(offset,limit) {
	return '/json/player/'+player_id+'/most_deaths/'+offset+'/'+limit;
    },function(data) {
	return data.kills;
    });

});
