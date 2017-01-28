$(document).ready(function() {
    var selectors = {
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
    };
    $('#content div#games').each(function(div_index,div) {
	for(var selector in selectors) {
	    var field_id = $(div).find(selector);
	    if (field_id.length) {
		var url = selectors[selector](field_id.attr('href'));
		Common.scroll_table(div,function(offset,limit) {
		    return url(offset,limit);
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
	    }
	}
    });
});
