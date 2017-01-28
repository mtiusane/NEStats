$(document).ready(function() {
    var map_id = $('#content div#map a.data.map_id').attr('href');
    $.get('/json/map/'+map_id,function(data) {
	Common.load_fields_generic($('#content div#map_overall'), data);
    });
});
