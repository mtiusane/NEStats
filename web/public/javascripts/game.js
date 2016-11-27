$(document).ready(function() {
    $('div#game').each(function(index) {
	var div = $(this);
	var anchor = div.find('a.data.game_id');
	var game_id = anchor.attr('href');
	anchor.remove();
	var table = div.find('table');
	var template = table.find('.template').detach();
	template.removeClass('template');
	table.data('loading',true);
	$.get('/json/game/'+game_id,function(data) {
	    var entry = template.clone();
	    Common.load_fields_generic(entry,data.game);
	    table.append(entry);
	    table.data('loading',false);
	});
    });
});
