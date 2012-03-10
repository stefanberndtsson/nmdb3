// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

function toggle_hidden(hidden_id) {
    var tds = document.getElementsByTagName("tr");
    for(var i=0; i<tds.length;i++) {
        if(tds[i].getAttribute("class") == ("body hidden "+hidden_id)) {
            tds[i].style.display = 'table-row';
        }
    }
    var links = document.getElementsByTagName("a");
    for(var i=0; i<links.length;i++) {
        if(links[i].getAttribute("class") == ("show_link_"+hidden_id)) {
            links[i].style.display = 'none';
        }
    }
}

jQuery(function($) {
    $(document).ready(function(event) {
	var update = $(".ajax_person_image").attr("update");
	var update_menuitem = $(".ajax_person_image").attr("update_menuitem");
	if(update) {
	    $('#spinner').show();
	    $.ajax({
		type: "POST",
		url: $(".ajax_person_image").attr("url"),
		success: function(data) {
		    $('#spinner').hide();
		    $('#'+update_menuitem).html(data.menuitem);
		    $('#'+update_menuitem).attr("class", "unselected");
		    $('#'+update).hide().html(data.image).fadeIn(500);
		}
	    });
	}
    });
});

jQuery(function($) {
	$(document).ready(function(event) {
		var update = $(".ajax_wikipedia_image").attr('update');
		var update_title = $(".ajax_wikipedia_image").attr('update_title');
		if(update) {
		    $('#spinner').show();
		    $.ajax({
			    type: "POST",
				url: $(".ajax_wikipedia_image").attr('url'),
				success: function(data) {
				$('#spinner').hide();
				$("#"+update).hide().html(data).fadeIn(500);
				if(update_title) {
				    $.ajax({
					    type: "POST",
						url: $(".ajax_wikipedia_image").attr('url_title'),
						success: function(data) {
						$("."+update_title).html(data);
						$("title").html("[N] "+data);
					    }
					});
				}
			    }
			});
		}
	    });
    });

jQuery(function($) {
	$(document).ready(function(event) {
		var update = $(".ajax_wikipedia_image_title").attr('update');
		var update_title = $(".ajax_wikipedia_image_title").attr('update_title');
		if(update) {
		    $.ajax({
			    type: "POST",
				url: $(".ajax_wikipedia_image_title").attr('url'),
				success: function(data) {
				if(update_title) {
				    $.ajax({
					    type: "POST",
						url: $(".ajax_wikipedia_image_title").attr('url_title'),
						success: function(data) {
						$("."+update_title).html(data);
						$("title").html("[N] "+data);
					    }
					});
				}
			    }
			});
		}
	    });
    });

jQuery(function($) {
	$(document).ready(function(event) {
		var update = $("#dym_movie").attr('update');
		if(update) {
		    $.ajax({
			    type: "POST",
				url: $("#dym_movie").attr('url'),
				success: function(data) {
				$("#"+update).hide().html(data).fadeIn(500);
			    }
			});
		}
	    });
    });

jQuery(function($) {
	$(document).ready(function(event) {
		var update = $("#dym_person").attr('update');
		if(update) {
		    $.ajax({
			    type: "POST",
				url: $("#dym_person").attr('url'),
				success: function(data) {
				$("#"+update).hide().html(data).fadeIn(500);
			    }
			});
		}
	    });
    });

jQuery(function($) {
	$('.update_toggle').click(function(event) {
		var update = $(this).attr('update');
		if(update) {
		    $.ajax({
			    type: "POST",
				url: $(this).attr('url'),
				success: function(data) {
				$("#"+update).html(data);
			    }
			});
		}
	    });
    });

/*
$(document).ready(function() 
    { 
        $("#user_movielist").tablesorter(); 
    } 
); 
*/

function image_loading_error(reseturl) {
    window.location = reseturl;
}

jQuery(function($) {
    var url = $('.autocomplete_search').attr('data-url');
    $('.autocomplete_search').result(function(event, data, formatted) {
	var data_value = data[0];
	if(data_value.substring(0,3) == "<b>") {
	    data_value = data_value.substring(3,data_value.length-4);
	}
	$('.autocomplete_search').val(data_value);
	window.location=data[1];
    });
    $('.autocomplete_search').autocomplete(url, {
	max: 10,
	delay: 150,
	cacheLength: 0,
	width: 650,
	minChars: 3,
	selectFirst: false,
	highlight: false,
    });
});