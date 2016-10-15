Common = {

    scroll_container: function(container,table,link,elements,line) {
	container = $(container);
	table = $(table);
	var template = table.find('.template').detach();
	template.removeClass('template');
	var loadPage = function(callback) {
	    var offset = table.data('offset');
	    var total = table.data('total');
	    var limit = table.data('limit');
	    table.data('loading',true);
	    $.get(link(offset,limit),function(data) {
		var lines = elements(data);
		$.each(lines,function(index,element) {
		    table.append(line(template,element));
		});
		table.data('total',data.total);
		table.data('offset',table.data('offset')+lines.length);
		table.data('loading',false);
		if (callback) callback();
	    });
	};
	table.data('offset',0);
	table.data('total',0);
	table.data('limit',25);
	loadPage(function() {
	    container.scroll(function() {
		if (table.data('offset') < table.data('total') && !table.data('loading') &&
		    $(this).scrollTop()+$(this).innerHeight() >= $(this)[0].scrollHeight-$(this).height()/4) loadPage();
	    });
	});
    },
    
    scroll_table: function(container,link,elements,line) {
	Common.scroll_container($(container),$(container).find('table'),link,elements,line);
    }
};
