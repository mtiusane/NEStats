Common = {

    scroll_container: function(container,table,link,elements,line) {
	container = $(container);
	table = $(table);
	var scroll = container.jScrollPane({
	    autoReinitialise: false,
	    showArrows: false,
	    maintainPosition: true,
	    verticalGutter: 0,
	    horizontalGutter: 0,
	    contentWidth: '100%'
	}).data('jsp');
	var template = table.find('.template').detach();
	template.removeClass('template');
	var thead = table.find('thead');
	var tbody = table.find('tbody');
	var loadPage = function(callback) {
	    var offset = table.data('offset');
	    var total = table.data('total');
	    var limit = table.data('limit');
	    var lastLoad = table.data('lastLoad');
	    table.data('loading',true);
	    $.get(link(offset,limit),function(data) {
		var lines = elements(data);
		$.each(lines,function(index,element) {
		    tbody.append(line(template,element,offset+index));
		});
		table.data('total',data.total);
		table.data('offset',table.data('offset')+lines.length);
		table.data('loading',false);
		table.data('lastLoad',(new Date()).getTime());
		var oldWidth = table.width();
		scroll.reinitialise();
		table.width(oldWidth,true); /* TODO: Without this the table keeps getting +10px at every new content row if scrolled to the rightmost position. */
		if (callback) callback();
	    });
	};
	table.data('offset',0);
	table.data('total',0);
	table.data('limit',25);
	table.data('lastLoad',(new Date()).getTime());
	container.bind('jsp-scroll-y',function(event,top,isAtTop,isAtBottom) {
	    var timeSinceLastLoad = (new Date()).getTime() - table.data('lastLoad');
	    if (table.data('offset') < table.data('total') && !table.data('loading') &&
		timeSinceLastLoad >= 500 && isAtBottom) {
		loadPage();
	    }
	    /*
	    thead.css({
		position: 'absolute',
		top: top
	    });
	    tbody.css({
		position: 'absolute',
		top: thead.height(),
		width: '100%'
	    });
	    */
	});
	loadPage();
    },
    
    scroll_table: function(container,link,elements,line) {
	container = $(container);
	Common.scroll_container(container,container.find('table'),link,elements,line);
    },
   
    load_fields_generic: function(selector,data) {
	// $.each(selector.find('a.data.field'),function(field_index,field) {
	//     var name = field.attr('href');
	//     if (_.has(data,name)) {
	// 	$(field).replaceWith(data[name]);
	//     }
	// });
	
	$.each(data,function(name,value) {
	    // console.log("Finding: "+name);
	    selector.find('.f_'+name).each(function(field_index,field) {
		// console.log("Loading field: f_"+name, field);
		field = $(field);
		if (field.is('a')) {
		    if (value != null)
			field.attr('href',value);
		    else
			field.children().unwrap();
		} else if (field.hasClass('f__sum')) {
		    var sum = field.data('f__sum');
		    if (sum === undefined) sum = 0.0;
		    sum += Number(value);
		    field.data('f__sum',sum);
		    field.html(sum);
		} else {
		    $(field).html(value);
		}
	    });
	});
	selector.find('.f__date').each(function(field_index,field) {
	    $(field).html(new Date($(field).text()).toLocaleDateString());
	});
	selector.find('.f__time').each(function(field_index,field) {
	    $(field).html(new Date($(field).text()).toLocaleTimeString());
	});
	selector.find('.f__duration').each(function(field_index,field) {
	    $(field).html(Common.format_duration($(field).text()));
	});
	selector.find('.f__duration_minutes').each(function(field_index,field) {
	    $(field).html(Common.format_duration_minutes($(field).text()));
	});
	selector.find('.f__text').each(function(field_index,field) {
	    $(field).html(Common.format_text($(field).text()));
	});
	selector.find('.f__bar').each(function(field_index,field) {
	    field = $(field);
	    var text = field.find('.bar_text');
	    text = text.length ? text.html() : null;
	    var prefix = field.find('.bar_prefix');
	    prefix = prefix.length ? prefix.html() : null;
	    var suffix = field.find('.bar_suffix');
	    suffix = suffix.length ? suffix.html() : null;
	    var fill_color = field.find('.bar_fillcolor');
	    fill_color = fill_color.length ? fill_color.text() : null;
	    var empty_color = field.find('.bar_emptycolor');
	    empty_color = empty_color.length ? empty_color.text() : null;
	    $(field).html(Common.bar2({
		value: field.find('.bar_value').text(),
		total: field.find('.bar_total').text(),
		text: text,
		prefix: prefix,
		suffix: suffix,
		fill_color: fill_color,
		empty_color: empty_color
	    }));
	});
    },

    scroll_table_multi: function(container,selectors,elements,line) {
	$(container).each(function(div_index,div) {
	    for(var selector in selectors) {
		var field_id = $(div).find(selector);
		if (field_id.length) {
		    var url = selectors[selector](field_id.attr('href'));
		    Common.scroll_table(div,url,elements,line);
		    field_id.remove();
		    return;
		}
	    }
	});
    },

    scroll_table_generic: function(container,link,elements) {
    	Common.scroll_table(container,link,elements,function(template,data,index) {
	    var entry = template.clone();
	    data._index = 1+index;
	    Common.load_fields_generic(entry,data);
	    return entry;
	});
    },

    format_percent: function(value) {
	return Number(100.0 * value).toFixed(2) + '%';
    },

    format_duration: function(seconds) {
	seconds = Number(seconds);
	var hours = Math.floor(seconds / 3600.0);
	seconds -= 3600.0 * hours;
	var minutes = Math.floor(seconds / 60.0);
	seconds -= 60.0 * minutes;
	seconds = Math.floor(seconds);
	seconds = (seconds > 0) ? ((minutes > 0) ? ' ' : '') + seconds + 's' : '';
	minutes = (minutes > 0) ? ((hours > 0) ? ' ' : '') + minutes + 'min' : '';
	hours = (hours > 0) ? hours + 'h' : '';
	return hours + minutes + seconds;
    },

    format_duration_minutes: function(seconds) {
	return Common.format_duration(Math.ceil(Number(seconds) / 60.0) * 60.0);
    },

    format_text: function(text) {
	return '<span class="color7">'+text
	    .replace(/\[(\S+?)\]/g,'<span class="smiley smiley_$1"></span>')
	    .replace(/\^(.)([^\^]*)/gi,function(match,color,content) {
		var n = (color.charCodeAt(0)-'0'.charCodeAt(0)) % 16;
		return '<span class="color'+n+'">'+content+'</span>';
	    })+'</span>';
    },

    format_outcome: function(outcome) {
    	return '<span class="'+outcome+'">'+outcome+'</span>';
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

    bar: function(value,total,text,prefix,suffix,fill_color,empty_color) {
	if (!Common.isDefined(fill_color)) var fill_color = '#3355ff';
	if (!Common.isDefined(empty_color)) var empty_color = '#ff5533';
	var resultWrapper = $('<div style="min-width: 200px"></div>');
	var result = $('<div class="bar"></div>');
	if (total > 0.0) {
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
	if (Common.isDefined(text)) result.append('<span class="overlay">'+text+'</span>');
	if (Common.isDefined(prefix)) resultWrapper.append('<div class="prefix">'+prefix+'</div>');
	resultWrapper.append(result);
	if (Common.isDefined(suffix)) resultWrapper.append('<div class="suffix">'+suffix+'</div>');
	return resultWrapper;
    },

    bar2: function(params) {
	return Common.bar(params.value,params.total,params.text,params.prefix,params.suffix,params.fill_color,params.empty_color);
    },

    rating: function(g,w,h) {
	var cw = (typeof w !== 'undefined') ? w : 160;
	var ch = (typeof h !== 'undefined') ? h : 16;
	var commonStyle='width: '+cw+'px; height: '+ch+'px; line-height: '+ch+'px';
	if (g.update_count > 0) {
	    var rangeMin = Number(g.min_range);
	    var rangeMax = Number(g.max_range);
	    var rangeDelta = rangeMax - rangeMin;
	    var rMin = Number(g.min_rating);
	    var rMax = Number(g.max_rating);
	    var rDelta = rMax - rMin;
	    var r = Number(g.rating);
	    var rd = Number(g.rd);
	    var rdScale = rd / (rangeDelta - rDelta);
	    var fill_color = 'rgba(100,63,51,0.66)';
	    var empty_color = 'transparent';
	    var stroke_color = '#642e1d';
	    var rd_fill_left = cw * (r - rangeMin - (2.0 - 0.25) * rd * rdScale) / rangeDelta;
	    var rd_fill_width = cw * (4.0 * rd * rdScale) / rangeDelta;
	    var x0 =       rd_fill_width /  4.0,x1 = 3.0*rd_fill_width / 10.0,x2 = rd_fill_width / 2.0;
	    var x3 = 2.0 * rd_fill_width / 10.0,x4 =     rd_fill_width /  4.0,x5 = rd_fill_width / 2.0;
	    var move = 'm '+$.each([ rd_fill_left, ch ], function(i,v) { return Number(v).toFixed(2); }).reduce(function(a,b) { return a + ' ' + b; });
	    var curve = 'c '+$.each([ x0, 0.0, x1, -ch, x2, -ch, x3, 0, x4, ch, x5, ch ], function(i,v) { return Number(v).toFixed(2); }).reduce(function(a,b) { return a + ' ' + b; });
	    var rd_fill_middle = rd_fill_left + 0.5 * rd_fill_width;
	    var extra = '';//'m '+rd_fill_middle.toFixed(2)+' 0 l '+rd_fill_middle.toFixed(2)+' '+ch.toFixed(2);
	    var graph = move+' '+curve+' '+extra;
	    var result = $('<div style="'+commonStyle+'" class="rating"></div>');
	    var svg = $('<svg style="'+commonStyle+'; background: '+empty_color+'"><path d="'+graph+'" fill="'+fill_color+'" stroke="'+stroke_color+'" stroke-width="1">');
	    result.append(svg);
	    result.append('<span style="'+commonStyle+'" class="overlay">'+Number(r).toFixed(2)+'</span>');
	    return result;
	} else return $('<div style="'+commonStyle+'" class="rating">N/A</div>');
    },

    extractIcons: function(text, color) {
	/*
	var parts = [ ];
	var start = 0;
	while(start < text.length) {
	    var next = text.indexOf('[', start);
	    var 
	}
*/
    },

    extractColors: function(text) {
	var parts = [ ];
	var start=0;
	var color='7';
	while(start < text.length) {
	    var next = text.indexOf('^', start);
	    if (next != -1) {
		if (next > start) parts.push({ color: color, text: text.substr(start, next-start) });
		color = text.charAt(next+1);
		start = next+2;
	    } else {
		parts.push({ color: color, text: text.substr(start) });
		start = text.length;
	    }
	}
	return parts;
    },

    combineTextFromColors: function(parts) {
	return $.map(parts, function(p) { return p.text; }).join('');
    },

    stripColors: function(text) {
	return Common.combineTextFromColors(Common.extractColors(text));
    },

    mapColor: function(color) {
	var index = (color.charCodeAt(0)-'0'.charCodeAt(0)) % 16;
	var colors = [
	    '#333333', '#ff0000', '#00ff00', '#ffff00',
	    '#0000ff', '#00ffff', '#ff00ff', '#ffffff',
	    '#ff7f00', '#7f7f7f', '#ff9919', '#007f7f',
	    '#7f007f', '#007fff', '#7f00ff', '#3399cc'
	];
	return colors[index];
    },
    
    generateFillStyle: function(canvas,text) {
	var parts = Common.extractColors(text);
	var letters = Common.combineTextFromColors(parts);
	var ctx = $(canvas)[0].getContext("2d");
	var width = ctx.measureText(letters).width;
	var gradient = ctx.createLinearGradient(0,0,width,0);
	var offset = Number(0.0);
	for(var i=0;i<parts.length;++i) {
	    gradient.addColorStop(offset, Common.mapColor(parts[i].color));
	    offset += Number(parts[i].text.length)/Number(letters.length);
	}
	return gradient;
    },

    wrapSVG: function(text) {
	return [].concat(
	    '<svg xmlns="http://www.w3.org/2000/svg" width="200" height="200">',
	    '<foreignObject width="100%" height="100%">',
	    '<div xmlns="http://www.w3.org/1999/xhtml" style="font-size:40px">',
	    text,
	    '</div>',
	    '</foreignObject>',
	    '</svg>'
	);
    },

    disableScroll: function() {
	var content = $('#content_wrapper.jspScrollable:first');
	var container = content.find('.jspContainer');
	var jsp = content.data('jsp');
	if (jsp !== undefined) {
	    jsp.disableMouseWheel();
	}
    },
    
    enableScroll: function() {
	var content = $('#content_wrapper.jspScrollable:first');
	var jsp = content.data('jsp');
	if (jsp !== undefined) {
	    jsp.enableMouseWheel();
	}
    },  

    updateFullSize: function(menu,page) {
	$('.jspScrollable').each(function(index,field) {
	    field = $(field);
	    var jsp = field.data('jsp');
	    if (jsp !== undefined) {
		// field.outerHeight(field.parent().innerHeight());
		// field.outerWidth(field.parent().innerWidth());
		jsp.reinitialise();
	    }
	});
    }
   
};

$(document).ready(function() {
    var win = $(window);
    var menu = $('#menu');
    var page = $('#page');
    var content = $('#content_wrapper');
    var isResizing = false;
    win.bind('resize',function() {
	if (!isResizing) {
	    isResizing = true;
	    content.css({ width: 1, height: 1 });
	    content.css({ width: page.width(), height: page.height() });
	    isResizing = false;
	    content.jScrollPane({ showArrows: true });
	    // Common.updateFullSize(menu,page);
	}
    }).trigger('resize');
    page.css('overflow','hidden');
    /* IE fix, retrigger due to incorrect initial size */
    if (content.width() != page.width()) {
	win.trigger('resize');
    }
});
