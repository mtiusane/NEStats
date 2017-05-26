$(document).ready(function() {
    var server_id = $('div#games a.data.server_id').attr('href');
    $.get('/json/server/'+server_id,function(data) {
	$('#content div#games').find('.f_server_name').html(data.name);
    });
    Common.scroll_table_multi('#content div#games',{
	'a.data.server_id': function(href) {
	    return function(offset,limit) {
		return '/json/server/'+href+'/games/'+offset+'/'+limit;
	    };
	},
	'a.data.map_id': function(href) {
	    return function(offset,limit) {
		return '/json/map/'+href+'/games/'+offset+'/'+limit;
	    };
	}
    },function(data) {
	return data.games;
    },function(template,element) {
	var entry = template.clone();
	entry.find('.game').html('<span class="name text"><a href="/game/'+element.id+'">'+element.date+' '+element.time+'</a></span>');
	entry.find('.map').html('<span class="name text"><a href="/map/'+element.map.id+'">'+element.map.name+'</a></span>');
	entry.find('.players').html('<span class="number">'+element.max_players+'</span>');
	entry.find('.outcome').html(Common.format_outcome(element.outcome));
	return entry;
    });
});
