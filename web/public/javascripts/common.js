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
                if (offset <= 0) {
                    table.find('.sticky').each(function() {
                        $(this).data('sticky',{
                            top: $(this).position().top,
                            offset: table.offset().top + $(this).position().top - table.offsetParent().offset().top
                        });
                    });
                }
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
            table.find('.sticky').each(function() {
                var sticky = $(this).data('sticky');
                if (top > sticky.top) {
                    $(this).addClass('hold');
                    $(this).offset({ top: table.offsetParent().offset().top + sticky.offset + top });
                } else {
                    $(this).removeClass('hold');
                }
            });
	    });
	    loadPage();
    },
    
    scroll_table: function(container,link,elements,line) {
	    container = $(container);
	    Common.scroll_container(container,container.find('table'),link,elements,line);
    },

    replaceField: function(field,value) {
	    if (field.is('span') && field.attr('class') == '') {
	        field.replaceWith(value);
	    } else {
	        field.html(value);
	    }
    },

    findFieldType: function(field) {
	    var numericTypes = new Map([
	        [ function(field) {
		        return field.hasClass('f__date') ||
		            field.hasClass('f__time') ||
		            field.hasClass('f__duration') ||
		            field.hasClass('f__duration_minutes') ||
		            field.hasClass('f__duration_date');
	        }, {
		        parseValue: function(value) { return new Date(value); }
	        } ],
	        [ function(field) { return true }, {
		        parseValue: function(value) { return new Number(value); }
	        } ]
	    ]);
	    for(var [test,fns] of numericTypes.entries()) {
	        if (test(field)) {
		        return fns;
	        }
	    }
	    return undefined;
    },

    loadFieldType: function(field) {
	    var fns = field.data('f__fieldType');
	    if (fns === undefined) {
	        fns = Common.findFieldType(field);
	        field.data('f__fieldType',fns);
	    }
	    return fns;
    },

    clearFieldType: function(field) {
	    field.removeData('f__fieldType');
    },

    loadFieldValues: function(selector,data) {
	    selector.find('.f__parent').each(function(index,parent) {
	        parent = $(parent);
	        parent.removeClass('f__parent');
	        $.each(data,function(name,value) {
		        var selectorName = 'f_'+name;
		        if (parent.hasClass(selectorName)) {
		            parent.removeClass(selectorName);
		            Common.loadFieldValues(parent,value);
		        }
	        });
	    });
	    $.each(data,function(name,value) {
	        var selectorName = 'f_'+name;
	        selector.find('.'+selectorName).each(function(field_index,field) {
		        // console.log("Loading field: f_"+name, field);
		        field = $(field);
		        field.removeClass(selectorName);
		        if (field.is('a')) {
		            if (value != null)
			            field.attr('href',value);
		            else
			            field.children().unwrap();
		        } else if (field.is('img')) {
		            if (value != null && value != "") {
			            field.attr('src',value);
			            field.parent().children('.imgNotFound').remove();
		            } else {
			            field.remove();
		            }
		        } else if (field.hasClass('f__sum') || field.hasClass('f__sub')) {
		            var fns = Common.loadFieldType(field);
		            var sum = field.data('f__sum');
		            var parsedValue = fns.parseValue(value);
		            if (sum === undefined) {
			            sum = parsedValue;
		            } else {
			            sum += parsedValue;
		            }
		            field.data('f__sum',sum);
		        } else {
		            Common.replaceField(field,value);
		        }
	        });
	    });
    },
   
    load_fields_generic: function(selector,data) {
	    // console.log("Loading generic fields: "+data._index);
	    // $.each(selector.find('a.data.field'),function(field_index,field) {
	    //     var name = field.attr('href');
	    //     if (_.has(data,name)) {
	    // 	$(field).replaceWith(data[name]);
	    //     }
	    // });
	    Common.loadFieldValues(selector,data);
	    selector.find('.f__img').each(function(index,field) {
	        field = $(field);
	        field.removeClass('f__img');
	        var commonStyle='display: inline-block; background: black';
	        field.attr('style',commonStyle);
	    });
	    selector.find('.f__sum').each(function(index,field) {
	        field = $(field);
	        field.removeClass('f__sum');
	        var sum = field.data('f__sum');
	        field.removeData('f__sum');
	        Common.replaceField(field,sum);
	    });
	    selector.find('.f__sub').each(function(index,field) {
	        field = $(field);
	        field.removeClass('f__sub');
	        var fns = Common.loadFieldType(field);
	        var sum = fns.parseValue(field.text()) - field.data('f__sum');
	        field.removeData('f__sum');
	        Common.clearFieldType(field);
	        Common.replaceField(field,sum);
	    });
	    selector.find('.f__date').each(function(field_index,field) {
	        field = $(field);
	        field.removeClass('f__date');
	        Common.replaceField(field,new Date($(field).text()).toLocaleDateString());
	    });
	    selector.find('.f__time').each(function(field_index,field) {
	        field = $(field);
	        field.removeClass('f__time');
	        Common.replaceField(field,new Date($(field).text()).toLocaleTimeString());
	    });
	    selector.find('.f__utcdate').each(function(field_index,field) {
	        field = $(field);
	        field.removeClass('f__utcdate');
	        Common.replaceField(field,new Date(field.text()).toUTCString().replace(' GMT',''));
	    });
	    selector.find('.f__duration').each(function(field_index,field) {
	        field = $(field);
	        field.removeClass('f__duration');
	        Common.replaceField(field,Common.format_duration(field.text()));
	    });
	    selector.find('.f__duration_minutes').each(function(field_index,field) {
	        field = $(field);
	        field.removeClass('f__duration_minutes');
	        Common.replaceField(field,Common.format_duration_minutes(field.text()));
	    });
	    selector.find('.f__duration_date').each(function(field_index,field) {
	        field = $(field);
	        field.removeClass('f__duration_date');
	        Common.replaceField(field,Common.format_duration_minutes(new Number(field.text()).valueOf() / 1000.0));
	    });
	    selector.find('.f__text').each(function(field_index,field) {
	        field = $(field);
	        field.removeClass('f__text');
	        Common.replaceField(field,Common.format_text(field.text()));
	    });
	    selector.find('.f__bar').each(function(field_index,field) {
	        field = $(field);
	        field.removeClass('f__bar');
	        var neutral = field.find('.bar_neutral');
	        neutral = neutral.length ? neutral.text() : null;
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
	        var neutral_color = field.find('.bar_neutralcolor');
	        neutral_color = neutral_color.length ? neutral_color.text() : null;
            var center_fill_text = field.hasClass('.bar_center_text');
	        Common.replaceField(field,Common.bar({
		        value: field.find('.bar_value').text(),
		        total: field.find('.bar_total').text(),
		        neutral: neutral,
		        text: text,
		        prefix: prefix,
		        suffix: suffix,
		        fill_color: fill_color,
		        empty_color: empty_color,
		        neutral_color: neutral_color,
                center_fill_text: center_fill_text
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

    scroll_table_generic_multi: function(container,selectors,elements) {
	    $(container).each(function(div_index,div) {
	        for(var selector in selectors) {
		        var field_id = $(div).find(selector);
		        if (field_id.length) {
		            var url = selectors[selector](field_id.attr('href'));
		            field_id.remove();
		            Common.scroll_table_generic(div,url,elements);
		            return;
		        }
	        }
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

    format_duration_hm: function(seconds)
    {
	    seconds = Number(seconds);
	    var hours = Math.floor(seconds / 3600.0);
	    seconds -= 3600.0 * hours;
	    var minutes = Math.floor(seconds / 60.0);
	    minutes = (minutes > 0) ? ((hours > 0) ? ' ' : '') + minutes + 'min' : '';
	    hours = (hours > 0) ? hours + 'h' : '';
	    return hours + minutes;
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

    roundTo: function(v,m) {
	    return Math.round(v / m) * m;
    },

    rating_size: function(aspect,margin) {
	    var a = (typeof aspect !== 'undefined') ? aspect : 4.0;
	    var m = (typeof margin !== 'undefined') ? margin : 0.1;
	    var ce = $('#page');
        var pa = ce.width() / ce.height();
        if (pa < a) {
	        wh = ce.height() / 8;
            ww = a * wh;
        } else {
            ww = ce.width() / 4;
            wh = ww / a;
        }
	    var ca = a - m;
	    var window_a = ww / wh;
	    if (ca < window_a) {
	        var ch = Common.roundTo(wh, 8);
	        return [ Common.roundTo(ch * ca, 16), ch ];
	    } else {
	        var cw = Common.roundTo(ww, 16);
	        return [ cw, Common.roundTo(cw / ca, 8) ];
	    }
    },

    bar_size: function() {
	    var [w,h] = Common.rating_size(8.0);
	    return [0.5*w,0.5*h];
    },

    image_size: function() {
	    var [w,h] = Common.rating_size(8.0);
	    return [0.25*w,1.2*h];
    },

    rating: function(g) {
	    var [cw,ch] = Common.rating_size();
	    if (g.update_count > 0) {
	        var rangeMin = Number(g.min_range);
	        var rangeMax = Number(g.max_range);
	        var rangeDelta = rangeMax - rangeMin;
	        //var rMin = Number(g.min_rating);
	        //var rMax = Number(g.max_rating);
	        //var rDelta = rMax - rMin;
	        var r = Number(g.rating);
	        var rd = Number(g.rd);
	        var rdScale = 0.5; // rd / (rangeDelta - 3/2 * rDelta);
	        var fill_color = 'rgba(100,63,51,0.66)';
	        var empty_color = 'transparent';
	        var stroke_color = '#642e1d';
	        var rd_fill_left = cw * (r - rangeMin - (2.0/* - 0.25*/) * rd * rdScale) / rangeDelta;
	        var rd_fill_width = cw * (4.0 * rd * rdScale) / rangeDelta;
	        var x0 =       rd_fill_width /  4.0,x1 = 3.0*rd_fill_width / 10.0,x2 = rd_fill_width / 2.0;
	        var x3 = 2.0 * rd_fill_width / 10.0,x4 =     rd_fill_width /  4.0,x5 = rd_fill_width / 2.0;
	        var move = 'm '+$.each([ rd_fill_left, ch ], function(i,v) { return Number(v).toFixed(2); }).reduce(function(a,b) { return a + ' ' + b; });
	        var curve = 'c '+$.each([ x0, 0.0, x1, -ch, x2, -ch, x3, 0, x4, ch, x5, ch ], function(i,v) { return Number(v).toFixed(2); }).reduce(function(a,b) { return a + ' ' + b; });
	        var rd_fill_middle = rd_fill_left + 0.5 * rd_fill_width;
	        var extra = '';//'m '+rd_fill_middle.toFixed(2)+' 0 l '+rd_fill_middle.toFixed(2)+' '+ch.toFixed(2);
	        var graph = move+' '+curve+' '+extra;
	        var result = $('<div class="rating"></div>');
            var fontSize = '2.5em';
            var ratingStyle = 'font-size: '+fontSize+'; fill: white'; // Number(ch/3).toFixed(2)+'px';
            var infoStyle = 'font-size: 0.6em; fill: #dfdddc';
            var text = '';
            text += '<text style="'+infoStyle+'" text-anchor="start" dominant-baseline="hanging" x="0.5%" y="2%">'+rangeMin.toFixed(2)+'</text>';
            text += '<text style="'+infoStyle+'" text-anchor="end" dominant-baseline="hanging" x="99.5%" y="2%">'+rangeMax.toFixed(2)+'</text>';

            text += '<text style="'+infoStyle+'" text-anchor="start" dominant-baseline="bottom" x="'+(0.5 + (r-rd-rangeMin)/rangeDelta*99.0).toFixed(2)+'%" y="98%">'+(r - rd).toFixed(2)+'</text>';
            text += '<text style="'+infoStyle+'" text-anchor="end" dominant-baseline="bottom" x="'+(0.5 + (r+rd-rangeMin)/rangeDelta*99.0).toFixed(2)+'%" y="98%">'+(r + rd).toFixed(2)+'</text>';
            text += '<text style="'+ratingStyle+'" text-anchor="middle" dominant-baseline="middle" x="50%" y="50%">'+r.toFixed(2)+'</text>';
	        var svg = $('<svg width="'+cw+'" height="'+ch+'" viewbox="0 0 '+cw+' '+ch+'" style="background: '+empty_color+'"><path d="'+graph+'" fill="'+fill_color+'" stroke="'+stroke_color+'" stroke-width="1"></path>'+text+'</svg>');
	        result.append(svg);
	        return result;
	    } else {
            var empty_color = 'transparent';
            var fill_color = '#6f6767';
            var text = '<text style="font-size: '+fontSize+'; fill: '+fill_color+'" text-anchor="middle" dominant-baseline="middle" x="50%" y="50%">N/A</text>';
            return $('<div class="rating"><svg width="'+cw+'" height="'+ch+'" viewbox="0 0 '+cw+' '+ch+'" style="background: '+empty_color+'">'+text+'</svg></div>');
        }
    },
    
    bar: function(params) {
        // TODO: Rename centerText as it's used to override default layout such that fill% is always shown but always at center
	    var [cw,ch] = Common.bar_size();
	    var fill_color = params.fill_color || '#3355ff';
	    var empty_color = params.empty_color || '#ff5533';
	    var neutral_color = params.neutral_color || '#555555';
	    var resultWrapper = $('<div class="field barWithCaptions"></div>');
	    var result = $('<div class="bar"></div>');
        var centerText = Common.isDefined(params.center_fill_text);
	    var hasText = Common.isDefined(params.text);
	    var total = Number(params.total);
        var svg = '';
	    if (total > 0.0) {
	        var fill = 100.0 * Number(params.value) / total;
	        var neutral = Common.isDefined(params.neutral) ? 100.0 * Number(params.neutral) / total : 0.0;
	        var empty = 100.0 - fill - neutral;
	        var fill_text = hasText ? '' : ((fill >= 33.0 || centerText) ? fill.toFixed(2)+'%' : '');
	        var empty_text = hasText ? '' : ((empty >= 33.0 && !centerText) ? empty.toFixed(2)+'%' : '');
	        var neutral_text = hasText ? '' : ((neutral >= 33.0 && !centerText) ? neutral.toFixed(2)+'%' : '');

            svg += '<svg width="'+cw+'" height="'+ch+'" viewbox="0 0 '+cw+' '+ch+'">';
            svg += '<rect x="0" y="0" width="'+Number(fill).toFixed(2)+'%" height="100%" fill="'+fill_color+'"></rect>';

            if (!centerText) {
                if (fill_text != "") {
                    svg += '<text x="'+Number(fill/2).toFixed(2)+'%" y="50%" dominant-baseline="middle" text-anchor="middle" style="font-size: '+Number(ch/3).toFixed(2)+'px; fill: white">'+fill_text+'</text>';
                }
                if (neutral > 0.0) {
                    svg += '<rect x="'+Number(fill).toFixed(2)+'%" y="0" width="'+Number(neutral).toFixed(2)+'%" height="100%" fill="'+neutral_color+'"></rect>';
                    if (neutral_text != "") {
                        svg += '<text x="'+Number(fill + neutral/2).toFixed(2)+'%" y="50%" dominant-baseline="middle" text-anchor="middle" style="font-size: '+Number(ch/3).toFixed(2)+'px; fill: white">'+neutral_text+'</text>';
                    }
                }
                svg += '<rect x="'+Number(fill+neutral).toFixed(2)+'%" y="0" width="'+Number(empty).toFixed(2)+'%" height="100%" fill="'+empty_color+'"></rect>';
                if (empty_text != "") {
                    svg += '<text x="'+Number(fill+neutral+empty/2).toFixed(2)+'%" y="50%" dominant-baseline="middle" text-anchor="middle" style="font-size: '+Number(ch/3).toFixed(2)+'px; fill: white">'+empty_text+'</text>';
                }
            } else {
                svg += '<text x="50%" y="50%" dominant-baseline="middle" text-anchor="middle" style="font-size: '+Number(ch/3).toFixed(2)+'px; fill: white">'+fill_text+'</text>';
            }
	    } else {
            //var empty_color = 'transparent';
            //var fill_color = '#6f6767';
            var text = '<text style="font-size: '+Number(ch/3).toFixed(2)+'px; fill: white" text-anchor="middle" dominant-baseline="middle" x="50%" y="50%">N/A</text>';
            svg += '<svg width="'+cw+'" height="'+ch+'" viewbox="0 0 '+cw+' '+ch+'" style="background: '+empty_color+'">'+text;
	    }
        if (hasText) {
            //var empty_color = 'transparent';
            //var fill_color = '#6f6767';
            svg += '<text style="font-size: '+Number(ch/3).toFixed(2)+'px; fill: white" text-anchor="middle" dominant-baseline="middle" x="50%" y="50%">'+params.text+'</text>';      
        }
        svg += '</svg>';
        result.append($(svg));
	    if (Common.isDefined(params.prefix)) {
            resultWrapper.append('<span class="prefix">'+params.prefix+'</span>');
        }
	    resultWrapper.append(result);
	    if (Common.isDefined(params.suffix)) {
            resultWrapper.append('<span class="suffix">'+params.suffix+'</span>');
        }
	    return resultWrapper;
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
        var [cw,ch] = Common.rating_size();
	    return [].concat(
	        '<svg xmlns="http://www.w3.org/2000/svg"  >', // width="'+cw+'" height="'+ch+'"
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
		        field.outerHeight(field.parent().outerHeight());
		        field.outerWidth(Math.min(field.parent().outerWidth(), $('#page').innerWidth()));
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
