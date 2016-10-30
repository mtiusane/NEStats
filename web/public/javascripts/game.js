$(document).ready(function() {
    $('#content div.game').each(function(index) {
	var div = $(this);
	var game_id = div.find('a.data.game_id').attr('href');
	$.get('/json/game/'+game_id,function(data) {
	   // div.find('.start').html('<span class="
	});
    });
});
