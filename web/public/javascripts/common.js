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
    },

    format_percent: function(value) {
	return Number(100.0 * value).toFixed(2) + '%';
    },

    sum: function(values) {
	return values.reduce(function(p,v) { return Number(p)+Number(v); });
    },

    isDefined: function(value) {
	return !(typeof value === 'undefined' || value === null);
    },

    percent: function(value,total) {
	if (total > 0)
	    return Common.format_percent(value/total);
	else
	    return "N/A";
    },

    bar: function(value,total,text,prefix,suffix) {	
	var result = $('<div class="bar"></div>');
	if (total > 0.0) {
	    var fill_color = '#3355ff';
	    var empty_color = '#ff5533';
	    var fill_value = (100.0 * value / total).toFixed(2);
	    var empty_value = (100.0 - fill_value).toFixed(2);
	    var fill_text = (fill_value >= 40) ? fill_value+'%' : '';
	    var empty_text = (fill_value <= 60) ? empty_value+'%' : '';
	    if (Common.isDefined(text)) fill_text = empty_text = '';
	    result.append(
		'<span class="fill" style="background: '+fill_color+'; left: 0px; top: 0px; height: 100%; width: '+fill_value+'%">'+fill_text+'</span>',
		'<span class="fill" style="background: '+empty_color+'; left: '+fill_value+'%; top: 0px; height: 100%; width: '+empty_value+'%">'+empty_text+'</span>')
	} else {
	    result.append('<span class="empty">N/A</span>');
	}
	if (Common.isDefined(text))
	    result.append('<span class="overlay">'+text+'</span>');
	if (Common.isDefined(prefix))
	    result.append('<span class="prefix">'+prefix+'</span>');	
	if (Common.isDefined(suffix))
	    result.append('<span class="suffix">'+suffix+'</span>');	
	return result;
    },

    
};
