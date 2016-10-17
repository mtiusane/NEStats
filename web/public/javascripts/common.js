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
		    table.append(line(template,element,offset+index));
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

    load_fields_generic: function(container,data) {
	$.each(data,function(name,value) {
	    if (!name.startsWith('_')) {
		$.each(container.find('.f_'+name),function(field_index,field) {
		    $(field).html(value);
		});
	    }
	});
    },

    scroll_table_generic: function(container,link,elements) {
    	Common.scroll_table(container,link,elements,function(template,data,index) {
	    var entry = template.clone();
	    Common.load_fields_generic(entry,data);
	    return entry;
	});
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

    rating: function(r,rd) {
	var fill_color = '#ff5533';
	var empty_color = '#3355ff';
	var stroke_color = fill_color;
	var cw = 160;
	var ch = 16;
	var rd_fill_left = cw * ( 0.5*r - 2.0 * rd ) / r;
	var rd_fill_width = cw * ( 4.0 * rd ) / r;
	var x0 =       rd_fill_width /  4.0,x1 = 3.0*rd_fill_width / 10.0,x2 = rd_fill_width / 2.0;
	var x3 = 2.0 * rd_fill_width / 10.0,x4 =     rd_fill_width /  4.0,x5 = rd_fill_width / 2.0;
	var move = 'm '+$.each([ rd_fill_left, ch ], function(i,v) { return Number(v).toFixed(2); }).reduce(function(a,b) { return a + ' ' + b; });
	var curve = 'c '+$.each([ x0, 0.0, x1, -ch, x2, -ch, x3, 0, x4, ch, x5, ch ], function(i,v) { return Number(v).toFixed(2); }).reduce(function(a,b) { return a + ' ' + b; });
	var result = $('<div class="rating"></div>');
	var svg = $('<svg style="width: '+cw+'px; height: '+ch+'px; background: '+empty_color+'"><path d="'+move+' '+curve+'" fill="'+fill_color+'" stroke="'+stroke_color+'" stroke-width="1">');
	result.append(svg);
	result.append('<span class="overlay">'+Number(r).toFixed(2)+'</span>');
	return result;
    },
    
};
