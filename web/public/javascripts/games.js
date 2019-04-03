$(document).ready(function() {
    var server_id = $('div#games a.data.server_id').attr('href');
    $.get('/json/server/'+server_id,function(data) {
	    $('#content div#games').find('.f_server_name').html(data.name);
    });
    var map_id = $('div#games a.data.map_id').attr('href');
    $.get('/json/map/'+map_id,function(data) {
        $('#content div#games').find('.f_map_name').html(data.name);
    });
    Common.scroll_table_generic_multi('#content div#games',{
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
    });
});
