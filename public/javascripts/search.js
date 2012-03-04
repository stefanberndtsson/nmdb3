$(document).ready(function() {
	var minyear = parseInt($("#year_min").val());
	var maxyear = parseInt($("#year_max").val());
	var facet_minyear = parseInt($("#facet_year_min").val());
	var facet_maxyear = parseInt($("#facet_year_max").val());
	var range = facet_minyear + ".." + facet_maxyear;
	var range_text = facet_minyear + " and " + facet_maxyear;
	$("#year_link").text(range_text);
	document.getElementById("year_link").href = $("#year_link_template").attr("href").replace("%40%40%40REPLACE_RANGE%40%40%40", range);
	$("#year_range").slider({ 
		range: true, 
		    min: minyear, 
		    max: maxyear,
		    values: [ facet_minyear, facet_maxyear ],
		    slide: function(e, ui) {
		    var range = ui.values[0] + ".." + ui.values[1];
		    var range_text = ui.values[0] + " and " + ui.values[1];
		    $("#year_link").text(range_text);
		    document.getElementById("year_link").href = $("#year_link_template").attr("href").replace("%40%40%40REPLACE_RANGE%40%40%40", range);
		} 
	    });
    });

$(document).ready(function() {
	var minrating = parseInt($("#rating_min").val());
	var maxrating = parseInt($("#rating_max").val());
	var facet_minrating = parseInt($("#facet_rating_min").val());
	var facet_maxrating = parseInt($("#facet_rating_max").val());
	var range = facet_minrating + ".." + facet_maxrating;
	var range_text = (facet_minrating/10).toFixed(1) + " and " + (facet_maxrating/10).toFixed(1);
	$("#rating_link").text(range_text);
	document.getElementById("rating_link").href = $("#rating_link_template").attr("href").replace("%40%40%40REPLACE_RANGE%40%40%40", range);
	$("#rating_range").slider({ 
		range: true, 
		    min: minrating, 
		    max: maxrating,
		    values: [ facet_minrating, facet_maxrating ],
		    slide: function(e, ui) {
		    var range = ui.values[0] + ".." + ui.values[1];
		    var range_text = (ui.values[0]/10).toFixed(1) + " and " + (ui.values[1]/10).toFixed(1);
		    $("#rating_link").text(range_text);
		    document.getElementById("rating_link").href = $("#rating_link_template").attr("href").replace("%40%40%40REPLACE_RANGE%40%40%40", range);
		} 
	    });
    });

