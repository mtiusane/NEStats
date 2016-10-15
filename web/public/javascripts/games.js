$(document).ready(function() {
    var server_id = $('#content a.server_id').attr('href');
    Common.scroll_table('#content div#games',function(offset,limit) {
	return '/json/server/'+server_id+'/games/'+offset+'/'+limit;
    },function(data) {
	return data.games;
    },function(template,element) {
	var entry = template.clone();
	entry.find('.game').html('<span class="name text"><a href="/game/'+element.id+'">'+element.date+' '+element.time+' '+element.outcome+'</a></span>');
	entry.find('.map').html('<span class="name text"><a href="/map/'+element.map.id+'">'+element.map.name+'</a></span>');
	entry.find('.players').html('<span class="number">'+element.max_players+'</span>');
	entry.find('.outcome').html('<span>'+element.outcome+'</span>');
	return entry;
    });
});
