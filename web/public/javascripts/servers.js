$(document).ready(function() {
    Common.scroll_table('#content div#servers',function(offset,limit) {
	return '/json/servers/'+offset+'/'+limit;
    },function(data) {
	return data.servers;
    },function(template,element) {
	var entry = template.clone();
	entry.find('.server').html('<span class="name text"><a href="/server/'+element.id+'/games">'+element.name+'</a></span>');
	return entry;
    });
});
