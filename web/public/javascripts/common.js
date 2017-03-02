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
		} else if (field.hasClass('f__date')) {
		    $(field).html(new Date(value).toLocaleDateString());
		} else if (field.hasClass('f__time')) {
		    $(field).html(new Date(value).toLocaleTimeString());
		} else if (field.hasClass('f__duration')) {
		    $(field).html(Common.format_duration(value));
		} else if (field.hasClass('f__text')) {
		    $(field).html(Common.format_text(value));
		} else {
		    $(field).html(value);
		}
	    });
	});
    },

    scroll_table_multi: function(container,selectors,elements,line) {
	$(container).each(function(div_index,div) {
	    for(var selector in selectors) {
		var field_id = $(div).find(selector);
		if (field_id.length) {
		    var url = selectors[selector](field_id.attr('href'));
		    Common.scroll_table(div,url,elements,line);
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
	if (hours > 0) return hours + ':' + minutes + ':' + seconds;
	if (minutes > 0) return minutes + ':' + seconds;
	return seconds;
    },

    format_text: function(text) {
	return text
	    .replace(/\[(\S+?)\]/g,'<span class="smiley smiley_$1"></span>')
	    .replace(/\^(.)([^\^]*)/gi,function(match,color,content) {
		var n = (color.charCodeAt(0)-'0'.charCodeAt(0)) % 16;
		return '<span class="color'+n+'">'+content+'</span>';
	    });
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
   
};
/*
$(document).ready(function() {
    $('.fullheight').each(function(index) {
	$(this).height($(this).parent().height()+'px');
    });
});
*/
