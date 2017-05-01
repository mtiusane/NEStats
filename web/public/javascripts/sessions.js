$(document).ready(function() {
    $('#content div#sessions').each(function(index,div) {
	var game_id = $(div).find('a.game_id').attr('href');
	var team = $(div).find('a.team').attr('href');
	Common.scroll_table_generic(div,function(offset,limit) {
	    return '/json/game/'+game_id+'/sessions/'+team+'/'+offset+'/'+limit;
	},function(data) {
	    return data.sessions;
	});
    });
});
