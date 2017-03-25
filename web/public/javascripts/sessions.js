$(document).ready(function() {
    $('#content div#sessions').each(function(index,div) {
	var game_id = div.find('a.game_id').attr('href');
	var team = div.find('a.team').attr('href');
	Common.scroll_table_generic(div,function(offset,limit) {
	    return '/json/game/'+game_id+'/sessions/'+team+'/'+offset+'/'+limit;
	},function(data) {
	    return data.sessions;
	}/*,function(template,element) {
	    var entry = template.clone();
   	    entry.find('.index').html('NA');
	    entry.find('.player').html('<span class="name text"><a href="/player/'+element.player.id+'">'+element.player.name+'</a></span>');
	    entry.find('.ping').html('<span class="number">'+element.ping+'</span>');
	    entry.find('.score').html('<span class="number">'+element.score+'</span>');
	    return entry;
	}*/);
    });
});
