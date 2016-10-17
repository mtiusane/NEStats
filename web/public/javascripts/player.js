$(document).ready(function() {
    var player_id = $('#content div#player a.data.player_id').attr('href');
    $.get('/json/player/'+player_id,function(data) {
	Common.load_fields_generic($('#content div#player_kills'), data);
	Common.load_fields_generic($('#content div#player_glicko'), data);
    });
    Common.scroll_table_generic('#content div#player_deaths',function(offset,limit) {
	return '/json/player/'+player_id+'/deaths_by_weapon/'+offset+'/'+limit;
    },function(data) {
	return data.deaths;
    });
});
