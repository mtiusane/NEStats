$(document).ready(function() {
    var map_id = $('#content div#map a.data.map_id').attr('href');
    $.get('/json/map/'+map_id,function(data) {
	Common.load_fields_generic($('#content div#map_overall'), data);
    });
    Common.scroll_table_generic('#content div#map_top_killers',function(offset,limit) {
	return '/json/map/'+map_id+'/top_killers/'+offset+'/'+limit;
    },function(data) {
	return data.top_killers;
    });
    Common.scroll_table_generic('#content div#map_recent_games',function(offset,limit) {
	return '/json/map/'+map_id+'/recent_games/'+offset+'/'+limit;
    },function(data) {
	return data.recent_games;
    });
});
