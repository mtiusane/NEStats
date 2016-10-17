$(document).ready(function() {
    $('#content div#weapons').each(function(div_index,div) {
	var server_id = $(div).find('a.data.server_id').attr('href');
	$.get('/json/server/'+server_id,function(data) {
	    $(div).find('.f_server_name').html(data.name);
	});
	Common.scroll_table_generic(div,function(offset,limit) {
	    return '/json/server/'+server_id+'/weapons/'+offset+'/'+limit;
	},function(data) {
	    return data.weapons;
	});
    });
});
